#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — set up this dotfiles repo on a fresh Arch install.
#
#   git clone https://github.com/hdehaini/arch-dotfiles ~/arch-dotfiles
#   cd ~/arch-dotfiles && ./bootstrap.sh
#
# What it does (safe to re-run; it skips what's already done):
#   1. Installs the base packages (packages/base.txt), plus the right GPU
#      drivers, CPU microcode, Bluetooth and laptop power tools for THIS
#      machine (detected, nothing hard-coded)
#   2. Offers your everyday apps (packages/apps.txt) — you choose
#   3. Links every config in config/ into ~/.config and home/ into ~
#      (existing files are moved aside to <name>.bak first)
#   4. Sets up the bar's Python environment and your location file
#   5. Installs the <hostname> command + tab completion, this machine's
#      screen layout file (hypr/hosts/<hostname>.lua, filled in at first
#      login), the login screen, and turns on the services the desktop needs
#
# Flags:
#   --link     only step 3 (re-link configs, no packages or sudo)
#   --full     also install EVERYTHING from packages.txt / packages-aur.txt
#              (the full snapshot of your main machine, games and all)
#   --yes      don't ask; install the apps too
# ============================================================
set -eu

REPO="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
MODE=normal YES=0
for arg in "$@"; do
    case "$arg" in
        --link) MODE=link ;;
        --full) MODE=full ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown flag: $arg (try --help)" >&2; exit 1 ;;
    esac
done

