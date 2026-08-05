# 이 저장소 셋업에 필요한 Homebrew 패키지 목록 (mac 전용 — setup-macos.sh가 소비)
# 사용법: brew bundle --file=Brewfile
#
# mac/linux 공용 툴은 setup-shell.sh / setup-nvim.sh에도 설치 로직이 있고,
# setup-macos.sh는 SKIP_PACKAGES=1로 그 중복을 막는다.
# 아래 "mac에서만" 섹션은 리눅스에 없거나 불필요한 것들 — 공용 스크립트에 넣지 말 것.

# --- mac에서만 ---
brew "mactop"    # Apple Silicon CPU/GPU 모니터
brew "asitop"    # Apple Silicon 전력 모니터
brew "thefuck"   # 직전 커맨드 오타 교정 ('fuck' 입력)
                 # — apt판(3.29)은 Python 3.12+ 에서 imp 제거로 깨져 리눅스에선 미설치

# 셸 & dotfiles 관리
brew "chezmoi"
brew "fzf"
brew "fzy"
brew "autojump"

# 에디터
brew "neovim"

# 언어 런타임 / 버전 관리
brew "go"
brew "node"
brew "nvm"
brew "python@3.14"

# 컨테이너 — Docker Desktop 대신 colima 사용 (sudo 불필요, CLI 전용)
brew "docker"
brew "docker-compose"
brew "colima"

# GitHub CLI
brew "gh"

# --- 개발 편의 CLI 툴 ---

# 시스템 모니터링
brew "htop"
brew "btop"
brew "ncdu"
brew "duf"
brew "glances"

# 파일 탐색/검색 (모던 대체)
brew "tree"
brew "eza"       # ls 대체
brew "bat"       # cat 대체
brew "fd"        # find 대체
brew "ripgrep"   # grep 대체 (rg)
brew "zoxide"    # 스마트 디렉토리 점프 (z)

# 노트북(ipynb in nvim) — molten-nvim 이미지 렌더링용
brew "imagemagick"
cask "kitty"     # 그래프 인라인 렌더링 지원 터미널

# 터미널 아이콘 글리프 (eza --icons, 프롬프트 심볼) — 터미널 폰트로 지정해야 적용됨
cask "font-jetbrains-mono-nerd-font"

# 텍스트/데이터
brew "jq"
brew "yq"
brew "git-delta" # git diff 하이라이트
brew "hexyl"

# 개발 워크플로우
brew "tmux"
brew "lazygit"
brew "direnv"
brew "entr"
brew "hyperfine"
brew "tldr"
brew "shellcheck"
brew "watch"     # 리눅스는 procps에 기본 탑재 — mac만 설치가 필요할 뿐 공용 툴
brew "atuin"     # 셸 히스토리 DB화 + Ctrl-R 퍼지검색
brew "navi"      # Ctrl-G 커맨드 치트시트
brew "broot"     # 디렉토리 트리 탐색/점프 (br)
brew "yazi"      # 터미널 파일 매니저 (y)

# 네트워크/컨테이너
brew "httpie"
brew "mtr"
brew "lazydocker"
brew "dive"
brew "k9s"

# --- 모던 CLI 2세대 + 해커 감성 (2026-08) ---
brew "fastfetch"  # 새 터미널 시스템 스플래시
brew "onefetch"   # git repo 요약 + ASCII 로고 (repo 진입 시 자동 표시)
brew "vivid"      # LS_COLORS 테마 생성기 (eza/fd/ls 색)
brew "procs"      # ps 대체 (컬러/트리)
brew "dust"       # du 대체 (시각화)
brew "sd"         # sed 대체 (직관 문법)
brew "gping"      # ping 그래프
brew "doggo"      # dig 대체 (컬러 DNS)
brew "glow"       # 터미널 markdown 렌더러
brew "bandwhich"  # 프로세스별 네트워크 사용량 (sudo bandwhich)
brew "cmatrix"    # 매트릭스 레인 (고전)
brew "genact"     # 가짜 해커 활동 애니메이션 (장난감)
