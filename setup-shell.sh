#!/usr/bin/env bash
# ============================================================================
# 셸 작업환경만 셋업 — zsh + oh-my-zsh + pure + CLI 툴 + 셸 dotfiles 배포
# (neovim은 건드리지 않음. 공용 머신에서 내 셸 환경만 얹을 때 사용)
#
# 사용법:
#   ./setup-shell.sh                  # 패키지 설치 포함 (mac: brew, linux: apt+sudo)
#   SKIP_PACKAGES=1 ./setup-shell.sh  # sudo 없는 공용 머신: dotfiles/플러그인만 배포
#     (zsh 플러그인은 저장소에 번들되어 있고, zshrc가 모든 툴을 존재할 때만
#      로드하므로 패키지 없이도 셸이 깨지지 않는다)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# --- 1. 패키지 (셸 관련만) ---
if [ -z "${SKIP_PACKAGES:-}" ]; then
    SHELL_TOOLS_COMMON=(
        fzf fzy autojump zoxide atuin
        htop btop ncdu duf glances
        tree eza bat jq yq hexyl
        tmux lazygit direnv entr hyperfine tldr shellcheck thefuck
        httpie mtr gh navi broot yazi
        lazydocker dive k9s
    )
    if [ "$OS" = "mac" ]; then
        brew install chezmoi fd ripgrep git-delta watch mactop asitop "${SHELL_TOOLS_COMMON[@]}" || true
    else
        sudo apt-get update
        for pkg in zsh git curl fd-find ripgrep git-delta "${SHELL_TOOLS_COMMON[@]}"; do
            sudo apt-get install -y "$pkg" || echo "skip: $pkg (이 배포판 apt에 없음)"
        done
        command -v atuin >/dev/null 2>&1 || sudo apt-get install -y atuin \
            || curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
        # Debian/Ubuntu 실행파일명 차이 -> 표준 이름으로 심링크
        mkdir -p "$HOME/.local/bin"
        command -v batcat >/dev/null 2>&1 && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
        command -v fdfind >/dev/null 2>&1 && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    fi
fi

# --- 2. chezmoi (패키지 매니저에 없거나 SKIP_PACKAGES면 유저 로컬에 설치) ---
if ! command -v chezmoi >/dev/null 2>&1; then
    sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# --- 3. oh-my-zsh + pure prompt (sudo 불필요) ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi
[ -d "$HOME/.zsh/pure" ] || git clone --depth=1 https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure"

# broot 런처 생성 (chezmoi apply 전에 — rc 파일 수정분이 apply로 정리되도록)
command -v broot >/dev/null 2>&1 && broot --install >/dev/null 2>&1 || true

# --- 4. 셸 dotfiles만 배포 ---
mkdir -p "$HOME/.config/chezmoi"
[ -f "$HOME/.config/chezmoi/chezmoi.toml" ] || printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
chezmoi apply "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.oh-my-zsh"

echo ""
echo "셸 환경 셋업 완료. 새 터미널을 열거나: exec zsh"
echo "기본 셸 변경(공용 머신은 보통 불가): chsh -s \$(which zsh)"
