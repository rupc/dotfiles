#!/usr/bin/env bash
# ============================================================================
# 셸 작업환경만 셋업 — zsh + oh-my-zsh + pure + CLI 툴 + 셸 dotfiles 배포
# (neovim은 건드리지 않음. 공용 머신에서 내 셸 환경만 얹을 때 사용)
#
# 실행 흐름(전부 로그로 표시):
#   ① 사전 요구사항 점검 — 없으면 어떤 단계가 영향을 받는지 알려줌
#   ② 항목별 현황 — 이미 있으면 ✓ 스킵, 없으면 설치 진행
#   ③ 요약 — 이미 있음 / 새로 설치 / 생략(사유) / 실패(사유)
# 멱등: 몇 번을 다시 실행해도 없는 것만 골라 설치한다.
#
# 사용법:
#   ./setup-shell.sh                  # 패키지 설치 포함 (mac: brew, linux: apt+sudo)
#   SKIP_PACKAGES=1 ./setup-shell.sh  # sudo 없는 공용 머신: dotfiles/플러그인만 배포
#     (zsh 플러그인은 저장소에 번들되어 있고, zshrc가 모든 툴을 존재할 때만
#      로드하므로 패키지 없이도 셸이 깨지지 않는다)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SETUP_SCRIPT="./setup-shell.sh"
source "$DOTFILES_DIR/lib-report.sh"
source "$DOTFILES_DIR/lib-tools.sh"   # 툴 목록/설명 (status.sh와 공유)

# 이 스크립트가 ~/.local/bin에 설치한 것들을 뒤 단계에서 곧바로 찾을 수 있게
export PATH="$HOME/.local/bin:$PATH"

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# 패키지 매니저 출력은 로그로 빼고 화면에는 항목별 상태만 — 실패 시 이 로그를 본다
LOG="${TMPDIR:-/tmp}/setup-shell-$(date +%Y%m%d-%H%M%S).log"
: > "$LOG"

# --- 0. 사전 요구사항 점검 --------------------------------------------------
step "사전 요구사항 점검 (없으면 해당 단계는 아래에서 '생략'으로 표시)"
if have curl; then ok "curl"; else
    err "curl 없음 — chezmoi/oh-my-zsh 다운로드 불가. 설치 후 재실행하라."; exit 1
fi
have git && ok "git" || warn "git 없음 — pure 프롬프트 clone 생략됨"
have zsh && ok "zsh ($(zsh --version 2>/dev/null | cut -d' ' -f2))" \
    || warn "zsh 없음 — 아래에서 설치를 시도한다 (실패하면 bash dotfiles만 적용됨)"

PKG_OK=1   # 패키지 설치 단계를 진행할 수 있는가
if [ -n "${SKIP_PACKAGES:-}" ]; then
    warn "SKIP_PACKAGES=1 — 패키지 매니저(brew/apt) 설치 단계 전부 생략"
    PKG_OK=0
elif [ "$OS" = "mac" ]; then
    have brew && ok "brew" || { warn "brew 없음 — 패키지 설치 생략됨 (https://brew.sh)"; PKG_OK=0; }
else
    if have sudo && sudo -v >/dev/null 2>&1; then
        ok "sudo"
    else
        warn "sudo 없음/인증 실패 — apt 패키지 설치 불가 (SKIP_PACKAGES=1로 실행 권장)"
        PKG_OK=0
    fi
fi

# --- 1. CLI 패키지 ----------------------------------------------------------

APT_ABSENT=()      # apt에 아예 없는 것들 — 아래 GitHub 릴리스 단계에서 재시도
GH_FALLBACK_ALL=0  # sudo가 없어 apt를 통째로 못 쓴 경우

step "CLI 패키지 (${#SHELL_TOOLS_COMMON[@]}종 + 기본 툴)"
if [ "$PKG_OK" = "0" ]; then
    if [ -n "${SKIP_PACKAGES:-}" ]; then
        skipped "CLI 패키지 전체" "SKIP_PACKAGES=1"
    else
        skipped "apt/brew 설치분" "패키지 매니저 사용 불가 (위 사전 점검 참고)"
        # sudo가 없어도 GitHub 릴리스 -> ~/.local/bin 은 가능하다
        if [ "$OS" = "linux" ]; then GH_FALLBACK_ALL=1; fi
    fi
