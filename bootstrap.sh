#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — Deploy this dotfiles repo on a fresh Arch install.
#
# Run after cloning:
#   git clone <repo-url> ~/arch-dotfiles
#   cd ~/arch-dotfiles
#   bash bootstrap.sh
#
# Modes:
#   ./bootstrap.sh           Install required packages + link configs.
#   ./bootstrap.sh --full    Also restore every package in packages.txt /
#                            packages-aur.txt (games, browsers, the works).
#   ./bootstrap.sh --link    Only symlink configs; skip package install.
#                            Use this if you ran it once and just want to
#                            re-link after collect.sh added new tools.
# ============================================================
set -eu

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONFIG_IN="$DOTFILES_DIR/config"
HOME_IN="$DOTFILES_DIR/home"

mode=normal
for arg in "$@"; do
    case "$arg" in
        --full) mode=full ;;
        --link) mode=link ;;
        -h|--help)
            sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown flag: $arg" >&2; exit 1 ;;
    esac
done

banner() {
    echo
    echo "── $* ──"
}

confirm() {
    read -rp "$1 [y/N] " r
    [[ "$r" =~ ^[Yy]$ ]]
}

symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "$dst.bak"
        echo "    backed up existing → $dst.bak"
    fi
    ln -sfn "$src" "$dst"
    echo "    ✓ $dst"
}

# --------------------------------------------------------------------------
# Required packages — the minimum needed for the bar, profiles, scripts,
# and core desktop to work. Keep this in sync with what the scripts in
# config/eww/scripts, config/profiles, and config/dotfiles-cli actually
# call (`bash audit-tools.sh` if you want a fresh check).
# --------------------------------------------------------------------------
OFFICIAL_PACKAGES=(
    # system base
    base-devel git sudo networkmanager network-manager-applet ntfs-3g
    polkit-gnome xdg-desktop-portal-hyprland xdg-utils
    qt5-wayland qt6-wayland qt6-5compat

    # audio
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
    pavucontrol pamixer

    # GPU drivers (AMD here; swap for nvidia-* if needed)
    mesa vulkan-radeon libva-mesa-driver

    # display manager + login
    sddm

    # Hyprland desktop
    hyprland hyprsunset awww kitty wofi dunst nemo

    # screenshot / clipboard
    grim slurp wl-clipboard

    # scripting deps used by eww + profiles + dotfiles-cli
    socat jq inotify-tools libnotify
    imagemagick brightnessctl playerctl
    matugen
    python python-pip

    # fonts
    noto-fonts noto-fonts-emoji
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd

    # containers (for selfhosted services like odysseus)
    docker docker-compose

    # misc tooling the configs reference
    fastfetch nwg-look xsettingsd

    # browsers / general apps
    firefox
)

AUR_PACKAGES=(
    # eww (widget toolkit — git build because GTK build needs latest)
    eww

    # hyprland helpers
    cursor-clip-git
    hyprshutdown

    # cursor + icon themes referenced by your configs
    bibata-cursor-theme-bin
    papirus-icon-theme
    papirus-folders-git

    # network/dmenu integration used in wofi flows
    networkmanager-dmenu-git
)

# --------------------------------------------------------------------------

echo "╔══════════════════════════════════════════╗"
echo "║   Arch Dotfiles Bootstrap (Hyprland +    ║"
echo "║   eww + per-machine CLI)                 ║"
echo "╚══════════════════════════════════════════╝"
echo
echo "Repo:  $DOTFILES_DIR"
echo "Mode:  $mode"

if [ "$mode" != "link" ]; then
    banner "Install paru (AUR helper)"
    if ! command -v paru >/dev/null; then
        sudo pacman -S --needed --noconfirm git base-devel
        tmp=$(mktemp -d)
        git clone https://aur.archlinux.org/paru.git "$tmp/paru"
        ( cd "$tmp/paru" && makepkg -si --noconfirm )
        rm -rf "$tmp"
    fi
    echo "  ✓ paru ready"

    banner "Enable multilib repo"
    if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
        sudo sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf
        sudo pacman -Sy
    fi
    echo "  ✓ multilib enabled"

    banner "Install official-repo packages (${#OFFICIAL_PACKAGES[@]})"
    sudo pacman -S --needed "${OFFICIAL_PACKAGES[@]}"

    banner "Install AUR packages (${#AUR_PACKAGES[@]})"
    paru -S --needed "${AUR_PACKAGES[@]}"

    if [ "$mode" = "full" ]; then
        banner "FULL mode: restore everything from packages*.txt"
        if [ -f "$DOTFILES_DIR/packages.txt" ]; then
            sudo pacman -S --needed - < "$DOTFILES_DIR/packages.txt" || true
        fi
        if [ -f "$DOTFILES_DIR/packages-aur.txt" ]; then
            paru -S --needed - < "$DOTFILES_DIR/packages-aur.txt" || true
        fi
    fi
fi

banner "Symlink ~/.config dirs"
for d in "$CONFIG_IN"/*/; do
    name="$(basename "$d")"
    symlink "$d" "$HOME/.config/$name"
done

banner "Symlink ~/.config files"
for f in "$CONFIG_IN"/*; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    symlink "$f" "$HOME/.config/$name"
done

banner "Symlink \$HOME files / dirs"
for f in "$HOME_IN"/* "$HOME_IN"/.[!.]*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    symlink "$f" "$HOME/$name"
done

banner "Install per-machine CLI ($(hostname))"
if [ -x "$HOME/.config/dotfiles-cli/install.sh" ]; then
    "$HOME/.config/dotfiles-cli/install.sh"
fi

banner "Enable system services"
sudo systemctl enable --now NetworkManager
sudo systemctl enable sddm
sudo systemctl enable --now docker || true
systemctl --user enable --now pipewire pipewire-pulse wireplumber

banner "Apply GTK theme defaults"
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"      || true
gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"     || true
gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice" || true
gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 11" || true

echo
echo "╔══════════════════════════════════════════╗"
echo "║              All done.                   ║"
echo "╚══════════════════════════════════════════╝"
echo
echo "Post-install todos:"
echo "  • Drop wallpapers into ~/Pictures/wallpapers/"
echo "  • Edit ~/.config/hypr/hyprland.conf monitor= lines for your displays"
echo "  • Add yourself to the docker group: sudo usermod -aG docker \$USER"
echo "  • Reboot. Hyprland starts via SDDM."
echo
echo "Then on first login:"
echo "  $(hostname) --help          # your machine-named CLI"
echo "  $(hostname) profile list    # see desktop profiles"
echo "  $(hostname) profile menu    # SUPER+SHIFT+P picker"
