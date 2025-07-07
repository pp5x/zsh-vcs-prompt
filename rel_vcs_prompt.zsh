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
    local display_path="$current_path"

    # Handle home directory expansion for display purposes only
    if [[ "$display_path" == "$HOME"* ]]; then
        display_path="~${display_path#$HOME}"
    fi
    
    # Split path into components for backwards processing
    local -a path_parts=(${(s:/:)display_path})
    local -a result_parts=()
    
    # Track outermost VCS directory found during traversal
    local outermost_vcs_root=""
    local outermost_vcs_type=""
    local outermost_vcs_start=-1
    
    # Process path components backwards (from end to beginning)
    local -a current_parts=(${(s:/:)current_path})
    for ((i=${#path_parts[@]}; i > 0; i--)); do
        local p="${path_parts[$i]}"
        
        # Skip empty components (from splitting)
        [[ -z "$p" ]] && continue

        # Build the full path up to this p - use current_path for VCS detection
        local current_idx=$i
        if [[ "$display_path" == "~"* ]]; then
            current_idx=$((i + ${#current_parts[@]} - ${#path_parts[@]}))
        fi
        local full_path="/${(j:/:)current_parts[@]:0:${current_idx}}"

        # Check if this path contains VCS
        local vcs_type="$(detect_vcs_dir "$full_path")"
        if [[ -n "$vcs_type" ]]; then
            # VCS directory - use full p name with color
            local color=$(get_vcs_color "$vcs_type")
            result_parts=("%B${color}${p}%f%b" "${result_parts[@]}")

            # Update outermost VCS info - track where VCS starts in final array
            outermost_vcs_root="$full_path"
            outermost_vcs_type="$vcs_type"
            outermost_vcs_start=$((i - 1))
        else
            # Non-VCS directory
            if [[ $i -eq ${#path_parts[@]} ]]; then
                # First p visited (current directory) - always show full name
                result_parts=("$p" "${result_parts[@]}")
            else
                # Intermediate p - truncate
                result_parts=($(truncate_component "$p") "${result_parts[@]}")
            fi
        fi
    done
    
    # If we found an outermost VCS directory, discard all components before it
    if [[ $outermost_vcs_start -ge 0 ]]; then
        result_parts=("${result_parts[@]:${outermost_vcs_start}}")
    fi
    
    # Join result
    local result="${(j:/:)result_parts}"
    
    # Handle absolute paths (but not home paths or VCS paths)
    if [[ -z "$outermost_vcs_root" && "$current_path" == /* && "$result" != "~"* ]]; then
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

