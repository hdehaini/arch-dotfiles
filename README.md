# 🌌 arch-dotfiles

> Personal Arch Linux configuration — dual boot with Windows 10, Hyprland WM, Tokyo Night theme.

**Machine:** nebula | **User:** hsdehaini | **GPU:** AMD RX 6750 XT | **DE:** Hyprland on Wayland

---

## 📸 Setup Overview

| Component | Choice |
|---|---|
| OS | Arch Linux (rolling) |
| Window Manager | Hyprland |
| Display Protocol | Wayland |
| Status Bar | Waybar |
| Terminal | Kitty |
| App Launcher | Wofi |
| Wallpaper | Hyprpaper |
| Notifications | Dunst |
| Login Screen | SDDM + Tokyo Night |
| File Manager | Thunar |
| GTK Theme | Tokyonight-Dark |
| Icon Theme | Papirus-Dark |
| Cursor | Bibata-Modern-Ice |
| Font | JetBrainsMono Nerd Font |
| Color Scheme | Tokyo Night |
| Shell | Bash |
| Editor | VS Code |

---

## 🗂️ Repo Structure

```
arch-dotfiles/
├── config/                  # ~/.config files
│   ├── hypr/                # Hyprland + Hyprpaper configs
│   ├── waybar/              # Waybar config + CSS
│   ├── kitty/               # Kitty terminal config
│   ├── wofi/                # Wofi launcher config + CSS
│   ├── dunst/               # Dunst notification config
│   ├── gtk-3.0/             # GTK3 theme settings
│   └── gtk-4.0/             # GTK4 theme settings
├── home/                    # Home directory dotfiles
│   ├── .icons/default/      # Cursor theme config
│   └── .gtkrc-2.0           # GTK2 settings
├── packages.txt             # All explicitly installed packages
├── packages-aur.txt         # AUR packages only
├── collect.sh               # Collect configs into this repo
├── bootstrap.sh             # Deploy everything on a new machine
├── sync-docs.sh             # Auto-detect package changes → update README
└── README.md                # This file
```

---

## ⚡ Fresh Install — Deploy on a New Machine

Follow these steps on a fresh Arch Linux install to replicate the full setup.

### Prerequisites

Complete the base Arch install first (partitioning, locale, user, GRUB). Then:

```bash
# 1. Connect to internet
nmtui

# 2. Clone this repo (adjust path as needed)
mkdir -p ~/Coding-Projects/Linux
git clone <your-repo-url> ~/Coding-Projects/Linux/arch-dotfiles
cd ~/Coding-Projects/Linux/arch-dotfiles

# 3. Run bootstrap (installs all packages + symlinks configs)
bash bootstrap.sh
```

The bootstrap script will:
- Install paru (AUR helper)
- Enable multilib repo
- Install all official and AUR packages
- Symlink all config files to their correct locations
- Enable system services
- Apply GTK theme settings
- Configure SDDM

### After Bootstrap

```bash
# 4. Copy your wallpapers
mkdir -p ~/Pictures/wallpapers
# Copy galaxy-nebula-1.png and nebula-login.png here

# 5. Update hyprpaper.conf with your monitor names
# Check monitor names with:
hyprctl monitors

# 6. Set BIOS boot order
# Restart → BIOS → Boot Order → Move GRUB above Windows

# 7. Reboot
reboot
```

### Updating Config for New Hardware

After cloning on a different machine, a few things need updating:

**Monitor names** — check with `hyprctl monitors` and update:
- `~/.config/hypr/hyprland.conf` — workspace assignments
- `~/.config/hypr/hyprpaper.conf` — wallpaper assignments

**GPU drivers** — this config assumes AMD. For Nvidia replace:
```bash
# Remove AMD packages
sudo pacman -R mesa vulkan-radeon libva-mesa-driver

# Install Nvidia
sudo pacman -S nvidia nvidia-utils lib32-nvidia-utils
```

**Username** — if your username differs from `hsdehaini`, update:
- `/etc/sddm.conf.d/sddm.conf` → `DefaultUser=`
- Any hardcoded paths in hyprpaper.conf

---

## 🔄 Keeping the Repo Updated

### When you change a config file:

```bash
cd /mnt/storage/Coding-Projects/Linux/arch-dotfiles
bash collect.sh
git add -A
git commit -m "config: update waybar style"
git push
```

### When you install or remove packages:

```bash
cd /mnt/storage/Coding-Projects/Linux/arch-dotfiles
bash sync-docs.sh   # detects changes, updates README with placeholders
bash collect.sh     # syncs config files
git add -A
git commit -m "packages: add discord and vscode"
git push
```

### Workflow summary

```
Change something on your system
        ↓
bash sync-docs.sh    ← updates README with new package placeholders
        ↓
Fill in TODO descriptions in README.md
        ↓
bash collect.sh      ← copies latest configs into repo
        ↓
git add -A && git commit && git push
```

---

## 📦 Package List

All explicitly installed packages are tracked in `packages.txt` (official) and `packages-aur.txt` (AUR).

Regenerate at any time:
```bash
pacman -Qqe > packages.txt
pacman -Qqem > packages-aur.txt
```

---

## 🎨 Tokyo Night Color Reference

| Role | Hex |
|---|---|
| Background | `#1a1b26` |
| Background Dark | `#16161e` |
| Foreground | `#c0caf5` |
| Foreground Dim | `#a9b1d6` |
| Comment/Inactive | `#414868` |
| Selection | `#283457` |
| Blue | `#7aa2f7` |
| Cyan | `#7dcfff` |
| Purple | `#bb9af7` |
| Green | `#9ece6a` |
| Red | `#f7768e` |
| Yellow | `#e0af68` |

---

## ⌨️ Key Keybindings

| Action | Shortcut |
|---|---|
| Open terminal | `Super + Q` |
| Open app launcher | `Super + R` |
| Open file manager | `Super + E` |
| Close window | `Super + C` |
| Toggle fullscreen | `F11` |
| Toggle floating | `Super + V` |
| Screenshot (region) | `Super + Shift + S` |
| Switch workspace | `Super + 1-9` |
| Move window to workspace | `Super + Shift + 1-9` |
| Move window (drag) | `Super + Left click drag` |
| Resize window (drag) | `Super + Right click drag` |

---

## 🖥️ Partition Layout

| Partition | Size | Purpose |
|---|---|---|
| nvme0n1p1 | 100M | EFI (shared with Windows) |
| nvme0n1p2 | 16M | Microsoft Reserved |
| nvme0n1p3 | 326G | Windows C: Drive |
| nvme0n1p4 | 508M | Windows Recovery |
| nvme0n1p5 | 142G | Arch Linux Root (/) |
| nvme0n1p6 | 8G | Arch Linux Swap |
| sda2 | 1.8T | HDD — mounted at /mnt/storage |

---

## 🗒️ Notes & Gotchas

- **Always create ROOT partition before SWAP in cfdisk** — order determines partition numbers
- **Disable Fast Startup in Windows** before dual booting — keeps HDD NTFS unlocked for Linux
- **BIOS boot order** — after every Arch install, set GRUB above Windows Boot Manager
- **Hyprpaper** — use full paths (`/home/hsdehaini/...`) not `~` — tilde not always expanded
- **Paru** — always run as regular user, never root
- **Steam** — needs multilib enabled and `lib32-vulkan-radeon` for AMD
- **Waybar workspace module** — set `"all-outputs": false` for proper multi-monitor workspace display
- **SDDM theme** — requires `qt6-5compat` package or theme fails to load with QtGraphicalEffects error

---

_Last synced: March 2026_
