#!/usr/bin/env bash
# ============================================================================
# neovim 환경만 셋업 — nvim + vimrc + 플러그인 + coc LSP + 노트북(ipynb) 지원
# (셸 설정은 건드리지 않음. 공용 머신에서 내 에디터만 얹을 때 사용)
#
# 사용법:
#   ./setup-nvim.sh                  # 패키지 설치 포함 (mac: brew, linux: apt+sudo)
#   SKIP_PACKAGES=1 ./setup-nvim.sh  # sudo 없는 공용 머신: nvim/node가 이미 있어야 함
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# --- 1. 패키지 (에디터 관련만; node는 coc.nvim 필수, ripgrep은 :Rg) ---
if [ -z "${SKIP_PACKAGES:-}" ]; then
    if [ "$OS" = "mac" ]; then
        brew install chezmoi neovim node ripgrep imagemagick || true
        brew install --cask kitty || true   # 그래프 인라인 렌더링용 터미널
    else
        sudo apt-get update
        for pkg in neovim nodejs npm ripgrep imagemagick kitty; do
            sudo apt-get install -y "$pkg" || echo "skip: $pkg"
        done
    fi
fi

# coc.nvim은 Node 20+ 필요 (18은 전역 crypto 없음) — 구버전이면 경고
if command -v node >/dev/null 2>&1; then
    NODE_MAJOR=$(node --version | sed 's/^v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -lt 20 ]; then
        echo "경고: node $(node --version) — coc.nvim은 Node 20+ 필요. nvm/NodeSource로 업그레이드 권장"
    fi
fi

# --- 2. chezmoi ---
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# --- 3. vim-plug ---
[ -f "$HOME/.vim/autoload/plug.vim" ] || curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# --- 4. vim/nvim dotfiles만 배포 ---
mkdir -p "$HOME/.config/chezmoi"
[ -f "$HOME/.config/chezmoi/chezmoi.toml" ] || printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
chezmoi apply "$HOME/.vimrc" "$HOME/.config/nvim"

# --- 5. 노트북(ipynb) 지원: 전용 venv (pynvim/jupyter/jupytext) ---
NVIM_VENV="$HOME/.venvs/nvim"
if command -v python3 >/dev/null 2>&1 && [ ! -x "$NVIM_VENV/bin/python" ]; then
    python3 -m venv "$NVIM_VENV" \
        && "$NVIM_VENV/bin/pip" install --quiet --upgrade pip \
        && "$NVIM_VENV/bin/pip" install --quiet pynvim jupyter_client ipykernel jupytext \
        && "$NVIM_VENV/bin/python" -m ipykernel install --user --name nvim-python >/dev/null \
        || echo "경고: 노트북용 venv 구성 실패 (molten 제외하고 계속)"
fi

# --- 6. 플러그인 설치 + molten 원격플러그인 등록 (coc 확장은 첫 실행 때 자동) ---
nvim --headless "+PlugInstall --sync" "+qall" || true
nvim --headless "+UpdateRemotePlugins" "+qall" || true

# --- 7. gopls (go가 있으면 — coc의 go languageserver가 사용) ---
if command -v go >/dev/null 2>&1 && ! command -v gopls >/dev/null 2>&1; then
    go install golang.org/x/tools/gopls@latest || true
fi

echo ""
echo "neovim 환경 셋업 완료. nvim 첫 실행 때 coc 확장들이 자동 설치된다."
echo "노트북: kitty 터미널에서 nvim으로 .ipynb 열기 -> ,mi (MoltenInit) -> Ctrl+Enter로 셀 실행"
