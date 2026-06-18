#!/usr/bin/env bash
# Install (or refresh) the hostname-named entrypoint in ~/.local/bin.
#
# Usage:
#   ./install.sh                # link to ~/.local/bin/$(hostname)
#   ./install.sh <name>         # override the name explicitly
#   ./install.sh --uninstall    # remove the current symlink
#
# Safe to re-run any time (e.g., after a hostname change). It just refreshes
# the symlink and warns about shadowed commands or missing PATH.

set -eu

CLI_ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CLI="$CLI_ROOT/cli"
BIN_DIR="$HOME/.local/bin"

die() { echo "error: $*" >&2; exit 1; }

[ -x "$CLI" ] || die "missing or non-executable: $CLI"

# Parse args.
mode=install
name=""
while [ $# -gt 0 ]; do
    case "$1" in
        --uninstall) mode=uninstall; shift ;;
        -h|--help)
            sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        -*) die "unknown flag: $1" ;;
        *)  name="$1"; shift ;;
    esac
done

[ -n "$name" ] || name="$(hostname -s 2>/dev/null || hostname)"
[ -n "$name" ] || die "could not determine hostname"

case "$name" in
    */*|-*|"") die "invalid name: $name" ;;
esac

LINK="$BIN_DIR/$name"

if [ "$mode" = "uninstall" ]; then
    if [ -L "$LINK" ]; then
        rm "$LINK"
        echo "removed: $LINK"
    else
        echo "nothing to remove at $LINK"
    fi
    exit 0
fi

# Warn if hostname collides with an existing command that isn't us.
existing="$(command -v "$name" 2>/dev/null || true)"
if [ -n "$existing" ] && [ "$(readlink -f "$existing" 2>/dev/null || echo "$existing")" != "$CLI" ]; then
    echo "warning: '$name' already resolves to $existing"
    echo "         after install, PATH order decides which wins."
fi

mkdir -p "$BIN_DIR"
ln -sfn "$CLI" "$LINK"
chmod +x "$CLI"
chmod +x "$CLI_ROOT/commands"/* 2>/dev/null || true

# PATH sanity.
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo "note: $BIN_DIR is not in your \$PATH."
        echo "      add this to your shell rc (~/.bashrc, ~/.zshrc, etc.):"
        echo "        export PATH=\"\$HOME/.local/bin:\$PATH\""
        ;;
esac

echo "installed: $LINK -> $CLI"
echo "try:       $name --help"
