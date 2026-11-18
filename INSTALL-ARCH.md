# Installing Arch + these dotfiles

> From a blank (or Windows) machine to the full desktop: Hyprland, the eww
> bar, profiles, the login screen and the `<hostname>` command.
> Parts 1–4 install Arch itself; part 5 is one script that sets up the rest.

Throughout, replace:

| Placeholder  | Meaning                          | Example (main desktop)  |
|--------------|----------------------------------|-------------------------|
| `<hostname>` | the machine's name — also the name of its command | `nebula` |
| `<user>`     | your login name                  | `hsdehaini`             |
| `<disk>`     | the drive Arch goes on           | `/dev/nvme0n1`          |
| `<zone>`     | your time zone                   | `America/Los_Angeles`   |

-----

## Contents

1. [Plan the disk](#1-plan-the-disk)
2. [Prepare Windows (dual boot only)](#2-prepare-windows-dual-boot-only)
3. [Make the USB stick](#3-make-the-usb-stick)
4. [Install Arch](#4-install-arch)
5. [Set up the desktop (bootstrap.sh)](#5-set-up-the-desktop-bootstrapsh)
6. [Per-machine touches](#6-per-machine-touches)
7. [Troubleshooting](#7-troubleshooting)
8. [Everyday commands](#8-everyday-commands)

-----

## 1. Plan the disk

Two layouts cover every machine so far:

**Dual boot with Windows** (main desktop) — Windows keeps its partitions;
Arch gets new space next to them and shares Windows' EFI partition:

| Partition | Size        | Purpose                                     |
|-----------|-------------|---------------------------------------------|
| (existing) | ~100M      | EFI System Partition — shared with Windows  |
| (existing) | …          | Windows partitions — leave alone            |
| new        | 100G+      | **Arch root (/)**                            |
| new        | 8G         | **Swap** (optional; RAM-sized for hibernate) |

**Arch only** (e.g. a laptop) — wipe the drive and make:

| Partition | Size   | Type             |
|-----------|--------|------------------|
| 1         | 1G     | EFI System       |
| 2         | 8G     | Linux swap       |
| 3         | rest   | Linux filesystem |

> 💡 Partition numbers follow the order you create them in. Write down which
> number is root and which is swap — the commands below use them.

-----

## 2. Prepare Windows (dual boot only)

Skip this part on an Arch-only machine.

**Turn off Fast Startup** — otherwise Windows leaves NTFS drives locked and
Linux mounts them read-only. Control Panel → Power Options → *Choose what the
power buttons do* → *Change settings that are currently unavailable* →
uncheck *Turn on fast startup*. (No option there = already off.)

**Turn off Secure Boot** in the BIOS (usually `Del` or `F2` at power-on,
under Boot or Security).

**Make room**: `Win+R` → `diskmgmt.msc` → right-click C: → *Shrink Volume*.
If Windows won't shrink far enough, unmovable files are in the way:

```
powercfg /h off
```

and temporarily set *No paging file* (System → Advanced → Performance →
Advanced → Virtual Memory), reboot, shrink, then set it back to *System
managed size*.

-----

## 3. Make the USB stick

1. Download the ISO from **archlinux.org/download** (any recent one — Arch is
   rolling, the first update brings everything current).
2. Optional: check it — `Get-FileHash .\archlinux-x86_64.iso -Algorithm SHA256`
   (Windows) or `sha256sum archlinux-x86_64.iso` (Linux) against the site.
3. Flash it:
   - **Windows — Rufus**: GPT, UEFI (non CSM), and choose **DD Image mode**
     when asked (ISO mode can fail to boot). The stick then shows as RAW in
     Windows; that's expected.
   - **Linux**: `sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync`
     (`/dev/sdX` = the stick, from `lsblk` — double-check it).

-----

## 4. Install Arch

### 4.1 Boot the stick and get online

Boot menu is usually `F11`/`F12`. At `root@archiso ~ #`:

```bash
ping -c2 archlinux.org          # Ethernet usually just works
```

Wi-Fi:

```bash
iwctl
  device list                   # the Wi-Fi device name, e.g. wlan0
  station wlan0 connect "Network Name"
  exit
```

```bash
timedatectl set-ntp true        # correct time, needed for package signatures
```

### 4.2 Partition

```bash
lsblk                           # find <disk>; the USB stick is here too
cfdisk <disk>
```

Create the partitions from [part 1](#1-plan-the-disk) (`[ New ]`, size,
`[ Type ]`), then `[ Write ]` → `yes` → `[ Quit ]`, and check with `lsblk`.

> NVMe partitions are `<disk>p1`, `p2`…; SATA ones are `/dev/sda1`, `sda2`….
> Below, `<root>`, `<swap>` and `<efi>` are the partitions you made/kept.

### 4.3 Format and mount

```bash
mkfs.ext4 <root>
mkswap <swap>
# Arch-only machine — a NEW EFI partition needs formatting (never do this to
# Windows' EFI partition in a dual boot):
mkfs.fat -F32 <efi>

mount <root> /mnt
swapon <swap>
mkdir -p /mnt/boot/efi
mount <efi> /mnt/boot/efi
```

### 4.4 Install the base system

```bash
# amd-ucode or intel-ucode: match your CPU (lscpu | grep Vendor)
pacstrap -K /mnt base linux linux-firmware linux-headers amd-ucode \
    base-devel git sudo vim networkmanager \
    grub efibootmgr os-prober ntfs-3g
genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt
```

> Installing the microcode now matters: GRUB only loads it if it's present
> when `grub-mkconfig` runs below. `git` is needed to clone this repo later.

### 4.5 Configure

```bash
ln -sf /usr/share/zoneinfo/<zone> /etc/localtime
hwclock --systohc

sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "<hostname>" > /etc/hostname          # also the name of your command

passwd                                     # root password
useradd -m -G wheel -s /bin/bash <user>
passwd <user>
EDITOR=vim visudo                          # uncomment: %wheel ALL=(ALL:ALL) ALL
```

### 4.6 Bootloader

```bash
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg       # dual boot: should list "Windows Boot Manager"
```

### 4.7 Reboot

```bash
systemctl enable NetworkManager
exit
umount -R /mnt
reboot                                     # pull the stick when the screen goes black
```

> ⚠️ If Windows boots instead of GRUB, move **GRUB** above *Windows Boot
> Manager* in the BIOS boot order. Needed after every fresh install.

-----

## 5. Set up the desktop (bootstrap.sh)

Log in as `<user>` on the text console, get online, and run the script:

```bash
nmtui                                      # Wi-Fi only: "Activate a connection"
git clone https://github.com/hdehaini/arch-dotfiles ~/arch-dotfiles
cd ~/arch-dotfiles && ./bootstrap.sh
reboot
```

It asks for your password (sudo) and shows each step. What it does — all
detected for *this* machine, nothing hard-coded:

| Step | Details |
|------|---------|
| AUR helper | installs `paru` |
| Hardware | CPU microcode; GPU drivers (AMD → mesa + vulkan-radeon, Intel → mesa + vulkan-intel + media driver, NVIDIA → nvidia-open-dkms); Bluetooth if there's an adapter; power profiles if there's a battery |
| Base packages | `packages/base.txt`: Hyprland, eww, kitty, wofi, dunst, SDDM, audio (PipeWire), fonts, cursor, icons, and every tool the bar/profiles/command use |
| Apps | `packages/apps.txt` (Brave, Joplin, VS Code, …) — it **asks** first |
| Configs | links `config/*` into `~/.config` and `home/*` into `~` (anything already there is kept as `<name>.bak`) |
| Bar | Python environment for prayer times; a `location.conf` to fill in |
| Command | `<hostname>` command + tab completion |
| Screens | `config/hypr/hosts/<hostname>.lua` for this machine — your screens are written into it at first login |
| Login screen | SDDM theme in your profile's wallpaper and colors |
| Services | NetworkManager, SDDM, Bluetooth, power profiles, Docker, Tailscale, PipeWire — only the ones installed |

At the end it prints a short to-do list. Flags:

| Command | Use |
|---------|-----|
| `./bootstrap.sh` | normal setup (safe to re-run; skips what's done) |
| `./bootstrap.sh --yes` | don't ask, install the apps too |
| `./bootstrap.sh --link` | only re-link configs (no packages, no sudo) |
| `./bootstrap.sh --full` | also everything in `packages.txt` — the main desktop's full snapshot, Steam and games included (turns on multilib) |

After the reboot you land on the login screen; pick **Hyprland**.

-----

## 6. Per-machine touches

All optional — things work without them.

**Your location** (weather + prayer times) — `~/.config/eww/location.conf`:

```bash
CITY="San Diego"
COUNTRY_CODE="US"
LATITUDE=32.72        # city-level is plenty
LONGITUDE=-117.16
TEMP_UNIT=fahrenheit  # or celsius
```

**Monitors** — nothing to do at first: `bootstrap.sh` creates
`config/hypr/hosts/<hostname>.lua`, and the first time you log in every
screen is set up at its best resolution and refresh rate, side by side, and
that layout is written into the file. To change it:

```bash
<hostname> monitors              # screens, models, modes, positions
<hostname> monitors edit         # move a screen, change refresh rate / scale
hyprctl reload                   # apply
<hostname> monitors save         # or: arrange live, then save what's on screen
```

Positions are the top-left corner in logical pixels (a 4K screen at scale 2
is 1920 wide). The same file holds env vars and startup commands for this
machine only; it's in the repo, so a reinstall gets it back. SUPER+1…0
always means "workspace 1…10 on the screen I'm on".

**Wallpapers** — not in the repo; set them per machine. Profiles live in
`~/.config/profiles/`; a screen without a wallpaper of its own gets the
profile's first image. To make them fit:

```bash
<hostname> profile wallpaper screens                 # names + short aliases
<hostname> profile wallpaper split wide.png "Teal Nebula" --apply
<hostname> profile login-screen                      # restyle the login screen to match
```

**A second drive** (e.g. an NTFS data disk shared with Windows):

```bash
lsblk -f                                   # its UUID
sudo mkdir -p /mnt/storage
echo 'UUID=<uuid>  /mnt/storage  ntfs3  defaults,uid=1000,gid=1000,nofail  0  0' | sudo tee -a /etc/fstab
sudo systemctl daemon-reload && sudo mount -a
```

(`nofail` keeps the machine booting if the drive is missing; use `ext4` and
drop the uid/gid options for a Linux-formatted drive.)

**NVIDIA** — follow https://wiki.hypr.land/Nvidia/ (kernel parameter
`nvidia_drm.modeset=1`, a few env vars — put those in your hosts file).

**Tailscale** — `sudo tailscale up` once to sign in.

-----

## 7. Troubleshooting

| Problem | Fix |
|---------|-----|
| Boots straight into Windows | BIOS boot order: GRUB first |
| No Windows in the GRUB menu | `sudo grub-mkconfig -o /boot/grub/grub.cfg` with `GRUB_DISABLE_OS_PROBER=false`; check `os-prober` is installed |
| NTFS drive is read-only | Windows Fast Startup is on (part 2), or Windows is hibernated |
| Black screen / no bar after login | `<hostname> health` (what's broken), then `Hyprland --verify-config -c ~/.config/hypr/hyprland.lua` |
| Bar missing | `eww daemon; eww open bar` |
| A config didn't change | `./bootstrap.sh --link`, then log out and in |
| Something else | `<hostname> health software logs` |

-----

## 8. Everyday commands

```bash
<hostname> --help                  # everything below, with examples
<hostname> update                  # update all, save package lists, clean caches
<hostname> health                  # is everything OK? (software, hardware, network)
<hostname> health hardware --temps
<hostname> packages --size         # what's taking space
<hostname> packages install <pkg>  # or: remove <pkg>
<hostname> profile switch "<name>" # wallpapers + colors (or SUPER+SHIFT+P)
<hostname> monitors                # screens and the saved layout

hyprctl monitors                   # screen names
hyprctl reload                     # re-read the Hyprland config
```

| Config | In the repo (linked into `~/.config`) |
|--------|---------------------------------------|
| Hyprland | `config/hypr/hyprland.lua`, `config/hypr/hosts/<hostname>.lua` |
| Bar, popups | `config/eww/` |
| Profiles | `config/profiles/` |
| Terminal, launcher, notifications | `config/kitty/`, `config/wofi/`, `config/dunst/` |
| The command | `config/dotfiles-cli/` |
| Login screen | `sddm/` (installed with `<hostname> profile login-screen`) |
| Package lists | `packages/base.txt`, `packages/apps.txt`, `packages.txt` |
