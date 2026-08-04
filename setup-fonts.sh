#!/usr/bin/env bash
# ============================================================================
# 터미널 폰트(Nerd Font) 셋업 — eza --icons, 프롬프트 글리프, 파워라인 심볼
#
# 폰트는 "터미널 에뮬레이터가 실행되는 로컬 머신"에만 필요하다.
# (ssh 접속 대상 리눅스 박스에는 불필요 — 글리프 렌더링은 로컬 터미널 몫)
#
# ttf를 저장소에 번들하지 않는 이유: 패밀리당 수십 MB 바이너리가 git 히스토리에
# 영구히 남는다. 대신 공식 릴리즈에서 버전 고정으로 받아 설치한다.
# (idempotent, sudo 불필요 — 유저 폰트 디렉토리에 설치)
#
# 사용법: ./setup-fonts.sh
#   폰트 추가: 아래 FONTS 배열에 이름 추가 (https://www.nerdfonts.com/font-downloads)
# ============================================================================
set -euo pipefail

NF_VERSION="v3.4.0"        # nerd-fonts 릴리즈 버전 고정
FONTS=(JetBrainsMono)      # 예: (JetBrainsMono Meslo FiraCode Hack)

case "$(uname -s)" in
    Darwin) OS="mac";   FONT_DIR="$HOME/Library/Fonts" ;;
    Linux)  OS="linux"; FONT_DIR="$HOME/.local/share/fonts" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

installed() {
    ls "$FONT_DIR"/"$1"*NerdFont*.ttf >/dev/null 2>&1
}

# mac + brew가 있으면 cask 우선 (업데이트 관리 일원화), 실패 시 직접 다운로드 폴백
brew_cask_name() {
    case "$1" in
        JetBrainsMono) echo "font-jetbrains-mono-nerd-font" ;;
        Meslo)         echo "font-meslo-lg-nerd-font" ;;
        FiraCode)      echo "font-fira-code-nerd-font" ;;
        Hack)          echo "font-hack-nerd-font" ;;
        *)             echo "" ;;
    esac
}

mkdir -p "$FONT_DIR"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

for font in "${FONTS[@]}"; do
    if installed "$font"; then
        echo "skip: $font (이미 설치됨)"
        continue
    fi

    if [ "$OS" = "mac" ] && command -v brew >/dev/null 2>&1; then
        cask=$(brew_cask_name "$font")
        if [ -n "$cask" ] && brew install --cask "$cask"; then
            continue
        fi
    fi

    echo "다운로드: $font ($NF_VERSION)"
    curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/${font}.tar.xz" \
        -o "$TMP/$font.tar.xz"
    mkdir -p "$TMP/$font"
    tar xJf "$TMP/$font.tar.xz" -C "$TMP/$font"
    find "$TMP/$font" -name '*.ttf' -exec cp {} "$FONT_DIR/" \;
    echo "설치됨: $font -> $FONT_DIR"
done

# linux는 폰트 캐시 갱신 필요
if [ "$OS" = "linux" ] && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$FONT_DIR" >/dev/null
fi

echo ""
echo "폰트 셋업 완료. 터미널 앱에서 폰트를 지정해야 적용된다:"
echo "  iTerm2:       Settings > Profiles > Text > Font -> 'JetBrainsMono Nerd Font'"
echo "  kitty:        자동 적용 (kitty.conf에 font_family 지정됨)"
echo "  Terminal.app: 설정 > 프로파일 > 서체 -> 'JetBrainsMono Nerd Font'"
