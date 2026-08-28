#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info() { printf '[+] %s\n' "$1"; }
ok()   { printf '[✓] %s\n' "$1"; }
warn() { printf '[!] %s\n' "$1" >&2; }

install_packages() {
    local missing=()
    command -v git  >/dev/null 2>&1 || missing+=(git)
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
            rm -rf -- "$target"
        else
            warn "$target exists and differs from the repo version"
            diff -ru -- "$target" "$source" || true
            read -r -p "Use the dotfiles version of $target? [y/N] " answer
            if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                info "leaving $target unchanged"
                return
            fi

            local backup
            backup="$(next_backup "$target")"
            mv -- "$target" "$backup"
            ok "backed up $target to $backup"
        fi
    fi

    ln -s -- "$source" "$target"
    ok "$target"
}

detect_shell() {
    local shell_path
    local passwd_entry

    shell_path="${SHELL:-}"
    case "${shell_path##*/}" in
        bash|zsh|fish) printf '%s\n' "${shell_path##*/}"; return ;;
    esac

    if command -v getent >/dev/null 2>&1; then
        passwd_entry="$(getent passwd "$(id -un)" 2>/dev/null || true)"
        shell_path="${passwd_entry##*:}"
        case "${shell_path##*/}" in
            bash|zsh|fish) printf '%s\n' "${shell_path##*/}"; return ;;
        esac
    fi

    warn "unable to detect a supported shell environment"
    warn "supported shells are bash, zsh, and fish"
    return 1
}

install_shell_config() {
    local shell_name="$1"
    local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    local fragment
    local hook
    local legacy_fragment
    local shell_config

    case "$shell_name" in
        bash)
            fragment="init.sh"
            legacy_fragment="$DOTFILES_DIR/dotfiles/shell/common.sh"
            shell_config="$HOME/.bashrc"
            ;;
        zsh)
            fragment="init.sh"
            legacy_fragment="$DOTFILES_DIR/dotfiles/shell/common.sh"
            shell_config="$HOME/.zshrc"
            ;;
        fish)
            fragment="init.fish"
            legacy_fragment="$DOTFILES_DIR/dotfiles/shell/config.fish"
            shell_config="$config_home/fish/config.fish"
            ;;
    esac

    link_file "$DOTFILES_DIR/dotfiles/shell/$fragment" "$config_home/dotfiles/$fragment"

    if [[ -L "$shell_config" ]] && [[ "$(readlink "$shell_config")" == "$legacy_fragment" ]]; then
        rm -- "$shell_config"
        info "replacing the legacy dotfiles-managed $shell_config symlink with a source hook"
    fi

    if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
        hook="source \"$config_home/dotfiles/$fragment\""
    else
        hook="source ~/.config/dotfiles/$fragment"
    fi

    mkdir -p "$(dirname "$shell_config")"
    if [[ -e "$shell_config" || -L "$shell_config" ]]; then
        if grep -Fqx -- "$hook" "$shell_config"; then
            ok "$shell_config already sources the dotfiles init"
            return
        fi
        printf '\n%s\n' "$hook" >> "$shell_config"
    else
        printf '%s\n' "$hook" > "$shell_config"
    fi
    ok "added the dotfiles init to $shell_config"
}

printf '\ndotfiles setup\n\n'
shell_name="$(detect_shell)"
info "detected $shell_name as the shell environment"

install_packages

ensure_repo "https://github.com/tmux-plugins/tpm.git" "$HOME/.tmux/plugins/tpm" "TPM"
ensure_repo "https://github.com/jimeh/tmux-themepack.git" "$HOME/.tmux-themepack" "tmux-themepack"

# Core, terminal-independent environment.
link_file "$DOTFILES_DIR/dotfiles/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/dotfiles/nvim" "$HOME/.config/nvim"

install_shell_config "$shell_name"

printf '\n'
ok "dotfiles installed"
printf 'Open tmux and press prefix + I if TPM has any remaining plugins to install.\n'
