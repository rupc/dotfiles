#!/usr/bin/env bash
# ============================================================================
# 새 맥북 전체 셋업 (idempotent) — 셸 + neovim + 언어 런타임 + 컨테이너까지
# 부분 셋업만 원하면: setup-shell.sh (셸만) / setup-nvim.sh (에디터만)
#
# 사용법: git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-macos.sh
# ============================================================================
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

# 2. 전체 패키지 (Brewfile) — 컴포넌트 스크립트에는 SKIP_PACKAGES로 중복 설치 방지
#    mac 전용 툴(mactop/asitop/thefuck)도 여기서만 설치된다.
#    공용 스크립트(setup-shell.sh/setup-nvim.sh)에는 mac/linux 양쪽 툴만 둘 것.
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 3. 셸 환경 + neovim 환경 (컴포넌트 스크립트 재사용)
SKIP_PACKAGES=1 "$DOTFILES_DIR/setup-shell.sh"
SKIP_PACKAGES=1 "$DOTFILES_DIR/setup-nvim.sh"

# 4. mac 전용 마무리
BREW_BIN="$(brew --prefix)/bin"

# python/pip 심링크 (brew는 python3/pip3만 제공)
[ -e "$BREW_BIN/python" ] || ln -s "$BREW_BIN/python3" "$BREW_BIN/python"
[ -e "$BREW_BIN/pip" ] || ln -s "$BREW_BIN/pip3" "$BREW_BIN/pip"

# nvm 작업 디렉토리 + docker compose CLI 플러그인 연결
mkdir -p "$HOME/.nvm"
mkdir -p "$HOME/.docker/cli-plugins"
ln -sf "$BREW_BIN/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"

# Tailscale: DMG로 설치한 앱의 내장 CLI를 PATH에 노출
# (심링크는 번들 식별 검사에 걸려서 안 됨 — 원본 경로로 exec하는 래퍼 사용.
#  brew tailscale을 설치하면 데몬이 중복되므로 앱 설치와 병행 금지)
TS_APP_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS_APP_CLI" ] && [ ! -e "$BREW_BIN/tailscale" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$TS_APP_CLI" > "$BREW_BIN/tailscale"
    chmod +x "$BREW_BIN/tailscale"
fi

echo ""
echo "완료! 새 터미널을 열면 적용됩니다."
echo "docker를 쓰려면: colima start   (로그인 시 자동 시작: brew services start colima)"
