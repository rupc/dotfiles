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

# --- macOS 설정 (옛 맥에서 쓰던 값, 2026-11) ---
# 값이 다를 때만 쓰고, 바뀐 게 있을 때만 Dock/Finder를 재시작한다 (재실행해도 깜빡임 없음).
CHANGED=""
set_default() {  # 도메인 키 타입 값 — 예: set_default com.apple.dock autohide -bool true
    local want="$4"
    if [ "$3" = "-bool" ]; then if [ "$4" = true ]; then want=1; else want=0; fi; fi
    [ "$(defaults read "$1" "$2" 2>/dev/null)" = "$want" ] && return 0
    defaults write "$1" "$2" "$3" "$4"
    CHANGED="$CHANGED $1"
}
# Dock 아이콘 튀기기(주의 끌기 바운스) 끄기
# Slack/메일 등이 알림을 띄울 때 독 아이콘이 계속 위아래로 튀는 동작이다.
# 알림 자체는 그대로 오고(배지·배너·알림센터) 튀는 애니메이션만 사라진다.
# 되돌리려면: defaults delete com.apple.dock no-bouncing && killall Dock
# 앱 실행 시 한 번 튀는 것까지 없애려면 launchanim 도 false 로 (실행 피드백이 사라진다)
set_default com.apple.dock no-bouncing -bool true
# Dock 자동 숨김, 아이콘 70. 확대는 켜져 있지만 확대 크기(43)가 아이콘보다 작아 사실상 효과 없음.
set_default com.apple.dock autohide -bool true
set_default com.apple.dock tilesize -int 70
set_default com.apple.dock magnification -bool true
set_default com.apple.dock largesize -int 43
# Finder: 경로 막대·상태 막대, 기본 목록 보기
set_default com.apple.finder ShowPathbar -bool true
set_default com.apple.finder ShowStatusBar -bool true
set_default com.apple.finder FXPreferredViewStyle -string Nlsv
case "$CHANGED" in *com.apple.dock*) killall Dock 2>/dev/null || true ;; esac
case "$CHANGED" in *com.apple.finder*) killall Finder 2>/dev/null || true ;; esac
# 트랙패드 탭하여 클릭·이동 속도 3, 마우스 이동 속도 3, 자연스러운 스크롤 끔(트랙패드·마우스 공통),
# 다크 모드 — 다시 로그인해야 전부 반영된다.
# 세·네 손가락 쓸기, 꼬집기, 클릭 세기는 옛 맥도 macOS 기본값이라 따로 쓰지 않는다.
set_default com.apple.AppleMultitouchTrackpad Clicking -bool true
set_default com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1
set_default -g com.apple.trackpad.scaling -float 3
set_default -g com.apple.mouse.scaling -float 3
set_default -g com.apple.swipescrolldirection -bool false
set_default -g AppleInterfaceStyle -string Dark
# Rectangle(창 배치): 옛 맥 설정 — 처음 한 번만. 이미 설정이 있으면 건드리지 않는다.
if ! defaults read com.knollsoft.Rectangle >/dev/null 2>&1; then
    R=com.knollsoft.Rectangle
    defaults write $R alternateDefaultShortcuts -bool true
    defaults write $R subsequentExecutionMode -int 1
    defaults write $R gapSize -float 1
    defaults write $R doubleClickTitleBar -int 0
    defaults write $R allowAnyShortcut -bool true
    defaults write $R launchOnLogin -bool true
    defaults write $R landscapeSnapAreas -string \
        '[7,{"compound":-4},5,{"compound":-3},8,{"action":14},3,{"action":16},1,{"action":15},2,{"action":2},4,{"compound":-2},6,{"action":13}]'
    defaults write $R toggleTodo -dict keyCode -int 11 modifierFlags -int 786432   # ⌃⌥B
    defaults write $R reflowTodo -dict keyCode -int 45 modifierFlags -int 786432   # ⌃⌥N
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

# HWP 문서 → 텍스트/HTML (hwp5txt 등). pyhwp가 six 의존성을 빠뜨려서 --with six가 필요하다.
# pipx 대신 uv: pipx는 python@3.15를 끌고 와서 python3가 Brewfile의 3.14가 아니게 된다.
command -v hwp5txt >/dev/null 2>&1 || uv tool install pyhwp --with six \
    || echo "경고: pyhwp 설치 실패 — 나중에: uv tool install pyhwp --with six"

