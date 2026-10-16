#!/usr/bin/env bash
# ============================================================================
# Claude Code 환경만 셋업 — CLI + Claude 설정(상태줄 포함)
# (셸/에디터는 건드리지 않음)
#
# 상태줄은 "지금 어느 머신의 어느 경로에서, 어떤 계정·모델·effort로 돌고 있는지"를
# 한 줄로 보여준다. 머신을 옮겨다니며 여러 세션을 띄우면 이게 없을 때 어느 창이
# 어디에 붙어 있는지 헷갈린다.
#
#   jyr@bsp-server-13  ~/dotfiles  main*  me@example.com  Opus 5 xhigh
#
# 두 가지 모드:
#
#   로컬 (기본) — 이 저장소 바로 위 디렉토리(BASE = ..)에 전부 넣는다.
#     여러 사람이 한 계정을 같이 쓰는 공용 서버용. 예: /data/yongrae/dotfiles 에서
#     실행하면 BASE=/data/yongrae 이고, BASE 밖은 아무것도 안 건드린다:
#       BASE/.claude/          설정·로그인·세션 기록 (CLAUDE_CONFIG_DIR)
#       BASE/.claude-setup/    여기서 받은 claude CLI·jq, 셋업 로그
#       BASE/claude-env.sh     쓰기 전에 source 하는 파일
#     ~/.claude, ~/.claude.json, ~/.local, ~/.config/chezmoi, 셸 rc는 그대로다.
#     BASE가 홈이면(~/dotfiles에 clone) 전역 모드와 같은 곳이라 전역 모드로 돈다.
#
#   전역 (--global) — ~/.claude 에 배포 (chezmoi, private_dot_claude/).
#     내 머신용. setup-macos.sh / setup-linux.sh가 이 모드로 부른다.
#       ~/.claude/settings.json    모델·effort·TUI 취향 + statusLine 연결
#       ~/.claude/statusline.sh    상태줄 렌더러
#       ~/.claude/                 디렉토리 자체는 0700 (세션 기록이 들어있다)
#     세션 기록(projects/, sessions/, history.jsonl)은 chezmoi 관리 대상이 아니라
#     그대로 남는다 — 위 두 파일만 덮어쓴다.
#
# 주의: settings.json은 Claude Code가 스스로도 쓴다(/config, 모델 변경, 각종 동의
# 다이얼로그). 이 스크립트를 다시 돌리면 repo 내용으로 덮인다 — repo가 source of
# truth. 전역 모드에서 TUI로 바꾼 걸 살리려면 먼저 되담을 것:
#   chezmoi re-add ~/.claude/settings.json
#
# 단독으로 돌려도 자립한다: claude CLI, jq(상태줄 파서), (전역 모드) chezmoi를 없으면
# 설치한다. 셸 rc는 setup-shell.sh 영역이라 직접 고치지 않는다 — 공용 머신에서 남의
# rc를 안 건드린다.
#
# 사용법:
#   ./setup-claude.sh                  # 로컬 모드 셋업 (멱등)
#   ./setup-claude.sh --reset          # 로컬 모드 원상복구: 로그아웃 + BASE의 셋업물 삭제
#   ./setup-claude.sh --reset --yes    #   확인 질문 없이
#   ./setup-claude.sh --global         # ~/.claude 에 배포 (내 머신)
#   SKIP_PACKAGES=1 ./setup-claude.sh  # 설정만 배포 (CLI/jq 설치 안 함)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_PACKAGES="${SKIP_PACKAGES:-0}"

MODE="local"; RESET=0; ASSUME_YES=0
for arg in "$@"; do
    case "$arg" in
        --global)  MODE="global" ;;
        --local)   MODE="local" ;;
        --reset)   RESET=1 ;;
        -y|--yes)  ASSUME_YES=1 ;;
        -h|--help) sed -n '/^# 사용법:/,/^# ====/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
        *)         echo "알 수 없는 옵션: $arg  (./setup-claude.sh --help)" >&2; exit 2 ;;
    esac
