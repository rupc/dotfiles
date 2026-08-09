#!/usr/bin/env bash
# ============================================================================
# 셋업 스크립트 공용 로깅/집계 헬퍼 (실행 파일 아님 — source 해서 쓴다)
#
#   SETUP_SCRIPT="./setup-shell.sh"          # 요약 끝의 재실행 안내에 쓰임
#   source "$DOTFILES_DIR/lib-report.sh"
#
#   step "단계 제목"                          # 굵은 헤더
#   ok/warn/err "메시지"                      # ✓ / ! / ✗ 단발 로그
#   already <이름> [부연]                      # 이미 있음 (집계됨)
#   newly   <이름>                            # 새로 설치 (집계됨)
#   skipped <이름> <사유>                      # 생략 + 사유 (집계됨)
#   failed  <이름> <사유>                      # 실패 + 사유 (집계됨)
#   print_summary                             # 마지막 요약표
#
# 집계 4종은 "무엇이 설치됐고 무엇이 왜 안 됐는지"를 마지막에 한눈에 보여주기 위한 것.
# 설치를 건너뛰거나 실패시킬 때는 반드시 사유를 같이 넘길 것.
# ============================================================================

if [ -t 1 ]; then
    C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_B=$'\033[1;34m'; C_0=$'\033[0m'
else
    C_G=""; C_Y=""; C_R=""; C_B=""; C_0=""
fi
step() { echo; echo "${C_B}==> $*${C_0}"; }
ok()   { echo "  ${C_G}✓${C_0} $*"; }
warn() { echo "  ${C_Y}!${C_0} $*"; }
err()  { echo "  ${C_R}✗${C_0} $*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# 항목마다 "이게 뭐 하는 물건인지" 한 줄 설명을 붙이고 싶으면 describe()를 정의해두면
# 된다(없으면 그냥 이름만 나온다). 툴 목록을 아는 건 각 셋업 스크립트라 훅으로 뺐다.
_desc() { command -v describe >/dev/null 2>&1 && describe "$1" || true; }

ALREADY=(); NEWLY=(); SKIPPED=(); FAILED=()
already() { local d; d=$(_desc "$1"); ALREADY+=("$1${d:+ — $d}"); ok "$1: 이미 설치됨${2:+ ($2)}${d:+ — $d}"; }
newly()   { local d; d=$(_desc "$1"); NEWLY+=("$1${d:+ — $d}");   ok "$1: 설치 완료${d:+ — $d}"; }
skipped() { local d; d=$(_desc "$1"); SKIPPED+=("$1${d:+ ($d)} — $2"); warn "$1: 생략 — $2${d:+ (${d})}"; }
failed()  { local d; d=$(_desc "$1"); FAILED+=("$1${d:+ ($d)} — $2");  err "$1: 실패 — $2${d:+ (${d})}"; }

print_summary() {
    step "요약: 이미 있음 ${#ALREADY[@]} / 새로 설치 ${#NEWLY[@]} / 생략 ${#SKIPPED[@]} / 실패 ${#FAILED[@]}"
    _list() {
        local title=$1; shift
        [ "$#" -eq 0 ] && return 0
        echo "  $title:"
        local item; for item in "$@"; do echo "    - $item"; done
    }
    _list "이미 있음" ${ALREADY[@]+"${ALREADY[@]}"}
    _list "새로 설치" ${NEWLY[@]+"${NEWLY[@]}"}
    _list "생략 (사유)" ${SKIPPED[@]+"${SKIPPED[@]}"}
    _list "실패 (사유)" ${FAILED[@]+"${FAILED[@]}"}
    if [ "${#SKIPPED[@]}" -gt 0 ] || [ "${#FAILED[@]}" -gt 0 ]; then
        echo "  → 사유(사전 요구사항 등) 해결 후 ${SETUP_SCRIPT:-이 스크립트}를 다시 실행하면"
        echo "    그 항목만 골라서 마저 설치된다 (멱등)."
    fi
}
