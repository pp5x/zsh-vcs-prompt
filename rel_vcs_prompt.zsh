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
        local current_path="$PWD"
        
        # Process VCS stack from outermost to innermost (reverse order)
        for ((i=${#vcs_stack[@]}; i>=1; i--)); do
            local vcs_info="${vcs_stack[$i]}"
            local vcs_type="${vcs_info%%:*}"
            local vcs_root="${vcs_info#*:}"
            vcs_root="${vcs_root%:*}"
            local vcs_name="${vcs_info##*:}"
            
            # Determine prefix based on VCS type
            case "$vcs_type" in
                "repo") prefix='%F{102}' ;;
                "jj") prefix='%F{105}' ;;
                "git") prefix='%F{104}' ;;
            esac
            
            prompt_parts+=("%{%B${prefix}%}@${vcs_name}%{%f%b%}")
        done
        
        # Calculate path relative to the innermost (first in stack) VCS root
        local innermost_vcs="${vcs_stack[1]}"
        local innermost_root="${innermost_vcs#*:}"
        innermost_root="${innermost_root%:*}"
        
        local relative_path="${PWD#$innermost_root}"
        relative_path="${relative_path#/}"
        
        # If we're not at the VCS root, add the relative path
        if [[ -n "$relative_path" ]]; then
            # Split the relative path
            local path_parts=(${(s:/:)relative_path})
            
            if [[ ${#path_parts[@]} -gt 1 ]]; then
                # Truncate intermediate directories, keep the last one full
                local truncated_parts=()
                for ((i=1; i<${#path_parts[@]}; i++)); do
                    truncated_parts+=("${path_parts[$i]:0:1}")
                done
                truncated_parts+=("${path_parts[-1]}")
                prompt_parts+=("${(j:/:)truncated_parts}")
            else
                # Only one part, add it only if it's different from the innermost VCS name
                local innermost_name="${innermost_vcs##*:}"
                if [[ "$relative_path" != "$innermost_name" ]]; then
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
        
        # Split path into components
        local path_parts=(${(s:/:)p})
        
        # If we have more than one component, truncate all but the last
        if [[ ${#path_parts[@]} -gt 1 ]]; then
            local truncated_parts=()
            
            # Handle the first component (could be ~ or empty for absolute paths)
            if [[ -n "${path_parts[1]}" ]]; then
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
            else
                # Empty first component means absolute path, preserve the leading slash
                truncated_parts+=("")
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
            
            psvar[1]="${(j:/:)truncated_parts}"
        else
            # Only one component (root or relative single dir)
            psvar[1]="$p"
        fi
    fi
    PROMPT="${psvar[1]} %(!.#.$) "
}

precmd_functions+=( prompt_pwd )
PROMPT="%1v %(!.#.$) "