done

# 아래에서 claude/chezmoi를 깔면 PATH에 ~/.local/bin을 export한다. 그러면 이
# 스크립트 안에서는 다 통하지만 "새 셸에서도 되는가"를 못 본다. 손대기 전 값을
# 따로 잡아두고 마지막 PATH 점검은 이걸로 한다.
PATH_AT_START="$PATH"

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      OS="other" ;;
esac

SETUP_SCRIPT="./setup-claude.sh"
# shellcheck source=lib-report.sh
source "$DOTFILES_DIR/lib-report.sh"

# --- 로컬 모드 경로 -----------------------------------------------------------
BASE="$(dirname "$DOTFILES_DIR")"
CFG="$BASE/.claude"
TOOLS="$BASE/.claude-setup"
ENV_FILE="$BASE/claude-env.sh"

# BASE가 홈이면 BASE/.claude 가 곧 ~/.claude 다. 이때 CLAUDE_CONFIG_DIR을 ~/.claude로
# 박아버리면 Claude Code가 로그인 정보(.claude.json)를 ~/.claude.json 이 아니라
# ~/.claude/.claude.json 에서 찾아 기존 로그인이 안 보인다. 그래서 전역 모드로 돈다.
if [ "$MODE" = "local" ] && [ "$BASE" = "$HOME" ]; then
    if [ "$RESET" = 1 ]; then
        err "상위 디렉토리가 홈($HOME)이다 — 지울 대상이 전역 ~/.claude 라서 --reset을 거부한다."
        echo "     전역 설정을 정말 지우려면 직접: claude auth logout && rm -rf ~/.claude ~/.claude.json"
        exit 1
    fi
    echo "※ 상위 디렉토리가 홈($HOME)이라 로컬 모드 = 전역 모드 — 전역 모드(~/.claude)로 진행한다."
    MODE="global"
fi
if [ "$RESET" = 1 ] && [ "$MODE" = "global" ]; then
    err "--reset은 로컬 모드 전용이다 (전역 모드는 덮어쓰기 전 원본을 보관하지 않아 되돌릴 게 없다)."
    exit 2
fi

