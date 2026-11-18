#!/usr/bin/env bash
# Install sk-pages on this host.
#
# With skskills: installs the skill (so Claude Code, Codex, Hermes, Pi and OpenCode
# can load SKILL.md) and links the CLI onto PATH from the installed copy.
# Without skskills: copies the CLI to ~/.local/bin.
#
#   ./install.sh            install or upgrade
#   ./install.sh --check    show what is installed, change nothing
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="${SKPAGES_BIN_DIR:-$HOME/.local/bin}"
SKILL_HOME="${SKSKILLS_HOME:-$HOME/.skskills}/installed/sk-pages"

if [ "${1:-}" = "--check" ]; then
    command -v sk-pages >/dev/null && sk-pages --version || echo "sk-pages not on PATH"
    [ -d "$SKILL_HOME" ] && echo "skill: $SKILL_HOME" || echo "skill: not installed"
    exit 0
fi

mkdir -p "$BIN"
if command -v skskills >/dev/null 2>&1; then
    skskills install "$HERE/skill" --force
    target="$SKILL_HOME/sk-pages"
    [ -f "$target" ] || target="$(find "${SKSKILLS_HOME:-$HOME/.skskills}/installed" -path '*sk-pages/sk-pages' | head -n1)"
    if [ -z "$target" ] || [ ! -f "$target" ]; then
        echo "install.sh: skskills did not install the CLI" >&2
        exit 1
    fi
    chmod +x "$target"
    ln -sfn "$target" "$BIN/sk-pages"
    skskills agents sync >/dev/null 2>&1 || true
    echo "installed skill + CLI: $BIN/sk-pages -> $target"
else
    install -m 755 "$HERE/skill/sk-pages" "$BIN/sk-pages"
    echo "installed CLI: $BIN/sk-pages (skskills not found, skill not registered)"
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "note: $BIN is not on PATH" ;; esac
"$BIN/sk-pages" --version
[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/sk-pages/config" ] || \
    echo "next: write ${XDG_CONFIG_HOME:-$HOME/.config}/sk-pages/config (see README, Configuration)"
