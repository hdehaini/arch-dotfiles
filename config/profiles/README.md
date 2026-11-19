# Desktop Profiles

Each profile bundles a wallpaper set, an eww color palette, and a dock app list.
The switcher (`switch.sh`) activates a profile by applying its files; anything a
profile doesn't override falls back to a pristine copy.

> **Will adding files here break anything?** No. The switcher only reads from
> profile folders (`<name>/wallpapers/`, `<name>/colors.scss`,
> `<name>/apps.json`) plus the `_defaults/` folder. Markdown notes, READMEs,
> backups — ignored.

## Folder layout

```
~/.config/profiles/
├── README.md         ← this file
├── .current          ← name of the active profile (managed by switch.sh)
├── switch.sh         ← the switcher
├── _defaults/        ← pristine copies; fallback when a profile omits a slot
│   ├── colors.scss
│   └── apps.json
├── default/          ← starter profile (matches your original setup)
│   └── wallpapers/
│       ├── DP-3.png
│       ├── HDMI-A-1.png
│       └── HDMI-A-2.png
└── <your profiles>/
```

## Overridable slots

| File in profile           | Replaces                       |
| ------------------------- | ------------------------------ |
| `wallpapers/<monitor>.*`  | wallpaper on that output       |
| `colors.scss`             | `~/.config/eww/colors.scss`    |
| `apps.json`               | `~/.config/eww/apps.json`      |

`<monitor>` is whatever `hyprctl monitors` reports — currently `DP-3`,
`HDMI-A-1` (the 4K TV), and `HDMI-A-2`. Drop in a `.png`, `.jpg`, `.webp`, …
anything awww reads. A profile missing a slot just keeps the default.

## Daily usage

| Action                        | How                                                       |
| ----------------------------- | --------------------------------------------------------- |
| Switch profile (picker)       | `SUPER+SHIFT+P` → wofi menu                               |
| Switch profile (CLI)          | `~/.config/profiles/switch.sh <name>`                     |
| What's currently active?      | `~/.config/profiles/switch.sh --current`                  |
| List all profiles             | `~/.config/profiles/switch.sh --list`                     |
| Re-apply on login (automatic) | run by `exec-once` in `~/.config/hypr/hyprland.conf`      |

## Making a new profile

```bash
~/.config/profiles/switch.sh --new work
```

That creates `~/.config/profiles/work/wallpapers/` and a small README inside.
Then drop wallpapers in by monitor name:

```bash
cp ~/Pictures/wallpapers/something.png ~/.config/profiles/work/wallpapers/DP-3.png
cp ~/Pictures/wallpapers/other.png     ~/.config/profiles/work/wallpapers/HDMI-A-1.png
```

Optional overrides:

```bash
# Recolor the eww bar and panels
cp my-palette.scss ~/.config/profiles/work/colors.scss

# Different apps in the dock for this profile
cp my-dock.json    ~/.config/profiles/work/apps.json
```

Activate:

```bash
~/.config/profiles/switch.sh work     # or SUPER+SHIFT+P
```

## Setting wallpapers

Everything goes through `<hostname> profile wallpaper` (same as
`~/.config/profiles/wallpaper.sh`). Instead of output names you can use short
names worked out from the Hyprland layout, so they fit whatever monitors the
machine has: `left`, `right` (ends of the desk row), `center` (middle of an
odd-sized row), `1 2 3 …` (desk screens from the left), `top`/`tv` (the
screen(s) above), `desk` (the whole desk row) and `all`. Use `.` as the
profile to mean the active one.

```bash
nebula profile wallpaper                                    # what's on each screen
nebula profile wallpaper screens                            # screens + short names
nebula profile wallpaper set   ~/Pictures/tv.png work top   # one screen
nebula profile wallpaper set   pic.png work left right      # same image on several screens
nebula profile wallpaper split ultrawide.png work           # cut across the desk row
nebula profile wallpaper split wide.png work center right   # only these, in this order
```

