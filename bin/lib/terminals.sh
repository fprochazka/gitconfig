#!/usr/bin/env bash
#
# Terminal detection and tab management utilities
#
# Usage: source this file after common.sh
#   source "${SCRIPT_DIR}/lib/terminals.sh"
#

# Detect which terminal emulator is running
# Returns: guake, kitty, wezterm, tmux, gnome-terminal, or "unknown"
detect_terminal() {
    if [[ -n "${GUAKE_TAB_UUID:-}" ]] || [[ "${TERM_PROGRAM:-}" == "guake" ]]; then
        echo "guake"
    elif [[ -n "${TMUX:-}" ]]; then
        echo "tmux"
    elif [[ -n "${KITTY_WINDOW_ID:-}" ]]; then
        echo "kitty"
    elif [[ -n "${WEZTERM_PANE:-}" ]]; then
        echo "wezterm"
    elif [[ "${TERM_PROGRAM:-}" == "gnome-terminal" ]] || [[ "${COLORTERM:-}" == "gnome-terminal" ]]; then
        echo "gnome-terminal"
    elif [[ "${TERM_PROGRAM:-}" == "konsole" ]] || [[ -n "${KONSOLE_VERSION:-}" ]]; then
        echo "konsole"
    else
        echo "unknown"
    fi
}

# Open a new terminal tab in the specified directory
# Usage: open_terminal_tab "/path/to/directory"
# Returns: 0 on success, 1 if terminal not supported (prints fallback message)
open_terminal_tab() {
    local directory="$1"
    local terminal

    terminal=$(detect_terminal)

    case "$terminal" in
        guake|tmux|kitty|wezterm|gnome-terminal|konsole)
            echo ""
            print_green "Opening in new terminal tab: $directory"
            ;;
    esac

    case "$terminal" in
        guake)
            _open_tab_guake "$directory"
            ;;
        tmux)
            _open_tab_tmux "$directory"
            ;;
        kitty)
            _open_tab_kitty "$directory"
            ;;
        wezterm)
            _open_tab_wezterm "$directory"
            ;;
        gnome-terminal)
            _open_tab_gnome_terminal "$directory"
            ;;
        konsole)
            _open_tab_konsole "$directory"
            ;;
        *)
            echo ""
            print_yellow "Cannot open directory in a new tab automatically, unsupported terminal."
            echo ""
            print_bold "cd $directory"
            return 1
            ;;
    esac
}

#
# Terminal-specific implementations
#

_open_tab_guake() {
    local directory="$1"

    # Use D-Bus for reliability
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session \
            --dest org.guake3.RemoteControl \
            --object-path /org/guake3/RemoteControl \
            --method org.guake3.RemoteControl.add_tab "$directory" >/dev/null 2>&1
        gdbus call --session \
            --dest org.guake3.RemoteControl \
            --object-path /org/guake3/RemoteControl \
            --method org.guake3.RemoteControl.show >/dev/null 2>&1
    elif command -v guake >/dev/null 2>&1; then
        # Fallback to CLI
        guake -n "$directory"
        guake --show
    else
        return 1
    fi
}

_open_tab_tmux() {
    local directory="$1"
    tmux new-window -c "$directory"
}

_open_tab_kitty() {
    local directory="$1"

    if command -v kitten >/dev/null 2>&1; then
        kitten @ launch --type=tab --cwd "$directory" >/dev/null 2>&1
    else
        return 1
    fi
}

_open_tab_wezterm() {
    local directory="$1"

    if command -v wezterm >/dev/null 2>&1; then
        wezterm cli spawn --cwd "$directory" >/dev/null 2>&1
    else
        return 1
    fi
}

_open_tab_gnome_terminal() {
    local directory="$1"

    if command -v gnome-terminal >/dev/null 2>&1; then
        gnome-terminal --tab --working-directory="$directory" >/dev/null 2>&1 &
        disown
    else
        return 1
    fi
}

_open_tab_konsole() {
    local directory="$1"

    # Konsole doesn't have great CLI tab support, open new window instead
    if command -v konsole >/dev/null 2>&1; then
        konsole --workdir "$directory" >/dev/null 2>&1 &
        disown
    else
        return 1
    fi
}
