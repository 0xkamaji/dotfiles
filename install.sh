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
        return
    fi
    info "installing $name"
    git clone --depth 1 "$url" "$destination"
}

next_backup() {
    local target="$1"
    local backup="${target}_backup"
    local number=1

    while [[ -e "$backup" || -L "$backup" ]]; do
        backup="${target}_backup_${number}"
        ((number++))
    done

    printf '%s\n' "$backup"
}

link_file() {
    local source="$1" target="$2"
    mkdir -p "$(dirname "$target")"

    if [[ -L "$target" ]] && [[ "$(readlink -f "$target")" == "$(readlink -f "$source")" ]]; then
        ok "$target"
        return
    fi

    if [[ -e "$target" || -L "$target" ]]; then
        if diff -qr "$source" "$target" >/dev/null 2>&1; then
            info "$target already matches the repo; replacing it with a symlink"
            rm -rf "$target"
        else
            warn "$target exists and differs from the repo version"
            read -r -p "Use the dotfiles version of $target? [y/N] " answer
            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                info "leaving $target unchanged"
                return
            fi

            local backup
            backup="$(next_backup "$target")"
            mv "$target" "$backup"
            ok "backed up $target to $backup"
        fi
    fi

    ln -s "$source" "$target"
    ok "$target"
}

set_default_shell() {
    local zsh_path
    zsh_path="$(command -v zsh)"

    if [[ "${SHELL:-}" == "$zsh_path" ]] || [[ "${SHELL:-}" == "$(readlink -f "$zsh_path")" ]]; then
        ok "zsh is already the default shell"
        return
    fi

    printf '\nCurrent login shell: %s\n' "${SHELL:-unknown}"
    read -r -p "Make zsh your default shell? [y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        chsh -s "$zsh_path"
        ok "default shell changed to zsh; log out and back in for it to take effect"
    else
        info "leaving default shell unchanged"
    fi
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

set_default_shell

printf '\n'
ok "dotfiles installed"
printf 'Open tmux and press prefix + I if TPM has any remaining plugins to install.\n'