# --- output helpers ---------------------------------------------------------
if [ -t 1 ]; then B=$'\e[1m' C=$'\e[36m' G=$'\e[32m' Y=$'\e[33m' D=$'\e[2m' R=$'\e[0m'; else B= C= G= Y= D= R=; fi
step() { printf '\n%s%s── %s%s\n' "$B" "$C" "$*" "$R"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$R" "$*"; }
note() { printf '  %s!%s %s\n' "$Y" "$R" "$*"; }
ask()  {   # ask "Question?" → yes unless the answer starts with n
    [ "$YES" = 1 ] && return 0
    local a; read -rp "  $1 [Y/n] " a; [[ ! "$a" =~ ^[Nn] ]]
}
TODO=()

# Packages from a list file: strips comments and blank lines.
read_list() { sed 's/#.*//' "$1" | tr -s ' \t' '\n' | grep -v '^$' || true; }

# --- sanity -------------------------------------------------------------------
command -v pacman >/dev/null || { echo "This is for Arch Linux (pacman not found)." >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root (it uses sudo when needed)." >&2; exit 1; }
HOST="$(cat /proc/sys/kernel/hostname 2>/dev/null || uname -n)"

printf '%s%sarch-dotfiles setup%s  %s(machine: %s, mode: %s)%s\n' "$B" "$C" "$R" "$D" "$HOST" "$MODE" "$R"

# ==============================================================================
# 1–2. Packages
# ==============================================================================
if [ "$MODE" != link ]; then
    step "AUR helper"
    if command -v paru >/dev/null; then
        ok "paru already installed"
    else
        sudo pacman -S --needed --noconfirm git base-devel
        tmp="$(mktemp -d)"
        git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
        rm -rf "$tmp"
        ok "paru installed"
    fi

    step "Detecting this machine's hardware"
    HW=()
    case "$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)" in
        AuthenticAMD) HW+=(amd-ucode);   ok "AMD CPU → amd-ucode" ;;
        GenuineIntel) HW+=(intel-ucode); ok "Intel CPU → intel-ucode" ;;
    esac
    command -v lspci >/dev/null || sudo pacman -S --needed --noconfirm pciutils
    # The GPU's own vendor (4th quoted field), not the card/board maker.
    gpus="$(lspci -mm 2>/dev/null | grep -Ei '"(VGA|3D|Display)' | awk -F'"' '{print $4}' || true)"
    if grep -qi 'AMD\|ATI' <<<"$gpus"; then
        HW+=(mesa vulkan-radeon); ok "AMD graphics → mesa, vulkan-radeon"
    fi
    if grep -qi 'Intel' <<<"$gpus"; then
        HW+=(mesa vulkan-intel intel-media-driver); ok "Intel graphics → mesa, vulkan-intel, intel-media-driver"
    fi
    if grep -qi 'NVIDIA' <<<"$gpus"; then
        HW+=(nvidia-open-dkms nvidia-utils linux-headers); ok "NVIDIA graphics → nvidia-open-dkms, nvidia-utils"
        TODO+=("NVIDIA: see https://wiki.hypr.land/Nvidia/ (kernel parameter nvidia_drm.modeset=1, env vars)")
    fi
    [ -n "$gpus" ] || note "couldn't detect the GPU — install its drivers yourself"
    BLUETOOTH=0 LAPTOP=0
    if [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
        HW+=(bluez bluez-utils); BLUETOOTH=1; ok "Bluetooth adapter → bluez"
    fi
    for b in /sys/class/power_supply/*; do
        if [ "$(cat "$b/type" 2>/dev/null)" = Battery ] && [ "$(cat "$b/scope" 2>/dev/null)" != Device ]; then
            HW+=(power-profiles-daemon); LAPTOP=1; ok "Laptop battery → power-profiles-daemon"
            break
        fi
    done

    NOCONFIRM=(); [ "$YES" = 1 ] && NOCONFIRM=(--noconfirm)
    mapfile -t BASE < <(read_list "$REPO/packages/base.txt")
    mapfile -t APPS < <(read_list "$REPO/packages/apps.txt")

    step "Base packages (${#BASE[@]} + ${#HW[@]} for this hardware)"
    paru -S --needed "${NOCONFIRM[@]}" "${BASE[@]}" "${HW[@]}"

    step "Everyday apps (packages/apps.txt)"
    printf '%s\n' "${APPS[@]}" | column -c "${COLUMNS:-100}" | sed 's/^/  /'
    if ask "Install these apps?"; then
        paru -S --needed "${NOCONFIRM[@]}" "${APPS[@]}"
    else
        note "skipped — edit packages/apps.txt and re-run to install some later"
    fi

    if [ "$MODE" = full ]; then
        step "Everything from packages.txt / packages-aur.txt (--full)"
        if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
            # 32-bit libraries, needed by Steam and Wine.
            sudo sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf
            sudo pacman -Sy
        fi
        mapfile -t ALL < <(cat "$REPO/packages.txt" "$REPO/packages-aur.txt" 2>/dev/null | sort -u)
        paru -S --needed "${NOCONFIRM[@]}" "${ALL[@]}" || \
            note "some packages failed (renamed or gone?) — the rest are installed"
    fi
fi

# ==============================================================================
# 3. Link configs
# ==============================================================================
link() {   # link <repo path> <target>
    local src="$1" dst="$2"
    if [ "$(readlink -f "$dst" 2>/dev/null)" = "$(readlink -f "$src")" ]; then
        ok "${dst/#$HOME/\~} ${D}(already linked)${R}"
        return
    fi
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        rm -rf -- "$dst.bak"
        mv -- "$dst" "$dst.bak"
        note "moved your existing ${dst/#$HOME/\~} to ${dst/#$HOME/\~}.bak"
    fi
    ln -s "$src" "$dst"
    ok "${dst/#$HOME/\~}"
}

step "Linking configs into ~/.config"
for item in "$REPO"/config/*; do
    link "$item" "$HOME/.config/$(basename "$item")"
done
step "Linking files into ~"
for item in "$REPO"/home/* "$REPO"/home/.[!.]*; do
    [ -e "$item" ] || continue
    link "$item" "$HOME/$(basename "$item")"
done

[ "$MODE" = link ] && { echo; ok "configs linked"; exit 0; }

# ==============================================================================
# 4. Bar extras: Python environment and location
# ==============================================================================
step "Bar (eww) setup"
EWW="$REPO/config/eww"
if [ -f "$EWW/scripts/requirements.txt" ]; then
    [ -x "$EWW/scripts/.venv/bin/python" ] || python -m venv "$EWW/scripts/.venv"
    "$EWW/scripts/.venv/bin/pip" install -q -r "$EWW/scripts/requirements.txt"
    ok "Python environment for the prayer-time widget"
fi
if [ ! -f "$EWW/location.conf" ]; then
    cp "$EWW/location.conf.example" "$EWW/location.conf"
    TODO+=("Set your city for weather + prayer times: ~/.config/eww/location.conf")
fi
ok "location file: ~/.config/eww/location.conf"

# ==============================================================================
# 5. Command, login screen, services
# ==============================================================================
step "The $HOST command"
"$REPO/config/dotfiles-cli/install.sh" >/dev/null && ok "installed as: $HOST (try: $HOST --help)"
if ! grep -qF "dotfiles-cli/completion.bash" "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# Tab completion for the %s command\n[ -f ~/.config/dotfiles-cli/completion.bash ] && . ~/.config/dotfiles-cli/completion.bash\n' "$HOST" >> "$HOME/.bashrc"
fi
ok "tab completion (new terminals)"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
    if ! grep -qF '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
        printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
        ok "added ~/.local/bin to PATH in ~/.bashrc"
    fi ;;
esac

"$REPO/config/dotfiles-cli/commands/monitors" init >/dev/null
ok "screen layout file: ~/.config/hypr/hosts/$HOST.lua (filled in at first login)"

step "Login screen"
if "$REPO/sddm/install.sh" >/dev/null; then ok "SDDM theme installed"; else note "SDDM theme failed — run sddm/install.sh to see why"; fi

step "Services"
sudo systemctl enable NetworkManager >/dev/null 2>&1 && ok "NetworkManager"
sudo systemctl enable sddm >/dev/null 2>&1 && ok "sddm (login screen at boot)"
[ "$BLUETOOTH" = 1 ] && sudo systemctl enable bluetooth >/dev/null 2>&1 && ok "bluetooth"
[ "$LAPTOP" = 1 ] && sudo systemctl enable power-profiles-daemon >/dev/null 2>&1 && ok "power-profiles-daemon"
if pacman -Q docker >/dev/null 2>&1; then
    sudo systemctl enable docker >/dev/null 2>&1 && ok "docker"
    if ! id -nG | grep -qw docker; then
        sudo usermod -aG docker "$USER" && ok "added you to the docker group (after you log in again)"
    fi
fi
if pacman -Q tailscale >/dev/null 2>&1; then
    sudo systemctl enable tailscaled >/dev/null 2>&1 && ok "tailscaled"
    TODO+=("Tailscale: run 'sudo tailscale up' once to sign in")
fi
systemctl --user enable pipewire pipewire-pulse wireplumber >/dev/null 2>&1 && ok "audio (pipewire)"

# ==============================================================================
printf '\n%s%sAll done.%s\n' "$B" "$G" "$R"
TODO+=("Screens: arranged automatically at first login and saved to ~/.config/hypr/hosts/$HOST.lua — to move one or change its refresh rate: $HOST monitors edit")
TODO+=("Wallpapers: $HOST profile new <name>, then $HOST profile wallpaper set|split <image> <name> ...")
TODO+=("Reboot — you'll land on the new login screen")
echo "Next:"
for t in "${TODO[@]}"; do printf '  • %s\n' "$t"; done
