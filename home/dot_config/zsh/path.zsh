# Sourced from ~/.zshenv and ~/.zprofile (see .zprofile for why twice).
# Must be idempotent; requires XDG_BIN_HOME.

# 1. Establish absolute baseline system paths
path=(
  /usr/local/bin
  /usr/bin
  /bin
  /usr/local/sbin
  /usr/sbin
  /sbin
)

# 2. Eval Homebrew if we find it on the sytem (darwin only...)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# 3. Eval mise shims to ensure we have tool access in non-interactive shells
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh --shims)"
fi

# 4. Enforce Priority Queue: Re-prepend XDG_BIN to the absolute front
path=(
  $XDG_BIN_HOME
  $path
)

export PATH MANPATH
