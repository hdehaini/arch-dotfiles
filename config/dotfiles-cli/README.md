# Dotfiles CLI

A single hostname-named entrypoint that wraps every personal script in this
repo. On this machine it's `nebula`; on a clone it's `<your-hostname>`.

```bash
nebula profile list
nebula profile switch chill
nebula wallpaper split ~/Pictures/wide.png work --apply
nebula wallpaper set ~/Pictures/tv.jpg work HDMI-A-1 --colors
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

## Layout

```
~/.config/dotfiles-cli/
├── cli                 ← main dispatcher (symlink target)
├── install.sh          ← creates ~/.local/bin/<hostname>
├── commands/
│   ├── profile         ← `<host> profile …` — wraps profiles/switch.sh
│   └── wallpaper       ← `<host> wallpaper …` — wraps split + set
└── README.md
```

## Help

Every level has `--help` (`-h`, `help`, or just no args):

```bash
nebula --help              # top-level commands
nebula profile --help      # profile actions
nebula wallpaper --help    # wallpaper actions
```

## Adding a new subcommand

Drop an executable file at `commands/<name>` with a `# DESC: <one-liner>`
marker on a comment line — the dispatcher picks it up automatically and
shows the description in the top-level help.

Skeleton:

```bash
#!/usr/bin/env bash
# DESC: One-line summary shown by the dispatcher.

set -u
SELF_NAME="${SELF_NAME:-$(basename "$(readlink -f "$0")")}"

show_help() { cat <<EOF
$SELF_NAME thing — what this does.

Usage: $SELF_NAME thing <action> [args...]

Actions:
  foo    Do foo.
  bar    Do bar.
EOF
}

action="${1:-}"
case "$action" in
    "" | -h | --help | help) show_help; exit 0 ;;
esac
shift

case "$action" in
    foo) ... ;;
    bar) ... ;;
    *)   echo "$SELF_NAME thing: unknown action: $action" >&2; exit 1 ;;
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
