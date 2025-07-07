setopt PROMPT_SUBST
setopt PROMPT_PERCENT

# Get the directory of this script
prompt_script_dir="${0:A:h}"

prompt_pwd() {
    # Call the Perl script and capture its output
    psvar[1]="$("$prompt_script_dir/rel_vcs_prompt.pl")"
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

# Debug function to test prompt generation without VCS (for compatibility)
debug_prompt_no_vcs() {
    local test_path="$1"
    local original_pwd="$PWD"
    
    # Temporarily override PWD for testing
    PWD="$test_path" "$prompt_script_dir/rel_vcs_prompt.pl"
    
    PWD="$original_pwd"
}