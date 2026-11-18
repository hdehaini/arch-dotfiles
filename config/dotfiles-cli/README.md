# Dotfiles CLI

A single hostname-named entrypoint that wraps every personal script in this
repo. On this machine it's `nebula`; on a clone it's `<your-hostname>`.

```bash
nebula profile                                   # profiles, active one marked
nebula profile switch "Teal Nebula"
nebula profile wallpaper                         # what's on each screen
nebula profile wallpaper split wide.png work --apply
nebula profile wallpaper set tv.jpg work top --colors
nebula health                                    # health summary of everything
nebula health hardware --temps                   # every temperature and fan
nebula health hardware gpu --usage --watch       # live GPU load
nebula health software processes                 # what's using CPU / memory
nebula health network                            # connection, Wi-Fi, ping, DNS
nebula packages --size                           # what's taking up space
nebula packages remove burpsuite
nebula update                                    # update, save lists, clean caches
nebula monitors                                  # screens + this machine's saved layout
nebula monitors save                             # pin the current layout
```

## Install

```bash
~/.config/dotfiles-cli/install.sh           # links ~/.local/bin/<hostname> → cli
~/.config/dotfiles-cli/install.sh customname  # override the name
~/.config/dotfiles-cli/install.sh --uninstall # remove the symlink
```

Safe to re-run. It re-links the symlink, warns if your hostname collides
with an existing command, and reminds you if `~/.local/bin` isn't on your
`$PATH`.

Tab completion: add this to `~/.bashrc` (install.sh reminds you):

```bash
[ -f ~/.config/dotfiles-cli/completion.bash ] && . ~/.config/dotfiles-cli/completion.bash
```

## Works on any machine

Nothing is tied to this computer. The command name comes from the hostname,
and everything else is looked up when it runs:

- **screens**: from `hyprctl monitors`; short names (`left`, `center`,
  `right`, `1 2 3…`, `top`) come from where the screens sit in the layout
- **hardware**: CPUs, GPUs (AMD/Intel via `/sys`, NVIDIA via `nvidia-smi`),
  RAM, disks, fans and batteries are discovered from `/proc`, `/sys`,
  `lspci` and `lsblk`; temperature warnings use each sensor's own limits
  when it reports them
- **services**: whatever is enabled in systemd on that machine
- **network**: every interface from `ip`; NetworkManager is optional
- **packages**: uses paru or yay, whichever is installed, else pacman

## Conventions

Every command follows the same shape, so new ones should too:

```
<host> <command> [action] [things...] [--flags]
```

- **Actions are words, flags are `--options`.** An action says *what to
  do or what to look at* (`remove`, `switch`, `hardware`). A flag only
  changes *how* (`--size`, `--watch`, `--apply`, `--force`).
- **No action = a read-only overview.** `profile` lists profiles,
  `packages` lists packages, `profile wallpaper` shows the screens,
  `health` runs the quick check. Running a command bare never changes
  anything. (`update` is the exception: it's an action by itself.)
- **`--help` works at every level** (`-h` and `help` too).
- **Anything destructive asks first** (`profile delete`, `packages remove`
  through pacman's own prompt).
- **Errors say what to type instead**, e.g.
  `error: unknown flag: --x (try: nebula packages --help)`.

## Layout

```
~/.config/dotfiles-cli/
├── cli                 ← main dispatcher (symlink target)
├── install.sh          ← creates ~/.local/bin/<hostname>
├── completion.bash     ← tab completion (source it from ~/.bashrc)
├── lib/common.sh       ← shared helpers: colors, bars, sensors, AUR helper
├── health/             ← parts of `health` (sourced, not commands)
│   ├── software.sh     ← desktop, services, processes, logs, packages
│   ├── hardware.sh     ← CPU/GPU/RAM/disks/fans/batteries
│   └── network.sh      ← connections, Wi-Fi, DNS, ping tests
├── commands/
│   ├── health          ← `<host> health [software|hardware|network]`
│   ├── monitors        ← `<host> monitors [list|save|init|edit]` — hosts/<hostname>.lua
│   ├── packages        ← `<host> packages …` — list, install, remove, clean, diff, save
│   ├── profile         ← `<host> profile …` — profiles/switch.sh + profiles/wallpaper.sh
│   └── update          ← `<host> update` — update, save lists, clean caches
└── README.md
```

## Adding a new command

Drop an executable file at `commands/<name>` with a `# DESC: <one-liner>`
marker on a comment line — the dispatcher picks it up automatically and
shows the description in the top-level help. Add its actions to
`completion.bash` for tab completion.

Skeleton:

```bash
#!/usr/bin/env bash
# DESC: One-line summary shown by the dispatcher.

set -u
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

show_help() { cat <<EOF
$SELF_NAME thing — what this does.

Usage: $SELF_NAME thing [action] [flags]

Actions:
  list    Show things (the default)
  add     Add a thing
EOF
}

action="${1:-list}"
[ $# -gt 0 ] && shift
case "$action" in
    -h|--help|help) show_help ;;
    list)           ... ;;
    add)            ... ;;
    *) die "unknown action: $action (try: $SELF_NAME thing --help)" ;;
esac
```

`chmod +x commands/<name>` and it's live — no other registration needed.

## Why `<hostname>` and not a fixed name?

So the same repo works on multiple machines without renaming anything.
`install.sh` reads `hostname` at install time and creates the symlink with
that name. Push the repo to GitHub, your friend clones it, runs
`install.sh`, and gets a command named after *their* machine.

If your hostname happens to collide with a real binary (`ls`, `cat`, etc.),
`install.sh` warns you — pass an explicit name to override:

```bash
~/.config/dotfiles-cli/install.sh dot
```
