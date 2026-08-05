#!/bin/bash
# ============================================================
# sync-docs.sh — Sync package changes to README.md
# Detects newly installed/removed packages since last run
# and adds placeholder sections to README.md for new ones.
# ============================================================

set -e

DOTFILES_DIR="/mnt/storage/Coding-Projects/Linux/arch-dotfiles"
README="$DOTFILES_DIR/README.md"
CURRENT_PKG="$DOTFILES_DIR/packages.txt"
LAST_PKG="$DOTFILES_DIR/.last-packages.txt"

echo "==> Syncing package changes to README.md"

# ── Generate current package list ──
pacman -Qqe > /tmp/current-packages.txt

# ── Diff against last known list ──
if [ ! -f "$LAST_PKG" ]; then
    echo "  ! No previous package snapshot found."
    echo "    Run collect.sh first to create a baseline."
    exit 1
fi

ADDED=$(comm -23 <(sort /tmp/current-packages.txt) <(sort "$LAST_PKG") || true)
REMOVED=$(comm -13 <(sort /tmp/current-packages.txt) <(sort "$LAST_PKG") || true)

if [ -z "$ADDED" ] && [ -z "$REMOVED" ]; then
    echo "  ✓ No package changes detected. README.md is up to date."
    exit 0
fi

# ── Report changes ──
echo ""
if [ -n "$ADDED" ]; then
    echo "  New packages detected:"
    echo "$ADDED" | while read -r pkg; do echo "    + $pkg"; done
fi

if [ -n "$REMOVED" ]; then
    echo "  Removed packages detected:"
    echo "$REMOVED" | while read -r pkg; do echo "    - $pkg"; done
fi

echo ""

# ── Append new package sections to README ──
if [ -n "$ADDED" ]; then
    echo "" >> "$README"
    echo "---" >> "$README"
    echo "" >> "$README"
    echo "## 🆕 New Packages (auto-detected — add descriptions)" >> "$README"
    echo "" >> "$README"
    echo "_The following packages were installed since the last sync._" >> "$README"
    echo "_Fill in the description and move to the appropriate section._" >> "$README"
    echo "" >> "$README"

    echo "$ADDED" | while read -r pkg; do
        # Try to get a short description from pacman
        DESC=$(pacman -Qi "$pkg" 2>/dev/null | grep "^Description" | cut -d: -f2- | xargs || echo "No description available")
        echo "### \`$pkg\`" >> "$README"
        echo "" >> "$README"
        echo "**Pacman description:** $DESC" >> "$README"
        echo "" >> "$README"
        echo "**Install command:**" >> "$README"
        echo "" >> "$README"
        echo '```bash' >> "$README"
        # Check if it's an AUR package
        if pacman -Qi "$pkg" 2>/dev/null | grep -q "AUR"; then
            echo "paru -S $pkg" >> "$README"
        else
            echo "sudo pacman -S $pkg" >> "$README"
        fi
        echo '```' >> "$README"
        echo "" >> "$README"
        echo "**What it does:** _TODO: Add description_" >> "$README"
        echo "" >> "$README"
    done
fi

# ── Note removed packages ──
if [ -n "$REMOVED" ]; then
    echo "" >> "$README"
    echo "## 🗑️ Removed Packages (auto-detected)" >> "$README"
    echo "" >> "$README"
    echo "_The following packages were removed since the last sync._" >> "$README"
    echo "_Remove their sections from this README if no longer needed._" >> "$README"
    echo "" >> "$README"
    echo "$REMOVED" | while read -r pkg; do
        echo "- \`$pkg\`" >> "$README"
    done
    echo "" >> "$README"
fi

# ── Update snapshots ──
cp /tmp/current-packages.txt "$CURRENT_PKG"
cp /tmp/current-packages.txt "$LAST_PKG"

echo "  ✓ README.md updated with package changes"
echo "  ✓ Package snapshot updated"
echo ""
echo "Next steps:"
echo "  1. Open README.md and fill in the TODO descriptions"
echo "  2. Move new sections to the appropriate place in the doc"
echo "  3. Run collect.sh to sync config files"
echo "  4. git add -A && git commit -m 'docs: sync package changes'"
