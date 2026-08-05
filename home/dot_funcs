help() {
    eval "$* --help" 2>&1 | bat -pl man
}

# Depending on how tldr is installed, the command may be `tldr` or `tealdeer`.
# This function checks which one is available and uses it accordingly.
tldr() {
    if type -p tldr &>/dev/null; then
        command tldr "$@"
    else
        command tealdeer "$@"
    fi
}

toggle-starship-prompt() {
    local DEFAULT="$XDG_CONFIG_HOME/starship/starship.toml"
    local MINI="$XDG_CONFIG_HOME/starship/starship_mini.toml"

    if [[ "$STARSHIP_CONFIG" == "$DEFAULT" ]]; then
        export STARSHIP_CONFIG="$MINI"
    else
        export STARSHIP_CONFIG="$DEFAULT"
    fi

    zle reset-prompt
}

# Create a ZLE widget from the function
zle -N toggle-starship-prompt

# Bind the widget to a shortcut (e.g., Ctrl+x followed by t)
bindkey '^Xt' toggle-starship-prompt
