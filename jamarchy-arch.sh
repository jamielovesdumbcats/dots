#!/bin/bash
#
#  ████████╗██╗   ██╗██╗  ██╗███╗   ███╗ █████╗ ████████╗███████╗
#  ╚══██╔══╝██║   ██║╚██╗██╔╝████╗ ████║██╔══██╗╚══██╔══╝██╔════╝
#     ██║   ██║   ██║ ╚███╔╝ ██╔████╔██║███████║   ██║   █████╗
#     ██║   ██║   ██║ ██╔██╗ ██║╚██╔╝██║██╔══██║   ██║   ██╔══╝
#     ██║   ╚██████╔╝██╔╝ ██╗██║ ╚═╝ ██║██║  ██║   ██║   ███████╗
#     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝   ╚═╝   ╚══════╝
#
#  Linux App Installer
#  https://github.com/abusoww/tuxmate
#
#  Distribution: Arch Linux
#  Packages: 24
#  Generated: 2026-05-01
#
# ---------------------------------------------------------------------------

set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export LC_ALL=C
umask 077

# ---------------------------------------------------------------------------
#  Logging & Colors
# ---------------------------------------------------------------------------

LOG="/tmp/tuxmate-arch-$(date +%Y%m%d-%H%M%S).log"
# Save original stdout to FD 3
exec 3>&1
# Redirect script's stdout & stderr to the log file to keep TTY clean
exec > "$LOG" 2>&1

if [ -t 3 ]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m'
    BLUE='\033[0;34m' CYAN='\033[0;36m' BOLD='\033[1m' DIM='\033[2m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
fi

# Print visually to FD 3 (the user's terminal)
info()    { echo -e "${BLUE}::${NC} $1" >&3; echo ":: $1"; }
success() {
    if [ -n "${2:-}" ]; then
        echo -e "${GREEN}[+]${NC} $1 ${DIM}($2)${NC}" >&3
        echo "[+] $1 ($2)"
    else
        echo -e "${GREEN}[+]${NC} $1" >&3
        echo "[+] $1"
    fi
}
warn()    { echo -e "${YELLOW}[!]${NC} $1" >&3; echo "[!] $1"; }
error()   { echo -e "${RED}[x]${NC} $1" >&3; echo "[x] $1" >&2; }
skip()    {
    local reason="${2:-already installed}"
    echo -e "${DIM}[-]${NC} $1 ${DIM}($reason)${NC}" >&3
    echo "[-] $1 ($reason)"
}

trap 'printf "\n" >&3; warn "Cancelled by user"; print_summary; exit 130' INT

TOTAL=24
CURRENT=0
FAILED=()
SUCCEEDED=()
SKIPPED=()
START_TIME=$(date +%s)

animate_progress() {
    local name=$1 pid=$2
    local start=$(date +%s)
    local spinstr='|/-\'
    local spin_idx=0
    
    while kill -0 $pid 2>/dev/null; do
        local elapsed=$(($(date +%s) - start))
        local percent=$((CURRENT * 100 / TOTAL))
        local filled=$((percent / 5))
        local empty=$((20 - filled))
        
        local hash="####################"
        local dash="--------------------"
        local bar="${CYAN}${hash:0:filled}${NC}${dash:0:empty}"
        local spin_char="${spinstr:$spin_idx:1}"
        spin_idx=$(( (spin_idx + 1) % 4 ))
        
        printf "\r\033[K[%b] %3d%% (%d/%d) ${BOLD}%s${NC} [%c] %ds" "$bar" "$percent" "$CURRENT" "$TOTAL" "$name" "$spin_char" "$elapsed" >&3
        
        sleep 0.1
    done
    wait $pid
    return $?
}

