#!/usr/bin/env bash
# 리눅스(Ubuntu/Debian) 부트스트랩 스크립트 — 이 저장소 기준으로 전체 환경 재현 (idempotent)
# 사용법: git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-linux.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. apt 패키지 (Brewfile의 리눅스 대응)
sudo apt-get update
sudo apt-get install -y \
    zsh git curl build-essential \
    neovim fzf fzy autojump \
    golang-go \
    python3 python3-pip python3-venv python-is-python3
# python-is-python3: python -> python3 심링크 (mac의 심링크와 동일 역할)

# docker + compose (v2 플러그인, 배포판에 따라 패키지명이 다름)
sudo apt-get install -y docker.io
sudo apt-get install -y docker-compose-v2 || sudo apt-get install -y docker-compose-plugin || sudo apt-get install -y docker-compose
sudo usermod -aG docker "$USER" || true

# 2. chezmoi (apt에 없으므로 공식 설치 스크립트 사용)
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# 3. nvm (공식 설치 스크립트; node는 nvm으로 관리)
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | PROFILE=/dev/null bash
fi

# 4. oh-my-zsh / pure prompt / vim 플러그인 매니저 (mac과 동일)
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d "$HOME/.zsh/pure" ] || git clone --depth=1 https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"
[ -d "$HOME/.vim/bundle/Vundle.vim" ] || git clone --depth=1 https://github.com/VundleVim/Vundle.vim.git "$HOME/.vim/bundle/Vundle.vim"
[ -f "$HOME/.vim/autoload/plug.vim" ] || curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# 5. dotfiles 배포 (chezmoi: 이 디렉토리를 source로 사용)
mkdir -p "$HOME/.config/chezmoi"
[ -f "$HOME/.config/chezmoi/chezmoi.toml" ] || printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
chezmoi apply

# 6. vim/nvim 플러그인 설치 (Vundle + vim-plug 둘 다 사용 중)
nvim --headless "+PluginInstall" "+qall" || true
nvim --headless "+PlugInstall --sync" "+qall" || true

# 7. node LTS 설치 (nvm)
bash -c 'source "$HOME/.nvm/nvm.sh" && nvm install --lts' || true

echo ""
echo "완료! 새 터미널을 열면 적용됩니다. (docker 그룹 반영은 재로그인 필요)"
echo "기본 셸을 zsh로 바꾸려면: chsh -s \$(which zsh)"
