#!/usr/bin/env bash
# 새 맥북 부트스트랩 스크립트 — 이 저장소 기준으로 전체 환경 재현 (idempotent)
# 사용법: git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-macos.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Homebrew
if ! command -v brew >/dev/null 2>&1; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 2. 패키지 설치
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 3. oh-my-zsh / pure prompt / vim 플러그인 매니저
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d "$HOME/.zsh/pure" ] || git clone --depth=1 https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
[ -d "$HOME/.vim/bundle/Vundle.vim" ] || git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
[ -f "$HOME/.vim/autoload/plug.vim" ] || curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# broot: br 런처 파일 생성 (rc 파일에 추가된 source 줄은 이후 chezmoi apply가 정리함)
command -v broot >/dev/null 2>&1 && broot --install >/dev/null 2>&1 || true

# 4. dotfiles 배포 (chezmoi: 이 디렉토리를 source로 사용)
mkdir -p "$HOME/.config/chezmoi"
[ -f "$HOME/.config/chezmoi/chezmoi.toml" ] || printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
chezmoi apply

# 5. vim/nvim 플러그인 설치 (Vundle + vim-plug 둘 다 사용 중)
nvim --headless "+PluginInstall" "+qall" || true
nvim --headless "+PlugInstall --sync" "+qall" || true

# 6. python/pip 심링크 (brew는 python3/pip3만 제공)
BREW_BIN="$(brew --prefix)/bin"
[ -e "$BREW_BIN/python" ] || ln -s "$BREW_BIN/python3" "$BREW_BIN/python"
[ -e "$BREW_BIN/pip" ] || ln -s "$BREW_BIN/pip3" "$BREW_BIN/pip"

# Tailscale: DMG로 설치한 앱의 내장 CLI를 PATH에 노출
# (심링크는 번들 식별 검사에 걸려서 안 됨 — 원본 경로로 exec하는 래퍼 사용.
#  brew tailscale을 설치하면 데몬이 중복되므로 앱 설치와 병행 금지)
TS_APP_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS_APP_CLI" ] && [ ! -e "$BREW_BIN/tailscale" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$TS_APP_CLI" > "$BREW_BIN/tailscale"
    chmod +x "$BREW_BIN/tailscale"
fi

# 7. nvm 작업 디렉토리 + docker compose CLI 플러그인 연결
mkdir -p "$HOME/.nvm"
mkdir -p "$HOME/.docker/cli-plugins"
ln -sf "$BREW_BIN/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"

echo ""
echo "완료! 새 터미널을 열면 적용됩니다."
echo "docker를 쓰려면: colima start   (로그인 시 자동 시작: brew services start colima)"