`set` replaces any older wallpaper for that screen (any extension). `split`
first crops the image (centered) to the combined shape of the chosen screens,
then cuts it into one piece per screen so the pieces line up. It writes PNGs.
The old `set-wallpaper.sh` / `split-wallpaper.sh` still work and just call
`wallpaper.sh`.

### Optional flags

| Flag                | What it does                                                         |
| ------------------- | -------------------------------------------------------------------- |
| `--colors`          | Run [matugen](https://github.com/InioX/matugen) on the wallpaper and write `<profile>/colors.scss`. The eww palette will match the image. |
| `--apply`           | Activate the profile right after writing files (same as `switch.sh <profile>` afterwards). |
| `--prefer <kind>`   | Tell matugen which color to lean on when an image has multiple candidates. Defaults to `darkness`; other options: `lightness`, `saturation`, `less-saturation`, `value`, `closest-to-fallback`. Implies `--colors`; `--colors <kind>` is a shorthand. |
| `--scheme <type>`   | How matugen builds the palette from that color: `tonal-spot` (default), `vibrant`, `expressive`, `fidelity`, `content`, `fruit-salad`, `rainbow`, `neutral`, `monochrome`. Implies `--colors`. |

Common combos:

```bash
# Full pipeline — split, palette, activate, all in one shot.
nebula profile wallpaper split --colors --apply ~/Pictures/wide.png work

# Same but bias the palette toward saturated tones.
nebula profile wallpaper split --colors --prefer saturation wide.jpg work
```

The matugen template that drives `--colors` lives at
`~/.config/matugen/templates/eww-colors.scss`. Edit it if you want to map
M3 tokens differently, change the terminal-color picks, etc.

## Trying color variants

`nebula profile colors` remakes only `colors.scss`, from the profile's own
wallpaper (a split wallpaper is joined back into one image first), and
updates the bar at once if the profile is active. Wallpapers aren't touched.
Settings you leave out stay as they were last time:

```bash
nebula profile colors --scheme vibrant          # active profile
nebula profile colors --prefer saturation       # keeps "vibrant"
nebula profile colors work --scheme monochrome  # another profile
nebula profile colors --from ~/Pictures/x.png   # colors from another image
nebula profile colors --show                    # what's in use now
```

## Updating a profile

Just edit the files in place — overwrite the wallpaper, edit `colors.scss`,
whatever. Then `~/.config/profiles/switch.sh <name>` (or `--apply` if you're
already on it) to re-apply.

## Renaming or deleting a profile

Rename — use the switcher so it tracks the active-profile pointer:

```bash
~/.config/profiles/switch.sh --rename work office
~/.config/profiles/switch.sh --rename "old name" "new name"
```

If the renamed profile happened to be active, `.current` is updated to
the new name automatically.

Delete — use the switcher so it handles the active-profile case:

```bash
~/.config/profiles/switch.sh --delete chill
~/.config/profiles/switch.sh --delete chill --force   # skip the y/N prompt
```

If you delete the profile that's currently active, the switcher
automatically falls back to `default` and reapplies it. `default` and the
`_defaults/` folder are refused as delete targets.

## Updating the defaults

Files in `_defaults/` are the fallback for any slot a profile doesn't fill. If
you want the "no-override" look to change globally:

```bash
cp my-new.scss ~/.config/profiles/_defaults/colors.scss
```

Don't put wallpapers in `_defaults/` — those are per-profile.

## Wallpaper rendering

The switcher uses [awww](https://codeberg.org/dnkl/awww) (formerly `swww` —
the project was renamed) as the wallpaper
daemon. It respects per-monitor scaling, so a 4K image on a 4K display renders
at native pixels instead of being upscaled from a logical resolution (which is
what hyprpaper does on scaled outputs).

`awww-daemon` is started at login by `hyprland.lua`. If it ever
isn't running, the switcher relaunches it.
