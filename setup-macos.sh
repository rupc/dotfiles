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

# 3. 셸 환경 + neovim 환경 + Claude Code (컴포넌트 스크립트 재사용)
SKIP_PACKAGES=1 "$DOTFILES_DIR/setup-shell.sh"
SKIP_PACKAGES=1 "$DOTFILES_DIR/setup-nvim.sh"
# claude CLI는 brew가 아니라 공식 네이티브 설치라 SKIP_PACKAGES를 안 넘긴다
# --global: 내 머신이라 ~/.claude 에 (기본값인 로컬 모드는 공용 서버용)
"$DOTFILES_DIR/setup-claude.sh" --global

# 4. mac 전용 마무리
BREW_BIN="$(brew --prefix)/bin"

# python/pip 심링크 (brew는 python3/pip3만 제공)
[ -e "$BREW_BIN/python" ] || ln -s "$BREW_BIN/python3" "$BREW_BIN/python"
[ -e "$BREW_BIN/pip" ] || ln -s "$BREW_BIN/pip3" "$BREW_BIN/pip"

# nvm 작업 디렉토리 + docker compose CLI 플러그인 연결
mkdir -p "$HOME/.nvm"
mkdir -p "$HOME/.docker/cli-plugins"
ln -sf "$BREW_BIN/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"

# Dock 아이콘 튀기기(주의 끌기 바운스) 끄기
# Slack/메일 등이 알림을 띄울 때 독 아이콘이 계속 위아래로 튀는 동작이다.
# 알림 자체는 그대로 오고(배지·배너·알림센터) 튀는 애니메이션만 사라진다.
# 되돌리려면: defaults delete com.apple.dock no-bouncing && killall Dock
# 앱 실행 시 한 번 튀는 것까지 없애려면 launchanim 도 false 로 (실행 피드백이 사라진다)
if [ "$(defaults read com.apple.dock no-bouncing 2>/dev/null)" != "1" ]; then
    defaults write com.apple.dock no-bouncing -bool true
    killall Dock 2>/dev/null || true
fi

# 논문용 폰트 Linux Libertine O / Linux Biolinum O (ACM acmart 본문·제목 폰트)
# TeX Live에 OTF가 들어 있지만 TeX 트리 안에만 있어서 Keynote·Word·matplotlib 같은 앱과
# XeLaTeX의 이름 검색(\setmainfont{Linux Libertine O})에서는 안 보인다 → 사용자 폰트로 복사.
# brew cask(font-linux-libertine)는 Libertine TTF뿐이고 패밀리 이름도 달라서("O" 없음) 쓰지 않는다.
# 심링크가 아니라 복사인 이유: Cellar 경로는 texlive 버전이 바뀌면 사라진다.
LIBERTINE_OTF="$("$BREW_BIN/kpsewhich" LinLibertine_R.otf 2>/dev/null || true)"
if [ -n "$LIBERTINE_OTF" ] && [ ! -e "$HOME/Library/Fonts/LinLibertine_R.otf" ]; then
    mkdir -p "$HOME/Library/Fonts"
    cp -n "$(dirname "$LIBERTINE_OTF")"/Lin{Libertine,Biolinum}_*.otf "$HOME/Library/Fonts/"
fi

# Tailscale: DMG로 설치한 앱의 내장 CLI를 PATH에 노출
# (심링크는 번들 식별 검사에 걸려서 안 됨 — 원본 경로로 exec하는 래퍼 사용.
#  brew tailscale을 설치하면 데몬이 중복되므로 앱 설치와 병행 금지)
TS_APP_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS_APP_CLI" ] && [ ! -e "$BREW_BIN/tailscale" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$TS_APP_CLI" > "$BREW_BIN/tailscale"
    chmod +x "$BREW_BIN/tailscale"
fi

# 한/영 전환 — 오른쪽 Command(외장 Varmilo는 오른쪽 Alt·한/영 키)
# 세 층이고, 위층이 없으면 아래층이 받는다:
#   1) Karabiner [hanyeong] 규칙: F18을 *누르는 순간* select_input_source로 직접 전환한다.
#      macOS 단축키는 키를 *뗄 때* 전환돼서, 한/영을 떼기 전에 다음 글자를 치면 그 글자가
#      이전 언어로 들어간다 ("가끔 한/영이 씹힘" — 2026-11 실측, 실사용 94회 중 29%).
#      Shift가 눌린 채여도 전환된다 (단축키는 수정키가 정확히 없어야만 걸린다).
#   2) LaunchAgent(hidutil): Karabiner 없이도 오른쪽 Command = F18. 로그인마다 다시 건다.
#      이 매핑은 Karabiner 가상 키보드에도 걸린다 — Karabiner 규칙에서 right_command 금지.
#   3) 시스템 단축키 60(이전 입력 소스 선택) = F18 — 1)이 없을 때 2)를 받아 전환한다.
# Karabiner GUI에서 설정을 바꿨으면 먼저 되담을 것 (안 그러면 여기서 repo 내용으로 덮인다):
#   chezmoi re-add ~/.config/karabiner/karabiner.json
KEYMAP_PLIST="$HOME/Library/LaunchAgents/local.keymap.right-command-f18.plist"
chezmoi apply --force --source "$DOTFILES_DIR" "$HOME/.config/karabiner" "$KEYMAP_PLIST"
# 다시 로드해서 지금 바로 건다. 끄려면:
#   launchctl bootout gui/$(id -u) "$KEYMAP_PLIST" && hidutil property --set '{"UserKeyMapping":[]}'
launchctl bootout "gui/$(id -u)" "$KEYMAP_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$KEYMAP_PLIST" 2>/dev/null \
    || echo "경고: 한/영 LaunchAgent 로드 실패 — 다시 로그인하면 걸린다"
# 단축키 60 = F18(키코드 79), 수정키 없음. activateSettings가 로그아웃 없이 반영한다.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>0</integer></array><key>type</key><string>standard</string></dict></dict>'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

echo ""
echo "완료! 새 터미널을 열면 적용됩니다."
echo "docker를 쓰려면: colima start   (로그인 시 자동 시작: brew services start colima)"