if [ "$MODE" = "local" ]; then
    # statusLine.command 에 이 경로가 그대로 들어가고, 그 명령은 셸을 거쳐 실행된다.
    # 공백·따옴표 등이 있으면 상태줄이 조용히 깨지므로 처음부터 막는다.
    case "$BASE" in
        *[[:space:]\'\"\\\$\`\&\;\|\<\>\(\)\*\?\[]*)
            err "경로에 공백/따옴표/특수문자가 있다: $BASE"
            echo "     상태줄 명령이 깨진다 — 특수문자 없는 디렉토리 아래에 clone해서 다시 실행할 것."
            exit 1 ;;
    esac
    # 지난 실행에서 받아둔 claude/jq가 있으면 그걸 쓴다 (재실행 멱등).
    [ -d "$TOOLS/bin" ] && PATH="$TOOLS/bin:$PATH"
fi

# --- 원상복구 (--reset, 로컬 모드) -------------------------------------------
# 셋업이 만든 건 전부 BASE 아래 세 곳뿐이라, 로그아웃 후 그 셋을 지우면 끝이다.
if [ "$RESET" = 1 ]; then
    step "로컬 Claude 셋업 원상복구 (BASE: $BASE)"
    targets=()
    for p in "$CFG" "$TOOLS" "$ENV_FILE"; do
        if [ -e "$p" ] || [ -L "$p" ]; then targets+=("$p"); fi
    done
    if [ "${#targets[@]}" -eq 0 ]; then
        ok "지울 것 없음 — 이미 깨끗하다."
        exit 0
    fi
    echo "  지울 대상:"
    for p in "${targets[@]}"; do
        echo "    - $p  ($(du -sh "$p" 2>/dev/null | cut -f1))"
    done
    [ -d "$CFG" ] && echo "    ($CFG 에는 로그인 정보와 세션 기록이 들어있다)"
    if [ "$ASSUME_YES" != 1 ]; then
        if [ ! -t 0 ]; then
            err "확인할 터미널이 없다 — 지우려면 --yes 를 붙일 것."; exit 1
        fi
        read -r -p "  정말 지울까? [y/N] " ans
        case "$ans" in y|Y|yes|YES) ;; *) echo "  취소했다."; exit 1 ;; esac
    fi

    # 디렉토리만 지우면 이 머신의 토큰은 사라지지만, 로그아웃을 먼저 해서 계정 쪽에도
    # 이 세션을 정리할 기회를 준다. 실패해도(이미 로그아웃 등) 삭제는 진행한다.
    claude_bin=""
    if [ -x "$TOOLS/bin/claude" ]; then claude_bin="$TOOLS/bin/claude"
    elif have claude; then claude_bin="$(command -v claude)"; fi
    if [ -d "$CFG" ] && [ -n "$claude_bin" ]; then
        if CLAUDE_CONFIG_DIR="$CFG" "$claude_bin" auth logout >/dev/null 2>&1; then
            ok "claude 로그아웃"
        else
            warn "claude 로그아웃 실패 (이미 로그아웃 상태일 수 있음) — 토큰은 디렉토리째 지운다"
        fi
    fi

    # 가드: 위에서 계산한 세 경로 외엔 절대 지우지 않는다.
    case "$CFG" in */.claude) ;; *) err "예상 밖의 경로: $CFG — 중단"; exit 1 ;; esac
    if [ -z "$BASE" ] || [ "$BASE" = "/" ]; then err "예상 밖의 BASE: '$BASE' — 중단"; exit 1; fi
    rm -rf -- "${targets[@]}"
    for p in "${targets[@]}"; do ok "삭제: $p"; done

    echo ""
    echo "원상복구 완료 — BASE 밖은 이 셋업이 건드린 적이 없다."
    echo "  남는 것 (이 셋업 소관 아님):"
    echo "    - 작업한 저장소 안의 .claude/ (프로젝트별 권한·설정) — 필요하면 직접 지울 것"
    echo "    - /tmp/claude-$(id -u)/ — Claude Code 임시 파일. 같은 계정의 다른 사람 세션도"
    echo "      여기를 쓰므로 건드리지 않았다 (재부팅 시 정리됨)"
    exit 0
fi

if [ "$MODE" = "local" ]; then
    mkdir -p "$TOOLS"
    LOG="$TOOLS/setup.log"
else
    LOG="/tmp/setup-claude.log"
fi
: > "$LOG"

if [ "$MODE" = "local" ]; then
    step "모드: 로컬 — $BASE 아래에만 설치·설정"
    echo "  설정·로그인·세션: $CFG"
    echo "  받은 도구·로그:   $TOOLS"
else
    step "모드: 전역 — ~/.claude"
fi

# --- 0. 사전 요구사항 점검 --------------------------------------------------
step "사전 요구사항 점검"
if have curl; then ok "curl"; else
    err "curl 없음 — claude CLI/chezmoi 다운로드 불가. 설치 후 재실행하라."; exit 1
fi

# --- 1. jq -------------------------------------------------------------------
# 상태줄이 세션 JSON을 읽는 유일한 수단이다. 없으면 경로·모델·effort·사용량이
# 전부 빠지고 user@host만 남는다. setup-shell.sh도 깔지만(SHELL_TOOLS_COMMON),
# 이 스크립트만 단독으로 돌리는 경우가 있어 여기서도 챙긴다.
# 로컬 모드는 apt(시스템 전체)를 안 쓰고 공식 정적 바이너리를 BASE에 받는다.
install_local_jq() {
    local os arch
    case "$OS" in mac) os="macos" ;; linux) os="linux" ;; *) return 1 ;; esac
    case "$(uname -m)" in
        x86_64|amd64)  arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) return 1 ;;
    esac
    mkdir -p "$TOOLS/bin"
    curl -fsSL -o "$TOOLS/bin/jq.part" \
        "https://github.com/jqlang/jq/releases/latest/download/jq-$os-$arch" >>"$LOG" 2>&1 \
        && chmod 755 "$TOOLS/bin/jq.part" \
        && "$TOOLS/bin/jq.part" --version >>"$LOG" 2>&1 \
        && mv "$TOOLS/bin/jq.part" "$TOOLS/bin/jq" \
        || { rm -f "$TOOLS/bin/jq.part"; return 1; }
    PATH="$TOOLS/bin:$PATH"
}
step "jq (상태줄 파서)"
if have jq; then
    already "jq"
