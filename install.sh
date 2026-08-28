#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[+] %s\n' "$1"; }
ok()   { printf '[✓] %s\n' "$1"; }
warn() { printf '[!] %s\n' "$1" >&2; }

install_packages() {
    local missing=()
    command -v git  >/dev/null 2>&1 || missing+=(git)
    command -v zsh  >/dev/null 2>&1 || missing+=(zsh)
    command -v tmux >/dev/null 2>&1 || missing+=(tmux)
    command -v nvim >/dev/null 2>&1 || missing+=(neovim)

    if ((${#missing[@]} == 0)); then
        ok "core packages already installed"
        return
    fi

    info "installing: ${missing[*]}"
    if command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "${missing[@]}"
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    else
        warn "unsupported package manager; install these manually: ${missing[*]}"
        return 1
    fi
}

ensure_repo() {
    local url="$1" destination="$2" name="$3"
    if [[ -d "$destination/.git" ]]; then
        ok "$name already installed"
        return
    fi
    if [[ -e "$destination" ]]; then
        warn "$destination already exists; not replacing it"
        return 1
    fi
    info "installing $name"
    git clone --depth 1 "$url" "$destination"
}

link_file() {
    local source="$1" target="$2"
    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]]; then
        if [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
            ok "$target"
            return
        fi
        warn "$target is already a symlink to something else; not replacing it"
        return 1
    fi
    if [[ -e "$target" ]]; then
        warn "$target already exists and is not managed by this repo; not replacing it"
        return 1
    fi
    ln -s "$source" "$target"
    ok "$target"
}

printf '\ndotfiles setup\n\n'
install_packages

ensure_repo "https://github.com/ohmyzsh/ohmyzsh.git" "$HOME/.oh-my-zsh" "Oh My Zsh"
ensure_repo "https://github.com/tmux-plugins/tpm.git" "$HOME/.tmux/plugins/tpm" "TPM"
ensure_repo "https://github.com/jimeh/tmux-themepack.git" "$HOME/.tmux-themepack" "tmux-themepack"

# Core, terminal-independent environment.
link_file "$DOTFILES_DIR/dotfiles/zshrc" "$HOME/.zshrc"
link_file "$DOTFILES_DIR/dotfiles/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/dotfiles/nvim" "$HOME/.config/nvim"

printf '\n'
ok "dotfiles installed"
printf 'Open tmux and press prefix + I if TPM has any remaining plugins to install.\n'
