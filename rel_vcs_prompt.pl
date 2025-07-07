#!/usr/bin/env perl
use strict;
use warnings;
use Cwd 'abs_path';
use File::Spec::Functions qw(splitdir catdir);

my $pwd = $ENV{PWD} || '.';
my $home = $ENV{HOME} || '';

sub find_vcs_stack {
    my ($dir) = @_;
    my @vcs_stack;
    
    while ($dir ne '/' && $dir ne '') {
        for my $vcs (['jj', '.jj'], ['git', '.git'], ['repo', '.repo']) {
            if (-d "$dir/$vcs->[1]") {
                my $name = (split '/', $dir)[-1];
                push @vcs_stack, "$vcs->[0]:$dir:$name";
                last;
            }
        }
        $dir =~ s{/[^/]*$}{} or last;
    }
    return @vcs_stack;
}

sub get_vcs_color {
    my ($type) = @_;
    return $type eq 'git' ? '%F{blue}' : 
           $type eq 'jj' ? '%F{magenta}' : 
           $type eq 'repo' ? '%F{green}' : '';
}

sub truncate_path_component {
    my ($part) = @_;
    if ($part =~ /^\.(.+)/) {
        return "." . substr($1, 0, 1) if length($1) > 0;
        return ".";
    }
    return substr($part, 0, 1);
}

sub check_vcs_in_path {
    my ($path) = @_;
    return ('git', 1) if -d "$path/.git";
    return ('repo', 1) if -d "$path/.repo";
    return ('jj', 1) if -d "$path/.jj";
    return ('', 0);
}

sub is_vcs_root {
    my ($name, $vcs_stack_ref) = @_;
    for my $vcs (@$vcs_stack_ref) {
        my (undef, undef, $vcs_name) = split ':', $vcs;
        return (split ':', $vcs)[0] if $vcs_name eq $name;
    }
    return '';
}

sub process_vcs_path {
    my ($vcs_stack_ref) = @_;
    my @prompt_parts;
    
    # Get outermost VCS
    my $outermost = $vcs_stack_ref->[-1];
    my ($type, $root, $name) = split ':', $outermost;
    my $color = get_vcs_color($type);
    push @prompt_parts, "%{%B${color}%}${name}%{%f%b%}";
    
    # Calculate relative path
    my $rel_path = $pwd;
    $rel_path =~ s{^\Q$root\E/?}{};
    return join('/', @prompt_parts) unless $rel_path;
    
    my @parts = split '/', $rel_path;
    
    if (@parts > 1) {
        my @truncated;
        
        # Process intermediate parts
        for my $i (0..$#parts-1) {
            my $part = $parts[$i];
            my $full_path = $root;
            for my $j (0..$i) {
                $full_path .= "/$parts[$j]";
            }
            
            my ($vcs_type, $has_vcs) = check_vcs_in_path($full_path);
            if ($has_vcs) {
                my $vcs_color = get_vcs_color($vcs_type);
                push @truncated, "%{%B${vcs_color}%}${part}%{%f%b%}";
            } else {
                push @truncated, truncate_path_component($part);
            }
        }
        
        # Handle last part
        my $last_part = $parts[-1];
        my $vcs_type = is_vcs_root($last_part, $vcs_stack_ref);
        if ($vcs_type) {
            my $vcs_color = get_vcs_color($vcs_type);
            push @truncated, "%{%B${vcs_color}%}${last_part}%{%f%b%}";
        } else {
            push @truncated, $last_part;
        }
        
        push @prompt_parts, join('/', @truncated);
    } else {
        # Single part
        my $vcs_type = is_vcs_root($rel_path, $vcs_stack_ref);
        if ($vcs_type) {
            my $vcs_color = get_vcs_color($vcs_type);
            push @prompt_parts, "%{%B${vcs_color}%}${rel_path}%{%f%b%}";
        } else {
            push @prompt_parts, $rel_path;
        }
    }
    
    return join('/', @prompt_parts);
}

sub process_regular_path {
    my $p = $pwd;
    
    # Handle home directory
    return '~' if $p eq $home;
    $p =~ s{^\Q$home\E}{~} if $home && $p =~ /^\Q$home\E\//;
    
    my $is_absolute = $p =~ m{^/};
    my @parts = split '/', $p;
    
    return $p if @parts <= 1;
    
    my @truncated;
    
    # Handle first component
    if ($is_absolute) {
        push @truncated, truncate_path_component($parts[0]) if $parts[0];
    } else {
        push @truncated, $parts[0] eq '~' ? '~' : truncate_path_component($parts[0]);
    }
    
    # Truncate intermediate components
    for my $i (1..$#parts-1) {
        push @truncated, truncate_path_component($parts[$i]);
    }
    
    # Keep last component full
    push @truncated, $parts[-1];
    
    my $result = join('/', @truncated);
    return $is_absolute ? "/$result" : $result;
}

# Main execution
my @vcs_stack = find_vcs_stack($pwd);

if (@vcs_stack) {
    print process_vcs_path(\@vcs_stack);
} else {
    print process_regular_path();
}