elif [ "$SKIP_PACKAGES" = "1" ]; then
    skipped "jq" "SKIP_PACKAGES=1 — 상태줄이 user@host만 표시"
elif [ "$MODE" = "local" ]; then
    install_local_jq && newly "jq ($TOOLS/bin)" \
        || failed "jq" "정적 바이너리 다운로드 실패 — 상태줄이 user@host만 표시 (로그: $LOG)"
elif [ "$OS" = "mac" ] && have brew; then
    brew install jq >>"$LOG" 2>&1 && newly "jq" || failed "jq" "brew install 실패 (로그: $LOG)"
elif [ "$OS" = "linux" ] && have sudo; then
    sudo apt-get install -y jq >>"$LOG" 2>&1 && newly "jq" \
        || failed "jq" "apt 설치 실패 (로그: $LOG)"
else
    skipped "jq" "패키지 매니저 없음 — 상태줄이 user@host만 표시"
fi

# --- 2. claude CLI ----------------------------------------------------------
# npm판이 아니라 공식 네이티브 설치를 쓴다. sudo 없이 ~/.local 에 들어가고
# 자체 업데이트(claude update)가 붙는다.
# 로컬 모드: 공식 설치기는 경로가 $HOME 고정(~/.claude/downloads, ~/.local/bin,
# ~/.local/share/claude)이라 HOME을 BASE/.claude-setup/home 으로 바꿔 돌린다.
# 그러면 설치기의 부산물이 전부 BASE 안에 떨어진다.
step "claude CLI"
if have claude; then
    already "claude CLI" "$(claude --version 2>/dev/null | head -1) — $(command -v claude)"
elif [ "$SKIP_PACKAGES" = "1" ]; then
    skipped "claude CLI" "SKIP_PACKAGES=1"
elif [ "$MODE" = "local" ]; then
    echo "  … claude 설치 중 ($TOOLS — 공식 네이티브 설치)"
    mkdir -p "$TOOLS/home" "$TOOLS/bin"
    if curl -fsSL https://claude.ai/install.sh 2>>"$LOG" | HOME="$TOOLS/home" bash >>"$LOG" 2>&1 \
       && [ -x "$TOOLS/home/.local/bin/claude" ]; then
        ln -sf "$TOOLS/home/.local/bin/claude" "$TOOLS/bin/claude"
        PATH="$TOOLS/bin:$PATH"
        newly "claude CLI ($TOOLS/bin)"
    else
        failed "claude CLI" "설치 스크립트 실패 (로그: $LOG)"
    fi
else
    echo "  … claude 설치 중 (~/.local/bin — 공식 네이티브 설치)"
    if curl -fsSL https://claude.ai/install.sh 2>>"$LOG" | bash >>"$LOG" 2>&1; then
        export PATH="$HOME/.local/bin:$PATH"
        have claude && newly "claude CLI" \
                    || failed "claude CLI" "설치는 됐으나 PATH에 없음 — ~/.local/bin 확인"
    else
        failed "claude CLI" "설치 스크립트 실패 (로그: $LOG)"
    fi
fi

