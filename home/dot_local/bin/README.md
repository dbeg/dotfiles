# ~/.local/bin

Scripts here are managed by chezmoi — the `dot_local/bin/` source path maps to `~/.local/bin/` via chezmoi's `dot_` → `.` prefix convention, and `executable_` files are installed with the execute bit set.

This is a grab-bag of one-off, self-managed scripts that don't warrant their own package or Homebrew formula. They're on `PATH` via `~/.zshenv` (`XDG_BIN_HOME`).
