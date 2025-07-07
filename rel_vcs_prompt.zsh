setopt PROMPT_SUBST
setopt PROMPT_PERCENT

# Helper function to get VCS color
get_vcs_color() {
    case "$1" in
        "git") echo '%F{blue}' ;;
        "jj") echo '%F{magenta}' ;;
        "repo") echo '%F{green}' ;;
        *) echo '' ;;
    esac
}

# Helper function to truncate path component
truncate_component() {
    local part="$1"
    if [[ "$part" == .* ]]; then
        echo ".${part:1:1}"
    else
        echo "${part:0:1}"
    fi
}

# Helper function to check if directory contains VCS
check_vcs_dir() {
    local dir="$1"
    [[ -d "$dir/.git" ]] && echo "git" && return
    [[ -d "$dir/.jj" ]] && echo "jj" && return
    [[ -d "$dir/.repo" ]] && echo "repo" && return
    echo ""
}

# Main function to build VCS stack
build_vcs_stack() {
    local current_dir="$PWD"
    local vcs_stack=()
    
    while [[ "$current_dir" != "/" && "$current_dir" != "" ]]; do
        local vcs_type=$(check_vcs_dir "$current_dir")
        [[ -n "$vcs_type" ]] && vcs_stack+=("$vcs_type:$current_dir:${current_dir##*/}")
        current_dir="${current_dir%/*}"
    done
    
    echo "${vcs_stack[@]}"
}

# Helper function to check if a name is a VCS root
is_vcs_root() {
    local name="$1"
    local -a vcs_stack=($2)
    
    for vcs_info in $vcs_stack; do
        local vcs_name="${vcs_info##*:}"
        if [[ "$vcs_name" == "$name" ]]; then
            echo "${vcs_info%%:*}"
            return
        fi
    done
    echo ""
}