elif [ "$OS" = "mac" ]; then
    MISSING=()
    for pkg in chezmoi fd ripgrep git-delta watch "${SHELL_TOOLS_COMMON[@]}"; do
        if brew list --versions "$pkg" >/dev/null 2>&1; then already "$pkg"; else MISSING+=("$pkg"); fi
    done
    if [ "${#MISSING[@]}" -gt 0 ]; then
        echo "  … ${#MISSING[@]}종 설치 중 (brew — 로그: $LOG)"
        brew install "${MISSING[@]}" >>"$LOG" 2>&1 || true
        for pkg in "${MISSING[@]}"; do
            if brew list --versions "$pkg" >/dev/null 2>&1; then newly "$pkg"
            else failed "$pkg" "brew 설치 실패 (formula 없음/충돌 — 로그: $LOG)"; fi
        done
    fi
else
    echo "  … apt 인덱스 갱신 중 (로그: $LOG)"
    sudo apt-get update >>"$LOG" 2>&1 || warn "apt-get update 실패 (로그: $LOG) — 캐시된 인덱스로 진행"
    apt_installed() { [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = "installed" ]; }
    apt_candidate() {
        local c; c=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}')
        [ -n "$c" ] && [ "$c" != "(none)" ]
    }
    # SHELL_TOOLS_LINUX: mac에는 의미 없어서 공용 목록에서 분리해둔 것들 (nvme-cli 등)
    for pkg in zsh git curl fd-find ripgrep git-delta "${SHELL_TOOLS_COMMON[@]}" "${SHELL_TOOLS_LINUX[@]}"; do
        if apt_installed "$pkg"; then
            already "$pkg"
        elif ! apt_candidate "$pkg"; then
            # 우분투/데비안 apt에 아예 없는 것들(lazygit/navi/broot/yazi/dive 등).
            # 대부분 Go/Rust 단일 바이너리라 데비안이 패키징한 적이 없다 -> 아래에서
            # GitHub 릴리스로 재시도하고, 거기에도 없는 것만 최종 '생략'으로 남는다.
            APT_ABSENT+=("$pkg")
        else
            echo "  … $pkg 설치 중 (apt)"
            if sudo apt-get install -y "$pkg" >>"$LOG" 2>&1; then newly "$pkg"
            else failed "$pkg" "apt 설치 실패 (의존성 충돌 등 — 로그: $LOG)"; fi
        fi
    done
    # Debian/Ubuntu 실행파일명 차이 -> 표준 이름으로 심링크
    mkdir -p "$HOME/.local/bin"
    have batcat && ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat" && ok "심링크 bat -> batcat"
    have fdfind && ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"  && ok "심링크 fd -> fdfind"
fi

# --- 1b. apt에 없는 툴 — GitHub 릴리스에서 ~/.local/bin으로 (sudo 불필요) ----

case "$(uname -m)" in
    x86_64|amd64)  GH_ARCH_RE='(x86_64|amd64)' ;;
    aarch64|arm64) GH_ARCH_RE='(aarch64|arm64)' ;;
    *)             GH_ARCH_RE="" ;;
esac

unpack_zip() {  # unzip이 없는 최소 설치 환경 대비 (python3는 거의 항상 있다)
    if have unzip; then unzip -qo "$1" -d "$2"
    elif have python3; then python3 -m zipfile -e "$1" "$2"
    else return 1; fi
}

