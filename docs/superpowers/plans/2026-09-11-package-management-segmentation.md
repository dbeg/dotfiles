# Package Management Segmentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give each platform its own package-manager path — Homebrew for macOS, pacman+yay for Omarchy/Arch, apt+mise for Debian/WSL — documented in one install script per platform, with mise demoted to runtimes + a Debian-only fallback for CLI tools, and zshenv split into per-OS fragments.

**Architecture:** Three self-contained `run_onchange_*` install scripts, each OS-guarded and idempotent (`--needed` / `--no-upgrade`, add-only, no removals). mise's global `config.toml.tmpl` shrinks to `[settings]` only; Debian CLI tools move into `~/.config/mise/conf.d/tools-debian.toml` (mise merges `conf.d/*.toml` natively). The Brewfile absorbs the former mise CLIs so macOS keeps full coverage. `~/.zshenv` becomes a core skeleton that sources per-OS fragments (`.zshenv-darwin`, `.zshenv-wsl`), which chezmoi only materializes on the matching OS via `.chezmoiignore`.

**Tech Stack:** chezmoi (templates, run scripts, `.chezmoiignore`), Homebrew bundle (macOS), pacman + yay (Omarchy/Arch), apt + mise (Debian/WSL), zsh. External data source: [mise configuration/conf.d](https://mise.jdx.dev/configuration.html) and [chezmoi `.chezmoi.osRelease`](https://www.chezmoi.io/reference/templates/variables/).

**Spec:** Agreed design from brainstorming session (2026-09-11): per-PM scripts inherited as-is for macOS and Debian; new inlined pacman/yay script for Omarchy; mise re-scoped to runtimes + Debian CLI fallback; zshenv per-OS fragments only (no zshrc splitting this round); scripts stay top-level in `home/`.

## Global Constraints

- **Worktree:** implement in `~/src/github.com/dbeg/dotfiles.feat-packages-segmentation` on branch `feat/packages-segmentation` (based off `origin/feature/omarchy`). The main checkout at `~/src/github.com/dbeg/dotfiles` is NOT the working directory for this work.
- **Do not merge, rebase, or push.** Leave work on the branch. (AGENTS.md)
- **Commits:** conventional commits `type(scope): subject`, `<72 chars` subject, lowercase, no trailing period. Add trailer `Co-Authored-By: opencode <opencode@opencode.ai>` on commits that materially change code.
- **No comments** in edited shell/template files unless the existing file already uses that comment style (AGENTS.md, DOT-style conventions). Do not "improve" adjacent code.
- **mise `conf.d` filenames MUST be hyphenated** (`tools-debian.toml`). Dotted names (`tools.debian.toml`) are reserved for `MISE_ENV` suffixes in mise ≥ 2026.8 and silently stop loading fragments.
- **`/etc/os-release` access:** `.chezmoi.osRelease` is Linux-only and may be `null`; always guard with `eq .chezmoi.os "linux"` and read keys via `get .chezmoi.osRelease "<camelCaseKey>"` (never dotted access — missing keys error). Keys are camelCase: `id`, `idLike`.
- **Idempotency semantics:** add-only. `--needed` (pacman/yay) and `--no-upgrade` (brew) mean "ensure present, never downgrade/upgrade beyond need, never remove." `pacman -Sy` refreshes the db but must NOT be `-Syu` (no broad system upgrade — matches the apt script's existing comment).
- **Every run script** keeps `set -euo pipefail` and early-exits with a message when its package manager is absent.
- **Verification limits:** brew cannot be executed on this Omarchy machine. Brewfile changes are verified by review + template rendering only and flagged for macOS-side check. Everything else is verifiable on this machine.

## File Structure

| File | Responsibility |
|---|---|
| `home/.chezmoi.toml.tmpl` | Compute + publish `debian`, `arch_family` data flags (alongside existing `wsl`) |
| `home/.chezmoiignore` | Only materialize `.zshenv-darwin`, `.zshenv-wsl`, `tools-debian.toml` on their OS |
| `home/dot_config/mise/config.toml.tmpl` | Global mise config — `[settings]` only; `[tools]` removed |
| `home/dot_config/mise/conf.d/tools-debian.toml.tmpl` | New — Debian/Ubuntu CLI tools via mise |
| `home/run_onchange_before_pacman.sh.tmpl` | New — Omarchy/Arch: pacman (extra) + yay (AUR) |
| `home/dot_config/homebrew/private_Brewfile` | macOS parity: append former mise CLI formulae |
| `home/dot_zshenv.tmpl` | Core skeleton; sources per-OS fragments |
| `home/dot_zshenv-darwin.tmpl` | New — macOS: java_home + brew shellenv |
| `home/dot_zshenv-wsl.tmpl` | New — WSL2 Bitwarden SSH-agent bridge (moved verbatim) |
| `README.md` | Update "Packmans" table row |

---

### Task 1: Add `debian` / `arch_family` template data

**Files:**
- Modify: `home/.chezmoi.toml.tmpl:14-30`

**Interfaces:**
- Produces: template data `.debian` (bool, true on Debian/Ubuntu — apt-family) and `.arch_family` (bool, true when `ID_LIKE` contains `arch`; covers `omarchy`). Consumed by Tasks 2, 3, 5 and the `.chezmoiignore` rules.

- [ ] **Step 1: Add the detection blocks**

Insert after the existing `$wsl` block (line 20) and before `[data]` (line 22):

```
{{- $debian := false -}}
{{- if eq .chezmoi.os "linux" -}}
  {{- $os_id := get .chezmoi.osRelease "id" | lower -}}
  {{- $os_id_like := get .chezmoi.osRelease "idLike" | lower -}}
  {{- if or (contains "debian" $os_id) (contains "ubuntu" $os_id) (contains "debian" $os_id_like) (contains "ubuntu" $os_id_like) -}}
    {{- $debian = true -}}
  {{- end -}}
{{- end }}

{{- $arch_family := false -}}
{{- if eq .chezmoi.os "linux" -}}
  {{- $os_id_like := get .chezmoi.osRelease "idLike" | lower -}}
  {{- if contains "arch" $os_id_like -}}
    {{- $arch_family = true -}}
  {{- end -}}
{{- end }}
```

- [ ] **Step 2: Publish the flags in `[data]`**

Modify the `[data]` section (lines 22-30) to add the two keys after `wsl`:

```
  wsl            = {{ $wsl }}
  debian         = {{ $debian }}
  arch_family    = {{ $arch_family }}
```

- [ ] **Step 3: Verify the template renders and data computes correctly**

Run: `chezmoi execute-template -S "$PWD" '{{ .debian }} {{ .arch_family }}'`
Expected: this machine is Omarchy (`ID_LIKE=arch`) → `false true`.

Note: `chezmoi execute-template` needs the resolved config data; if `.debian`/`.arch_family` come back empty, run `chezmoi apply --dry-run -S "$PWD"` once to persist `.chezmoi.toml.tmpl` template evaluation, then re-run. Do NOT let `apply` execute the install scripts yet — dry-run (`--dry-run`) only.

- [ ] **Step 4: Commit**

```bash
git add home/.chezmoi.toml.tmpl
git commit -m "feat(chezmoi): add debian and arch_family data"
```

---

### Task 2: Re-scope mise config and add Debian CLI fragment

**Files:**
- Modify: `home/dot_config/mise/config.toml.tmpl`
- Create: `home/dot_config/mise/conf.d/tools-debian.toml.tmpl`
- Modify: `home/.chezmoiignore`

**Interfaces:**
- Consumes: `.debian` from Task 1.
- Produces: `~/.config/mise/conf.d/tools-debian.toml` (existing only on Debian/Ubuntu) whose `[tools]` are merged by mise at runtime; base `config.toml` with no `[tools]`.

- [ ] **Step 1: Replace the mise global config with settings only**

Write `home/dot_config/mise/config.toml.tmpl` as:

```toml
#:schema https://mise.jdx.dev/schema/mise.json

[settings]
gpg_verify = true
minimum_release_age = "2d"
```

This removes the `[tools]` block and the darwin-amd64 conditional comment (moot: those tools now come from Homebrew on all macOS).

- [ ] **Step 2: Create the Debian CLI fragment**

Create `home/dot_config/mise/conf.d/tools-debian.toml.tmpl` with **no template guard** (the `.chezmoiignore` rule in Step 3 controls existence):

```toml
# CLI tools on Debian/Ubuntu where apt lacks current versions.
# macOS gets these from Homebrew, Omarchy/Arch from pacman/AUR.
[tools]
atuin = "latest"
delta = "latest"
age = "latest"
bat = "latest"
bitwarden = "latest"
chezmoi = "latest"
eza = "latest"
gum = "latest"
fastfetch = "latest"
fzf = "latest"
gh = "latest"
gitleaks = "latest"
hwatch = "latest"
lazygit = "latest"
opencode = "latest"
ripgrep = "latest"
starship = "latest"
worktrunk = "latest"
zoxide = "latest"
"github:tealdeer-rs/tealdeer" = "latest"
```

- [ ] **Step 3: Add the `.chezmoiignore` rule for the fragment**

Append to `home/.chezmoiignore` (after the existing omarchy ignores):

```
{{ if not .debian -}}
.config/mise/conf.d/tools-debian.toml
{{- end }}
```

Target path is `~/.config/mise/conf.d/tools-debian.toml` — the `.tmpl` suffix is stripped by chezmoi.

- [ ] **Step 4: Verify rendering on this machine**

Run: `chezmoi apply --dry-run -S "$PWD" --verbose 2>&1 | rg "mise/config|mise/conf.d"`
Expected: `config.toml` is rendered (`~/.config/mise/config.toml`) and `tools-debian.toml` is NOT listed (`.debian` is false on Omarchy). This is the reliable check — the `.chezmoiignore` rule prevents the file from existing on non-Debian systems.

- [ ] **Step 5: Validate the fragment is parseable TOML**

Run: `python3 -c "import tomllib; tomllib.load(open('home/dot_config/mise/conf.d/tools-debian.toml.tmpl','rb'))"`
Expected: no error. (The file is intentionally guard-free — existence is governed by `.chezmoiignore` — so it must already be valid TOML.)

- [ ] **Step 6: Commit**

```bash
git add home/dot_config/mise/config.toml.tmpl home/dot_config/mise/conf.d/tools-debian.toml.tmpl home/.chezmoiignore
git commit -m "refactor(mise): cli tools to platform package managers"
```

---

### Task 3: Add the Omarchy/Arch install script

**Files:**
- Create: `home/run_onchange_before_pacman.sh.tmpl`

**Interfaces:**
- Consumes: `.arch_family` from Task 1.
- Produces: a `run_onchange_before_*` script registered by chezmoi (executable, templated) that installs the verified package list on Arch-family Linux and no-ops elsewhere.

- [ ] **Step 1: Create the script**

Create `home/run_onchange_before_pacman.sh.tmpl`:

```bash
#!/usr/bin/env bash
set -euo pipefail

{{ if and (eq .chezmoi.os "linux") .arch_family }}
if ! command -v pacman >/dev/null 2>&1; then
  echo "pacman installation skipped: pacman not found."
  exit 0
fi

if ! command -v yay >/dev/null 2>&1; then
  echo "ERROR: yay not found — required for AUR package 'hwatch'." >&2
  exit 1
fi

sudo pacman -Sy --noconfirm
sudo pacman -S --needed --noconfirm \
  age \
  atuin \
  bat \
  bitwarden-cli \
  btop \
  chezmoi \
  eza \
  fastfetch \
  fzf \
  git-delta \
  gitleaks \
  github-cli \
  gum \
  lazygit \
  mise \
  opencode \
  ripgrep \
  starship \
  tealdeer \
  ttf-jetbrains-mono-nerd \
  worktrunk \
  zoxide \
  zsh \
  zsh-autosuggestions \
  zsh-syntax-highlighting

yay -S --needed --noconfirm --answerdiff=None --answerclean=None hwatch
{{ else }}
echo "pacman installation skipped: Not Linux/Arch-family."
{{ end }}
```

Package-name mappings were verified against omarchy mirrors on 2026-09-11: `github-cli` provides `gh` (plain `gh` no longer resolves), `git-delta` provides `delta` (AUR `delta` is an unrelated 2006 tool), `bitwarden-cli` is the CLI (plain `bitwarden` is the GUI app), `ttf-jetbrains-mono-nerd` replaces the getnf font install, `hwatch` is the only AUR package.

- [ ] **Step 2: Make it executable**

Run: `chmod +x home/run_onchange_before_pacman.sh.tmpl`

- [ ] **Step 3: Verify shell syntax and template rendering**

Render the template to a temp file, then shell-syntax-check the rendered output (the guards render away on this Omarchy box, so the file should parse as valid bash):

```bash
mkdir -p /tmp/opencode/pacman-check
chezmoi execute-template -S "$PWD" home/run_onchange_before_pacman.sh.tmpl > /tmp/opencode/pacman-check/pacman.sh
bash -n /tmp/opencode/pacman-check/pacman.sh
```

Expected: `bash -n` silent (syntax OK). Grep the rendered file: `rg -n "github-cli|git-delta|ttf-jetbrains-mono-nerd|hwatch" /tmp/opencode/pacman-check/pacman.sh` — all four present. Note: `chezmoi execute-template` needs the resolved set of config data; `.arch_family` must be `true` here (Omarchy's `ID_LIKE=arch`).

- [ ] **Step 4: Dry-run is skipped — confirm no accidental install yet**

Run: `chezmoi apply --dry-run -S "$PWD" --verbose 2>&1 | rg "pacman.sh"`.
Expected: the script is listed as would-run. **Do NOT run a live `chezmoi apply` in this task** — live installation is the last task.

- [ ] **Step 5: Commit**

```bash
git add home/run_onchange_before_pacman.sh.tmpl
git commit -m "feat(scripts): add pacman/yay installer for omarchy"
```

---

### Task 4: macOS Brewfile parity for former mise CLIs

**Files:**
- Modify: `home/dot_config/homebrew/private_Brewfile`

**Interfaces:**
- Consumes: nothing new (Brewfile is the macOS-only manifest).
- Produces: a Brewfile that covers every CLI tool moved out of mise, so macOS loses no tools.

- [ ] **Step 1: Append the missing formulae as `brew` entries**

Add the following lines at the end of the formulae group (after line 51, `brew "zsh-syntax-highlighting"`), keeping the existing `brew "name"` style:

```
# Command-line utility for comparing and merging files
brew "age"
# Colorful cat clone with syntax highlighting
brew "bat"
# Bitwarden command-line interface
brew "bitwarden-cli"
# Manage dotfiles across multiple machines
brew "chezmoi"
# Modern replacement for ls
brew "eza"
# Fast, cross-platform system fetch
brew "fastfetch"
# GitHub command-line interface
brew "gh"
# Gitleaks detects secrets in your git repos
brew "gitleaks"
# A tool for glamorous shell scripts
brew "gum"
# Watch command with highlighting and diff
brew "hwatch"
# Simple terminal UI for git commands
brew "lazygit"
# Terminal-based AI coding assistant
brew "opencode"
# Recursively search files
brew "ripgrep"
# Minimal, blazing fast, cross-platform prompt
brew "starship"
# Command-line note taker
brew "tealdeer"
# Command line tool for managing worktrees
brew "worktrunk"
# Jump to directories
brew "zoxide"
```

- [ ] **Step 2: Verify the tap resolves `opencode` / `worktrunk`**

Run: `rg -n "anomalyco/tap" home/dot_config/homebrew/private_Brewfile`
Expected: the existing `tap "anomalyco/tap", trusted: true` (line 1) is already present; the top-level `brew "opencode"` and `brew "worktrunk"` entries are expected to resolve from this tap. **Cannot execute `brew info` on this machine** — flag in the PR/commit that macOS must confirm `opencode` and `worktrunk` resolve from `anomalyco/tap`.

- [ ] **Step 3: Confirm the Brewfile stays valid bundle syntax**

Run: `ruby -c home/dot_config/homebrew/private_Brewfile` (if ruby is available) — otherwise `python3 -c "import pathlib; [line for line in pathlib.Path('home/dot_config/homebrew/private_Brewfile').read_text().splitlines() if line.startswith('brew ')]"` to eyeball that every appended line is `brew "name"` or `brew "name", ...`.
Expected: syntax valid, all additions are plain `brew "name"` one-liners.

- [ ] **Step 4: Commit**

```bash
git add home/dot_config/homebrew/private_Brewfile
git commit -m "feat(brew): add cli formulae for macos parity"
```

---

### Task 5: Split zshenv into per-OS fragments

**Files:**
- Modify: `home/dot_zshenv.tmpl`
- Create: `home/dot_zshenv-darwin.tmpl`
- Create: `home/dot_zshenv-wsl.tmpl`
- Modify: `home/.chezmoiignore`

**Interfaces:**
- Consumes: `wsl` (existing) and `.chezmoi.os` (built-in) for gating; `debian` / `arch_family` are NOT used here (no Debian/Arch fragments this round).
- Produces: `~/.zshenv-darwin` (macOS only), `~/.zshenv-wsl` (WSL only), sourced conditionally by the core `~/.zshenv`.

- [ ] **Step 1: Create `home/dot_zshenv-darwin.tmpl`**

Move the `java_home` block (old lines 20-24) and the Homebrew eval block (old lines 89-94) out of `dot_zshenv.tmpl` into this file:

```bash
if [[ -x /usr/libexec/java_home ]] && /usr/libexec/java_home -v 1.8 &>/dev/null; then
  export JAVA_HOME="$(/usr/libexec/java_home -v 1.8)"
fi

# Eval Homebrew if we find it on the system
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```

- [ ] **Step 2: Create `home/dot_zshenv-wsl.tmpl`**

Move the WSL Bitwarden SSH-agent bridge block (old lines 30-62, the body of the `{{ if .wsl }}` block, without the template wrapper) into this file, verbatim:

```bash
# Bitwarden SSH Agent Bridge for WSL2
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

if [ ! -S "$SSH_AUTH_SOCK" ]; then
    rm -f "$SSH_AUTH_SOCK"

    # Cache location for the resolved binary path
    NPIPERELAY_CACHE="$XDG_CACHE_HOME/npiperelay_path"

    # 1. Read cached path, or locate via Windows PATH/WinGet glob fallback
    if [ -f "$NPIPERELAY_CACHE" ] && [ -x "$(cat "$NPIPERELAY_CACHE")" ]; then
        NPIPERELAY_PATH=$(cat "$NPIPERELAY_CACHE")
    else
        mkdir -p "$XDG_CACHE_HOME"
        WIN_PATH=$(where.exe npiperelay.exe 2>/dev/null | head -n 1 | tr -d '\r')

        if [ -n "$WIN_PATH" ]; then
            NPIPERELAY_PATH=$(wslpath -u "$WIN_PATH")
        else
            # Wildcard fallback to handle WinGet directory structure dynamically
            NPIPERELAY_PATH=$(ls /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Packages/albertony.npiperelay*/npiperelay.exe 2>/dev/null | head -n 1)
        fi

        # Save to cache if found
        if [ -n "$NPIPERELAY_PATH" ]; then
            echo "$NPIPERELAY_PATH" > "$NPIPERELAY_CACHE"
        fi
    fi

    # 2. Spawn the background bridge
    if [ -n "$NPIPERELAY_PATH" ]; then
        ( setsid socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork EXEC:"${NPIPERELAY_PATH} -ei -s //./pipe/openssh-ssh-agent",nofork & ) >/dev/null 2>&1
    fi
fi
```

- [ ] **Step 3: Rewrite `home/dot_zshenv.tmpl`**

Remove the moved blocks and insert a fragment-sourcing block in place of the Homebrew eval block (at the old `# 2. Eval Homebrew…` comment, line 89 — i.e., **after** the baseline path array at lines 79-87):

```sh
# 2. Source OS-specific fragments (gated by .chezmoiignore)
{{ if eq .chezmoi.os "darwin" }}[[ -f "$HOME/.zshenv-darwin" ]] && source "$HOME/.zshenv-darwin"{{ end }}
{{ if .wsl }}[[ -f "$HOME/.zshenv-wsl" ]] && source "$HOME/.zshenv-wsl"{{ end }}
```

**Placement is deliberate:** fragments must be sourced *after* the baseline path block. The darwin fragment's `brew shellenv` prepends `/opt/homebrew/bin` and must not be clobbered by the later baseline reset — the current file gets this right by eval'ing brew after baseline (line 89), and moving that to a fragment must preserve the ordering. (The wsl bridge and java_home only set vars / connect a socket; they're order-insensitive.) Also remove the now-empty `{{ if eq .chezmoi.os "darwin" }}` java_home block and the `{{ if .wsl -}}` wrapper, replacing line 26 area and the wsl block with just `export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"` (line 26 stays; the wsl block at lines 28-63 is deleted).

No `.zshenv-debian` / `.zshenv-arch` fragments or sourcing lines are added this round — the agreed design creates only the darwin and wsl fragments, and Debian/Arch currently have no OS-specific zshenv content to move. Future OS-specific content gets a new fragment + sourcing line then.

Keep everything else (YARN/NPM env, `BITWARDENCLI_APPDATA_DIR`, `HOMEBREW_NO_AUTO_UPDATE`/`HOMEBREW_NO_ENV_HINTS`, `GOPATH`/`GOMODCACHE`, `STARSHIP_CONFIG`, path baseline, mise shims eval, XDG_BIN prepend, `.work` env, `export PATH MANPATH`) unchanged. The final file must contain no `{{ if eq .chezmoi.os "darwin" }}` or `{{ if .wsl }}` blocks other than the fragment-sourcing lines.

- [ ] **Step 4: Add ignore rules so fragments only exist on their OS**

Append to `home/.chezmoiignore`:

```
{{ if not (eq .chezmoi.os "darwin") -}}
.zshenv-darwin
{{- end }}
{{ if not .wsl -}}
.zshenv-wsl
{{- end }}
```

- [ ] **Step 5: Verify on this machine**

Run: `chezmoi apply --dry-run -S "$PWD" --verbose 2>&1 | rg "zshenv"`
Expected: `.zshenv` renders; `.zshenv-darwin` and `.zshenv-wsl` are NOT listed (not darwin, not wsl). Confirm no `java_home`/`npiperelay` content remains in `home/dot_zshenv.tmpl` by eyeballing the file.

- [ ] **Step 6: Bash syntax-check the fragments**

Run: `bash -n home/dot_zshenv-darwin.tmpl && bash -n home/dot_zshenv-wsl.tmpl`
Expected: no output (syntax OK).

- [ ] **Step 7: Commit**

```bash
git add home/dot_zshenv.tmpl home/dot_zshenv-darwin.tmpl home/dot_zshenv-wsl.tmpl home/.chezmoiignore
git commit -m "refactor(env): split zshenv into os fragments"
```

---

### Task 6: Update README packman documentation

**Files:**
- Modify: `README.md:37`

**Interfaces:**
- Consumes: nothing structurally; documents the new ownership map from Tasks 3-5.

- [ ] **Step 1: Update the "Packmans" row**

Replace the row starting `| **Packmans** |` (line 37) with:

```markdown
| **Packmans** | [Homebrew](https://brew.sh) (macOS formulae/casks in [`Brewfile`](home/dot_config/homebrew/Brewfile)), [pacman](https://wiki.archlinux.org/title/Pacman) + [yay](https://github.com/Jguer/yay) (Omarchy/Arch, driven by `run_onchange_before_pacman.sh.tmpl`), [apt](https://en.wikipedia.org/wiki/APT_%28software%29) + [mise](https://mise.jdx.dev) (Debian/WSL; CLI tools in [`tools-debian.toml`](home/dot_config/mise/conf.d/tools-debian.toml.tmpl)), mise reserved for runtimes |
```

- [ ] **Step 2: Verify the table is still well-formed**

Run: `rg -n "^\| \*\*Packmans\*\*" README.md`
Expected: single matching line.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document per-platform package managers"
```

---

### Task 7: Live-apply on this Omarchy machine and verify system packages win

**Files:**
- No new files. Applies the work from Tasks 1–6 and verifies the real effect on this machine.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: a machine where CLI tools resolve from `/usr/bin`/system packages instead of `${mise_installs}`, with mise config containing no stale CLI tools.

- [ ] **Step 1: Confirm state safety with the user before it mutates the system**

Run: `chezmoi apply --dry-run -S "$PWD"` and show the diff to the user. Live apply will execute the pacman`/`yay` install script (network + root). **Get explicit approval before Step 2.**

- [ ] **Step 2: Live apply and install**

Run: `chezmoi apply -S "$PWD"` (or `chezmoi apply` from the worktree root). This runs `run_onchange_before_pacman.sh.tmpl` first (installs packages with sudo) then applies all files.
Expected: pacman installs the listed packages; yay installs `hwatch`; file changes land.

- [ ] **Step 3: Verify tools now resolve from system paths**

Run:
```bash
for b in atuin delta bat bw chezmoi eza gum fastfetch fzf gh gitleaks hwatch lazygit opencode rg starship wt tldr zoxide; do
  printf "%s => %s\n" "$b" "$(command -v "$b")"
done
```
Expected: each path starts with `/usr/bin` (or a system location), **not** `~/.local/share/mise/installs`.

- [ ] **Step 4: Verify mise no longer manages these tools**

Run: `mise ls`
Expected: no CLI tools listed under `Tools` (runtimes only, currently none) — mise `[tools]` is empty in `~/.config/mise/config.toml`.

- [ ] **Step 5: Optional — prune orphaned mise installs**

Run: `mise prune` (removes tool versions no longer referenced). Confirm with the user first; it frees disk but deletes the old mise binary trees.

- [ ] **Step 6: Report and stop (no merge/push)**

Summarize: what changed, live verification results, and the macOS follow-up (confirm `opencode`/`worktrunk` resolve from `anomalyco/tap`). Do NO merge or push.

---

## Self-Review

**Spec coverage:**
- macOS → Brewfile kept + parity formulae → Tasks 4. ✓
- Omarchy → new inlined pacman/yay script → Task 3. ✓
- Debian/WSL kept working → apt script untouched, mise CLI fallback in `conf.d/tools-debian.toml`, `.zshenv-wsl` bridge preserved → Tasks 2, 5. ✓
- mise → settings-only + runtimes later; no speculative runtime stanzas added → Task 2. ✓
- zshenv per-OS fragments, zshenv only (no zshrc split) → Task 5. ✓
- Scripts stay top-level → Tasks 3, and existing scripts untouched. ✓
- Build on `feature/omarchy` → worktree `feat/packages-segmentation` based off `origin/feature/omarchy`. ✓

**Placeholder scan:** No TBDs. Every step has exact file content or exact command. The one flagged-unknown (`opencode`/`worktrunk` resolving from `anomalyco/tap`) is explicitly a verification assignment, not a placeholder.

**Type/name consistency:** `.debian`, `.arch_family` used consistently across Tasks 1, 2, 3 and `.chezmoiignore`; `.wsl` reused in Task 5. Fragment filenames consistent between creation (Task 5) and ignore rules (Task 5 Step 4). mise fragment is `tools-debian.toml` everywhere (hyphenated, per constraint). Package names in Task 3 match the verified mappings listed in the task.

**Scope check:** Fits one plan. The Brewfile task is bounded to parity additions. No dispatcher/shared-TOML/pacdef machinery added (explicitly out of scope by design).