# Arch Linux Installation & Ricing Guide

> A complete personal reference for dual boot setup, Hyprland desktop, and Tokyo Night ricing.
> **hsdehaini | nebula | March 2026**

-----

## Table of Contents

1. [Overview & System Info](#1-overview--system-info)
1. [Windows Preparation](#2-windows-preparation)
1. [Creating the Arch USB](#3-creating-the-arch-usb)
1. [Arch Linux Installation](#4-arch-linux-installation)
1. [Post-Installation Setup](#5-post-installation-setup)
1. [Desktop Environment Installation](#6-desktop-environment-installation)
1. [Hyprland Configuration](#7-hyprland-configuration)
1. [Wallpaper Setup (Hyprpaper)](#8-wallpaper-setup-hyprpaper)
1. [Waybar Configuration](#9-waybar-configuration)
1. [Kitty Terminal Configuration](#10-kitty-terminal-configuration)
1. [Wofi App Launcher](#11-wofi-app-launcher)
1. [Dunst Notifications](#12-dunst-notifications)
1. [GTK Theme & Icons](#13-gtk-theme--icons)
1. [SDDM Login Screen](#14-sddm-login-screen)
1. [Tokyo Night Color Reference](#15-tokyo-night-color-reference)
1. [Useful Commands Reference](#16-useful-commands-reference)

-----

## 1. Overview & System Info

This document covers the complete setup of an Arch Linux dual boot system alongside Windows 10, including the full Hyprland desktop environment and Tokyo Night rice. Use this as a step-by-step reference for reinstalling or replicating the setup.

### System Specs

|Property|Value                                         |
|--------|----------------------------------------------|
|GPU     |AMD RX 6750 XT                                |
|Storage |476GB NVMe SSD (C: drive) + 2TB HDD (D: drive)|
|Hostname|nebula                                        |
|Username|hsdehaini                                     |
|Timezone|America/Los_Angeles                           |
|Monitors|DP-3 (main) + HDMI-A-2 (secondary)            |

### Partition Layout

|Partition|Size|Purpose                                         |
|---------|----|------------------------------------------------|
|nvme0n1p1|100M|EFI System Partition (Windows, shared with Arch)|
|nvme0n1p2|16M |Microsoft Reserved                              |
|nvme0n1p3|326G|Windows C: Drive                                |
|nvme0n1p4|508M|Windows Recovery                                |
|nvme0n1p5|142G|**Arch Linux Root (/)**                         |
|nvme0n1p6|8G  |**Arch Linux Swap**                             |
|sda (HDD)|1.8T|Mounted at /mnt/storage                         |


> ⚠️ **Critical:** Always create ROOT first, then SWAP in cfdisk. The creation order determines partition numbers — p5 must be root (142G) and p6 must be swap (8G). Reversing this fills root with only 8GB and breaks the install.

-----

## 2. Windows Preparation

Before installing Arch, prepare Windows to avoid conflicts with the dual boot setup.

### 2.1 Disable Fast Startup

Fast Startup keeps a lock on NTFS drives when Windows shuts down. If left on, Linux will mount your HDD as read-only to protect it.

- Control Panel → Power Options → Choose what the power buttons do
- Click “Change settings that are currently unavailable”
- Uncheck “Turn on fast startup” → Save changes

> 💡 If the Fast Startup option isn’t visible, your system doesn’t support hibernation and it’s already disabled. Skip this step.

### 2.2 Disable Secure Boot

Secure Boot can block the Arch bootloader from loading.

- Restart and spam `Delete` or `F2` to enter BIOS
- Find Secure Boot under the Boot or Security tab
- Set to Disabled → Save and exit

### 2.3 Free Up Disk Space (Shrink C: Drive)

You need to shrink the Windows partition to create 150GB of unallocated space for Arch.

**If Windows won’t let you shrink enough** (common issue — unmovable system files block shrinking):

Disable Hibernation to remove `hiberfil.sys`:

```
powercfg /h off
```

Disable the Pagefile temporarily:

- Control Panel → System → Advanced System Settings → Performance Settings → Advanced → Virtual Memory → Change
- Uncheck “Automatically manage” → Select “No paging file” → Set → OK → Reboot

Then shrink the drive:

- Windows key + R → `diskmgmt.msc`
- Right-click C: drive → Shrink Volume
- Enter `153,600` (150 GB in MB) → Shrink

> ⚠️ Re-enable the pagefile after partitioning is complete (set back to “System managed size”).

-----

## 3. Creating the Arch USB

### 3.1 Download the ISO

Go to **archlinux.org/download** and download via the BitTorrent magnet link (using qBittorrent) or direct download.

> 💡 The ISO version doesn’t matter. Arch is a rolling release distro — once installed, `pacman -Syu` updates everything to the latest regardless of which ISO you used.

### 3.2 Flash with Rufus

1. Open Rufus → select your USB drive
1. Click SELECT → choose the Arch ISO file
1. Set: Partition scheme = **GPT** | Target system = **UEFI (non CSM)** | File system = **FAT32**
1. Click START → when prompted, choose **“Write in DD Image mode”**
1. Click OK to confirm data wipe

> ⚠️ DD Image mode is required for Arch. ISO mode can cause boot failures. After flashing, the USB won’t appear in Windows File Explorer — this is normal. It will show in Disk Management as RAW, which confirms the flash worked.

### 3.3 Verify the ISO (Optional)

```powershell
Get-FileHash C:\Users\YourName\Downloads\archlinux-x86_64.iso -Algorithm SHA256
```

Compare the output hash with the SHA256 checksum listed on the Arch download page. If they match, the ISO is intact.

-----

## 4. Arch Linux Installation

### 4.1 Boot Into Live Environment

Restart, spam `F11` or `F12` for the boot menu, select your USB. You’ll land at the Arch live terminal (`root@archiso ~ #`).

### 4.2 Connect to Internet

**Ethernet (recommended — usually works automatically):**

```bash
ip link
# Look for an interface starting with 'en' (e.g. enp3s0)
ip link set enp3s0 up
dhcpcd enp3s0
ping google.com
```

**WiFi (if needed):**

```bash
iwctl
station wlan0 connect "YourWiFiName"
exit
ping google.com
```

**Set system clock:**

```bash
timedatectl set-ntp true
```

> `timedatectl set-ntp true` enables automatic time sync over NTP (Network Time Protocol). Accurate time is required for package signing and SSL certificates.

### 4.3 Identify Drives

```bash
lsblk
```

Your layout should show:

- `nvme0n1` — your SSD (476.9G) with Windows partitions already on it
- `sda` — your HDD (1.8T)
- `sdb` — your USB drive (the live environment)

### 4.4 Partitioning

Open cfdisk on the SSD:

```bash
cfdisk /dev/nvme0n1
```

> ⚠️ **Critical order — ROOT first, SWAP second:**

**Step 1 — Create ROOT partition (must be first):**

- Highlight **Free space (150G)** → select `[ New ]`
- Enter `142G` → hit Enter
- Highlight that partition → `[ Type ]` → **Linux filesystem**

**Step 2 — Create SWAP partition (must be second):**

- Highlight remaining **Free space (~8G)** → select `[ New ]`
- Hit Enter to use all remaining space
- Highlight that partition → `[ Type ]` → **Linux swap**

**Step 3 — Save and exit:**

- Select `[ Write ]` → type `yes` → Enter
- Select `[ Quit ]`

**Step 4 — Verify before proceeding:**

```bash
lsblk
```

Confirm before continuing:

- `nvme0n1p5` = **142G** ← root ✅
- `nvme0n1p6` = **8G** ← swap ✅

If reversed, go back into cfdisk, delete both partitions, and redo them in the correct order.

### 4.5 Format Partitions

```bash
mkfs.ext4 /dev/nvme0n1p5
mkswap /dev/nvme0n1p6
```

> `mkfs.ext4` creates an ext4 filesystem — the standard Linux filesystem. `mkswap` prepares the swap partition. Swap is used as emergency overflow when RAM fills up.

### 4.6 Mount Partitions

```bash
mount /dev/nvme0n1p5 /mnt
swapon /dev/nvme0n1p6
mkdir -p /mnt/boot/efi
mount /dev/nvme0n1p1 /mnt/boot/efi
```

> We mount root at `/mnt`, enable swap, then mount the **existing Windows EFI partition** at `/mnt/boot/efi`. We share the Windows EFI partition rather than creating a new one — this is the standard dual boot approach.

### 4.7 Install Base System

```bash
pacstrap -K /mnt base linux linux-firmware
pacstrap -K /mnt base-devel vim networkmanager grub efibootmgr os-prober ntfs-3g sudo
```

> `pacstrap` installs packages into the new system at `/mnt`. Key packages: `base` = minimal Arch system, `linux` = the kernel, `grub` = bootloader, `os-prober` = detects Windows for GRUB menu, `ntfs-3g` = enables read/write access to NTFS drives (your HDD).

### 4.8 System Configuration

**Generate fstab** (filesystem table — tells the system where partitions are on every boot):

```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

**Chroot into the new system** (you are now “inside” your Arch install):

```bash
arch-chroot /mnt
```

**Set timezone:**

```bash
ln -sf /usr/share/zoneinfo/America/Los_Angeles /etc/localtime
hwclock --systohc
```

**Set locale:**

```bash
vim /etc/locale.gen
# Uncomment: en_US.UTF-8 UTF-8
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
```

**Set hostname:**

```bash
echo "nebula" > /etc/hostname
```

**Set root password:**

```bash
passwd
```

**Create your user account:**

```bash
useradd -m -G wheel -s /bin/bash hsdehaini
passwd hsdehaini
```

> `useradd -m` creates a home directory. `-G wheel` adds the user to the wheel group which grants sudo access. `-s /bin/bash` sets bash as the default shell.

**Grant sudo access:**

```bash
EDITOR=vim visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL
```

### 4.9 Install GRUB Bootloader

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
```

**Enable Windows detection in GRUB:**

```bash
vim /etc/default/grub
# Uncomment: GRUB_DISABLE_OS_PROBER=false
```

**Generate GRUB config:**

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

You should see “Windows Boot Manager” detected in the output. If not, verify `os-prober` is installed and the EFI partition is mounted.

> ⚠️ After rebooting, if Windows loads instead of GRUB: enter BIOS, find Boot Order, and move GRUB above Windows Boot Manager. You’ll need to do this after every fresh Arch install.

### 4.10 Enable Networking and Reboot

```bash
systemctl enable NetworkManager
exit
umount -R /mnt
reboot
# Remove USB when screen goes black
```

-----

## 5. Post-Installation Setup

After rebooting into Arch, log in as `hsdehaini` and complete the following.

### 5.1 Connect to Internet

```bash
nmtui
# Select "Activate a connection" and connect
```

### 5.2 Mount the HDD

The 2TB HDD needs to be permanently mounted so it’s accessible every boot.

```bash
# Find the UUID for sda2:
lsblk -f

# Create the mount point:
sudo mkdir /mnt/storage

# Add to fstab:
sudo vim /etc/fstab
# Add this line at the bottom (replace UUID with yours):
# UUID=your-sda2-uuid  /mnt/storage  ntfs-3g  defaults,uid=1000,gid=1000  0  0

# Mount everything:
sudo mount -a

# If you get a hint about daemon-reload:
systemctl daemon-reload
sudo mount -a
```

> `fstab` (filesystem table) tells Linux what to mount at boot. `ntfs-3g` is the driver for reading/writing Windows NTFS drives. `uid=1000` ensures your user (the first created user) owns the mounted files.

### 5.3 Install Paru (AUR Helper)

Pacman only accesses official Arch repos. Paru adds access to the AUR (Arch User Repository) — a massive community repo with thousands of extra packages.

```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ~
```

> ⚠️ Always run `paru` as your regular user (`hsdehaini`), never as root. Paru deliberately blocks root usage for security — it builds packages in user space before handing off to pacman.

### 5.4 Install Audio

```bash
sudo pacman -S pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

> PipeWire is the modern Linux audio system. The multiple packages cover different interfaces: `pipewire-alsa` for ALSA apps, `pipewire-pulse` for PulseAudio apps, `pipewire-jack` for pro audio. `wireplumber` is the session manager that routes audio between apps and devices.

### 5.5 Install GPU Drivers

```bash
sudo pacman -S mesa vulkan-radeon libva-mesa-driver
```

> `mesa` contains the core open source AMD GPU drivers (amdgpu). `vulkan-radeon` is the RADV Vulkan driver used by games for high performance rendering. `libva-mesa-driver` enables hardware video acceleration. Note: `mesa-vdpau` is already bundled inside mesa and does not need to be installed separately.

### 5.6 Enable Multilib (Required for Steam)

Steam and many games are 32-bit applications. Multilib is a separate Arch repo containing 32-bit libraries.

```bash
sudo vim /etc/pacman.conf
# Find and uncomment these two lines:
# [multilib]
# Include = /etc/pacman.d/mirrorlist

sudo pacman -Sy
```

-----

## 6. Desktop Environment Installation

### 6.1 Install Hyprland and Tools

```bash
sudo pacman -S hyprland waybar kitty wofi hyprpaper dunst polkit-gnome xdg-desktop-portal-hyprland qt5-wayland qt6-wayland
```

|Package                    |Purpose                                 |
|---------------------------|----------------------------------------|
|hyprland                   |Wayland compositor and window manager   |
|waybar                     |Status bar                              |
|kitty                      |GPU-accelerated terminal emulator       |
|wofi                       |Application launcher (like a Start menu)|
|hyprpaper                  |Wallpaper manager for Hyprland          |
|dunst                      |Notification daemon (shows popups)      |
|polkit-gnome               |Handles permission dialogs for GUI apps |
|xdg-desktop-portal-hyprland|Enables screen sharing and file pickers |
|qt5-wayland / qt6-wayland  |Makes Qt apps work correctly on Wayland |


> **What is Wayland?** Wayland is the modern replacement for X11 (Xorg). It’s the display protocol between applications and your screen. Hyprland is a Wayland compositor — it runs on Wayland and handles drawing windows, animations, and effects. You don’t install Wayland separately; it’s part of Hyprland.

### 6.2 Install SDDM (Login Screen)

```bash
sudo pacman -S sddm
sudo systemctl enable sddm
# When prompted for ttf-font provider: choose 9 (ttf-input-nerd)
```

### 6.3 Install Gaming Tools

```bash
sudo pacman -S steam lutris gamemode mangohud firefox
```

|Package |Purpose                                       |
|--------|----------------------------------------------|
|steam   |Game platform                                 |
|lutris  |Game manager for non-Steam games              |
|gamemode|Auto-optimizes CPU/GPU when a game launches   |
|mangohud|Performance overlay (FPS, GPU temp, CPU usage)|


> When prompted for `lib32-vulkan-driver` provider, choose **12 (lib32-vulkan-radeon)** for the AMD RX 6750 XT.

### 6.4 Install Additional Tools

```bash
sudo pacman -S thunar wl-clipboard grim slurp
```

|Package     |Purpose                                                 |
|------------|--------------------------------------------------------|
|thunar      |File manager                                            |
|wl-clipboard|Clipboard manager for Wayland                           |
|grim        |Screenshot tool for Wayland                             |
|slurp       |Region selector (used with grim for partial screenshots)|

### 6.5 Install Nerd Font

```bash
paru -S ttf-jetbrains-mono-nerd
```

> Nerd Fonts are patched fonts that include thousands of icons used by Waybar, terminals, and rice components. Without a Nerd Font, many UI elements show squares or missing glyphs.

-----

## 7. Hyprland Configuration

The Hyprland config lives at `~/.config/hypr/hyprland.conf`. Edit with vim and apply changes instantly with `hyprctl reload` — no reboot needed.

### 7.1 Monitor Setup

```
monitor=,preferred,auto,auto
```

> The comma-separated format is: name, resolution, position, scale. Leaving fields blank uses auto-detection.

### 7.2 Workspace Assignment (Multi-Monitor)

```
workspace = 1, monitor:DP-3, default:true
workspace = 2, monitor:DP-3
workspace = 3, monitor:DP-3
workspace = 4, monitor:DP-3
workspace = 5, monitor:DP-3
workspace = 6, monitor:HDMI-A-2, default:true
workspace = 7, monitor:HDMI-A-2
workspace = 8, monitor:HDMI-A-2
workspace = 9, monitor:HDMI-A-2
workspace = 10, monitor:HDMI-A-2
```

> This pins workspaces 1-5 to the main monitor (DP-3) and 6-10 to the secondary (HDMI-A-2). Each monitor scrolls through its own workspaces independently.

### 7.3 Autostart

```
exec-once = nm-applet &
exec-once = waybar & hyprpaper & dunst
```

> `exec-once` runs commands once when Hyprland starts. The `&` sends processes to the background so they don’t block startup.

### 7.4 Look and Feel

```
general {
    gaps_in = 3
    gaps_out = 12
    border_size = 1
    col.active_border = rgba(7aa2f7ff) rgba(bb9af7ff) 45deg
    col.inactive_border = rgba(16161eff)
    resize_on_border = true    # Drag edges/corners to resize windows
    layout = dwindle
}

decoration {
    rounding = 5
    active_opacity = 1.0
    inactive_opacity = 0.92    # Unfocused windows are slightly transparent
    blur {
        enabled = true
        size = 6
        passes = 3
        vibrancy = 0.2
    }
}
```

### 7.5 Input Settings

```
input {
    accel_profile = flat           # Disables mouse acceleration (raw input)
    scroll_method = on_button_down
    scroll_button = 274            # Middle mouse button for click-drag scroll
}
```

### 7.6 Keybindings Reference

```
$mainMod = SUPER    # Windows key

# Applications
bind = $mainMod, Q, exec, $terminal          # Open Kitty terminal
bind = $mainMod, R, exec, $menu              # Open Wofi launcher
bind = $mainMod, E, exec, $fileManager       # Open Thunar
bind = $mainMod, C, killactive               # Close focused window

# Window Management
bind = , F11, fullscreen, 0                  # Toggle fullscreen
bind = $mainMod, V, togglefloating           # Toggle floating window
bind = $mainMod, J, layoutmsg, togglesplit   # Toggle tiling split direction

# Screenshots (region → clipboard, no file saved)
bind = $mainMod SHIFT, S, exec, grim -g "$(slurp)" - | wl-copy

# Move focus with arrow keys
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Mouse window controls
bindm = $mainMod, mouse:272, movewindow      # Super + left drag = move window
bindm = $mainMod, mouse:273, resizewindow    # Super + right drag = resize window
bind = , mouse:275, pass, class:.*           # Side button back
bind = , mouse:276, pass, class:.*           # Side button forward

# Workspaces
bind = $mainMod, 1, workspace, 1             # Switch to workspace 1
bind = $mainMod SHIFT, 1, movetoworkspace, 1 # Move window to workspace 1
# (repeat for 2-10)

# Scroll through workspaces
bind = $mainMod, mouse_down, workspace, e+1
bind = $mainMod, mouse_up, workspace, e-1
```

### 7.7 Wofi Keybind (Toggle + Single Instance)

```
$menu = pkill wofi || wofi --show drun --close-on-focus-loss
```

> `pkill wofi ||` kills wofi if it’s running. If wofi isn’t running, pkill fails and `||` triggers the second command to open wofi. This makes Super+R toggle wofi and prevents multiple instances from stacking up.

-----

## 8. Wallpaper Setup (Hyprpaper)

Hyprpaper config lives at `~/.config/hypr/hyprpaper.conf`. Use the block syntax (the old comma syntax is deprecated).

> ⚠️ Always use the full path (`/home/hsdehaini/...`) instead of `~`. Hyprpaper doesn’t always expand tilde correctly.

### 8.1 Single Wallpaper on Both Monitors

```
preload = /home/hsdehaini/Pictures/wallpapers/galaxy-nebula-1.png

wallpaper {
    monitor = DP-3
    path = /home/hsdehaini/Pictures/wallpapers/galaxy-nebula-1.png
    fit_mode = cover
}

wallpaper {
    monitor = HDMI-A-2
    path = /home/hsdehaini/Pictures/wallpapers/galaxy-nebula-1.png
    fit_mode = cover
}
```

### 8.2 Spanning Ultrawide Wallpaper Across Two Monitors

Use ImageMagick to split an ultrawide image into two halves:

```bash
sudo pacman -S imagemagick

# Check dimensions:
identify ~/Pictures/wallpapers/ultrawide-galaxy.png

# Split into two halves (creates left-0.png and left-1.png):
convert ~/Pictures/wallpapers/ultrawide-galaxy.png -crop 50%x100% +repage ~/Pictures/wallpapers/ultrawide-galaxy-left.png
```

Then assign each half to a monitor in `hyprpaper.conf`:

```
preload = /home/hsdehaini/Pictures/wallpapers/ultrawide-galaxy-left-0.png
preload = /home/hsdehaini/Pictures/wallpapers/ultrawide-galaxy-left-1.png

wallpaper {
    monitor = DP-3
    path = /home/hsdehaini/Pictures/wallpapers/ultrawide-galaxy-left-0.png
    fit_mode = cover
}

wallpaper {
    monitor = HDMI-A-2
    path = /home/hsdehaini/Pictures/wallpapers/ultrawide-galaxy-left-1.png
    fit_mode = cover
}
```

> Swap `left-0` and `left-1` if the halves appear on the wrong monitors.

**Restart hyprpaper to apply changes:**

```bash
pkill hyprpaper && hyprpaper &
```

-----

## 9. Waybar Configuration

Waybar config lives at `~/.config/waybar/`. Two files: `config.jsonc` (modules and layout) and `style.css` (appearance).

### 9.1 config.jsonc

```jsonc
{
    "layer": "top",
    "position": "top",
    "margin-top": 10,
    "margin-left": 20,
    "margin-right": 20,
    "height": 40,
    "spacing": 6,

    "modules-left": ["hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "pulseaudio", "network", "tray"],

    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "activate",
        "all-outputs": false,    // Only show this monitor's workspaces
        "sort-by-number": true
    },

    "clock": {
        "format": "󰃰  {:%a, %b %d  %I:%M %p}",
        "tooltip-format": "<big>{:%B %Y}</big>\n<tt><small>{calendar}</small></tt>"
    },

    "cpu": {
        "format": "󰻠  {usage}%",
        "tooltip": true,
        "interval": 2
    },

    "memory": {
        "format": "󰍛  {percentage}%",
        "tooltip-format": "{used:0.1f}GB / {total:0.1f}GB",
        "interval": 2
    },

    "pulseaudio": {
        "format": "{icon}  {volume}%",
        "format-muted": "󰝟  muted",
        "format-icons": { "default": ["󰕿", "󰖀", "󰕾"] },
        "on-click": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
        "scroll-step": 5
    },

    "network": {
        "format-wifi": "󰤨  {essid}",
        "format-ethernet": "󰈀  ethernet",
        "format-disconnected": "󰤭  offline",
        "tooltip-format": "{ipaddr}  {signalStrength}%",
        "interval": 5
    },

    "tray": { "spacing": 8 }
}
```

### 9.2 style.css (Floating Pill, Tokyo Night)

```css
* {
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
    border: none;
    border-radius: 0;
    min-height: 0;
}

window#waybar { background: transparent; }

.modules-left,
.modules-center,
.modules-right {
    background: rgba(26, 27, 38, 0.90);
    border-radius: 16px;
    padding: 4px 16px;
}

#workspaces button { color: #414868; background: transparent; padding: 2px 6px; border-radius: 8px; }
#workspaces button.active { color: #7aa2f7; background: rgba(122, 162, 247, 0.15); }
#workspaces button.urgent { color: #f7768e; background: rgba(247, 118, 142, 0.15); }
#workspaces button:hover { color: #c0caf5; background: rgba(192, 202, 245, 0.1); }

#clock { color: #c0caf5; font-weight: bold; padding: 0 8px; }
#cpu { color: #7dcfff; padding: 0 8px; }
#memory { color: #bb9af7; padding: 0 8px; }
#pulseaudio { color: #9ece6a; padding: 0 8px; }
#pulseaudio.muted { color: #414868; }
#network { color: #7aa2f7; padding: 0 8px; }
#network.disconnected { color: #f7768e; }
#tray { padding: 0 4px; }
```

**Restart Waybar:**

```bash
pkill waybar && waybar &
```

-----

## 10. Kitty Terminal Configuration

Config lives at `~/.config/kitty/kitty.conf`.

```
# Tokyo Night Colors
background            #1a1b26
foreground            #c0caf5
selection_background  #283457
selection_foreground  #c0caf5
cursor                #c0caf5
cursor_text_color     #1a1b26

# Color palette
color0  #15161e    color8  #414868
color1  #f7768e    color9  #f7768e
color2  #9ece6a    color10 #9ece6a
color3  #e0af68    color11 #e0af68
color4  #7aa2f7    color12 #7aa2f7
color5  #bb9af7    color13 #bb9af7
color6  #7dcfff    color14 #7dcfff
color7  #a9b1d6    color15 #c0caf5

# Transparency and blur
background_opacity  0.7
background_blur     1

# Font
font_family  JetBrainsMono Nerd Font
font_size    12.0

# Padding
window_padding_width 12

# Keybindings
map ctrl+c copy_or_interrupt
map ctrl+v paste_from_clipboard
mouse_map right press ungrabbed paste_from_clipboard

# Word navigation
map ctrl+left      send_text all \x1b[1;5D
map ctrl+right     send_text all \x1b[1;5C
map ctrl+backspace send_text all \x17
map ctrl+delete    send_text all \x1b[3;5~
```

-----

## 11. Wofi App Launcher

Config lives at `~/.config/wofi/`.

### 11.1 config

```
width=500
height=400
location=center
show=drun
prompt=Search...
filter_rate=100
allow_markup=true
no_actions=true
allow_images=true
image_size=24
gtk_dark=true
close_on_focus_lost=true
```

### 11.2 style.css (Tokyo Night)

```css
* { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; }

window {
    background-color: rgba(26, 27, 38, 0.95);
    border: 1px solid rgba(122, 162, 247, 0.3);
    border-radius: 16px;
}

#input {
    background-color: rgba(22, 22, 30, 0.9);
    color: #c0caf5;
    border: 1px solid rgba(122, 162, 247, 0.2);
    border-radius: 10px;
    padding: 8px 12px;
    margin: 10px;
    outline: none;
}

#input:focus { border-color: rgba(122, 162, 247, 0.6); }
#input::placeholder { color: #414868; }
#scroll { margin: 0 8px 8px 8px; }
#outer-box { padding: 8px; }

#entry {
    background: transparent;
    border-radius: 10px;
    padding: 6px 10px;
    margin: 2px 0;
    color: #a9b1d6;
}

#entry:selected { background-color: rgba(122, 162, 247, 0.15); color: #c0caf5; }
#entry:hover { background-color: rgba(192, 202, 245, 0.08); }
#text { color: inherit; margin-left: 8px; }
#img { border-radius: 4px; }
```

-----

## 12. Dunst Notifications

Config lives at `~/.config/dunst/dunstrc`.

```ini
[global]
    monitor = 0
    follow = none
    origin = top-right
    offset = 20x60
    width = 340
    height = 200
    gap_size = 8
    frame_width = 1
    frame_color = "#7aa2f7"
    corner_radius = 10
    transparency = 10
    font = JetBrainsMono Nerd Font 11
    icon_position = left
    min_icon_size = 32
    max_icon_size = 48
    icon_theme = Papirus-Dark
    alignment = left
    word_wrap = yes
    markup = full
    format = "<b>%s</b>\n%b"
    mouse_left_click = close_current
    mouse_right_click = close_all
    separator_height = 1
    separator_color = "#283457"
    padding = 12
    horizontal_padding = 14

[urgency_low]
    background = "#1a1b26"
    foreground = "#a9b1d6"
    frame_color = "#414868"
    timeout = 4

[urgency_normal]
    background = "#1a1b26"
    foreground = "#c0caf5"
    frame_color = "#7aa2f7"
    timeout = 6

[urgency_critical]
    background = "#1a1b26"
    foreground = "#f7768e"
    frame_color = "#f7768e"
    timeout = 0
```

**Test notification:**

```bash
notify-send "Test" "Tokyo Night notifications working!" -i dialog-information
```

**Restart Dunst:**

```bash
pkill dunst && dunst &
```

-----

## 13. GTK Theme & Icons

GTK is the toolkit most Linux GUI apps use (Thunar, Firefox, etc.). Applying a GTK theme makes these apps match your rice instead of showing a default gray look.

### 13.1 Install Packages

```bash
sudo pacman -S nwg-look
paru -S tokyonight-gtk-theme-git
paru -S papirus-icon-theme papirus-folders-git
paru -S bibata-cursor-theme-bin

# Set Papirus folder colors to Tokyo Night blue:
papirus-folders -C indigo --theme Papirus-Dark
```

### 13.2 Apply with nwg-look

```bash
nwg-look
```

- **Widgets tab** → GTK Theme: `Tokyonight-Dark`
- **Widgets tab** → Default font: `JetBrainsMono Nerd Font Regular 11`
- **Icon theme tab** → `Papirus-Dark`
- **Mouse cursor tab** → `Bibata-Modern-Ice`
- Click **Apply**

### 13.3 Cursor Theme in Hyprland

Add to `~/.config/hypr/hyprland.conf` env section:

```
env = XCURSOR_THEME,Bibata-Modern-Ice
env = XCURSOR_SIZE,24
```

Create cursor config:

```bash
mkdir -p ~/.icons/default
vim ~/.icons/default/index.theme
```

```ini
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=Bibata-Modern-Ice
```

### 13.4 Autostart GTK Settings

Add to hyprland.conf autostart section:

```
exec-once = gsettings set org.gnome.desktop.interface gtk-theme "Tokyonight-Dark"
exec-once = gsettings set org.gnome.desktop.interface icon-theme "Papirus-Dark"
exec-once = gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Modern-Ice"
exec-once = gsettings set org.gnome.desktop.interface font-name "JetBrainsMono Nerd Font 11"
```

-----

## 14. SDDM Login Screen

### 14.1 Install Theme and Dependencies

```bash
paru -S sddm-theme-tokyo-night-git
sudo pacman -S qt6-5compat    # Required — provides QtGraphicalEffects module
```

### 14.2 Copy Login Wallpaper

```bash
sudo cp ~/Pictures/wallpapers/nebula-login.png /usr/share/sddm/themes/tokyo-night-sddm/
```

### 14.3 Configure theme.conf

```bash
sudo vim /usr/share/sddm/themes/tokyo-night-sddm/theme.conf
```

Key settings to configure:

```ini
Background="nebula-login.png"
ScreenWidth="1920"
ScreenHeight="1080"
MainColor="#7aa2f7"
AccentColor="#7aa2f7"
BackgroundColor="#16161e"
OverrideLoginButtonTextColor="#16161E"
Font="JetBrainsMono Nerd Font"
FormPosition="right"
RoundCorners="20"
HourFormat="hh:mm AP"
DateFormat="dddd  MMM d"
HeaderText="Hello!"
ForceLastUser="true"
ForcePasswordFocus="true"
```

### 14.4 Configure SDDM

```bash
sudo mkdir -p /etc/sddm.conf.d
sudo vim /etc/sddm.conf.d/sddm.conf
```

```ini
[Theme]
Current=tokyo-night-sddm

[General]
DisplayServer=x11

[Users]
DefaultUser=hsdehaini
```

**Test without rebooting:**

```bash
sudo systemctl restart sddm
```

> ⚠️ **Troubleshooting black screen:** If SDDM shows a black screen after theme changes, do a clean reinstall: remove the theme (`paru -Rns sddm-theme-tokyo-night-git`), remove sddm (`sudo pacman -Rns sddm`), remove config (`sudo rm -rf /etc/sddm.conf.d`), reinstall (`sudo pacman -S sddm && sudo systemctl enable sddm`), confirm it works with no theme, then re-add the theme.

-----

## 15. Tokyo Night Color Reference

These colors are used consistently across all config files.

|Role            |Hex      |Usage                          |
|----------------|---------|-------------------------------|
|Background      |`#1a1b26`|Main window/bar background     |
|Background Dark |`#16161e`|Darker surfaces, SDDM bg       |
|Foreground      |`#c0caf5`|Primary text                   |
|Foreground Dim  |`#a9b1d6`|Secondary text                 |
|Comment/Inactive|`#414868`|Inactive borders, dim elements |
|Selection       |`#283457`|Selected text background       |
|Blue            |`#7aa2f7`|Primary accent, borders, Waybar|
|Cyan            |`#7dcfff`|CPU module, cursor             |
|Purple          |`#bb9af7`|Secondary accent, memory module|
|Green           |`#9ece6a`|Volume module, success states  |
|Red             |`#f7768e`|Errors, critical notifications |
|Yellow          |`#e0af68`|Warnings, notes                |

-----

## 16. Useful Commands Reference

### Package Management

```bash
sudo pacman -S package          # Install from official repos
paru -S package                 # Install from AUR (run as user, not root)
sudo pacman -Syu                # Update entire system
sudo pacman -Rns package        # Remove package + deps + leftover config files
sudo pacman -Sc                 # Clear package cache (free up disk space)
paru package                    # Search for a package by name
```

> `-R` = remove, `-n` = remove config files, `-s` = remove orphaned dependencies. Always use `-Rns` for a clean uninstall.

### Hyprland

```bash
hyprctl reload                  # Reload config without rebooting
hyprctl monitors                # List connected monitors with their names
hyprctl clients                 # List all open windows
hyprctl dispatch exit           # Exit Hyprland session
```

### System

```bash
df -h                           # Check disk space usage (human readable)
lsblk                           # List all drives and partitions
lsblk -f                        # List with filesystem types and UUIDs
sudo mount -a                   # Mount all entries in /etc/fstab
systemctl --user status pipewire  # Check audio daemon status
pgrep -a polkit                 # Check if polkit authentication agent is running
journalctl -u sddm -b           # View SDDM logs from last boot (for debugging)
```

### Desktop Components

```bash
pkill waybar && waybar &        # Restart Waybar
pkill dunst && dunst &          # Restart Dunst notification daemon
pkill hyprpaper && hyprpaper &  # Restart Hyprpaper wallpaper daemon
pkill wofi                      # Close Wofi if stuck open
notify-send "Title" "Message"   # Send a test notification
```

### File Locations Quick Reference

|Config       |Location                                            |
|-------------|----------------------------------------------------|
|Hyprland     |`~/.config/hypr/hyprland.conf`                      |
|Hyprpaper    |`~/.config/hypr/hyprpaper.conf`                     |
|Waybar layout|`~/.config/waybar/config.jsonc`                     |
|Waybar style |`~/.config/waybar/style.css`                        |
|Kitty        |`~/.config/kitty/kitty.conf`                        |
|Wofi config  |`~/.config/wofi/config`                             |
|Wofi style   |`~/.config/wofi/style.css`                          |
|Dunst        |`~/.config/dunst/dunstrc`                           |
|SDDM theme   |`/usr/share/sddm/themes/tokyo-night-sddm/theme.conf`|
|SDDM config  |`/etc/sddm.conf.d/sddm.conf`                        |
|fstab        |`/etc/fstab`                                        |
|pacman config|`/etc/pacman.conf`                                  |

-----

*End of Documentation*