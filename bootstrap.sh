#!/bin/bash
# ============================================================
# bootstrap.sh — Deploy dotfiles on a new Arch Linux machine
# Run after cloning the repo:
#   git clone <your-repo-url> ~/arch-dotfiles
#   cd ~/arch-dotfiles
#   bash bootstrap.sh
# ============================================================

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$DOTFILES_DIR/config"
HOME_DIR="$DOTFILES_DIR/home"

echo "╔══════════════════════════════════════════╗"
echo "║     Arch Dotfiles Bootstrap Script       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Dotfiles directory: $DOTFILES_DIR"
echo ""

# ── Helper functions ──
confirm() {
    read -rp "$1 [y/N] " response
    [[ "$response" =~ ^[Yy]$ ]]
}

symlink() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -e "$dest" ] && [ ! -L "$dest" ]; then
        echo "  ! Backing up existing $dest → $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    ln -sf "$src" "$dest"
    echo "  ✓ Linked $dest"
}

# ── Step 1: Install paru ──
echo "── Step 1: Install paru (AUR helper) ──"
if ! command -v paru &>/dev/null; then
    echo "  Installing paru..."
    sudo pacman -S --needed git base-devel
    git clone https://aur.archlinux.org/paru.git /tmp/paru
    cd /tmp/paru && makepkg -si
    cd "$DOTFILES_DIR"
    echo "  ✓ paru installed"
else
    echo "  ✓ paru already installed"
fi

# ── Step 2: Enable multilib ──
echo ""
echo "── Step 2: Enable multilib repo ──"
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    echo "  Enabling multilib..."
    sudo sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf
    sudo pacman -Sy
    echo "  ✓ multilib enabled"
else
    echo "  ✓ multilib already enabled"
fi

# ── Step 3: Install official packages ──
echo ""
echo "── Step 3: Install official repo packages ──"
OFFICIAL_PACKAGES=(
    # System
    base-devel vim networkmanager ntfs-3g sudo
    # Audio
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    # GPU (AMD)
    mesa vulkan-radeon libva-mesa-driver
    # Desktop
    hyprland waybar kitty wofi hyprpaper dunst
    polkit-gnome xdg-desktop-portal-hyprland
    qt5-wayland qt6-wayland qt6-5compat
    # Login
    sddm
    # Apps
    thunar wl-clipboard grim slurp
    firefox steam lutris gamemode mangohud
    pavucontrol imagemagick
    # GTK
    nwg-look
    # Fonts
    noto-fonts noto-fonts-emoji
)

echo "  Installing ${#OFFICIAL_PACKAGES[@]} packages..."
sudo pacman -S --needed "${OFFICIAL_PACKAGES[@]}"
echo "  ✓ Official packages installed"

# ── Step 4: Install AUR packages ──
echo ""
echo "── Step 4: Install AUR packages ──"
AUR_PACKAGES=(
    ttf-jetbrains-mono-nerd
    ttf-input-nerd
    tokyonight-gtk-theme-git
    papirus-icon-theme
    papirus-folders-git
    bibata-cursor-theme-bin
    visual-studio-code-bin
    discord
    heroic-games-launcher-bin
    proton-ge-custom-bin
    sddm-theme-tokyo-night-git
)

echo "  Installing ${#AUR_PACKAGES[@]} AUR packages..."
paru -S --needed "${AUR_PACKAGES[@]}"
echo "  ✓ AUR packages installed"

# ── Step 5: Set Papirus folder colors ──
echo ""
echo "── Step 5: Set Papirus folder colors ──"
papirus-folders -C indigo --theme Papirus-Dark
echo "  ✓ Papirus folders set to indigo"

# ── Step 6: Symlink config files ──
echo ""
echo "── Step 6: Symlinking config files ──"

# Hyprland
if [ -d "$CONFIG_DIR/hypr" ]; then
    symlink "$CONFIG_DIR/hypr" "$HOME/.config/hypr"
fi

# Waybar
if [ -d "$CONFIG_DIR/waybar" ]; then
    symlink "$CONFIG_DIR/waybar" "$HOME/.config/waybar"
fi

# Kitty
if [ -d "$CONFIG_DIR/kitty" ]; then
    symlink "$CONFIG_DIR/kitty" "$HOME/.config/kitty"
fi

# Wofi
if [ -d "$CONFIG_DIR/wofi" ]; then
    symlink "$CONFIG_DIR/wofi" "$HOME/.config/wofi"
fi

# Dunst
if [ -d "$CONFIG_DIR/dunst" ]; then
    symlink "$CONFIG_DIR/dunst" "$HOME/.config/dunst"
fi

# GTK
if [ -d "$CONFIG_DIR/gtk-3.0" ]; then
    symlink "$CONFIG_DIR/gtk-3.0" "$HOME/.config/gtk-3.0"
fi
if [ -d "$CONFIG_DIR/gtk-4.0" ]; then
    symlink "$CONFIG_DIR/gtk-4.0" "$HOME/.config/gtk-4.0"
fi

# Cursor
if [ -d "$HOME_DIR/.icons" ]; then
    symlink "$HOME_DIR/.icons/default" "$HOME/.icons/default"
fi

# GTK2
if [ -f "$HOME_DIR/.gtkrc-2.0" ]; then
    symlink "$HOME_DIR/.gtkrc-2.0" "$HOME/.gtkrc-2.0"
fi

echo "  ✓ All configs symlinked"

# ── Step 7: Enable services ──
echo ""
echo "── Step 7: Enabling system services ──"
sudo systemctl enable --now NetworkManager
sudo systemctl enable sddm
systemctl --user enable --now pipewire pipewire-pulse wireplumber
echo "  ✓ Services enabled"

# ── Step 8: Apply GTK settings ──
echo ""
echo "── Step 8: Applying GTK theme ──"
gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark"
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 11"
echo "  ✓ GTK theme applied"

# ── Step 9: SDDM theme ──
echo ""
echo "── Step 9: SDDM theme ──"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/sddm.conf > /dev/null <<EOF
[Theme]
Current=tokyo-night-sddm

[General]
DisplayServer=x11

[Users]
DefaultUser=$(whoami)
EOF
echo "  ✓ SDDM configured"
echo "  ! Note: Copy your login wallpaper to:"
echo "    /usr/share/sddm/themes/tokyo-night-sddm/nebula-login.png"
echo "    Then update Background= in the theme.conf"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║           Bootstrap Complete!            ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "  Reboot to start Hyprland via SDDM."
echo "  Don't forget to:"
echo "    1. Copy your wallpapers to ~/Pictures/wallpapers/"
echo "    2. Update hyprpaper.conf with correct monitor names"
echo "    3. Set your BIOS boot order (GRUB before Windows)"
echo ""