# Tailscale: 앱(App Store판·DMG판 둘 다 같은 경로)의 내장 CLI를 PATH에 노출
# (심링크는 번들 식별 검사에 걸려서 안 됨 — 원본 경로로 exec하는 래퍼 사용.
#  brew tailscale을 설치하면 데몬이 중복되므로 앱 설치와 병행 금지)
TS_APP_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS_APP_CLI" ] && [ ! -e "$BREW_BIN/tailscale" ]; then
    printf '#!/bin/sh\nexec "%s" "$@"\n' "$TS_APP_CLI" > "$BREW_BIN/tailscale"
    chmod +x "$BREW_BIN/tailscale"
fi

# 한/영 전환 — 오른쪽 Command(외장 Varmilo는 오른쪽 Alt·한/영 키)
# 세 층이고, 위층이 없으면 아래층이 받는다:
#   1) Karabiner [hanyeong] 규칙: 한/영을 *누르는 순간* F18을 눌렀다-뗀 것으로 보낸다.
#      macOS 단축키는 키를 *뗄 때* 전환돼서, 한/영을 떼기 전에 다음 글자를 치면 그 글자가
#      이전 언어로 들어간다 ("가끔 한/영이 씹힘" — 2026-11 실측, 실사용 94회 중 29%).
#      Shift가 눌린 채면 Shift를 떼고 보낸다 (단축키는 수정키가 정확히 없어야만 걸린다).
#      select_input_source(직접 전환)는 쓰지 않는다 — 연속 전환 중 메뉴바만 "한"이 되고
#      앱(iTerm2)에는 영어가 계속 들어가는 상태에 빠졌다 (2026-11-23).
#   2) LaunchAgent(hidutil): Karabiner 없이도 오른쪽 Command = F18. 로그인마다 다시 건다.
#      이 매핑은 Karabiner 가상 키보드에도 걸린다 — Karabiner 규칙에서 right_command 금지.
#   3) 시스템 단축키 60(이전 입력 소스 선택) = F18 — 1)이 없을 때 2)를 받아 전환한다.
#
# mac 앱 설정은 여기서 한 번에 배포한다 — 컴포넌트 스크립트(셸/nvim/claude)는 자기 영역만 apply한다.
#   Karabiner · 한/영 LaunchAgent · kitty · Hammerspoon · LinearMouse · git 전역 ignore
# 앱 GUI에서 설정을 바꿨으면 먼저 되담을 것 (안 그러면 여기서 repo 내용으로 덮인다):
#   chezmoi re-add ~/.config/karabiner/karabiner.json   (LinearMouse도 같은 식)
KEYMAP_PLIST="$HOME/Library/LaunchAgents/local.keymap.right-command-f18.plist"
chezmoi apply --force --source "$DOTFILES_DIR" \
    "$HOME/.config/karabiner" "$KEYMAP_PLIST" "$HOME/.config/kitty" \
    "$HOME/.hammerspoon" "$HOME/.config/linearmouse" "$HOME/.config/git"
# 다시 로드해서 지금 바로 건다. 끄려면:
#   launchctl bootout gui/$(id -u) "$KEYMAP_PLIST" && hidutil property --set '{"UserKeyMapping":[]}'
launchctl bootout "gui/$(id -u)" "$KEYMAP_PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$KEYMAP_PLIST" 2>/dev/null \
    || echo "경고: 한/영 LaunchAgent 로드 실패 — 다시 로그인하면 걸린다"
# 단축키 60 = F18(키코드 79), 수정키 없음. activateSettings가 로그아웃 없이 반영한다.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 \
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>79</integer><integer>0</integer></array><key>type</key><string>standard</string></dict></dict>'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

# 일상 GUI 앱 — 맨 마지막, 실패해도 셋업은 끝낸다 (Brewfile.apps 머리말 참고)
brew bundle --file="$DOTFILES_DIR/Brewfile.apps" \
    || echo "경고: 일부 앱 설치 실패 — 원인 확인 후 다시: brew bundle --file=$DOTFILES_DIR/Brewfile.apps"

echo ""
echo "완료! 새 터미널을 열면 적용됩니다."
echo "docker를 쓰려면: colima start   (로그인 시 자동 시작: brew services start colima)"
