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
| **Per-machine CLI** (`config/dotfiles-cli/`) | `<hostname> profile …`, `health`, `packages`, `update`. One symlink at install time = same code, different command name on every machine. |
| **Login screen** (`sddm/`) | SDDM theme using the active profile's wallpaper and colors. |
| **kitty / wofi / dunst / nemo / nwg-look / fastfetch / xsettingsd / matugen / networkmanager-dmenu / GTK** | Configured to match. |

## Fresh-Arch install (after `archinstall`, with networking)

```bash
git clone https://github.com/hdehaini/arch-dotfiles ~/arch-dotfiles
cd ~/arch-dotfiles
./bootstrap.sh
reboot
```

`bootstrap.sh` is safe to re-run. It:

1. installs the **base packages** in `packages/base.txt` (the desktop, the
   bar, and every tool the scripts call), plus what **this** machine needs:
   GPU drivers (AMD / Intel / NVIDIA), CPU microcode, Bluetooth, laptop
   power tools — detected, not hard-coded;
2. shows your **everyday apps** (`packages/apps.txt`: Brave, Joplin, VS Code…)
   and asks before installing them;
3. links every folder in `config/` into `~/.config` and `home/` into `~`
   (anything already there is moved to `<name>.bak`);
4. sets up the bar's Python environment and `~/.config/eww/location.conf`;
5. installs the `<hostname>` command with tab completion, the login screen,
   and enables NetworkManager, SDDM, Bluetooth, Docker, etc. as needed.

It ends with a short list of what's left (usually: set your city in
`location.conf`, reboot).

| Mode | What it does |
| --- | --- |
| `./bootstrap.sh` | base + (asks) apps + links + setup |
| `./bootstrap.sh --yes` | same, without questions |
| `./bootstrap.sh --full` | also everything in `packages.txt` / `packages-aur.txt` — a full rebuild of the main machine, games and all |
| `./bootstrap.sh --link` | only re-link configs (no packages, no sudo) |

To change what a new machine gets, edit `packages/base.txt` (needed by the
configs — keep it complete) or `packages/apps.txt` (your choice of apps).

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
$(hostname) profile wallpaper split image.png myprofile           # across the desk monitors
$(hostname) profile wallpaper split img.png prof --colors --apply # split + matugen + activate
$(hostname) profile wallpaper set tv.png prof top                 # one image, one monitor
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

- App-managed folders that rewrite themselves (`~/.config/Code`,
  `discord`, `mozilla`, …).
- `config/eww/scripts/.venv/` — the prayer-widget Python environment;
  `bootstrap.sh` recreates it from `requirements.txt`.
- `config/eww/location.conf` — your location (per machine).
- `config/profiles/*/wallpapers/` — wallpapers are personal and large;
  bring your own.

## Per-machine settings

Everything works without these; they're for fine-tuning one machine.

| What | Where |
| --- | --- |
| **Location** (weather, prayer times) | `~/.config/eww/location.conf` — created from `location.conf.example`; not committed, so a laptop can have its own |
| **Monitor positions, refresh rates, machine-only env vars / startup commands** | `~/.config/hypr/hosts/<hostname>.lua` — created by `bootstrap.sh` and filled with your screens at first login; change it with `<hostname> monitors edit` (or arrange, then `<hostname> monitors save`). Screens not in it are set up automatically (best mode, highest refresh rate). |
| **Login screen** | `<hostname> profile login-screen` restyles it from the current profile (`--preview` to look first) |

### Appearance

| What | Where |
| --- | --- |
| **GTK theme / icons / cursor / font** | `config/gtk-3.0`, `config/gtk-4.0`, `home/.gtkrc-2.0`, and the `gsettings` lines in `hyprland.lua`: Adwaita-dark, Papirus-Dark, Windows-10 cursor (22px), Inter 11 |
| **Default applications** | `config/mimeapps.list` |
| **Matugen palette type** | `config/matugen/config.toml` |
| **Adhan audio** | `config/eww/assets/adhan-0.mp3` |

### Recommended first-run smoke test

```bash
# All should print without errors:
hyprctl monitors
awww query
~/.config/eww/scripts/weather.sh current
~/.config/eww/scripts/.venv/bin/python ~/.config/eww/scripts/prayer_engine.py
nebula --help    # or whatever your hostname is
nebula profile list

# Visual checks:
nebula profile menu                      # wofi pops up
# Click the bar's time → control center opens: Night Mode, sliders,
#   and Sleep / Restart / Shut down at the bottom
# Click the bar's center widget → dashboard with cpu/mem stats
```

## Repo layout

```
arch-dotfiles/
├── README.md                  ← you're here
├── INSTALL-ARCH.md            ← long-form Arch install walkthrough
├── REAUDIT-PROMPT.txt         ← LLM prompt to re-audit configs later
├── bootstrap.sh               ← clone → run on a fresh machine
├── collect.sh                 ← sync live system → repo (skips linked dirs)
├── sync-docs.sh               ← annotate README with new packages (optional)
├── packages/
│   ├── base.txt               ← always installed: desktop + everything the configs call
│   └── apps.txt               ← offered during setup: your everyday apps
├── packages.txt               ← full `pacman -Qqe` snapshot (`<host> packages save`)
├── packages-aur.txt           ← full `pacman -Qqem` snapshot
├── sddm/                      ← login screen theme + install.sh
├── config/                    ← mirrors ~/.config (tracked subset only)
└── home/                      ← mirrors $HOME (small, tracked files only)
```
