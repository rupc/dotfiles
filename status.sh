#!/usr/bin/env bash
# ============================================================================
# 셋업 전체 상태 점검 — 무엇이 깔려 있고, 안 깔린 건 왜 안 깔렸는지
#
# 읽기 전용이다. 아무것도 설치/수정하지 않으므로 아무 때나 돌려도 안전하다.
# 각 설치 스크립트(setup-shell / setup-nvim / setup-linux / setup-macos)가
# 책임지는 범위를 카테고리로 나눠 보여주고, 통계는 맨 마지막에 모아 찍는다.
#
# 사용법:
#   ./status.sh            # 전체
#   ./status.sh --missing  # 빠진 것만 (설치된 항목은 생략)
# ============================================================================
set -uo pipefail   # -e 없음: 여기서 명령이 실패하는 건 '없다'는 정상 결과다

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$DOTFILES_DIR/lib-report.sh"   # 색/기호/have()
source "$DOTFILES_DIR/lib-tools.sh"    # 툴 목록/설명 (setup-shell.sh와 공유)

ONLY_MISSING=0
[ "${1:-}" = "--missing" ] && ONLY_MISSING=1

case "$(uname -s)" in
    Darwin) OS="mac";   SETUP_ALL="setup-macos.sh" ;;
    Linux)  OS="linux"; SETUP_ALL="setup-linux.sh" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# --- 집계 ------------------------------------------------------------------
# 카테고리별 카운터는 인덱스가 같은 병렬 배열로 둔다 (연관배열은 bash 3.2에서 안 됨)
CAT_NAME=(); CAT_OK=(); CAT_NG=(); CAT_SCRIPT=()
CUR=-1
MISSING_LIST=()   # "카테고리\t항목\t사유"

