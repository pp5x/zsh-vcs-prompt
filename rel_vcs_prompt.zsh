setopt PROMPT_SUBST
setopt PROMPT_PERCENT

# Helper function to get VCS color
get_vcs_color() {
    case "$1" in
        "git") echo '%F{blue}' ;;
        "jj") echo '%F{magenta}' ;;
        "repo") echo '%F{red}' ;;
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
detect_vcs_dir() {
    local dir="$1"
    # Check for git: directory, symlink, or file (git worktrees/submodules)
    [[ -d "$dir/.git" || -L "$dir/.git" || -f "$dir/.git" ]] && echo "git" && return
    # Check for jj: directory or symlink
    [[ -d "$dir/.jj" || -L "$dir/.jj" ]] && echo "jj" && return
    # Check for repo: directory or symlink
    [[ -d "$dir/.repo" || -L "$dir/.repo" ]] && echo "repo" && return
    echo ""
}

# Core function to generate VCS path string for a given directory
generate_vcs_path() {
    local current_path="${1:-$PWD}"
    
    # Calculate HOME offset for later replacement
    local home_offset=0
    if [[ "$current_path" == "$HOME"* ]]; then
        local -a home_parts=(${(s:/:)HOME})
        home_offset=${#home_parts[@]}
    fi
    
    # Split path into components for processing
    local -a path_parts=(${(s:/:)current_path})
    local -a result_parts=()
    
    # Track outermost VCS found during traversal
    local outermost_vcs_index=-1
    
    # Process path components backwards (from end to beginning)
    for ((i=${#path_parts[@]}; i > 0; i--)); do
        local dir="${path_parts[$i]}"
        [[ -z "$dir" ]] && continue

        # Build full path for VCS detection
        local full_path="/${(j:/:)path_parts[@]:0:${i}}"

        # Check for VCS
        local vcs_type="$(detect_vcs_dir "$full_path")"
        if [[ -n "$vcs_type" ]]; then
            # VCS directory with color
            local color=$(get_vcs_color "$vcs_type")
            result_parts=("%B${color}${dir}%f%b" "${result_parts[@]}")
            outermost_vcs_index=$((i - 1))
        else
            # Non-VCS directory
            if [[ $i == ${#path_parts[@]} ]]; then
                # Last path component is not truncated
                result_parts=("$dir" "${result_parts[@]}")
            else
                result_parts=($(truncate_component "$dir") "${result_parts[@]}")
            fi
        fi
    done
    
    # If we found an outermost VCS, discard all components before it
    if [[ $outermost_vcs_index -ge 0 ]]; then
        result_parts=("${result_parts[@]:${outermost_vcs_index}}")
    fi
    
    # Replace HOME portion with ~ if applicable
    if [[ $outermost_vcs_index -ge 0 ]]; then
        # VCS found - check if it's after HOME parts
        if [[ $((outermost_vcs_index + home_offset)) -le ${#result_parts[@]} ]]; then
            result_parts=("~" "${result_parts[@]:${home_offset}}")
        fi
    elif [[ $home_offset -gt 0 ]]; then
        # No VCS but in HOME - always replace HOME parts
        result_parts=("~" "${result_parts[@]:${home_offset}}")
    fi
    
    # Join result
    local result="${(j:/:)result_parts}"
    
    # Handle absolute paths (but not home paths or VCS paths)
    if [[ $outermost_vcs_index -lt 0 && $home_offset -eq 0 && "$current_path" == /* ]]; then
        result="/$result"
    fi
    
    echo "$result"
}

# Build the prompt format string for a given directory
build_prompt_format() {
    local path=$(generate_vcs_path "$1")
    echo "${path} %(?..[%F{red}%?%f] )%(!.#.$) "
}

prompt_pwd() {
    PROMPT="$(build_prompt_format)"
}

precmd_functions+=( prompt_pwd )

