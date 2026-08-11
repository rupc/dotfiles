#!/usr/bin/env bash
# Claude Code 상태줄 — 어느 머신의, 어느 경로에서, 어떤 계정·모델로 돌고 있는지.
#
#   jyr@bsp-server-13  ~/dotfiles  main*  me@example.com  Opus 5 xhigh
#
# Claude Code가 이 스크립트를 실행하면서 세션 정보를 JSON으로 stdin에 넣어준다.
# 쓰는 필드: .workspace.current_dir (작업 경로), .model.display_name (모델),
#            .effort.level (추론 강도 — low/medium/high/xhigh/max),
#            .context_window.remaining_percentage (컨텍스트 잔량, 0~100 정수),
#            .rate_limits.{five_hour,seven_day} (결제 플랜 사용량).
#   effort는 모델이 지원할 때만 들어온다. 없으면 그 칸은 그냥 안 나온다.
#   잔량은 세션 시작 직후(아직 토큰을 안 쓴 상태)엔 null이라 역시 안 나온다.
#   rate_limits는 API 응답 헤더(anthropic-ratelimit-unified-*)에서 오므로
#   첫 응답을 받기 전까진 아예 없다. used_percentage는 0~100 실수(소수점 나옴 →
#   반올림해서 쓴다), resets_at은 유닉스 epoch 초.
#
# ctx와 rate_limit은 다른 것이다:
#   ctx  = 이 대화창이 얼마나 찼나 (넘으면 compact)
#   5h/7d = 결제 플랜 사용량 (넘으면 그 시간까지 못 씀)
#   전체 필드: cwd, session_id, model{}, workspace{}, version, output_style,
#   cost{}, context_window, exceeds_200k_tokens, rate_limits{}, vim{mode} 등.
# 호스트와 OS 계정은 JSON에 없으므로 시스템에서 직접 읽는다.
# Claude 로그인 계정은 ~/.claude.json 의 oauthAccount 에 들어있다.
#
# 배포: chezmoi (private_dot_claude/executable_statusline.sh -> ~/.claude/statusline.sh)
# 연결: ~/.claude/settings.json 의 statusLine.command 가 이 파일을 가리킨다.
# 출력은 한 줄. 이 스크립트가 실패해도 상태줄만 비고 세션은 멀쩡하다.
# mac 기본 bash 3.2에서도 도는 문법만 쓴다 (연관배열·${var^^} 같은 건 금지).

input=$(cat)

have_jq() { command -v jq >/dev/null 2>&1; }