category() {  # $1=카테고리명 $2=담당 스크립트
    CAT_NAME+=("$1"); CAT_SCRIPT+=("$2"); CAT_OK+=(0); CAT_NG+=(0)
    CUR=$((${#CAT_NAME[@]} - 1))
    step "$1  ($2)"
}
# 설치됨 — $2는 버전 등 부연
yes_() {
    CAT_OK[$CUR]=$(( ${CAT_OK[$CUR]} + 1 ))
    [ "$ONLY_MISSING" = "1" ] && return 0
    local d; d=$(describe "$1" 2>/dev/null)
    ok "$1${2:+ ($2)}${d:+ — $d}"
}
# 없음 — $2는 사유 (필수)
no_() {
    CAT_NG[$CUR]=$(( ${CAT_NG[$CUR]} + 1 ))
    local d; d=$(describe "$1" 2>/dev/null)
    err "$1${d:+ ($d)} — $2"
    MISSING_LIST+=("${CAT_NAME[$CUR]}	$1	$2")
}
# 이 환경에는 해당 없음 (통계에서 제외) — 예: mac 전용 항목을 리눅스에서 볼 때
na_() { [ "$ONLY_MISSING" = "1" ] && return 0; warn "$1 — $2 (해당 없음)"; }

# 한글은 1글자가 2칸을 차지해서 printf %-Ns(바이트 기준)로는 표가 어긋난다.
# 표시 폭을 직접 세서 채운다.
pad() {  # $1=문자열 $2=목표 표시폭
    local s=$1 target=$2 w=0 i c
    for (( i=0; i<${#s}; i++ )); do
        c=${s:i:1}
        case "$c" in [가-힣ㄱ-ㅎㅏ-ㅣ]) w=$((w+2)) ;; *) w=$((w+1)) ;; esac
    done
    printf '%s' "$s"
    while [ "$w" -lt "$target" ]; do printf ' '; w=$((w+1)); done
}

# 실행파일 후보 중 하나라도 있으면 설치된 것으로 본다 (fd/fdfind, bat/batcat)
have_any() {
    local c
    for c in ${1//,/ }; do have "$c" && return 0; done
    return 1
}

# --- 사전 요구사항: 뒤 카테고리의 '왜 없는지'를 여기서 결정한다 -------------
category "사전 요구사항" "공통"
if have curl; then yes_ curl; else no_ curl "필수 — 이게 없으면 어떤 셋업도 못 돈다"; fi
if have git;  then yes_ git;  else no_ git "패키지 매니저로 설치 필요"; fi
if have zsh;  then yes_ zsh "$(zsh --version 2>/dev/null | cut -d' ' -f2)"; else no_ zsh "setup-shell.sh가 설치 시도함"; fi

PKG_MGR_OK=0   # brew(mac) / sudo+apt(linux) 를 쓸 수 있는가
if [ "$OS" = "mac" ]; then
    if have brew; then yes_ brew "$(brew --version 2>/dev/null | head -1 | cut -d' ' -f2)"; PKG_MGR_OK=1
    else no_ brew "https://brew.sh — 없으면 CLI 툴 전부 설치 불가"; fi
else
    if have sudo && sudo -n true 2>/dev/null; then yes_ sudo "패스워드 없이 사용 가능"; PKG_MGR_OK=1
    elif have sudo; then yes_ sudo "있음 (실행 시 패스워드 필요)"; PKG_MGR_OK=1
    else no_ sudo "apt 설치 불가 — GitHub 릴리스로 받는 툴만 설치된다"; fi
fi

have python3 && yes_ python3 "$(python3 --version 2>/dev/null | cut -d' ' -f2)" \
    || no_ python3 "노트북/basedpyright LSP 불가"
HAVE_NPM=0
if have npm; then yes_ npm "$(npm --version 2>/dev/null)"; HAVE_NPM=1
else no_ npm "node 미설치 — 일부 LSP·ACP 브리지 불가 (nvm 권장)"; fi
HAVE_CC=0
if have cc || have gcc || have clang; then yes_ "C 컴파일러"; HAVE_CC=1
else no_ "C 컴파일러" "treesitter 파서 컴파일 불가 (apt: build-essential / mac: xcode-select --install)"; fi
HAVE_GO=0;     have go     && { yes_ go "$(go version 2>/dev/null | cut -d' ' -f3)"; HAVE_GO=1; }     || no_ go "gopls(go LSP) 불가"
HAVE_RUSTUP=0; have rustup && { yes_ rustup; HAVE_RUSTUP=1; } || no_ rustup "rust-analyzer 불가"
HAVE_CARGO=0
if have cargo; then yes_ cargo; HAVE_CARGO=1
elif [ "$OS" = "mac" ]; then no_ cargo "rust 툴체인 없음 (taplo는 brew로 해결됨)"
else no_ cargo "rust 툴체인 없음 — taplo(toml LSP) 소스 빌드 불가"; fi

# CLI 툴이 없을 때의 사유 — 패키지 매니저 상태에 따라 달라진다
why_cli() {  # $1=툴 이름
    local gh=0 entry
    for entry in "${GH_RELEASE_TOOLS[@]}"; do
        [ "${entry%%|*}" = "$1" ] || [ "${entry%%,*}" = "$1" ] && { gh=1; break; }
    done
    if [ "$OS" = "mac" ]; then
        [ "$PKG_MGR_OK" = "1" ] && echo "setup-shell.sh 미실행 (brew로 설치됨)" || echo "brew 없음"
    elif [ "$gh" = "1" ]; then
        echo "apt에 없는 툴 — setup-shell.sh가 GitHub 릴리스로 설치 (sudo 불필요)"
    elif [ "$PKG_MGR_OK" = "1" ]; then
        echo "setup-shell.sh 미실행 (apt로 설치됨)"
    else
        echo "sudo 없음 — apt 설치 불가"
    fi
}

# --- CLI 툴 ----------------------------------------------------------------
# 44종을 한 줄씩 쏟으면 뭐가 뭔지 안 보인다. lib-tools.sh의 기능별 묶음으로
# 나눠 찍고, 묶음마다 몇 개가 채워졌는지(3/5)를 헤더에 붙인다.
category "CLI 툴" "setup-shell.sh"
report_tool() {  # $1=패키지명
    if have_any "$(tool_cmd "$1")"; then yes_ "$1"; else no_ "$1" "$(why_cli "$1")"; fi
}
GROUPED=""   # 어느 그룹에도 안 들어간 툴을 찾기 위한 기록
for grp in "${TOOL_GROUPS[@]}"; do
    gname=${grp%%|*}; gtools=${grp#*|}
    gok=0; gtot=0
    for pkg in $gtools; do
        gtot=$((gtot + 1))
        have_any "$(tool_cmd "$pkg")" && gok=$((gok + 1))
    done
    # --missing에서는 전부 갖춰진 묶음의 헤더까지 지운다 (볼 게 없으므로)
    if [ "$ONLY_MISSING" != "1" ] || [ "$gok" -lt "$gtot" ]; then
        echo "  ${C_B}── ${gname}${C_0} (${gok}/${gtot})"
    fi
    for pkg in $gtools; do
        GROUPED="$GROUPED $pkg"
        report_tool "$pkg"
    done
done
# 그룹에 넣는 걸 잊은 툴 — 조용히 사라지면 안 되니 여기로 모은다
UNGROUPED=""
for pkg in chezmoi fd ripgrep git-delta "${SHELL_TOOLS_COMMON[@]}"; do
    case " $GROUPED " in *" $pkg "*) ;; *) UNGROUPED="$UNGROUPED $pkg" ;; esac
done
if [ -n "${UNGROUPED// /}" ]; then
    echo "  ${C_B}── 기타${C_0} (lib-tools.sh의 TOOL_GROUPS에 아직 안 넣은 것)"
    for pkg in $UNGROUPED; do report_tool "$pkg"; done
fi

# --- 셸 환경 ---------------------------------------------------------------
category "셸 환경" "setup-shell.sh"
[ -d "$HOME/.oh-my-zsh" ] && yes_ "oh-my-zsh" || no_ "oh-my-zsh" "setup-shell.sh 미실행"
[ -d "$HOME/.zsh/pure" ]  && yes_ "pure 프롬프트" || no_ "pure 프롬프트" "setup-shell.sh 미실행 (git 필요)"

# 폰트는 터미널이 뜨는 로컬 머신에만 필요하다 (ssh 대상 서버에는 무의미)
FONT_DIR="$HOME/Library/Fonts"; [ "$OS" = "linux" ] && FONT_DIR="$HOME/.local/share/fonts"
if ls "$FONT_DIR"/*NerdFont*.ttf >/dev/null 2>&1; then
    yes_ "Nerd Font" "$(ls "$FONT_DIR"/*NerdFont*.ttf 2>/dev/null | wc -l | tr -d ' ')개"
else
    no_ "Nerd Font" "setup-fonts.sh 미실행 — 아이콘이 깨져 보인다 (원격 서버면 불필요)"
fi

case "${SHELL:-}" in
    */zsh) yes_ "기본 셸 = zsh" ;;
    *)     no_ "기본 셸 = zsh" "현재 ${SHELL:-미설정} — chsh -s \$(which zsh)" ;;
esac

# dotfiles가 실제로 배포됐는지 + 소스가 이 저장소인지
if have chezmoi; then
    SRC=$(chezmoi source-path 2>/dev/null)
    if [ "$SRC" = "$DOTFILES_DIR" ]; then yes_ "chezmoi sourceDir" "$SRC"
    else no_ "chezmoi sourceDir" "${SRC:-미설정} — 이 저장소($DOTFILES_DIR)가 아니다"; fi
    # chezmoi status가 뱉는 파일 = 배포 안 됐거나 밖에서 수정된 것
    DIRTY=$(chezmoi status --source "$DOTFILES_DIR" 2>/dev/null | awk '{print $2}')
    for f in .zshrc .bashrc .bash_profile; do
        case "$DIRTY" in
            *"$f"*) no_ "~/$f" "저장소와 다름 — ./setup-shell.sh 또는 chezmoi apply 필요" ;;
            *)      [ -f "$HOME/$f" ] && yes_ "~/$f" || no_ "~/$f" "배포 안 됨 — ./setup-shell.sh 실행" ;;
        esac
    done