# Unified path processing function
process_path() {
    local path="$1"
    local vcs_root="${2:-}"
    local -a vcs_stack=($3)
    local -a path_parts=(${(s:/:)path})
    
    # Handle single component - still check for VCS coloring
    if [[ ${#path_parts[@]} -eq 1 ]]; then
        local single_part="$path"
        local vcs_type=""
        
        # Check if this single component is a VCS root by position
        if [[ -n "$vcs_root" ]]; then
            local full_path="$vcs_root/$single_part"
            
            # Check if any VCS root matches this exact path position
            local -a vcs_array=(${(s: :)vcs_stack})
            for vcs_info in "${vcs_array[@]}"; do
                local vcs_path="${vcs_info#*:}"
                vcs_path="${vcs_path%:*}"
                if [[ "$vcs_path" == "$full_path" ]]; then
                    vcs_type="${vcs_info%%:*}"
                    break
                fi
            done
        fi
        
        if [[ -n "$vcs_type" ]]; then
            local color=$(get_vcs_color "$vcs_type")
            echo "%{%B${color}%}${single_part}%{%f%b%}"
        else
            echo "$single_part"
        fi
        return
    fi
    
    local -a result_parts=()
    local is_absolute=$([[ "$path" == /* ]] && echo true || echo false)
    
    # Process all components except the last
    for ((i=1; i<${#path_parts[@]}; i++)); do
        local part="${path_parts[$i]}"
        
        # Skip empty parts (from leading slash)
        [[ -z "$part" ]] && continue
        
        # Check if this part should be colored (VCS detection by position)
        local should_color=false
        local vcs_type=""
        
        if [[ -n "$vcs_root" ]]; then
            # Build full path to check for VCS at this position
            local full_path="$vcs_root"
            for ((j=1; j<=i; j++)); do
                [[ -n "${path_parts[$j]}" ]] && full_path+="/${path_parts[$j]}"
            done
            
            # Check if any VCS root matches this exact path position
            local -a vcs_array=(${(s: :)vcs_stack})
            for vcs_info in "${vcs_array[@]}"; do
                local vcs_path="${vcs_info#*:}"
                vcs_path="${vcs_path%:*}"
                if [[ "$vcs_path" == "$full_path" ]]; then
                    vcs_type="${vcs_info%%:*}"
                    should_color=true
                    break
                fi
            done
        fi
        
        # Add component (colored or truncated)
        if [[ "$should_color" == true ]]; then
            local color=$(get_vcs_color "$vcs_type")
            result_parts+=("%{%B${color}%}${part}%{%f%b%}")
        else
            result_parts+=($(truncate_component "$part"))
        fi
    done
    
    # Handle last component
    local last_part="${path_parts[-1]}"
    local last_vcs_type=""
    
    # Check if last component is a VCS root by position
    if [[ -n "$vcs_root" ]]; then
        local full_path="$vcs_root"
        for ((j=1; j<=${#path_parts[@]}; j++)); do
            [[ -n "${path_parts[$j]}" ]] && full_path+="/${path_parts[$j]}"
        done
        
        # Check if any VCS root matches this exact path position
        local -a vcs_array=($vcs_stack)
        for vcs_info in "${vcs_array[@]}"; do
            local vcs_path="${vcs_info#*:}"
            vcs_path="${vcs_path%:*}"
            if [[ "$vcs_path" == "$full_path" ]]; then
                last_vcs_type="${vcs_info%%:*}"
                break
            fi
        done
    fi
    
    if [[ -n "$last_vcs_type" ]]; then
        local color=$(get_vcs_color "$last_vcs_type")
        result_parts+=("%{%B${color}%}${last_part}%{%f%b%}")
    else
        result_parts+=("$last_part")
    fi
    
    # Join and return
    local result="${(j:/:)result_parts}"
    [[ "$is_absolute" == true ]] && result="/$result"
    echo "$result"
}

prompt_pwd() {
    local vcs_stack_str=$(build_vcs_stack)
    local -a vcs_stack=(${(s: :)vcs_stack_str})
    
    if [[ ${#vcs_stack[@]} -gt 0 ]]; then
        # VCS mode: start with outermost VCS root
        local outermost_vcs="${vcs_stack[-1]}"
        local outermost_root="${outermost_vcs#*:}"
        outermost_root="${outermost_root%:*}"
        local outermost_name="${outermost_vcs##*:}"
        local outermost_type="${outermost_vcs%%:*}"
        
        local color=$(get_vcs_color "$outermost_type")
        local -a prompt_parts=("%{%B${color}%}${outermost_name}%{%f%b%}")
        
        # Calculate relative path from outermost VCS root
        local relative_path="${PWD#$outermost_root}"
        relative_path="${relative_path#/}"
        
        if [[ -n "$relative_path" ]]; then
            local processed_path=$(process_path "$relative_path" "$outermost_root" "$vcs_stack_str")
            prompt_parts+=("$processed_path")
        fi
        
        psvar[1]="${(j:/:)prompt_parts}"
    else
        # Non-VCS mode: handle home directory and process normally
        local p="$PWD"
        
        [[ "$p" == "$HOME" ]] && psvar[1]="~" && PROMPT="${psvar[1]} %(!.#.$) " && return
        [[ "$p" == "$HOME"/* ]] && p="~${p#$HOME}"
        
        psvar[1]=$(process_path "$p" "" "")
    fi
    
    PROMPT="${psvar[1]} %(!.#.$) "
}

precmd_functions+=( prompt_pwd )
PROMPT="%1v %(!.#.$) "

# Testable function that returns the prompt string for a given directory
get_prompt_string() {
    local test_dir="$1"
    local original_pwd="$PWD"
    
    cd "$test_dir"
    
    local vcs_stack_str=$(build_vcs_stack)
    local -a vcs_stack=(${(s: :)vcs_stack_str})
    
    local result=""
    if [[ ${#vcs_stack[@]} -gt 0 ]]; then
        # VCS mode: start with outermost VCS root
        local outermost_vcs="${vcs_stack[-1]}"
        local outermost_root="${outermost_vcs#*:}"
        outermost_root="${outermost_root%:*}"
        local outermost_name="${outermost_vcs##*:}"
        local outermost_type="${outermost_vcs%%:*}"
        
        local color=$(get_vcs_color "$outermost_type")
        local -a prompt_parts=("%{%B${color}%}${outermost_name}%{%f%b%}")
        
        # Calculate relative path from outermost VCS root
        local relative_path="${PWD#$outermost_root}"
        relative_path="${relative_path#/}"
        
        if [[ -n "$relative_path" ]]; then
            local processed_path=$(process_path "$relative_path" "$outermost_root" "$vcs_stack_str")
            prompt_parts+=("$processed_path")
        fi
        
        result="${(j:/:)prompt_parts}"
    else
        # Non-VCS mode: handle home directory and process normally
        local p="$PWD"
        
        if [[ "$p" == "$HOME" ]]; then
            result="~"
        elif [[ "$p" == "$HOME"/* ]]; then
            p="~${p#$HOME}"
            result=$(process_path "$p" "" "")
        else
            result=$(process_path "$p" "" "")
        fi
    fi
    
    cd "$original_pwd"
    echo "$result"
}

# Debug functions (simplified)
debug_prompt() {
    local original_pwd="$PWD"
    [[ -n "$1" ]] && cd "$1"
    prompt_pwd
    echo "Debug prompt for $PWD: ${psvar[1]}"
    cd "$original_pwd"
}

debug_prompt_no_vcs() {
    local original_pwd="$PWD"
    PWD="$1"
    local p="$PWD"
    [[ "$p" == "$HOME" ]] && echo "Debug prompt for $1: ~" && PWD="$original_pwd" && return
    [[ "$p" == "$HOME"/* ]] && p="~${p#$HOME}"
    local result=$(process_path "$p" "" "")
    echo "Debug prompt for $1: $result"
    PWD="$original_pwd"
}