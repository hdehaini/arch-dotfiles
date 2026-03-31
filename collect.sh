#!/bin/bash
# ============================================================
# collect.sh — Collect all config files into the dotfiles repo
# Run this from anywhere: bash /path/to/collect.sh
# ============================================================

set -e

DOTFILES_DIR="/mnt/storage/Coding-Projects/Linux/arch-dotfiles"
CONFIG_DIR="$DOTFILES_DIR/config"
HOME_DIR="$DOTFILES_DIR/home"

echo "==> Collecting dotfiles into $DOTFILES_DIR"

# Create directory structure
mkdir -p "$CONFIG_DIR/hypr"
mkdir -p "$CONFIG_DIR/waybar"
mkdir -p "$CONFIG_DIR/kitty"
mkdir -p "$CONFIG_DIR/wofi"
mkdir -p "$CONFIG_DIR/dunst"
mkdir -p "$CONFIG_DIR/gtk-3.0"
mkdir -p "$CONFIG_DIR/gtk-4.0"
mkdir -p "$HOME_DIR/.icons/default"

echo ""
echo "── Copying ~/.config files ──"

# Hyprland
if [ -d "$HOME/.config/hypr" ]; then
    cp -r "$HOME/.config/hypr/"* "$CONFIG_DIR/hypr/"
    echo "  ✓ hypr"
fi

# Waybar
if [ -d "$HOME/.config/waybar" ]; then
    cp -r "$HOME/.config/waybar/"* "$CONFIG_DIR/waybar/"
    echo "  ✓ waybar"
fi

# Kitty
if [ -d "$HOME/.config/kitty" ]; then
    cp -r "$HOME/.config/kitty/"* "$CONFIG_DIR/kitty/"
    echo "  ✓ kitty"
fi

# Wofi
if [ -d "$HOME/.config/wofi" ]; then
    cp -r "$HOME/.config/wofi/"* "$CONFIG_DIR/wofi/"
    echo "  ✓ wofi"
fi

# Dunst
if [ -d "$HOME/.config/dunst" ]; then
    cp -r "$HOME/.config/dunst/"* "$CONFIG_DIR/dunst/"
    echo "  ✓ dunst"
fi

# GTK
if [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    cp "$HOME/.config/gtk-3.0/settings.ini" "$CONFIG_DIR/gtk-3.0/"
    echo "  ✓ gtk-3.0"
fi
if [ -f "$HOME/.config/gtk-4.0/settings.ini" ]; then
    cp "$HOME/.config/gtk-4.0/settings.ini" "$CONFIG_DIR/gtk-4.0/"
    echo "  ✓ gtk-4.0"
fi

# Cursor theme
if [ -f "$HOME/.icons/default/index.theme" ]; then
    cp "$HOME/.icons/default/index.theme" "$HOME_DIR/.icons/default/"
    echo "  ✓ cursor theme"
fi

# GTK2 rc
if [ -f "$HOME/.gtkrc-2.0" ]; then
    cp "$HOME/.gtkrc-2.0" "$HOME_DIR/"
    echo "  ✓ .gtkrc-2.0"
fi

echo ""
echo "── Exporting installed package list ──"

# Export explicitly installed packages (not dependencies)
pacman -Qqe > "$DOTFILES_DIR/packages.txt"
echo "  ✓ packages.txt"

# Export AUR packages separately
pacman -Qqem > "$DOTFILES_DIR/packages-aur.txt"
echo "  ✓ packages-aur.txt"

echo ""
echo "── Updating sync-docs.sh package snapshot ──"

# Save current package list as last known for sync-docs.sh comparison
cp "$DOTFILES_DIR/packages.txt" "$DOTFILES_DIR/.last-packages.txt" 2>/dev/null || true

echo ""
echo "==> Done! All configs collected."
echo ""
echo "Next steps:"
echo "  cd $DOTFILES_DIR"
echo "  git add -A"
echo "  git commit -m 'chore: sync dotfiles'"
echo "  git push"
