#!/usr/bin/env bash
# ============================================================================
# Claude Code 환경만 셋업 — CLI + ~/.claude 설정(상태줄 포함)
# (셸/에디터는 건드리지 않음)
#
# 상태줄은 "지금 어느 머신의 어느 경로에서, 어떤 계정·모델·effort로 돌고 있는지"를
# 한 줄로 보여준다. 머신을 옮겨다니며 여러 세션을 띄우면 이게 없을 때 어느 창이
# 어디에 붙어 있는지 헷갈린다.
#
#   jyr@bsp-server-13  ~/dotfiles  main*  me@example.com  Opus 5 xhigh
#
# 배포되는 것 (chezmoi, private_dot_claude/):
#   ~/.claude/settings.json    모델·effort·TUI 취향 + statusLine 연결
#   ~/.claude/statusline.sh    상태줄 렌더러
#   ~/.claude/                 디렉토리 자체는 0700 (세션 기록이 들어있다)
# 세션 기록(projects/, sessions/, history.jsonl)은 chezmoi 관리 대상이 아니라
# 그대로 남는다 — 이 스크립트는 위 두 파일만 덮어쓴다.
#
# 주의: settings.json은 Claude Code가 스스로도 쓴다(/config, 모델 변경, 각종 동의
# 다이얼로그). 이 스크립트를 다시 돌리면 repo 내용으로 덮인다 — repo가 source of
# truth. TUI에서 바꾼 걸 살리려면 먼저 되담을 것:
#   chezmoi re-add ~/.claude/settings.json
#
# 사용법:
#   ./setup-claude.sh                  # CLI 없으면 설치까지
#   SKIP_PACKAGES=1 ./setup-claude.sh  # 설정만 배포 (CLI 설치 안 함)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SKIP_PACKAGES="${SKIP_PACKAGES:-0}"

SETUP_SCRIPT="./setup-claude.sh"
# shellcheck source=lib-report.sh
source "$DOTFILES_DIR/lib-report.sh"

LOG="/tmp/setup-claude.log"; : > "$LOG"

# --- 0. 사전 요구사항 점검 --------------------------------------------------
step "사전 요구사항 점검"
if have curl; then ok "curl"; else
    err "curl 없음 — claude CLI/chezmoi 다운로드 불가. 설치 후 재실행하라."; exit 1
fi
# jq는 setup-shell.sh가 깐다(SHELL_TOOLS_COMMON). 없어도 상태줄은 뜨지만
# 경로/모델/effort를 못 읽어서 user@host 만 남는다.
if have jq; then ok "jq"; else
    warn "jq 없음 — 상태줄이 경로·모델·effort를 못 읽는다 (./setup-shell.sh로 설치)"
fi

# --- 1. claude CLI ----------------------------------------------------------
# npm판이 아니라 공식 네이티브 설치를 쓴다. sudo 없이 ~/.local 에 들어가고
# 자체 업데이트(claude update)가 붙는다.
step "claude CLI"
if have claude; then
    already "claude CLI" "$(claude --version 2>/dev/null | head -1)"
elif [ "$SKIP_PACKAGES" = "1" ]; then
    skipped "claude CLI" "SKIP_PACKAGES=1"
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

# --- 2. chezmoi -------------------------------------------------------------
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

# --- 3. ~/.claude 설정 배포 -------------------------------------------------
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

# --- 4. 상태줄 점검 ---------------------------------------------------------
# 설정만 깔아두고 끝내면, 상태줄이 안 뜰 때 스크립트가 문제인지 Claude Code가
# 아직 설정을 못 읽은 건지 구분이 안 된다. 여기서 실제로 한 번 렌더해본다.
step "상태줄 점검"
if [ -x "$HOME/.claude/statusline.sh" ]; then
    probe='{"workspace":{"current_dir":"'"$PWD"'"},"model":{"display_name":"probe"},"effort":{"level":"high"}}'
    if rendered=$(printf '%s' "$probe" | "$HOME/.claude/statusline.sh" 2>>"$LOG") \
       && [ -n "$rendered" ]; then
        ok "상태줄 렌더 확인: $rendered"
    else
        failed "상태줄" "statusline.sh가 빈 출력 (로그: $LOG)"
    fi
else
    failed "상태줄" "~/.claude/statusline.sh 없음 — 배포 단계 실패"
fi

print_summary

echo ""
echo "Claude Code 셋업 완료."
echo "  로그인은 스크립트로 못 한다 — 'claude' 실행 후 브라우저 인증 1회."
echo "  상태줄은 이미 떠 있는 세션엔 안 붙는다. 새로 띄우면 하단에 나온다:"
echo "    사용자@호스트  경로  git브랜치  계정  모델 effort"
echo "  TUI(/config)에서 설정을 바꿨다면 repo로 되담을 것: chezmoi re-add ~/.claude/settings.json"
