alias vim nvim

if status is-interactive; and command -q tmux; and not set -q TMUX
    tmux
end