else
    no_ "dotfiles 배포 상태" "chezmoi 없어서 확인 불가"
fi

# --- neovim ----------------------------------------------------------------
category "neovim" "setup-nvim.sh"
NVIM_BIN=""
[ -x "$HOME/.local/bin/nvim" ] && NVIM_BIN="$HOME/.local/bin/nvim" || NVIM_BIN=$(command -v nvim 2>/dev/null)
NVIM_MIN="0.11.0"
if [ -n "$NVIM_BIN" ]; then
    NV=$("$NVIM_BIN" --version 2>/dev/null | head -1 | sed 's/^NVIM v//')
    if [ "$(printf '%s\n' "$NVIM_MIN" "$NV" | sort -V | head -1)" = "$NVIM_MIN" ]; then
        yes_ "nvim" "v$NV"
    else
        no_ "nvim" "v$NV — $NVIM_MIN 미만이라 lua 플러그인/LSP가 전부 죽는다. setup-nvim.sh 실행"
    fi
else
    no_ "nvim" "setup-nvim.sh 미실행"
fi
[ -f "$HOME/.vim/autoload/plug.vim" ] && yes_ "vim-plug" || no_ "vim-plug" "setup-nvim.sh 미실행"

if have chezmoi; then
    DIRTY_NV=$(chezmoi status --source "$DOTFILES_DIR" 2>/dev/null | awk '{print $2}')
    case "$DIRTY_NV" in
        *.vimrc*) no_ "~/.vimrc" "저장소와 다름 — ./setup-nvim.sh 실행" ;;
        *)        [ -f "$HOME/.vimrc" ] && yes_ "~/.vimrc" || no_ "~/.vimrc" "배포 안 됨 — ./setup-nvim.sh 실행" ;;
    esac