# --- 3. 설정 배포 -----------------------------------------------------------
if [ "$MODE" = "local" ]; then
    # chezmoi를 쓰면 ~/.config/chezmoi(설정·상태 DB)를 건드리게 된다 — 공용 계정에선
    # 남의 chezmoi 설정을 덮는 셈이라, 로컬 모드는 private_dot_claude/를 직접 복사한다.
    # chezmoi 접두사 규칙만 흉내낸다: executable_ → 755, private_ → 600, dot_ → '.'.
    step "Claude 설정 배포 → $CFG (매번 실행)"
    deploy_ok=1
    install -d -m 700 "$CFG" && chmod 700 "$CFG"
    for src in "$DOTFILES_DIR/private_dot_claude/"*; do
        name="${src##*/}"
        if [ ! -f "$src" ] || [ "${name%.tmpl}" != "$name" ]; then
            warn "건너뜀: $name (하위 디렉토리·템플릿은 로컬 모드 복사 대상 아님)"; continue
        fi
        mode=644
        case "$name" in
            executable_*) name="${name#executable_}"; mode=755 ;;
            private_*)    name="${name#private_}";    mode=600 ;;
        esac
        case "$name" in dot_*) name=".${name#dot_}" ;; esac
        install -m "$mode" "$src" "$CFG/$name" || deploy_ok=0
    done
    # repo의 settings.json은 ~/.claude/statusline.sh 를 가리킨다 — 이 위치로 바꿔 쓴다.
    old='~/.claude/statusline.sh'; new="$CFG/statusline.sh"
    if [ -f "$CFG/settings.json" ]; then
        s="$(cat "$CFG/settings.json")"
        printf '%s\n' "${s//"$old"/$new}" > "$CFG/settings.json"
        grep -qF "\"$new\"" "$CFG/settings.json" || deploy_ok=0
    fi
    if [ "$deploy_ok" = 1 ]; then
        newly "claude 설정 (source: $DOTFILES_DIR/private_dot_claude)"
    else
        failed "claude 설정" "복사 또는 statusLine 경로 치환 실패 — $CFG 확인"
    fi

    # 쓰기 전에 source 하는 파일. CLAUDE_CONFIG_DIR 하나로 설정·로그인·세션 기록이
    # 전부 $CFG 로 간다.
    step "환경 파일 → $ENV_FILE"
    {
        echo "# Claude Code — $BASE 전용 설정으로 띄운다. 사용: source $ENV_FILE && claude"
        echo "# setup-claude.sh가 생성 (재실행하면 다시 씀). 원상복구: $DOTFILES_DIR/setup-claude.sh --reset"
        echo "export CLAUDE_CONFIG_DIR='$CFG'"
        if [ -d "$TOOLS/bin" ] && [ -n "$(ls -A "$TOOLS/bin" 2>/dev/null)" ]; then
            echo "case \":\$PATH:\" in *':$TOOLS/bin:'*) ;; *) export PATH='$TOOLS/bin':\"\$PATH\" ;; esac"
        fi
        if [ -x "$TOOLS/bin/claude" ]; then
            echo "# 자동 업데이트는 HOME(공용 ~/.local)에 새 버전을 깐다 — 끈다. 갱신은 --reset 후 재셋업."
            echo "export DISABLE_AUTOUPDATER=1"
        fi
    } > "$ENV_FILE"
    ok "생성"
else
    # --- 2b. chezmoi ----------------------------------------------------------
    step "chezmoi (설정 배포 도구)"
    if have chezmoi; then
        already "chezmoi"
    else
        echo "  … chezmoi 설치 중 (~/.local/bin)"
        if sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin" >>"$LOG" 2>&1; then
            export PATH="$HOME/.local/bin:$PATH"
            newly "chezmoi"
        else
            failed "chezmoi" "설치 스크립트 실패 (로그: $LOG)"; print_summary; exit 1
        fi
    fi

    # sourceDir은 항상 이 repo로 강제. 예전 셋업이 남긴 chezmoi.toml이 옛 clone을
    # 가리키고 있으면 엉뚱한 설정이 배포된다.
    # --force: 타깃이 밖에서 수정됐을 때(= Claude Code가 스스로 쓴 경우) 뜨는
    # overwrite 프롬프트가 로그 리다이렉트에 가려 무한 대기하는 것을 막는다.
    step "~/.claude 설정 배포 (chezmoi apply — 매번 실행)"
    mkdir -p "$HOME/.config/chezmoi"
    printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
    if chezmoi apply --force --source "$DOTFILES_DIR" "$HOME/.claude" >>"$LOG" 2>&1; then
        newly "claude 설정 (source: $DOTFILES_DIR)"
    else
        failed "claude 설정" "chezmoi apply 실패 (로그: $LOG)"
    fi