# ── 세션 정보 (stdin JSON) ────────────────────────────────────────────────
cwd=""; model=""; effort=""; ctx=""; h5=""; h5r=""; d7=""; d7r=""
if have_jq; then
  # 한 번의 jq 호출로 전부 받는다 (상태줄은 자주 갱신되므로 프로세스를 아낀다).
  # 2>/dev/null: 페이로드가 깨졌을 때 jq 파스 에러가 상태줄에 새는 걸 막는다.
  # // 는 null도 걸러주므로 값이 null인 세션 초반엔 빈 문자열이 된다.
  # empty는 절대 쓰면 안 된다 — 배열에서 원소가 통째로 빠져 칸이 밀린다.
  #
  # 구분자가 탭이면 안 된다. bash는 탭을 "IFS 공백"으로 취급해서 연속된 탭을
  # 하나로 뭉갠다 — effort와 ctx가 동시에 빈 세션에서 칸이 두 개 밀려
  # 리셋 epoch가 ctx 자리에 "1786427095%"로 찍히는 걸 확인했다.
  # US(0x1F)는 IFS 공백이 아니라서 빈 칸이 빈 칸으로 그대로 온다.
  IFS=$'\037' read -r cwd model effort ctx h5 h5r d7 d7r <<<"$(
    printf '%s' "$input" |
      jq -j '
        def pct(v): if (v|type) == "number" then (v|round|tostring) else "" end;
        [ (.workspace.current_dir // .cwd // ""),
          (.model.display_name // ""),
          (.effort.level // ""),
          (.context_window.remaining_percentage // "" | tostring),
          pct(.rate_limits.five_hour.used_percentage),
          (.rate_limits.five_hour.resets_at // "" | tostring),
          pct(.rate_limits.seven_day.used_percentage),
          (.rate_limits.seven_day.resets_at // "" | tostring)
        ] | join("\u001f")' 2>/dev/null
  )"
fi
[ -n "$cwd" ] || cwd="$PWD"

# ── 경로: 홈 아래면 ~ 로 줄인다 ───────────────────────────────────────────
case "$cwd" in
  "$HOME")   path="~" ;;
  "$HOME"/*) path="~${cwd#"$HOME"}" ;;
  *)         path="$cwd" ;;
esac

# ── 호스트 / OS 계정 ──────────────────────────────────────────────────────
host="${HOSTNAME:-$(hostname 2>/dev/null)}"
host="${host%%.*}"                 # bsp-server-13.example.com, mbp.local -> 앞부분만
user="${USER:-$(id -un 2>/dev/null)}"

# ── Claude 로그인 계정 ────────────────────────────────────────────────────
account=""
if have_jq && [ -r "$HOME/.claude.json" ]; then
  account=$(jq -r '.oauthAccount.emailAddress // empty' "$HOME/.claude.json" 2>/dev/null)
fi

# ── git 브랜치 (저장소 안일 때만, * = 커밋 안 한 변경 있음) ───────────────
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
if [ -n "$branch" ]; then
  git -C "$cwd" diff --quiet --ignore-submodules HEAD -- 2>/dev/null || branch="${branch}*"
fi

# ── 출력 ──────────────────────────────────────────────────────────────────
D=$'\033[2m'; R=$'\033[0m'         # dim / reset
C=$'\033[36m'; Y=$'\033[33m'; M=$'\033[35m'; G=$'\033[32m'; RED=$'\033[31m'
# 누가/어디서 돌고 있나는 상태줄에서 제일 자주 확인하는 정보다. dim(\033[2m)으로
# 두니 배경에 묻혀서 안 읽혔다 — 256색으로 빼서 대비를 준다.
# 색을 바꾸고 싶으면 이 두 숫자만 건드리면 된다 (`for i in $(seq 0 255)` 로 확인).
LGREEN=$'\033[38;5;157m'           # 옅은 초록 — 사용자@호스트
LPINK=$'\033[38;5;218m'            # 연분홍   — 로그인 계정

out="${LGREEN}${user}@${host}${R}  ${C}${path}${R}"
[ -n "$branch"  ] && out="${out}  ${Y}${branch}${R}"
[ -n "$account" ] && out="${out}  ${LPINK}${account}${R}"
[ -n "$model"   ] && out="${out}  ${M}${model}${R}"
[ -n "$effort"  ] && out="${out} ${G}${effort}${R}"

# 컨텍스트 잔량 — 색이 곧 경고다. 숫자를 읽기 전에 빨간색이 먼저 눈에 들어와야
# 컴팩션이 임박한 걸 알아챈다. 정수가 아닌 값이 오면 그냥 안 그린다.
# 주의: 이건 "남은" 값이라 작을수록 위험하다 (아래 플랜 사용량과 방향이 반대).
case "$ctx" in
  ''|*[!0-9]*) ;;
  *)
    if   [ "$ctx" -le 15 ]; then ctx_c="$RED"
    elif [ "$ctx" -le 35 ]; then ctx_c="$Y"
    else                         ctx_c="$G"
    fi
    out="${out}  ${D}ctx${R} ${ctx_c}${ctx}%${R}"
    ;;
esac

# 결제 플랜 사용량 — 이쪽은 "쓴" 값이라 클수록 위험하다.
# 한도에 가까워졌을 때만 리셋까지 남은 시간을 붙인다. 여유 있을 땐 알 필요가
# 없고, 상태줄에 항상 띄우기엔 폭이 아깝다.
usage_seg() {   # $1=라벨(5h/7d)  $2=사용%  $3=리셋 epoch
    case "$2" in ''|*[!0-9]*) return 0 ;; esac
    local c seg now left
    if   [ "$2" -ge 85 ]; then c="$RED"
    elif [ "$2" -ge 60 ]; then c="$Y"
    else                       c="$G"
    fi
    seg="  ${D}$1${R} ${c}$2%${R}"
    if [ "$2" -ge 80 ]; then
        case "$3" in
            ''|*[!0-9]*) ;;
            *)
                now=$(date +%s)
                left=$(( $3 - now ))
                if [ "$left" -gt 0 ]; then
                    if [ "$left" -ge 3600 ]; then
                        seg="${seg}${D}→$(( left / 3600 ))h$(( left % 3600 / 60 ))m${R}"
                    else
                        seg="${seg}${D}→$(( left / 60 ))m${R}"
                    fi
                fi
                ;;
        esac
    fi
    printf '%s' "$seg"
}

out="${out}$(usage_seg 5h "$h5" "$h5r")"
out="${out}$(usage_seg 7d "$d7" "$d7r")"

printf '%s' "$out"