# $1=바이너리들(콤마) $2=repo $3=자산 정규식
gh_release_install() {
    local bins=$1 repo=$2 pat=$3
    local main=${bins%%,*} url tmp file src b got=0
    pat=${pat//%A%/$GH_ARCH_RE}
    url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null \
        | grep -o '"browser_download_url": *"[^"]*"' | sed 's/.*"\(https[^"]*\)".*/\1/' \
        | grep -E -- "$pat" | head -1) || true   # 정규식이 -로 시작할 수 있어 -- 필수
    if [ -z "$url" ]; then
        failed "$main" "GitHub 릴리스에 이 아키텍처용 자산 없음 ($repo)"; return 1
    fi
    tmp=$(mktemp -d); file="$tmp/${url##*/}"
    if ! curl -fsSL "$url" -o "$file"; then
        rm -rf "$tmp"; failed "$main" "다운로드 실패 ($url)"; return 1
    fi
    case "$file" in
        *.tar.gz|*.tgz) tar xzf "$file" -C "$tmp" || true ;;
        *.zip)          unpack_zip "$file" "$tmp" || true ;;
        *)              : ;;   # 압축 없이 바이너리만 올리는 프로젝트(genact)
    esac
    for b in ${bins//,/ }; do
        case "$file" in
            *.tar.gz|*.tgz|*.zip)
                # broot처럼 여러 플랫폼을 한 zip에 담는 경우가 있어 아키텍처 경로를 먼저 본다
                src=$(find "$tmp" -type f -name "$b" -path "*$(uname -m)*" 2>/dev/null | head -1)
                [ -n "$src" ] || src=$(find "$tmp" -type f -name "$b" 2>/dev/null | head -1) ;;
            *)  src=$file ;;
        esac
        [ -n "$src" ] || continue
        install -m 755 "$src" "$HOME/.local/bin/$b" && got=1
    done
    rm -rf "$tmp"
    if [ "$got" = "1" ]; then newly "$main"; else failed "$main" "받은 파일에서 실행파일을 못 찾음"; fi
}

if [ "$OS" = "linux" ] && [ -z "${SKIP_PACKAGES:-}" ] \
   && { [ "${#APT_ABSENT[@]}" -gt 0 ] || [ "$GH_FALLBACK_ALL" = "1" ]; }; then
    step "apt에 없는 툴 — GitHub 릴리스에서 설치 (~/.local/bin, sudo 불필요)"
    if [ -z "$GH_ARCH_RE" ]; then
        skipped "GitHub 릴리스 설치" "지원하지 않는 아키텍처 ($(uname -m))"
    else
        mkdir -p "$HOME/.local/bin"
        GH_HANDLED=""
        for entry in "${GH_RELEASE_TOOLS[@]}"; do
            bins=${entry%%|*}; rest=${entry#*|}; repo=${rest%%|*}; pat=${rest#*|}
            main=${bins%%,*}
            GH_HANDLED="$GH_HANDLED $main"
            # apt가 해결했거나 애초에 안 빠진 툴은 건드리지 않는다
            if [ "$GH_FALLBACK_ALL" != "1" ]; then
                case " ${APT_ABSENT[*]} " in *" $main "*) ;; *) continue ;; esac
            fi
            if have "$main"; then already "$main"; continue; fi
            # 아키텍처 표기가 없는 자산(onefetch)은 x86_64 전용 빌드다
            if [ "${pat#*%A%}" = "$pat" ] && [ "$(uname -m)" != "x86_64" ]; then
                skipped "$main" "이 아키텍처용 공식 릴리스 없음"; continue
            fi
            echo "  … $main 설치 중 (GitHub 릴리스: $repo)"
            gh_release_install "$bins" "$repo" "$pat" || true
        done
        # GitHub 레시피조차 없는 것들만 최종 '생략'으로 남긴다
        for pkg in ${APT_ABSENT[@]+"${APT_ABSENT[@]}"}; do
            case " $GH_HANDLED " in
                *" $pkg "*) ;;
                *) skipped "$pkg" "이 배포판 apt에 없고 GitHub 릴리스 레시피도 없음" ;;
            esac
        done
    fi
fi

# --- 2. Nerd Font (아이콘 글리프) -------------------------------------------
step "Nerd Font (eza --icons / 프롬프트 심볼용)"
if [ -n "${SKIP_PACKAGES:-}" ]; then
    skipped "Nerd Font" "SKIP_PACKAGES=1"
elif "$DOTFILES_DIR/setup-fonts.sh" >>"$LOG" 2>&1; then
    ok "폰트 셋업 완료 (터미널 폰트로 지정해야 실제 적용 — setup-fonts.sh 참고)"
