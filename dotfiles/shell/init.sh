alias vim='nvim'

case $- in
    *i*)
        if command -v tmux >/dev/null 2>&1 && [ -z "${TMUX:-}" ]; then
            tmux
        fi
        ;;
esac
