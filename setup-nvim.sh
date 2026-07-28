#!/usr/bin/env bash
# ============================================================================
# neovim 환경만 셋업 — nvim + vimrc + 플러그인 + 내장 LSP + 노트북(ipynb) 지원
# (셸 설정은 건드리지 않음. 공용 머신에서 내 에디터만 얹을 때 사용)
#
# LSP는 nvim 내장(0.11+)을 쓴다 — coc.nvim 제거(2026-07), Node 의존성 없음.
# linux에서 nvim은 apt가 아니라 공식 릴리즈 바이너리를 ~/.local에 설치한다.
# (apt nvim은 0.6~0.7대 — nvim_create_augroup 등 lua API가 없어서
#  toggleterm/coc/테마가 전부 startup 에러를 뿜던 사고의 재발 방지)
#
# 사용법:
#   ./setup-nvim.sh                  # 패키지 설치 포함 (mac: brew, linux: apt+sudo)
#   SKIP_PACKAGES=1 ./setup-nvim.sh  # sudo 없는 공용 머신 (nvim은 sudo 없이 ~/.local에 설치됨)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_MIN="0.11.0"   # vim.lsp.config/enable + lua 플러그인들의 최소 요구 버전

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# --- 0. nvim 확보 (버전 검사 포함) ---
# ~/.local/bin/nvim이 있으면 시스템 nvim보다 우선 (공용 머신의 낡은 /usr/bin/nvim 회피)
nvim_bin() {
    if [ -x "$HOME/.local/bin/nvim" ]; then
        echo "$HOME/.local/bin/nvim"
    else
        command -v nvim || true
    fi
}
nvim_ok() {
    local bin ver
    bin=$(nvim_bin); [ -n "$bin" ] || return 1
    ver=$("$bin" --version 2>/dev/null | head -1 | sed 's/^NVIM v//') || return 1
    [ -n "$ver" ] || return 1
    [ "$(printf '%s\n' "$NVIM_MIN" "$ver" | sort -V | head -1)" = "$NVIM_MIN" ]
}

if ! nvim_ok; then
    if [ "$OS" = "mac" ]; then
        brew install neovim || brew upgrade neovim || true
    else
        # 공식 릴리즈 tarball → ~/.local (sudo 불필요, SKIP_PACKAGES와 무관하게 실행).
        # 공식 빌드는 최신 glibc 기준이라 구형 배포판에서 실행이 안 될 수 있는데,
        # 그 경우 같은 파일명을 제공하는 neovim-releases(구 glibc용 빌드)로 폴백.
        ARCH=$([ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64")
        TARBALL="nvim-linux-${ARCH}.tar.gz"
        NVIM_TMP=$(mktemp -d)
        mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
        for REPO in neovim/neovim neovim/neovim-releases; do
            curl -fsSL "https://github.com/${REPO}/releases/download/stable/${TARBALL}" \
                -o "$NVIM_TMP/$TARBALL" || continue
            rm -rf "$HOME/.local/opt/nvim-linux-${ARCH}"
            tar xzf "$NVIM_TMP/$TARBALL" -C "$HOME/.local/opt"
            ln -sf "$HOME/.local/opt/nvim-linux-${ARCH}/bin/nvim" "$HOME/.local/bin/nvim"
            "$HOME/.local/bin/nvim" --version >/dev/null 2>&1 && break   # glibc 호환 확인
        done
        rm -rf "$NVIM_TMP"
    fi
fi

# 버전 미달이면 여기서 즉시 실패 — 구버전 위에 플러그인만 깔린 어중간한 상태를 만들지 않는다
if ! nvim_ok; then
    echo "에러: nvim ${NVIM_MIN}+ 확보 실패 (현재: $(nvim_bin || echo 없음))." >&2
    echo "      nvim --version 확인 후 다시 실행하라." >&2
    exit 1
fi
NVIM=$(nvim_bin)
echo "nvim: $("$NVIM" --version | head -1) — $NVIM"

# --- 1. 에디터 보조 패키지 (ripgrep=:Rg, imagemagick=그래프 인라인 렌더링) ---
if [ -z "${SKIP_PACKAGES:-}" ]; then
    if [ "$OS" = "mac" ]; then
        brew install chezmoi ripgrep imagemagick || true
        brew install --cask kitty || true   # 그래프 인라인 렌더링용 터미널
    else
        sudo apt-get update
        for pkg in ripgrep imagemagick kitty; do
            sudo apt-get install -y "$pkg" || echo "skip: $pkg"
        done
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

# --- 5. 전용 venv — 노트북(pynvim/jupyter/jupytext) + python LSP(basedpyright) ---
# basedpyright는 pip 패키지 하나로 language server까지 들어와서 node가 필요 없다
NVIM_VENV="$HOME/.venvs/nvim"
if command -v python3 >/dev/null 2>&1 && [ ! -x "$NVIM_VENV/bin/python" ]; then
    python3 -m venv "$NVIM_VENV" \
        && "$NVIM_VENV/bin/pip" install --quiet --upgrade pip \
        && "$NVIM_VENV/bin/pip" install --quiet pynvim jupyter_client ipykernel jupytext basedpyright \
        && "$NVIM_VENV/bin/python" -m ipykernel install --user --name nvim-python >/dev/null \
        || echo "경고: 노트북용 venv 구성 실패 (molten 제외하고 계속)"
fi
# 기존 venv 마이그레이션: basedpyright만 없으면 추가
if [ -x "$NVIM_VENV/bin/pip" ] && [ ! -x "$NVIM_VENV/bin/basedpyright-langserver" ]; then
    "$NVIM_VENV/bin/pip" install --quiet basedpyright || echo "경고: basedpyright 설치 실패 (python LSP 제외하고 계속)"
fi

# --- 6. 플러그인 설치/정리 + molten 원격플러그인 등록 ---
# PlugClean!: vimrc에서 제거된 플러그인(coc.nvim 등) 디렉토리 정리
"$NVIM" --headless "+PlugInstall --sync" "+PlugClean!" "+qall" || true
"$NVIM" --headless "+UpdateRemotePlugins" "+qall" || true

# --- 7. gopls (go가 있으면 — vim-go가 사용) ---
if command -v go >/dev/null 2>&1 && ! command -v gopls >/dev/null 2>&1; then
    go install golang.org/x/tools/gopls@latest || true
fi

echo ""
echo "neovim 환경 셋업 완료. LSP는 nvim 내장(0.11+) — 서버 실행파일이 있으면 자동 연결:"
echo "  python=basedpyright(venv 포함) / rust=rust-analyzer / c,cpp=clangd / go=gopls(vim-go)"
echo "노트북: kitty 터미널에서 nvim으로 .ipynb 열기 -> ,mi (MoltenInit) -> Ctrl+Enter로 셀 실행"
