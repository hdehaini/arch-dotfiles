# Bash tab completion for the dotfiles CLI (<hostname> …).
# Loaded from ~/.bashrc:
#   [ -f ~/.config/dotfiles-cli/completion.bash ] && . ~/.config/dotfiles-cli/completion.bash
#
# Commands are found by looking in commands/, profiles and screens are
# looked up live, so nothing here is specific to one machine.

_dotfiles_cli_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

# Add every candidate that starts with what's typed so far, escaped so
# names with spaces ("Teal Nebula") come out right.
_dotfiles_cli_add() {
    local cur="$1" c; shift
    # Undo the escaping in what's typed: Teal\ Ne → Teal Ne
    cur="${cur//\\ / }"; cur="${cur#[\"\']}"
    for c in "$@"; do
        [[ "$c" == "$cur"* ]] && COMPREPLY+=("$(printf '%q' "$c")")
    done
}

# Add matches from a long list (package names) quickly.
_dotfiles_cli_add_many() {   # cur, then a command that prints candidates
    local cur="$1"; shift
    mapfile -t -O "${#COMPREPLY[@]}" COMPREPLY < <("$@" 2>/dev/null | awk -v c="$cur" 'index($0, c) == 1' | head -n 200)
}

_dotfiles_cli_profiles() {
    local d
    for d in "$HOME/.config/profiles"/*/; do
        d="$(basename "$d")"
        [ "$d" = "_defaults" ] || echo "$d"
    done
}

_dotfiles_cli_screens() {
    local json n i
    printf "%s\n" left center right top desk all
    command -v hyprctl >/dev/null || return 0
    json="$(hyprctl monitors -j 2>/dev/null)"
    jq -r '.[].name' <<<"$json" 2>/dev/null
    # Desk screens are numbered 1..N (N = screens in the biggest row).
    n="$(jq '[group_by(.y)[] | length] | max // 0' <<<"$json" 2>/dev/null)"
    for (( i = 1; i <= ${n:-0}; i++ )); do echo "$i"; done
}

_dotfiles_cli_images() {   # folders and image files
    local f
    compopt -o filenames 2>/dev/null
    while IFS= read -r f; do
        if [ -d "$f" ] || [[ "${f,,}" =~ \.(png|jpe?g|webp|gif|bmp|avif|jxl|tiff?)$ ]]; then
            COMPREPLY+=("$f")
        fi
    done < <(compgen -f -- "$1")
}

_dotfiles_cli_all_packages() {   # repo packages + AUR names cached by paru/yay
    pacman -Slq
    cat "$HOME/.cache/paru/packages.aur" 2>/dev/null
}

# Count the positional words between index $1 and the cursor, skipping
# --flags (and the value after --prefer).
_dotfiles_cli_pos() {
    local i pos=0
    for (( i = $1; i < COMP_CWORD; i++ )); do
        case "${COMP_WORDS[i]}" in
            --prefer|--scheme|--from) i=$((i + 1)) ;;
            -*) ;;
            *) pos=$((pos + 1)) ;;
        esac
    done
    echo "$pos"
}

# `profile wallpaper …`; $1 = index of the wallpaper action word.
_dotfiles_cli_wallpaper() {
    local at="$1" cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}" p=()
    if [ "$COMP_CWORD" -eq "$at" ]; then
        _dotfiles_cli_add "$cur" show screens set split --help; return
    fi
    if [ "$prev" = "--prefer" ] || [ "$prev" = "--colors" ]; then
        _dotfiles_cli_add "$cur" darkness lightness saturation less-saturation value closest-to-fallback
        [ "$prev" = "--prefer" ] && return
    fi
    if [ "$prev" = "--scheme" ]; then
        _dotfiles_cli_add "$cur" tonal-spot vibrant expressive fidelity content fruit-salad rainbow neutral monochrome
        return
    fi
    if [[ "$cur" == -* ]]; then
        _dotfiles_cli_add "$cur" --apply --colors --prefer --scheme; return
    fi
    local pos; pos="$(_dotfiles_cli_pos $(( at + 1 )))"
    case "${COMP_WORDS[at]}" in
        show) [ "$pos" -eq 0 ] && { mapfile -t p < <(_dotfiles_cli_profiles); _dotfiles_cli_add "$cur" . "${p[@]}"; } ;;
        set|split)
            case "$pos" in
                0) _dotfiles_cli_images "$cur" ;;
                1) mapfile -t p < <(_dotfiles_cli_profiles); _dotfiles_cli_add "$cur" . "${p[@]}" ;;
                *) mapfile -t p < <(_dotfiles_cli_screens); _dotfiles_cli_add "$cur" "${p[@]}" ;;
            esac ;;
    esac
}

_dotfiles_cli() {
    local cur="${COMP_WORDS[COMP_CWORD]}" prev="${COMP_WORDS[COMP_CWORD-1]}"
    local cmd="${COMP_WORDS[1]:-}" action="${COMP_WORDS[2]:-}"
    COMPREPLY=()
    local p=()

    # Level 1: the command (whatever is in commands/).
    if [ "$COMP_CWORD" -eq 1 ]; then
        local cmds=() f
        for f in "$_dotfiles_cli_dir"/commands/*; do [ -x "$f" ] && cmds+=("$(basename "$f")"); done
        _dotfiles_cli_add "$cur" "${cmds[@]}" --help
        return
    fi

    case "$cmd" in
        profile)
            if [ "$COMP_CWORD" -eq 2 ]; then
                _dotfiles_cli_add "$cur" list current switch apply menu new delete rename wallpaper colors login-screen --help; return
            fi
            case "$action" in
                wallpaper|wp) _dotfiles_cli_wallpaper 3 ;;
                colors|colours)
                    case "$prev" in
                        --prefer) _dotfiles_cli_add "$cur" darkness lightness saturation less-saturation value closest-to-fallback ;;
                        --scheme) _dotfiles_cli_add "$cur" tonal-spot vibrant expressive fidelity content fruit-salad rainbow neutral monochrome ;;
                        --from)   _dotfiles_cli_images "$cur" ;;
                        *) if [[ "$cur" == -* ]]; then _dotfiles_cli_add "$cur" --prefer --scheme --from --show --help
                           else mapfile -t p < <(_dotfiles_cli_profiles); _dotfiles_cli_add "$cur" . "${p[@]}"; fi ;;
                    esac ;;
                login-screen)
                    if [[ "$cur" == -* ]]; then _dotfiles_cli_add "$cur" --preview
                    else _dotfiles_cli_images "$cur"; fi ;;
                switch|delete|rename)
                    local pos; pos="$(_dotfiles_cli_pos 3)"
                    [ "$pos" -eq 0 ] && { mapfile -t p < <(_dotfiles_cli_profiles); _dotfiles_cli_add "$cur" "${p[@]}"; }
                    [ "$action" = delete ] && [ "$pos" -eq 1 ] && _dotfiles_cli_add "$cur" --force ;;
            esac
            ;;
        packages)
            local list_flags=(--size --recent --desc --all --orphans --aur --repo)
            if [ "$COMP_CWORD" -eq 2 ]; then
                if [[ "$cur" == -* ]]; then _dotfiles_cli_add "$cur" "${list_flags[@]}" --help
                else _dotfiles_cli_add "$cur" list search install remove clean diff save; fi
                return
            fi
            case "$action" in
                list|-*) _dotfiles_cli_add "$cur" "${list_flags[@]}" ;;
                remove|rm|uninstall)
                    if [[ "$cur" == -* ]]; then _dotfiles_cli_add "$cur" --orphans
                    else _dotfiles_cli_add_many "$cur" pacman -Qq; fi ;;
                install|add)
                    [ -n "$cur" ] && _dotfiles_cli_add_many "$cur" _dotfiles_cli_all_packages ;;
            esac
            ;;
        health|doctor)
            if [ "$COMP_CWORD" -eq 2 ]; then
                _dotfiles_cli_add "$cur" software hardware network --all --watch --help; return
            fi
            [ "$prev" = "--watch" ] && return   # number of seconds
            case "$action" in
                software) _dotfiles_cli_add "$cur" desktop services processes logs packages --watch ;;
                hardware) _dotfiles_cli_add "$cur" cpu gpu ram disks fans battery --usage --temps --watch ;;
                *)        _dotfiles_cli_add "$cur" --watch ;;
            esac
            ;;
        update)  _dotfiles_cli_add "$cur" --repo-only --no-save --no-clean --help ;;
        monitors) [ "$COMP_CWORD" -eq 2 ] && _dotfiles_cli_add "$cur" list save init edit --help ;;
    esac
}

# Register for every name in ~/.local/bin that links to this CLI
# (normally the hostname).
for _f in "$HOME"/.local/bin/*; do
    [ -L "$_f" ] && [ "$(readlink -f "$_f")" = "$_dotfiles_cli_dir/cli" ] \
        && complete -F _dotfiles_cli "$(basename "$_f")"
done
unset _f
