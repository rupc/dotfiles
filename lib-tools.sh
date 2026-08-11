#!/usr/bin/env bash
# ============================================================================
# 셸 CLI 툴 목록 — setup-shell.sh(설치)와 status.sh(점검)가 공유한다.
# (실행 파일 아님 — source 해서 쓴다)
#
# 목록이 두 군데로 갈라지면 "설치는 되는데 상태 표시에는 안 잡히는" 툴이 생긴다.
# 툴을 추가할 때는 여기 세 곳만 보면 된다:
#   SHELL_TOOLS_COMMON  설치 대상 (mac=brew, linux=apt)
#   GH_RELEASE_TOOLS    apt에 없어서 GitHub 릴리스로 받아야 하는 것
#   describe()          요약/상태 출력에 붙는 한 줄 설명
# ============================================================================

# mac/linux 양쪽에서 쓰는 툴만. mac 전용(mactop/asitop/thefuck)은 Brewfile + setup-macos.sh.
SHELL_TOOLS_COMMON=(
    fzf fzy autojump zoxide
    htop btop ncdu duf glances
    tree eza bat jq yq hexyl
    tmux lazygit direnv entr hyperfine tldr shellcheck
    httpie mtr gh navi broot yazi rsync
    lazydocker dive k9s
    fastfetch onefetch vivid procs dust sd gping doggo glow
    bandwhich cmatrix genact
)

# apt에 없는 툴 — GitHub 릴리스에서 ~/.local/bin으로 (sudo 불필요).
# 전부 Go/Rust 단일 바이너리 프로젝트라 배포 방식이 GitHub 릴리스뿐이다.
# 자산 이름 규칙이 제각각(linux_x86_64 / Linux_x86_64 / x86_64-unknown-linux-musl /
# linux-amd64)이라 파일명을 박아두면 금방 썩는다 -> 릴리스 API + 툴별 정규식으로 고른다.
#   형식: 바이너리[,같이나오는바이너리]|GitHub repo|자산 정규식
#   %A%  : 아키텍처 표기 흔들림(x86_64/amd64, aarch64/arm64)을 흡수하는 자리표시자
GH_RELEASE_TOOLS=(
    "lazygit|jesseduffield/lazygit|_linux_%A%\.tar\.gz$"
    "lazydocker|jesseduffield/lazydocker|_Linux_%A%\.tar\.gz$"
    "navi|denisidoro/navi|%A%-unknown-linux-(musl|gnu)\.tar\.gz$"
    "broot|Canop/broot|^https.*/broot_[0-9.]+\.zip$"
    "yazi,ya|sxyazi/yazi|yazi-%A%-unknown-linux-(musl|gnu)\.zip$"
    "dive|wagoodman/dive|_linux_%A%\.tar\.gz$"
    "k9s|derailed/k9s|k9s_[Ll]inux_%A%\.tar\.gz$"
    "fastfetch|fastfetch-cli/fastfetch|fastfetch-linux-%A%\.tar\.gz$"
    "onefetch|o2sh/onefetch|onefetch-linux\.tar\.gz$"
    "procs|dalance/procs|-%A%-linux\.zip$"
    "dust|bootandy/dust|dust-v[0-9.]+-%A%-unknown-linux-(gnu|musl)\.tar\.gz$"
    "doggo|mr-karan/doggo|doggo-linux-%A%\.tar\.gz$"
    "glow|charmbracelet/glow|_Linux_%A%\.tar\.gz$"
    "bandwhich|imsnif/bandwhich|-%A%-unknown-linux-(musl|gnu)\.tar\.gz$"
    "genact|svenstaro/genact|genact-[0-9.]+-%A%-unknown-linux-musl$"
)

# 기능별 묶음 — status.sh가 "44종 나열" 대신 이 순서/그룹으로 보여준다.
# SHELL_TOOLS_COMMON + (chezmoi fd ripgrep git-delta)의 모든 툴이 정확히 한 번씩
# 들어가야 한다. 빠뜨린 게 있으면 status.sh가 '기타'로 몰아서 보여주니 그때 채우면 된다.
#   형식: 그룹명|툴 툴 툴
TOOL_GROUPS=(
    "검색·탐색|fzf fzy fd ripgrep zoxide autojump broot yazi tree"
    "파일 보기|eza bat hexyl glow"
    "시스템 모니터링|htop btop glances procs fastfetch"
    "디스크·용량|ncdu duf dust"
    "네트워크|httpie mtr gping doggo bandwhich rsync"
    "개발 워크플로우|tmux lazygit gh git-delta direnv entr hyperfine shellcheck onefetch"
    "텍스트·데이터|jq yq sd tldr navi"
    "컨테이너·쿠버네티스|lazydocker dive k9s"
    "dotfiles·꾸미기|chezmoi vivid"
    "장난감|cmatrix genact"
)