fi

# 선언된 플러그인 vs 실제로 받아진 것.
# 파일을 파싱하면 'as'/'dir' 옵션이나 vim 전용 분기(nerdtree)를 놓치므로,
# vim-plug가 vimrc를 실제로 평가한 결과인 g:plugs를 그대로 물어본다.
if [ -n "$NVIM_BIN" ] && [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    PLUG_OUT=$("$NVIM_BIN" --headless \
        -c 'let n=0 | let m=[] | for [k,v] in items(get(g:,"plugs",{})) | let n+=1 | if !isdirectory(expand(v.dir)) | call add(m,k) | endif | endfor | echo n."|".join(m," ")' \
        -c 'qall!' 2>&1 | grep -E '^[0-9]+\|' | head -1)
    PLUG_N=${PLUG_OUT%%|*}; PLUG_MISS=${PLUG_OUT#*|}
    if [ -z "${PLUG_MISS// /}" ]; then yes_ "vim 플러그인" "${PLUG_N}개 전부 설치됨"
    else no_ "vim 플러그인" "미설치: $PLUG_MISS — nvim에서 :PlugInstall 또는 ./setup-nvim.sh"; fi
fi

# 노트북(molten) + python LSP가 같이 들어있는 전용 venv
NVENV="$HOME/.venvs/nvim"
[ -x "$NVENV/bin/python" ] && yes_ "nvim venv" "$NVENV" \
    || no_ "nvim venv" "setup-nvim.sh 미실행 — 노트북(molten)/python LSP 불가"
[ -x "$NVENV/bin/jupytext" ] && yes_ "jupytext/pynvim" "노트북(.ipynb) 지원" \
    || no_ "jupytext/pynvim" "venv 미구성 — .ipynb 열기 불가"

if have tree-sitter && tree-sitter --version >/dev/null 2>&1; then
    yes_ "tree-sitter CLI" "$(tree-sitter --version 2>/dev/null | head -1)"
elif have tree-sitter; then
    no_ "tree-sitter CLI" "설치는 됐지만 실행 불가 (glibc 비호환) — setup-nvim.sh가 0.25.10으로 교체 시도"
elif [ "$HAVE_NPM" = "1" ]; then
    no_ "tree-sitter CLI" "setup-nvim.sh 미실행 (npm -g tree-sitter-cli)"
else
    no_ "tree-sitter CLI" "npm 없음 — 파서 신규 설치 불가 (regex 하이라이팅으로 폴백)"
fi

# 파서는 vimrc의 my_ts_langs 목록 기준
TS_WANT=$(grep -A6 'my_ts_langs = {' "$DOTFILES_DIR/executable_dot_vimrc" 2>/dev/null \
    | tr -d " \n'" | sed 's/.*{//;s/}.*//' | tr ',' '\n' | grep -c . )
TS_HAVE=$(ls "$HOME/.local/share/nvim/site/parser/" 2>/dev/null | grep -c '\.so$')
if [ "${TS_HAVE:-0}" -gt 0 ] && [ "${TS_HAVE:-0}" -ge "${TS_WANT:-0}" ]; then
    yes_ "treesitter 파서" "$TS_HAVE/${TS_WANT}개"
elif [ "${TS_HAVE:-0}" -gt 0 ]; then
    no_ "treesitter 파서" "$TS_HAVE/${TS_WANT}개만 설치됨 — ./setup-nvim.sh 재실행"
else
    no_ "treesitter 파서" "0개 — tree-sitter CLI + C 컴파일러 확보 후 ./setup-nvim.sh"
fi

# 에디터 보조 (vimrc가 있으면 쓰고 없으면 그 기능만 빠지는 것들)
for entry in "ripgrep:rg::Rg 검색" "imagemagick:convert,magick:그래프 인라인 렌더링" \
             "kitty:kitty:노트북 이미지 출력용 터미널" "shellcheck:shellcheck:sh 진단" \
             "shfmt:shfmt:sh 포맷팅"; do
    p=${entry%%:*}; rest=${entry#*:}; cmds=${rest%%:*}; use=${rest##*:}
    if have_any "$cmds"; then yes_ "$p" "$use"; else no_ "$p" "$use 불가 — setup-nvim.sh 미실행"; fi
done

# --- LSP 서버 --------------------------------------------------------------
category "LSP 서버" "setup-nvim.sh"
[ -x "$NVENV/bin/basedpyright-langserver" ] && yes_ "basedpyright" "python" \
    || no_ "basedpyright" "python LSP — venv 미구성 (setup-nvim.sh)"
have clangd && yes_ "clangd" "c/cpp" || no_ "clangd" "c/cpp LSP — apt: clangd / mac: brew install llvm"
if have gopls; then yes_ "gopls" "go"
elif [ "$HAVE_GO" = "1" ]; then no_ "gopls" "go는 있음 — setup-nvim.sh 실행하면 설치됨"
else no_ "gopls" "go 없음"; fi
if have rust-analyzer; then yes_ "rust-analyzer" "rust"
elif [ "$HAVE_RUSTUP" = "1" ]; then no_ "rust-analyzer" "rustup은 있음 — rustup component add rust-analyzer"
else no_ "rust-analyzer" "rustup 없음"; fi
for srv in bash-language-server yaml-language-server; do
    if have "$srv"; then yes_ "$srv"
    elif [ "$HAVE_NPM" = "1" ]; then no_ "$srv" "setup-nvim.sh 미실행 (npm -g $srv)"
    else no_ "$srv" "npm 없음"; fi
done
if have ts-lsp; then yes_ "ts-lsp" "js/ts"
elif [ "$HAVE_NPM" = "1" ]; then no_ "ts-lsp" "setup-nvim.sh 미실행 (typescript 설치 후 래퍼 생성)"
else no_ "ts-lsp" "npm 없음"; fi
if have taplo; then yes_ "taplo" "toml"
elif [ "$OS" = "mac" ]; then no_ "taplo" "brew install taplo"
elif [ "$HAVE_CARGO" = "1" ]; then no_ "taplo" "cargo는 있음 — cargo install taplo-cli --locked"
else no_ "taplo" "cargo 없음"; fi

# --- AI 에이전트 -----------------------------------------------------------
# 두 갈래다: toggleterm은 CLI를 그냥 띄우고(<space>t*), agentic.nvim은 ACP로 붙어
# 선택영역·파일을 컨텍스트로 넘긴다(<space>a*). ACP 쪽은 브리지 바이너리가 따로 필요.
category "AI 에이전트" "setup-nvim.sh"
for cli in claude codex gemini; do
    have "$cli" && yes_ "$cli CLI" "toggleterm에서 바로 실행" \
        || no_ "$cli CLI" "각자 공식 설치 경로로 설치 (셋업 스크립트 범위 밖)"
done
for entry in "claude-agent-acp:claude" "gemini:gemini" "codex-acp:codex"; do
    b=${entry%%:*}; who=${entry##*:}
    if have "$b"; then yes_ "$b" "$who ACP 브리지"
    elif [ "$HAVE_NPM" = "1" ]; then no_ "$b" "${who}를 agentic.nvim에서 못 씀 — ./setup-nvim.sh 실행"
    else no_ "$b" "npm 없음 — ACP 브리지 설치 불가"; fi
done
for p in agentic.nvim neo-tree.nvim nvim-window-picker; do
    [ -d "$HOME/.vim/plugged/$p" ] && yes_ "$p" || no_ "$p" ":PlugInstall 또는 ./setup-nvim.sh"
done

# --- 런타임/컨테이너 -------------------------------------------------------
category "런타임/컨테이너" "${SETUP_ALL}"
have node && yes_ "node" "$(node --version 2>/dev/null)" || no_ "node" "nvm으로 설치 (${SETUP_ALL})"
[ -s "$HOME/.nvm/nvm.sh" ] && yes_ "nvm" || no_ "nvm" "${SETUP_ALL} 미실행"
if have docker; then
    yes_ "docker" "$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ,)"
    docker compose version >/dev/null 2>&1 && yes_ "docker compose" \
        || { have docker-compose && yes_ "docker compose" "v1" || no_ "docker compose" "플러그인 미설치"; }
else
    no_ "docker" "${SETUP_ALL} 미실행"
fi
if [ "$OS" = "mac" ]; then
    have colima && yes_ "colima" "docker 데몬 (colima start)" || no_ "colima" "brew install colima — mac에서 docker 실행에 필요"
else
    na_ "colima" "mac 전용"
    # MOTD 광고: setup-linux.sh가 끄는 대상들
    ADS=""
    for f in 50-motd-news 88-esm-announce 91-contract-ua-esm-status 91-contract-ubuntu-advantage; do
        [ -x "/etc/update-motd.d/$f" ] && ADS="$ADS $f"
    done
    [ -z "$ADS" ] && yes_ "MOTD 광고 제거" "로그인 배너 정리됨" \
        || no_ "MOTD 광고 제거" "아직 켜져 있음:$ADS — ./setup-linux.sh 실행"
fi

# --- mac 전용 --------------------------------------------------------------
if [ "$OS" = "mac" ]; then
    category "mac 전용" "setup-macos.sh"
    if have brew; then
        BREW_MISS=$(brew bundle check --file="$DOTFILES_DIR/Brewfile" --verbose 2>/dev/null \
            | sed -n 's/^Missing formula: //p;s/^Missing cask: //p' | tr '\n' ' ')
        [ -z "${BREW_MISS// /}" ] && yes_ "Brewfile" "전부 설치됨" \
            || no_ "Brewfile" "미설치:${BREW_MISS} — brew bundle --file=Brewfile"
    else
        no_ "Brewfile" "brew 없음"
    fi
    have tailscale && yes_ "tailscale CLI" || no_ "tailscale CLI" "Tailscale.app 설치 후 setup-macos.sh 실행"
fi

# --- 통계 (맨 마지막) ------------------------------------------------------
TOT_OK=0; TOT_NG=0
step "통계"
printf "  "; pad "카테고리" 18; printf " %6s %6s %6s  %s\n" "설치" "누락" "비율" "담당 스크립트"
printf "  %s\n" "----------------------------------------------------------------------"
i=0
while [ "$i" -lt "${#CAT_NAME[@]}" ]; do
    o=${CAT_OK[$i]}; n=${CAT_NG[$i]}; t=$((o + n))
    TOT_OK=$((TOT_OK + o)); TOT_NG=$((TOT_NG + n))
    pct=0; [ "$t" -gt 0 ] && pct=$((o * 100 / t))
    # 다 채워졌으면 초록, 절반 이상이면 노랑, 아니면 빨강
    c=$C_R; [ "$pct" -ge 50 ] && c=$C_Y; [ "$pct" -eq 100 ] && c=$C_G
    printf "  "; pad "${CAT_NAME[$i]}" 18
    printf " %6d %6d %s%5d%%%s  %s\n" "$o" "$n" "$c" "$pct" "$C_0" "${CAT_SCRIPT[$i]}"
    i=$((i + 1))
done
TOT=$((TOT_OK + TOT_NG)); TOT_PCT=0; [ "$TOT" -gt 0 ] && TOT_PCT=$((TOT_OK * 100 / TOT))
printf "  %s\n" "----------------------------------------------------------------------"
printf "  "; pad "전체" 18; printf " %6d %6d %5d%%\n" "$TOT_OK" "$TOT_NG" "$TOT_PCT"

if [ "${#MISSING_LIST[@]}" -gt 0 ]; then
    # 같은 사유끼리 묶어 보여준다 — "이거 하나 해결하면 N개가 같이 풀린다"가 보이도록
    step "누락 ${#MISSING_LIST[@]}건 — 사유별"
    printf '%s\n' "${MISSING_LIST[@]}" | awk -F'\t' '
        { cnt[$3]++; items[$3] = items[$3] (items[$3] ? ", " : "") $2 }
        END { for (r in cnt) printf "%d\t%s\t%s\n", cnt[r], r, items[r] }' \
    | sort -rn | while IFS=$'\t' read -r n reason items; do
        echo "  ${C_Y}[${n}건]${C_0} $reason"
        echo "     $items"
    done
else
    echo ""
    ok "누락 없음 — 전부 설치되어 있다"
fi

echo ""
echo "설치하려면: ./setup-shell.sh (셸) / ./setup-nvim.sh (에디터) / ./${SETUP_ALL} (전체)"
echo "빠진 것만 다시 보려면: ./status.sh --missing"