fi

# --- 4. 상태줄 점검 ---------------------------------------------------------
# 설정만 깔아두고 끝내면, 상태줄이 안 뜰 때 스크립트가 문제인지 Claude Code가
# 아직 설정을 못 읽은 건지 구분이 안 된다. 여기서 실제로 한 번 렌더해본다.
step "상태줄 점검"
if [ "$MODE" = "local" ]; then SL="$CFG/statusline.sh"; else SL="$HOME/.claude/statusline.sh"; fi
if [ -x "$SL" ]; then
    probe='{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"probe"},"effort":{"level":"high"}}'
    if [ "$MODE" = "local" ]; then export CLAUDE_CONFIG_DIR="$CFG"; fi
    if rendered=$(printf '%s' "$probe" | "$SL" 2>>"$LOG") \
       && [ -n "$rendered" ]; then
        ok "상태줄 렌더 확인: $rendered"
    else
        failed "상태줄" "statusline.sh가 빈 출력 (로그: $LOG)"
    fi
else
    failed "상태줄" "$SL 없음 — 배포 단계 실패"
fi

# --- 5. PATH 점검 (전역 모드) -----------------------------------------------
# claude와 chezmoi는 ~/.local/bin에 깔린다. 이 스크립트 안에서는 위에서 export한
# 덕에 통하지만, 새 셸의 PATH에 없으면 'claude: command not found'가 난다.
# (macOS 기본 zsh는 ~/.local/bin을 PATH에 안 넣는다.)
# 셸 rc는 setup-shell.sh 영역이라 여기서 고치지 않고 알려만 준다 — 공용 머신에서
# 남의 rc를 건드리지 않는다는 이 저장소의 방침.
# 로컬 모드는 claude-env.sh가 PATH를 챙기므로 점검할 게 없다.
if [ "$MODE" = "global" ]; then
    step "PATH 점검"
    case ":$PATH_AT_START:" in
        *":$HOME/.local/bin:"*)
            ok "~/.local/bin 이 PATH에 있음" ;;
        *)
            warn "~/.local/bin 이 PATH에 없다 — 새 셸에서 claude를 못 찾는다"
            echo "     고치는 법 (둘 중 하나):"
            echo "       ./setup-shell.sh                        # 권장 — PATH 포함 셸 설정 배포"
            echo "       echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
            ;;
    esac
fi

print_summary

echo ""
echo "Claude Code 셋업 완료."
if [ "$MODE" = "local" ]; then
    echo "  쓰는 법 (셸마다 한 번):"
    echo "    source $ENV_FILE && claude"
    echo "  첫 실행 때 로그인 1회 (브라우저 인증) — 로그인 정보는 $CFG 에 저장된다."
    echo "  주의: source 없이 그냥 'claude'를 치면 이 계정 공용 ~/.claude 를 쓴다"
    echo "        (같은 계정을 쓰는 다른 사람의 로그인·기록일 수 있다)."
    echo "  주의: 같은 리눅스 계정을 쓰는 사람은 $CFG 도 읽을 수 있다 — 다 쓰면 바로:"
    echo "    $DOTFILES_DIR/setup-claude.sh --reset"
else
    echo "  로그인은 스크립트로 못 한다 — 'claude' 실행 후 브라우저 인증 1회."
    echo "  상태줄은 이미 떠 있는 세션엔 안 붙는다. 새로 띄우면 하단에 나온다:"
    echo "    사용자@호스트  경로  git브랜치  계정  모델 effort"
    echo "  TUI(/config)에서 설정을 바꿨다면 repo로 되담을 것: chezmoi re-add ~/.claude/settings.json"
fi