# 패키지 이름과 실행파일 이름이 다른 것들 (콤마 = 후보 여럿, 하나라도 있으면 설치된 것)
# 데비안이 실행파일명을 바꿔 다는 경우(fd->fdfind, bat->batcat)까지 포함.
tool_cmd() {
    case "$1" in
        ripgrep)   echo "rg" ;;
        git-delta) echo "delta" ;;
        httpie)    echo "http" ;;
        fd|fd-find) echo "fd,fdfind" ;;
        bat)       echo "bat,batcat" ;;
        *)         echo "$1" ;;
    esac
}

# 요약/상태 출력의 한 줄 설명 (lib-report.sh가 훅으로 호출) — "이게 뭐였더라"를 없애기 위한 것
describe() {
    case "$1" in
    zsh)        echo "기본 셸" ;;
    git)        echo "버전 관리" ;;
    curl)       echo "HTTP 다운로드" ;;
    chezmoi)    echo "dotfiles 배포/관리" ;;
    fd|fd-find) echo "find 대체 — 빠르고 문법이 단순" ;;
    ripgrep)    echo "grep 대체 — 초고속 재귀 검색 (rg)" ;;
    git-delta)  echo "git diff를 읽기 좋게 렌더링" ;;
    watch)      echo "명령을 주기적으로 반복 실행" ;;
    fzf)        echo "퍼지 파인더 — Ctrl-R 히스토리, Ctrl-T 파일" ;;
    fzy)        echo "가벼운 퍼지 셀렉터 — 스크립트 파이프용" ;;
    autojump)   echo "자주 간 디렉토리로 점프 (j)" ;;
    zoxide)     echo "더 빠른 디렉토리 점프 (z) — autojump 후속" ;;
    htop)       echo "대화형 프로세스 뷰어" ;;
    btop)       echo "그래프형 리소스 모니터 (CPU/메모리/네트워크)" ;;
    ncdu)       echo "디스크 사용량 탐색기 — 어디가 꽉 찼는지" ;;
    duf)        echo "df 대체 — 마운트별 용량을 표로" ;;
    glances)    echo "시스템 전반 한 화면 모니터" ;;
    tree)       echo "디렉토리 구조를 트리로 출력" ;;
    eza)        echo "ls 대체 — 아이콘/git 상태/트리" ;;
    bat)        echo "cat 대체 — 문법 하이라이팅 + 페이저" ;;
    jq)         echo "JSON 질의/변환" ;;
    yq)         echo "YAML/TOML/XML 질의 — jq 문법" ;;
    hexyl)      echo "16진수 덤프 뷰어 — 색으로 구분" ;;
    tmux)       echo "터미널 멀티플렉서 — 세션 유지/분할" ;;
    lazygit)    echo "터미널 git UI — 스테이징/브랜치/리베이스" ;;
    direnv)     echo "디렉토리별 환경변수 자동 로드 (.envrc)" ;;
    entr)       echo "파일 변경을 감지해 명령 재실행" ;;
    hyperfine)  echo "명령 실행시간 벤치마크 — 통계까지" ;;
    tldr)       echo "man 요약판 — 실전 예제 위주" ;;
    shellcheck) echo "셸 스크립트 정적 분석" ;;
    httpie)     echo "읽기 좋은 HTTP 클라이언트 (http)" ;;
    mtr)        echo "traceroute+ping — 실시간 경로 진단" ;;
    gh)         echo "GitHub CLI — PR/이슈/릴리스" ;;
    navi)       echo "커맨드 치트시트 실행기 (Ctrl-G)" ;;
    broot)      echo "디렉토리 트리 탐색/점프 (br)" ;;
    yazi)       echo "터미널 파일 매니저 — 이미지 미리보기 (y)" ;;
    rsync)      echo "증분/이어받기 파일 동기화 — 원격 포함" ;;
    lazydocker) echo "터미널 도커 UI — 컨테이너/로그/이미지" ;;
    dive)       echo "도커 이미지 레이어 분석 — 용량 낭비 찾기" ;;
    k9s)        echo "쿠버네티스 클러스터 터미널 UI" ;;
    fastfetch)  echo "시스템 정보 스플래시 — 새 터미널마다" ;;
    onefetch)   echo "git repo 요약 — 언어 비율/기여자" ;;
    vivid)      echo "LS_COLORS 테마 생성기" ;;
    procs)      echo "ps 대체 — 트리/검색/색상" ;;
    dust)       echo "du 대체 — 용량 큰 디렉토리를 그래프로" ;;
    sd)         echo "sed 대체 — 직관적인 문자열 치환" ;;
    gping)      echo "ping 결과를 실시간 그래프로" ;;
    doggo)      echo "dig 대체 DNS 조회 — DoH/DoT 지원" ;;
    glow)       echo "마크다운을 터미널에서 렌더링해 읽기" ;;
    bandwhich)  echo "프로세스별 실시간 대역폭 사용량" ;;
    cmatrix)    echo "매트릭스 화면보호기" ;;
    genact)     echo "가짜 작업 로그 생성기 — 바빠 보이기용" ;;
    esac
}