else
    failed "Nerd Font" "setup-fonts.sh 실패 (로그: $LOG) — 아이콘 없이도 셸은 정상"
fi

# --- 3. chezmoi (패키지 매니저에 없거나 SKIP_PACKAGES면 유저 로컬에 설치) ---
step "chezmoi (dotfiles 배포 도구)"
if have chezmoi; then
    already "chezmoi" "$(chezmoi --version 2>/dev/null | head -1)"
else
    echo "  … chezmoi 설치 중 (get.chezmoi.io -> ~/.local/bin)"
    if sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin" >>"$LOG" 2>&1; then
        export PATH="$HOME/.local/bin:$PATH"
        newly "chezmoi"
    else
        failed "chezmoi" "설치 실패 (로그: $LOG) — dotfiles 배포 불가"
    fi
fi

# --- 4. oh-my-zsh + pure prompt (sudo 불필요) -------------------------------
step "oh-my-zsh + pure 프롬프트"
if [ -d "$HOME/.oh-my-zsh" ]; then
    already "oh-my-zsh"
else
    echo "  … oh-my-zsh 설치 중"
    if RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended >>"$LOG" 2>&1
    then newly "oh-my-zsh"; else failed "oh-my-zsh" "설치 실패 (로그: $LOG)"; fi
fi

if [ -d "$HOME/.zsh/pure" ]; then
    already "pure 프롬프트"
elif ! have git; then
    skipped "pure 프롬프트" "git 없음"
else
    echo "  … pure clone 중"
    if git clone --depth=1 https://github.com/sindresorhus/pure.git "$HOME/.zsh/pure" >>"$LOG" 2>&1
    then newly "pure 프롬프트"; else failed "pure 프롬프트" "clone 실패 (로그: $LOG)"; fi
fi

# broot 런처 생성 (chezmoi apply 전에 — rc 파일 수정분이 apply로 정리되도록)
if have broot; then
    broot --install >/dev/null 2>&1 && ok "broot 런처(br) 생성" || warn "broot --install 실패 (br 별칭 없이 계속)"
else
    skipped "broot 런처(br)" "broot 미설치"
fi

# --- 5. 셸 dotfiles 배포 ----------------------------------------------------
step "셸 dotfiles 배포 (.zshrc / .bashrc / .bash_profile / .oh-my-zsh / fastfetch)"
if have chezmoi; then
    # sourceDir은 항상 이 repo로 강제 — 예전 셋업이 남긴 toml이 옛 clone을 가리키는 사고 방지
    mkdir -p "$HOME/.config/chezmoi"
    printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
    # --force: 타깃이 밖에서 수정됐을 때 뜨는 overwrite 프롬프트(/dev/tty)가
    # 로그 리다이렉트에 가려져 무한 대기하는 것을 방지 — repo가 항상 source of truth
    # fastfetch 설정도 셸 스플래시의 일부라 여기서 배포한다 (zshrc가 fastfetch를 부른다)
    if chezmoi apply --force --source "$DOTFILES_DIR" \
        "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.oh-my-zsh" \
        "$HOME/.config/fastfetch" >>"$LOG" 2>&1
    then newly "셸 dotfiles (source: $DOTFILES_DIR)"; else failed "셸 dotfiles" "chezmoi apply 실패 (로그: $LOG)"; fi
else
    failed "셸 dotfiles" "chezmoi 없음 — 배포 불가"
fi

# --- 6. 마무리 점검 ---------------------------------------------------------
step "마무리 점검"
case "${SHELL:-}" in
    */zsh) ok "기본 셸이 zsh" ;;
    *)     warn "기본 셸이 zsh가 아님(${SHELL:-미설정}) — 바꾸려면: chsh -s \$(which zsh)" ;;
esac
have zsh && { zsh -n "$HOME/.zshrc" 2>>"$LOG" && ok ".zshrc 문법 검사 통과" \
    || err ".zshrc 문법 오류 (로그: $LOG)"; }

print_summary
echo ""
echo "전체 로그: $LOG"
echo "셸 환경 셋업 완료. 새 터미널을 열거나: exec zsh"
