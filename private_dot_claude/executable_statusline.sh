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
# 경로가 길면 뒤쪽만 남겨 줄인다 (아래 "경로가 길면" 절 — 다른 칸이 밀려나지 않게).

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

# ── 경로가 길면 뒤쪽만 남긴다 ─────────────────────────────────────────────
# 상태줄은 터미널 폭을 넘으면 뒤가 잘린다. 경로가 앞쪽에 있어서 경로가 길면
# 브랜치·계정·모델·ctx·사용량이 통째로 밀려나 안 보인다. 그래서 경로에 폭 예산을
# 두고, 넘으면 아래 순서로 줄여서 예산 안에 드는 첫 모양을 쓴다:
#   1) 그대로                    ~/work/dotfiles
#   2) 앞 생략 + 뒤 두 단계      ~/…/제안서및평가/1차년도_연장공고제안서
#   3) 앞 생략 + 마지막 단계     ~/…/1차년도_연장공고제안서
#   4) 마지막 단계 가운데 생략   ~/…/1차년도_연…고제안서
# 예산은 화면 칸 수 기준(한글·한자 1자 = 2칸). 기본 40, CLAUDE_STATUSLINE_PATH_MAX로 조정.
#
# 바이트 단위로 문자를 가른다(LC_ALL=C). 상태줄이 어떤 로케일로 실행될지 모르고,
# 로케일에 따라 ${#s}가 바이트를 세기도 문자를 세기도 해서 믿을 수 없다.
# 3바이트 이상 UTF-8 문자는 2칸으로 센다 — 한글·한자는 정확하고, 그 밖의 기호는
# 실제보다 넓게 잡혀 조금 더 줄어들 뿐이다(넘치는 쪽으로 틀리지 않는다).
PATH_MAX_W="${CLAUDE_STATUSLINE_PATH_MAX:-40}"
case "$PATH_MAX_W" in ''|*[!0-9]*) PATH_MAX_W=40 ;; esac

# $1을 문자 단위로 쪼개 전역 배열 _ch(문자) / _cw(칸 수)에 담고, 합계를 _W에 둔다.
# 결과를 echo 대신 전역에 두는 이유: $(...)는 매번 fork라 상태줄 갱신마다 쌓인다.
_split_chars() {
  local LC_ALL=C s=$1 n w i=0
  _ch=(); _cw=(); _W=0
  while [ -n "$s" ]; do
    case "${s:0:1}" in
      [$'\xf0'-$'\xff']) n=4; w=2 ;;
      [$'\xe0'-$'\xef']) n=3; w=2 ;;
      [$'\xc0'-$'\xdf']) n=2; w=1 ;;
      *)                 n=1; w=1 ;;
    esac
    _ch[i]=${s:0:n}; _cw[i]=$w; _W=$((_W + w)); s=${s:n}; i=$((i + 1))
  done
}

# $1을 $2칸 이내로 가운데를 …로 줄여 _OUT에 둔다 (앞쪽은 날짜·번호, 뒤쪽은 구분되는
# 이름인 경우가 많아서 양끝을 살린다). 문자 경계에서만 자르므로 글자가 깨지지 않는다.
_mid_trunc() {
  local max=$2 hw tw w i j n head="" tail=""
  _split_chars "$1"
  if [ "$_W" -le "$max" ]; then _OUT=$1; return; fi
  n=${#_ch[@]}
  hw=$(( (max - 1) / 2 )); tw=$(( max - 1 - hw ))      # … 이 1칸
  i=0; w=0
  while [ "$i" -lt "$n" ] && [ $((w + _cw[i])) -le "$hw" ]; do
    head="$head${_ch[i]}"; w=$((w + _cw[i])); i=$((i + 1))
  done
  j=$((n - 1)); w=0
  while [ "$j" -ge "$i" ] && [ $((w + _cw[j])) -le "$tw" ]; do
    tail="${_ch[j]}$tail"; w=$((w + _cw[j])); j=$((j - 1))
  done
  # 중괄호 필수: bash 5는 "$head…"에서 …의 첫 바이트를 변수 이름으로 읽어 깨뜨린다
  _OUT="${head}…${tail}"
}

_shorten_path() {   # $1=경로(~ 치환 후)  $2=최대 칸 → _OUT
  local p=$1 max=$2 anchor rest last1 head last2 more cand pre
  _split_chars "$p"
  if [ "$_W" -le "$max" ]; then _OUT=$p; return; fi
  case "$p" in "~"*) anchor="~" ;; *) anchor="" ;; esac
  rest=${p#"$anchor"}; rest=${rest#/}                     # a/b/c/d
  last1=${rest##*/}
  head=${rest%/*};  [ "$head" = "$rest" ] && head=""      # a/b/c (마지막 제외)
  last2=${head##*/}
  more=${head%/*};  [ "$more" = "$head" ] && more=""      # 뒤 두 단계 앞에 더 있나
  if [ -n "$more" ]; then                                 # 2) 뒤 두 단계
    cand="$anchor/…/$last2/$last1"
    _split_chars "$cand"; if [ "$_W" -le "$max" ]; then _OUT=$cand; return; fi
  fi
  if [ -n "$head" ]; then pre="$anchor/…/"; else pre="$anchor/"; fi
  if [ -n "$head" ]; then                                 # 3) 마지막 단계
    cand="$pre$last1"
    _split_chars "$cand"; if [ "$_W" -le "$max" ]; then _OUT=$cand; return; fi
  fi
  _split_chars "$pre"                                     # 4) 마지막 단계 가운데 생략
  local avail=$((max - _W)); [ "$avail" -lt 8 ] && avail=8
  _mid_trunc "$last1" "$avail"
  _OUT="$pre$_OUT"
}

# 맥은 한글 파일명을 자모 분해형(NFD: ㅈ+ㅔ)으로 저장한다. 그대로 자르면 글자가
# 쪼개지고 폭도 두 배로 잡힌다 → 비ASCII가 있을 때만 완성형(NFC)으로 바꾼다.
# (iconv의 UTF-8-MAC은 맥 전용. 리눅스 경로는 원래 완성형이라 할 필요가 없다.)
_has_nonascii() { local LC_ALL=C; case "$1" in *[$'\x80'-$'\xff']*) return 0 ;; esac; return 1; }
case "$OSTYPE" in
  darwin*)
    if _has_nonascii "$path"; then
      nfc=$(printf '%s' "$path" | iconv -f UTF-8-MAC -t UTF-8 2>/dev/null) && [ -n "$nfc" ] && path=$nfc
    fi ;;
esac
_shorten_path "$path" "$PATH_MAX_W"; path=$_OUT

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