with_retry() {
    local attempt=1 max=3 delay=5
    while [ $attempt -le $max ]; do
        echo "=== Executing (Attempt $attempt/$max): $* ==="
        if "$@"; then return 0; fi
        echo "=== Command failed ==="
        if [ $attempt -lt $max ]; then
            echo "Retrying in ${delay}s..."
            sleep $delay
            delay=$((delay * 2))
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

wait_for_lock() {
    local file=$1 timeout=60 elapsed=0
    while [ -f "$file" ] || fuser "$file" >/dev/null 2>&1; do
        if [ $elapsed -ge $timeout ]; then
            error "Lock timeout after ${timeout}s: $file"
            exit 1
        fi
        warn "Waiting for lock: $file"
        sleep 2
        elapsed=$((elapsed + 2))
    done
}

print_summary() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local mins=$((duration / 60))
    local secs=$((duration % 60))

    echo >&3
    echo "---------------------------------------------------------------------------" >&3
    local installed=${#SUCCEEDED[@]}
    local skipped_count=${#SKIPPED[@]}
    local failed_count=${#FAILED[@]}

    if [ $failed_count -eq 0 ]; then
        if [ $skipped_count -gt 0 ]; then
            echo -e "${GREEN}[+]${NC} Done: $installed installed, $skipped_count already present ${DIM}(${mins}m ${secs}s)${NC}" >&3
        else
            echo -e "${GREEN}[+]${NC} All $TOTAL packages installed ${DIM}(${mins}m ${secs}s)${NC}" >&3
        fi
    else
        echo -e "${YELLOW}[!]${NC} $installed installed, $skipped_count skipped, $failed_count failed ${DIM}(${mins}m ${secs}s)${NC}" >&3
        echo >&3
        echo -e "${RED}Failed:${NC}" >&3
        for pkg in "${FAILED[@]}"; do
            echo "  - $pkg" >&3
        done
    fi
    echo "---------------------------------------------------------------------------" >&3
    echo -e "${DIM}Log: $LOG${NC}" >&3
}


is_installed() { pacman -Qi "$1" &>/dev/null; }

install_pkg() {
    local name=$1 pkg=$2 cmd=$3
    CURRENT=$((CURRENT + 1))

    if is_installed "$pkg"; then
        skip "$name"
        SKIPPED+=("$name")
        return 0
    fi

    local start=$(date +%s)
    
    with_retry $cmd -S --needed --noconfirm "$pkg" &
    local pid=$!

    if animate_progress "$name" $pid; then
        local elapsed=$(($(date +%s) - start))
        printf "\r\033[K" >&3
        success "$name" "${elapsed}s"
        SUCCEEDED+=("$name")
    else
        printf "\r\033[K" >&3
        error "$name"
        FAILED+=("$name")
    fi
}

install_gem() {
    local name=$1 pkg=$2
    CURRENT=$((CURRENT + 1))
    
    gem install "$pkg"
}

# ---------------------------------------------------------------------------

[ "$EUID" -eq 0 ] && { error "Do not run as root."; exit 1; }

info "Caching sudo credentials..."
sudo -v || exit 1
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

wait_for_lock /var/lib/pacman/db.lck

info "Syncing package databases..."
with_retry sudo pacman -Sy --noconfirm &
if animate_progress "Syncing..." $!; then
    printf "\r\033[K" >&3
    success "Synced"
else
    printf "\r\033[K" >&3
    warn "Sync failed, continuing..."
fi


#if ! command -v yay &>/dev/null; then
#    warn "yay not found, installing for AUR packages..."
#    sudo pacman -S --needed --noconfirm git base-devel >/dev/null 2>&1
#    tmp=$(mktemp -d)
#    trap 'rm -rf "$tmp"' EXIT
#    git clone "https://aur.archlinux.org/yay.git" "$tmp/yay" >/dev/null 2>&1
#    (cd "$tmp/yay" && makepkg -si --noconfirm >/dev/null 2>&1)
#    command -v yay &>/dev/null && success "yay ready" || { error "Failed to install yay"; exit 1; }
#fi

echo >&3
info "Installing $TOTAL packages"
echo >&3

install_pkg "VS Code" "code" "sudo pacman"
#install_pkg "Ollama" "ollama" "sudo pacman"
#install_pkg "OpenCode" "opencode" "sudo pacman"
#install_pkg "Ollama ROCM" "ollama-rocm" "sudo pacman"
install_pkg "pnpm" "pnpm" "sudo pacman"
install_pkg "VLC" "vlc" "sudo pacman"
install_pkg "VLC FFMPEG Plugin" "vlc-plugin-ffmpeg" "sudo pacman"
install_pkg "Go" "go" "sudo pacman"
install_pkg "CMake" "cmake" "sudo pacman"
install_pkg "Godot Engine" "godot" "sudo pacman"
#install_pkg "Neovim" "neovim" "sudo pacman"
install_pkg "fastfetch" "fastfetch" "sudo pacman"
install_pkg "tldr" "tldr" "sudo pacman"
install_pkg "wget" "wget" "sudo pacman"
install_pkg "curl" "curl" "sudo pacman"
install_pkg "btop" "btop" "sudo pacman"
install_pkg "Obsidian" "obsidian" "sudo pacman"
install_pkg "Mission Center" "mission-center" "sudo pacman"
install_pkg "Alacritty" "alacritty" "sudo pacman"
#install_pkg "Emacs" "emacs" "sudo pacman"
install_pkg "qBittorrent" "qbittorrent" "sudo pacman"
install_pkg "Discord" "discord" "sudo pacman"
install_pkg "Quickshell" "quickshell" "sudo pacman"
install_pkg "Sway Background" "swaybg" "sudo pacman"
install_pkg "Sway Idle" "swayidle" "sudo pacman"
install_pkg "Sway Lock" "swaylock" "sudo pacman"
install_pkg "Nerd Font Symbols" "ttf-nerd-fonts-symbols" "sudo pacman"
install_pkg "Nerd Font Agave" "ttf-agave-nerd" "sudo pacman"
install_pkg "Nerd Font 3270" "ttf-3270-nerd" "sudo pacman"
install_pkg "Brightness CTL" "brightnessctl" "sudo pacman"
install_pkg "FFMPEG" "ffmpeg" "sudo pacman"
install_pkg "GST Good" "gst-plugins-good" "sudo pacman"
install_pkg "GST Bad" "gst-plugins-bad" "sudo pacman"
install_pkg "GST Ugly" "gst-plugins-ugly" "sudo pacman"
install_pkg "GST LibAV" "gst-libav" "sudo pacman"
install_pkg "Foliate" "foliate" "sudo pacman"
install_pkg "Blender" "blender" "sudo pacman"
install_pkg "Labwc" "labwc" "sudo pacman"
install_pkg "NPM" "npm" "sudo pacman"
install_pkg "GhosTTY" "ghostty" "sudo pacman"
install_pkg "Libre Office" "libreoffice-fresh" "sudo pacman"
install_pkg "Libresprite" "libresprite" "sudo pacman"
install_pkg "Kew" "kew" "sudo pacman"
install_pkg "Tiled" "tiled" "sudo pacman"
install_pkg "Cool Retro Term" "cool-retro-term" "sudo pacman"
install_pkg "Firefox" "firefox" "sudo pacman"
install_pkg "Make" "make" "sudo pacman"
install_pkg "ROCM SMI" "rocm-smi-lib" "sudo pacman"
install_pkg "Rhythmbox" "rhythmbox" "sudo pacman"
install_pkg "libgpos" "libgpod" "sudo pacman"

#if command -v yay &>/dev/null; then
#    install_pkg "Zen Browser" "zen-browser-bin" "yay"
#    install_pkg "LocalSend" "localsend-bin" "yay"
#    install_pkg "Aseprite" "aseprite" "yay"
#    install_pkg "NM TUI" "nmtui-go" "yay"
#fi

#if is_installed "labwc"; then
#    if is_installed "aseprite"; then
#        sudo sed -i 's/Exec=aseprite %F/Exec=labwc -s aseprite %F/' /usr/share/applications/aseprite.desktop 
#        success "Updated Aseprite desktop entry for Labwc"
#        error "Failed to update Aseprite desktop entry for Labwc"
#    else
#        warn "Aseprite not installed, skipping Labwc desktop entry update"
#    fi
#fi

# Install Zen
curl -fsSL https://github.com/zen-browser/updates-server/raw/refs/heads/main/install.sh | $SHELL
sudo ln -s ~/.tarball-installations/zen/zen /usr/bin/zen

# Install Claude
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
export ANTHROPIC_BASE_URL="http://localhost:8080"
export ANTHROPIC_API_KEY="sk-no-key-required"
export ANTHROPIC_AUTH_TOKEN="llama"
# also need to copy the json


# Install Llama CPP
curl -LsSf https://llama.app/install.sh | sh

# Install aseprite
sudo pacman -S gcc clang cmake ninja libx11 libxcursor libxi libxrandr mesa-libgl fontconfig libwebp unzip
cd ~/
mkdir GithubProjects
cd GithubProjects
git clone --recursive https://github.com/aseprite/aseprite.git
cd aseprite
git pull
git submodule update --init --recursive
./build.sh
ln -s ~/GithubProjects/aseprite/build/bin/aseprite ~/.local/bin/aseprite
cd ~/dots
cp desktop-entries/aseprite.desktop ~/.local/share/applications

# Hermes Agent
#curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

print_summary

echo "programs installed please run link-dots.sh to update dot files"
