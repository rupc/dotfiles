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
# 이미 docker가 있으면 손대지 않는다 — 공식 저장소판(docker-ce + containerd.io)이 깔린
# 머신에 apt의 docker.io를 얹으면 containerd 충돌로 apt가 거부하고 스크립트가 죽는다.
if command -v docker >/dev/null 2>&1; then
    echo "skip: docker (이미 설치됨 — $(docker --version 2>/dev/null))"
else
    sudo apt-get install -y docker.io
fi
if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
    echo "skip: docker compose (이미 설치됨)"
else
    sudo apt-get install -y docker-compose-v2 \
        || sudo apt-get install -y docker-compose-plugin \
        || sudo apt-get install -y docker-compose \
        || echo "skip: docker compose (이 배포판 apt에 없음)"
fi
sudo usermod -aG docker "$USER" || true

# 2. 셸 환경 (CLI 툴 설치 포함) + neovim 환경 (에디터 패키지 설치 포함)
"$DOTFILES_DIR/setup-shell.sh"
"$DOTFILES_DIR/setup-nvim.sh"

# 3. nvm + node LTS (apt node는 구버전이라 nvm 경유)
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | PROFILE=/dev/null bash
fi
bash -c 'source "$HOME/.nvm/nvm.sh" && nvm install --lts' || true

# 4. 로그인 MOTD 광고 제거 — 유용한 것(시스템 정보/업데이트 개수/재부팅 필요)은 남기고
#    구독 권유·뉴스 배너만 끈다. sudo가 필요해서 setup-shell.sh가 아니라 여기에 둔다.
#      50-motd-news              : motd.ubuntu.com에서 받아오는 뉴스/홍보 배너
#      88-esm-announce           : "Expanded Security Maintenance" 안내
#      91-contract-ua-esm-status : Ubuntu Pro 구독 상태/권유 (22.04)
#      91-contract-ubuntu-advantage : 같은 것의 구버전 이름
for f in 50-motd-news 88-esm-announce 91-contract-ua-esm-status 91-contract-ubuntu-advantage; do
    if [ -x "/etc/update-motd.d/$f" ]; then
        sudo chmod -x "/etc/update-motd.d/$f" && echo "motd 광고 끔: $f"
    fi
done
# 위 스크립트를 지워도 캐시된 뉴스가 남을 수 있어 설정 자체도 끈다
if [ -f /etc/default/motd-news ]; then
    sudo sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news || true
fi
# apt 실행 때마다 끼어드는 Pro 광고("Get more security updates...")는 별도 스위치
if command -v pro >/dev/null 2>&1; then
    sudo pro config set apt_news=false >/dev/null 2>&1 || true
fi

echo ""
echo "완료! 새 터미널을 열면 적용됩니다. (docker 그룹 반영은 재로그인 필요)"
echo "기본 셸을 zsh로 바꾸려면: chsh -s \$(which zsh)"
