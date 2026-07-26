#!/usr/bin/env bash
# ============================================================================
# 리눅스(Ubuntu/Debian) 전체 셋업 (idempotent) — 셸 + neovim + 런타임 + 컨테이너
# 부분 셋업만 원하면: setup-shell.sh (셸만) / setup-nvim.sh (에디터만)
# 공용 머신에서 sudo가 없으면: SKIP_PACKAGES=1 로 부분 스크립트 사용 권장
#
# 사용법: git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-linux.sh
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. 기반 패키지 + 언어 런타임
sudo apt-get update
sudo apt-get install -y \
    zsh git curl build-essential \
    golang-go \
    python3 python3-pip python3-venv python-is-python3
# python-is-python3: python -> python3 심링크 (mac의 심링크와 동일 역할)

# docker + compose (v2 플러그인, 배포판에 따라 패키지명이 다름)
sudo apt-get install -y docker.io
sudo apt-get install -y docker-compose-v2 || sudo apt-get install -y docker-compose-plugin || sudo apt-get install -y docker-compose
sudo usermod -aG docker "$USER" || true

# 2. 셸 환경 (CLI 툴 설치 포함) + neovim 환경 (에디터 패키지 설치 포함)
"$DOTFILES_DIR/setup-shell.sh"
"$DOTFILES_DIR/setup-nvim.sh"

# 3. nvm + node LTS (apt node는 구버전이라 nvm 경유)
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | PROFILE=/dev/null bash
fi
bash -c 'source "$HOME/.nvm/nvm.sh" && nvm install --lts' || true

echo ""
echo "완료! 새 터미널을 열면 적용됩니다. (docker 그룹 반영은 재로그인 필요)"
echo "기본 셸을 zsh로 바꾸려면: chsh -s \$(which zsh)"
