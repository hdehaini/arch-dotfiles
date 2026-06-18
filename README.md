# arch-dotfiles

Hyprland + eww + per-machine CLI. Designed for a fresh Arch install. The
repo's hostname-based wrapper (`<hostname> profile switch …`) means cloning
this onto a second machine doesn't need any name changes — your hostname
becomes the command name automatically.

## What's in here

| Area | What it does |
| --- | --- |
| **Hyprland** (`config/hypr/`) | Wayland window manager, monitor layout, keybinds. |
| **eww bar + dashboard** (`config/eww/`) | Top bar, control center, notification history, dashboard popup with system stats, profile-themed widgets. Replaces waybar. |
| **Desktop profiles** (`config/profiles/`) | Per-profile wallpapers, color palette (matugen-generated), and dock contents. Switch via wofi (SUPER+SHIFT+P) or `<hostname> profile switch <name>`. Auto-reloads when an external monitor connects. |
| **Per-machine CLI** (`config/dotfiles-cli/`) | `<hostname> profile …`, `<hostname> wallpaper …`. One symlink at install time = same code, different command name on every machine. |
| **Selfhost helpers** | Container toggle wired into the dashboard for things like the odysseus stack. |
| **kitty / wofi / dunst / nemo / nwg-look / fastfetch / xsettingsd / matugen / networkmanager-dmenu / GTK** | Configured to match. |

## Fresh-Arch install (assumes you've finished `archinstall` and have networking)

```bash
# 1. clone the repo
git clone <your-fork-url> ~/arch-dotfiles
cd ~/arch-dotfiles

# 2. bootstrap — installs packages, symlinks configs, installs the CLI
bash bootstrap.sh

# 3. drop wallpapers in
mkdir -p ~/Pictures/wallpapers
# put your images here, then create a profile:
#   <hostname> profile new mywork
#   <hostname> wallpaper set ~/Pictures/wallpapers/img.png mywork DP-3

# 4. add yourself to the docker group (only if you'll use selfhost)
sudo usermod -aG docker $USER

# 5. fix the monitor= lines in ~/.config/hypr/hyprland.conf for your displays
hyprctl monitors    # tells you the names (DP-3, HDMI-A-1, …)

# 6. reboot — Hyprland comes up via SDDM
reboot
```

After reboot, log in and try:

```bash
$(hostname) --help         # the CLI takes your hostname as its name
$(hostname) profile list
$(hostname) profile menu   # same as SUPER+SHIFT+P
```

If `<hostname>` isn't found, your `~/.local/bin` isn't on PATH yet. Add to
`~/.bashrc` (or `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Open a fresh shell and try again.

## Bootstrap modes

```bash
bash bootstrap.sh             # default — required packages + symlinks
bash bootstrap.sh --full      # also reinstalls everything in packages*.txt
                              # (games, browsers, all of it)
bash bootstrap.sh --link      # symlink only; skip pacman/paru
```

`--full` is for when you want a faithful rebuild of your old machine.
`--link` is for re-running after `collect.sh` adds new tools to the repo.

## Day-to-day commands

```bash
# Profiles (managed by config/profiles/switch.sh under the hood)
$(hostname) profile list
$(hostname) profile new "weekend"
$(hostname) profile switch "weekend"
$(hostname) profile rename old new
$(hostname) profile delete chill          # --force to skip confirm
$(hostname) profile menu                  # wofi picker

# Wallpapers
$(hostname) wallpaper split image.png myprofile                   # halve a 3840×1080
$(hostname) wallpaper split img.png prof --colors --apply         # split + matugen + activate
$(hostname) wallpaper set tv.png prof HDMI-A-1                    # one image, one monitor
```

The dashboard popup (open it from the bar's center widget) has:
- Profile button — opens the wofi profile picker
- Night Mode toggle — color-temp shift via hyprsunset
- Brightness slider — software gamma via hyprsunset (true backlight isn't
  available on desktops)
- Odysseus container toggle — start/stop the selfhost stack from the bar

## Keeping the repo in sync

After tweaking configs on the live machine:

```bash
bash collect.sh    # copies ~/.config bits + packages*.txt back into the repo
cd /path/to/arch-dotfiles
git add -A && git commit -m "sync"
git push
```

`collect.sh` is data-driven — the list of tracked dirs/files lives at the
top of the script. If you adopt a new tool, add its config dir there and
re-run.

To audit what's actually being used vs. orphaned (e.g., something you
stopped using), see **`REAUDIT-PROMPT.txt`** — a ready-made prompt you can
paste into Claude (or any LLM) to walk the repo, find unused tools, and
update the package lists + scripts.

## Per-machine dynamic name (the hostname trick)

`bootstrap.sh` runs `~/.config/dotfiles-cli/install.sh` at the end. That
script reads `hostname` and creates a symlink at `~/.local/bin/<hostname>`
pointing at `~/.config/dotfiles-cli/cli`. The dispatcher reads its own
basename at runtime, so all the help text and error messages auto-print
whatever name the symlink has — no per-machine edits anywhere in the repo.

On a name collision with an existing binary, install.sh warns and PATH
order decides which wins. Override by passing an explicit name:

```bash
~/.config/dotfiles-cli/install.sh dot
```

To extend the CLI later, drop an executable into
`config/dotfiles-cli/commands/<name>` with a `# DESC:` marker. The
dispatcher auto-discovers it.

## Things the repo intentionally does NOT include

- `~/.config/Code`, `discord`, `mozilla`, `htop`, `mpv`, `pulse`,
  `systemd`, `Thunar`, `xfce4` — app-managed dirs that rewrite themselves.
- `~/.config/eww/scripts/.venv/` — the prayer-engine venv. Regenerated on
  demand.
- `~/Pictures/wallpapers/` — too large for git; bring your own.

If you ever want one of these in, edit `CONFIG_DIRS` in `collect.sh`.

## Manual one-time tweaks the bootstrap doesn't do

- `hyprland.conf` near the `env =` block has `XDG_DATA_DIRS` hardcoded
  with a previous username. Check before first login and update if it
  doesn't match yours.
- SDDM theme background — point it at your login wallpaper:
  ```
  /etc/sddm.conf.d/sddm.conf
  /usr/share/sddm/themes/tokyo-night-sddm/theme.conf
  ```
- Firmware updates for displays / GPU — not handled.

## Repo layout

```
arch-dotfiles/
├── README.md                  ← you're here
├── INSTALL-ARCH.md            ← long-form Arch install walkthrough
├── REAUDIT-PROMPT.txt         ← LLM prompt to re-audit configs later
├── bootstrap.sh               ← clone → run on a fresh machine
├── collect.sh                 ← sync live system → repo
├── sync-docs.sh               ← annotate README with new packages (optional)
├── packages.txt               ← `pacman -Qqe` snapshot
├── packages-aur.txt           ← `pacman -Qqem` snapshot
├── config/                    ← mirrors ~/.config (tracked subset only)
└── home/                      ← mirrors $HOME (small, tracked files only)
```
