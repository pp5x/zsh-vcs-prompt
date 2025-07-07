setopt PROMPT_SUBST
setopt PROMPT_PERCENT
prompt_pwd() {
    local current_dir="$PWD"
    local vcs_stack=()  # Stack to hold VCS info: "type:root:name"
    
    # Search upward for version control directories
    while [[ "$current_dir" != "/" && "$current_dir" != "" ]]; do
        if [[ -d "$current_dir/.jj" ]]; then
            vcs_stack+=("jj:$current_dir:${current_dir##*/}")
        elif [[ -d "$current_dir/.git" ]]; then
            vcs_stack+=("git:$current_dir:${current_dir##*/}")
        elif [[ -d "$current_dir/.repo" ]]; then
            vcs_stack+=("repo:$current_dir:${current_dir##*/}")
        fi
        current_dir="${current_dir%/*}"
    done
    
    if [[ ${#vcs_stack[@]} -gt 0 ]]; then
        # We found VCS directories, build the prompt
        local prompt_parts=()
        
        # Start with the outermost VCS root
        local outermost_vcs="${vcs_stack[-1]}"
        local outermost_root="${outermost_vcs#*:}"
        outermost_root="${outermost_root%:*}"
        local outermost_name="${outermost_vcs##*:}"
        local outermost_type="${outermost_vcs%%:*}"
        
        # Add outermost VCS with color
        case "$outermost_type" in
            "repo") color='%F{green}' ;;
            "jj") color='%F{magenta}' ;;
            "git") color='%F{blue}' ;;
        esac
        prompt_parts+=("%{%B${color}%}${outermost_name}%{%f%b%}")
        
        # Calculate path relative to the outermost VCS root
        local relative_path="${PWD#$outermost_root}"
        relative_path="${relative_path#/}"
        
        if [[ -n "$relative_path" ]]; then
            # Split the relative path
            local path_parts=(${(s:/:)relative_path})
            
            if [[ ${#path_parts[@]} -gt 1 ]]; then
                # Truncate intermediate directories, keep the last one full
                local truncated_parts=()
                for ((i=1; i<${#path_parts[@]}; i++)); do
                    local part="${path_parts[$i]}"
                    local full_path="${outermost_root}"
                    
                    # Build the full path to this directory
                    for ((j=1; j<=i; j++)); do
                        full_path="${full_path}/${path_parts[$j]}"
                    done
                    
                    # Check if this directory contains any VCS directories
                    local contains_vcs=false
                    local vcs_type_in_dir=""
                    if [[ -d "$full_path/.git" ]]; then
                        contains_vcs=true
                        vcs_type_in_dir="git"
                    elif [[ -d "$full_path/.repo" ]]; then
                        contains_vcs=true
                        vcs_type_in_dir="repo"
                    elif [[ -d "$full_path/.jj" ]]; then
                        contains_vcs=true
                        vcs_type_in_dir="jj"
                    fi
                    
                    if [[ "$contains_vcs" == true ]]; then
                        # Don't truncate directories that contain VCS, and add color
                        case "$vcs_type_in_dir" in
                            "repo") color='%F{green}' ;;
                            "jj") color='%F{magenta}' ;;
                            "git") color='%F{blue}' ;;
                        esac
                        truncated_parts+=("%{%B${color}%}${part}%{%f%b%}")
                    elif [[ "$part" == .* ]]; then
                        # Hidden directory: keep dot + first character after dot
                        truncated_parts+=(".${part:1:1}")
                    else
                        # Regular directory: keep first character
                        truncated_parts+=("${part:0:1}")
                    fi
                done
                
                # Check if the last directory is a VCS root
                local last_part="${path_parts[-1]}"
                local is_vcs_root=false
                local vcs_type_for_last=""
                
                for ((i=1; i<=${#vcs_stack[@]}; i++)); do
                    local vcs_info="${vcs_stack[$i]}"
                    local vcs_name="${vcs_info##*:}"
                    if [[ "$vcs_name" == "$last_part" ]]; then
                        is_vcs_root=true
                        vcs_type_for_last="${vcs_info%%:*}"
                        break
                    fi
                done
                
                if [[ "$is_vcs_root" == true ]]; then
                    # Last part is a VCS root, add it with color
                    case "$vcs_type_for_last" in
                        "repo") color='%F{green}' ;;
                        "jj") color='%F{magenta}' ;;
                        "git") color='%F{blue}' ;;
                    esac
                    truncated_parts+=("%{%B${color}%}${last_part}%{%f%b%}")
                else
                    # Last part is not a VCS root, add it normally
                    truncated_parts+=("${last_part}")
                fi
                
                prompt_parts+=("${(j:/:)truncated_parts}")
            else
                # Only one part - check if it's a VCS root
                local is_vcs_root=false
                local vcs_type_for_single=""
                
                for ((i=1; i<=${#vcs_stack[@]}; i++)); do
                    local vcs_info="${vcs_stack[$i]}"
                    local vcs_name="${vcs_info##*:}"
                    if [[ "$vcs_name" == "$relative_path" ]]; then
                        is_vcs_root=true
                        vcs_type_for_single="${vcs_info%%:*}"
                        break
                    fi
                done
                
                if [[ "$is_vcs_root" == true ]]; then
                    # Single part is a VCS root, add it with color
                    case "$vcs_type_for_single" in
                        "repo") color='%F{green}' ;;
                        "jj") color='%F{magenta}' ;;
                        "git") color='%F{blue}' ;;
                    esac
                    prompt_parts+=("%{%B${color}%}${relative_path}%{%f%b%}")
                else
                    # Single part is not a VCS root, add it normally
                    prompt_parts+=("$relative_path")
                fi
            fi
        fi
        
        psvar[1]="${(j:/:)prompt_parts}"
    else
        # No VCS found, use fish-like truncation
        local p="$PWD"
        
        # Handle home directory substitution
        if [[ "$p" == "$HOME" ]]; then
            psvar[1]="~"
            PROMPT="${psvar[1]} %(!.#.$) "
            return
        elif [[ "$p" == "$HOME"/* ]]; then
            p="~${p#$HOME}"
        fi
        
        # Handle absolute paths vs relative paths
        local is_absolute=false
        if [[ "$p" == /* ]]; then
            is_absolute=true
        fi
        
        # Split path into components
        local path_parts=(${(s:/:)p})
        
        # If we have more than one component, truncate all but the last
        if [[ ${#path_parts[@]} -gt 1 ]]; then
            local truncated_parts=()
            
            # Handle the first component
            if [[ "$is_absolute" == true ]]; then
                # For absolute paths, first component should be truncated
                local part="${path_parts[1]}"
                if [[ "$part" == .* ]]; then
                    # Hidden directory: keep dot + first character after dot
                    truncated_parts+=(".${part:1:1}")
                else
                    # Regular directory: keep first character
                    truncated_parts+=("${part:0:1}")
                fi
            else
                # For relative paths, handle ~ and regular directories
                if [[ "${path_parts[1]}" == "~" ]]; then
                    truncated_parts+=("~")
                else
                    local part="${path_parts[1]}"
                    if [[ "$part" == .* ]]; then
                        # Hidden directory: keep dot + first character after dot
                        truncated_parts+=(".${part:1:1}")
                    else
                        # Regular directory: keep first character
                        truncated_parts+=("${part:0:1}")
                    fi
                fi
            fi
            
            # Truncate intermediate components
            for ((i=2; i<${#path_parts[@]}; i++)); do
                local part="${path_parts[$i]}"
                if [[ "$part" == .* ]]; then
                    # Hidden directory: keep dot + first character after dot
                    truncated_parts+=(".${part:1:1}")
                else
                    # Regular directory: keep first character
                    truncated_parts+=("${part:0:1}")
                fi
            done
            
            # Keep the last component full
            truncated_parts+=("${path_parts[-1]}")
            
            # Join the parts
            local result="${(j:/:)truncated_parts}"
            
            # Add leading slash for absolute paths
            if [[ "$is_absolute" == true ]]; then
                result="/$result"
            fi
            
            psvar[1]="$result"
        else
            # Only one component (root or relative single dir)
            psvar[1]="$p"
        fi
    fi
    PROMPT="${psvar[1]} %(!.#.$) "
}

precmd_functions+=( prompt_pwd )
PROMPT="%1v %(!.#.$) "

# Debug function to test prompt generation
debug_prompt() {
    local original_pwd="$PWD"
    if [[ -n "$1" ]]; then
        cd "$1"
    fi
    prompt_pwd
    echo "Debug prompt for $PWD: ${psvar[1]}"
    cd "$original_pwd"
}

# Debug function to test prompt generation without VCS
debug_prompt_no_vcs() {
    local test_path="$1"
    local original_pwd="$PWD"
    
    # Temporarily override PWD for testing
    PWD="$test_path"
    
    # Fish-like truncation logic (copied from main function)
    local p="$PWD"
    
    # Handle home directory substitution
    if [[ "$p" == "$HOME" ]]; then
        echo "Debug prompt for $test_path: ~"
        PWD="$original_pwd"
        return
    elif [[ "$p" == "$HOME"/* ]]; then
        p="~${p#$HOME}"
    fi
    
    # Handle absolute paths vs relative paths
    local is_absolute=false
    if [[ "$p" == /* ]]; then
        is_absolute=true
    fi
    
    # Split path into components
    local path_parts=(${(s:/:)p})
    
    # If we have more than one component, truncate all but the last
    if [[ ${#path_parts[@]} -gt 1 ]]; then
        local truncated_parts=()
        
        # Handle the first component
        if [[ "$is_absolute" == true ]]; then
            # For absolute paths, first component should be truncated
            local part="${path_parts[1]}"
            if [[ "$part" == .* ]]; then
                # Hidden directory: keep dot + first character after dot
                truncated_parts+=(".${part:1:1}")
            else
                # Regular directory: keep first character
                truncated_parts+=("${part:0:1}")
            fi
        else
            # For relative paths, handle ~ and regular directories
            if [[ "${path_parts[1]}" == "~" ]]; then
                truncated_parts+=("~")
            else
                local part="${path_parts[1]}"
                if [[ "$part" == .* ]]; then
                    # Hidden directory: keep dot + first character after dot
                    truncated_parts+=(".${part:1:1}")
                else
                    # Regular directory: keep first character
                    truncated_parts+=("${part:0:1}")
                fi
            fi
        fi
        
        # Truncate intermediate components
        for ((i=2; i<${#path_parts[@]}; i++)); do
            local part="${path_parts[$i]}"
            if [[ "$part" == .* ]]; then
                # Hidden directory: keep dot + first character after dot
                truncated_parts+=(".${part:1:1}")
            else
                # Regular directory: keep first character
                truncated_parts+=("${part:0:1}")
            fi
        done
        
        # Keep the last component full
        truncated_parts+=("${path_parts[-1]}")
        
        # Join the parts
        local result="${(j:/:)truncated_parts}"
        
        # Add leading slash for absolute paths
        if [[ "$is_absolute" == true ]]; then
            result="/$result"
        fi
        
        echo "Debug prompt for $test_path: $result"
    else
        # Only one component (root or relative single dir)
        echo "Debug prompt for $test_path: $p"
    fi
    
    PWD="$original_pwd"
}