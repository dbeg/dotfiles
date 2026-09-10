#!/usr/bin/env bash
# Installs the omarchy shell plugins referenced by shell.json. Plugins are
# git-repo clones managed by `omarchy plugin`, so they are installed here
# rather than tracked directly.

set -euo pipefail

if ! command -v omarchy >/dev/null 2>&1; then
    echo "omarchy: not installed, skipping."
    exit 0
fi

PLUGIN_DIR="$HOME/.config/omarchy/plugins"

install_plugin() {
    local id="$1" url="$2"
    if [[ -d "$PLUGIN_DIR/$id" ]]; then
        echo "omarchy plugin: $id already installed, skipping."
        return
    fi
    echo "omarchy plugin: installing $id"
    omarchy plugin add "$url"
}

install_plugin "io.github.weedwhitesandwine.plug" "https://github.com/weedwhitesandwine/plug.git"
install_plugin "meviusisback.keybinds" "https://github.com/meviusisback/keybinds-plugin.git"
install_plugin "sid.sessions" "https://github.com/Sudhanshugtm/omarchy-session-browser.git"
install_plugin "tenzin.auto-workspace" "https://github.com/yesheytenzin/auto-workspace.git"
install_plugin "tmn73.calendar" "https://github.com/tmn73/omarchy-calendar.git"