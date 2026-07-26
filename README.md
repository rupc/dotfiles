# dotfiles

macOS / Linux 겸용 dotfiles. [chezmoi](https://chezmoi.io) 형식(`dot_`, `private_`, `executable_` 접두사)으로 관리.

## 새 머신 셋업 (시나리오별)

```sh
git clone https://github.com/rupc/dotfiles ~/work/dotfiles
cd ~/work/dotfiles
```

| 시나리오 | 커맨드 |
|---|---|
| **전체 셋업** (내 머신: 셸+에디터+런타임+docker) | mac: `./setup-macos.sh` · linux: `./setup-linux.sh` |
| **셸 환경만** (zsh/oh-my-zsh/pure/CLI 툴) | `./setup-shell.sh` |
| **neovim 환경만** (vimrc/플러그인/LSP/노트북) | `./setup-nvim.sh` |
| **공용 머신, sudo 없음** | `SKIP_PACKAGES=1 ./setup-shell.sh` 또는 `SKIP_PACKAGES=1 ./setup-nvim.sh` |

- 전체 셋업 스크립트는 내부적으로 `setup-shell.sh`/`setup-nvim.sh`를 재사용한다.
- 컴포넌트 스크립트는 자기 영역의 dotfiles만 배포한다(셸: zshrc/bashrc/oh-my-zsh,
  nvim: vimrc/coc 설정) — 공용 머신에서 다른 사람 환경을 건드리지 않는다.
- `SKIP_PACKAGES=1`이면 패키지 설치를 건너뛴다. zsh 플러그인은 저장소에 번들되어
  있고 zshrc/vimrc가 모든 툴을 "있을 때만" 로드하므로, 도구가 없어도 깨지지 않는다.
- 모든 스크립트는 재실행해도 안전하다(idempotent).

## Jupyter 노트북 (ipynb를 nvim 안에서 실행 + 그래프 인라인)

molten-nvim + image.nvim + jupytext 조합. **그래프 렌더링은 kitty 터미널에서 동작**
(iTerm2는 텍스트 출력만 가능). 파이썬 의존성은 `~/.venvs/nvim` 전용 venv에 격리
(setup-nvim.sh가 생성; pynvim/jupyter_client/ipykernel/jupytext).

1. kitty에서 `nvim notebook.ipynb` — jupytext가 py:percent 포맷으로 자동 변환
2. `,mi` (`:MoltenInit`) — 커널 선택 (기본 등록: `nvim-python`)
3. **Ctrl+Enter** — 현재 `# %%` 셀 실행, 결과/그래프가 코드 아래 인라인 표시
4. 기타: `,ml`(현재 줄), 비주얼 선택 후 `,mr`, `,mo`(출력 다시 보기), `,md`(출력 삭제)
5. 저장하면 jupytext가 .ipynb로 다시 변환

## 구조

- 셸 설정(`dot_zshrc`, `dot_bash_profile`, `dot_bashrc`)은 최상단에서 OS를 감지해
  `$DOTFILES_OS`(`mac`/`linux`) 변수로 분기한다. 공통 설정은 무조건 로드, OS별 설정
  (Homebrew, pnpm, fzf, clipboard, CUDA 등)만 if 분기.
- 수정은 항상 이 저장소에서 하고 `chezmoi apply`로 홈에 배포한다. (`~/.zshrc` 직접 수정 금지)
- zsh 플러그인(zsh-autosuggestions 등)은 `dot_oh-my-zsh/custom/plugins/`에 스냅샷으로 포함.
- vim 플러그인은 **vim-plug 하나로 통합**(`~/.vim/plugged`)되어 있으며, nvim은
  `~/.vimrc`를 그대로 source 한다. LSP·자동완성·진단은 coc.nvim이 단독 담당
  (과거의 Vundle/deoplete/syntastic/snipmate는 2026-07에 제거). 파일 탐색은
  ctrlp 대신 fzf.vim(`<C-p>`=Files).
- coc 확장은 vimrc의 `g:coc_global_extensions`에 선언되어 **nvim 첫 실행 때 자동
  설치**된다: pyright(python) · rust-analyzer · clangd(C++/CUDA) · yaml(k8s 스키마
  검증 내장) · json · toml · docker · sh · snippets. go는 vim-go의 gopls를 쓰므로
  coc-go는 넣지 않는다(이중 실행 방지). k8s 매니페스트 경로 패턴은
  `coc-settings.json`의 `yaml.schemas`에 정의.

## 주요 커맨드라인 툴 설치 (macOS / Linux)

셋업 스크립트가 아래를 전부 자동으로 설치한다. 개별 설치가 필요할 때 참고용.

| 툴 | 용도 | macOS (Homebrew) | Linux (Ubuntu/Debian) |
|---|---|---|---|
| chezmoi | dotfiles 배포/관리 | `brew install chezmoi` | `sh -c "$(curl -fsSL get.chezmoi.io)"` (apt에 없음) |
| fzf | 퍼지 파인더 (Ctrl-R 등) | `brew install fzf` | `sudo apt install fzf` |
| fzy | 퍼지 파인더 (vim 연동) | `brew install fzy` | `sudo apt install fzy` |
| autojump | 디렉토리 점프 (`j`) | `brew install autojump` | `sudo apt install autojump` |
| neovim | 에디터 (`vi`/`vim` alias) | `brew install neovim` | `sudo apt install neovim` |
| go | Go 런타임 | `brew install go` | `sudo apt install golang-go` |
| node | Node.js (시스템 기본) | `brew install node` | nvm으로 설치 (`nvm install --lts`) |
| nvm | Node 버전 관리 | `brew install nvm` + `mkdir ~/.nvm` | 공식 install.sh (`~/.nvm`에 설치) |
| python 3 | Python 런타임 | `brew install python@3.14` | `sudo apt install python3 python3-pip python3-venv` |
| `python`/`pip` 커맨드 | `python3`/`pip3`를 짧은 이름으로 | brew bin에 심링크 (setup 스크립트가 처리) | `sudo apt install python-is-python3` |
| docker | 컨테이너 CLI | `brew install docker` | `sudo apt install docker.io` |
| docker compose | 컨테이너 오케스트레이션 | `brew install docker-compose` + cli-plugins 심링크 | `sudo apt install docker-compose-v2` |
| colima | docker 런타임 VM (**mac 전용**) | `brew install colima` → `colima start` | 불필요 (리눅스는 네이티브 데몬) |
| gh | GitHub CLI (인증/PR) | `brew install gh` | `sudo apt install gh` |

### 개발 편의 툴 (mac/linux 공용, 셋업 스크립트가 함께 설치)

| 분류 | 툴 |
|---|---|
| 시스템 모니터링 | `htop` · `btop` · `ncdu` · `duf` · `glances` · `mactop`/`asitop`(**mac 전용**) |
| 파일 탐색/검색 | `tree` · `eza`(ls) · `bat`(cat) · `fd`(find) · `ripgrep`(grep) · `zoxide`(디렉토리 점프 `z`) |
| 텍스트/데이터 | `jq` · `yq` · `git-delta` · `hexyl` |
| 워크플로우 | `tmux` · `lazygit` · `direnv` · `entr` · `hyperfine` · `tldr` · `shellcheck` · `thefuck`(오타 교정) · `watch`(mac만 설치) |
| 네트워크/컨테이너 | `httpie` · `mtr` · `lazydocker` · `dive` · `k9s` |

- zsh에서 `zoxide`(`z`)와 `direnv` 훅은 설치되어 있을 때만 자동 로드된다 (zshrc 6-1절)
- Ubuntu apt 패키지명 차이: `bat`→`batcat`, `fd`→`fdfind`(setup-linux.sh가 표준 이름으로 심링크), `delta`는 `git-delta`
- 구버전 Ubuntu apt에 없는 툴(lazygit, lazydocker, dive, k9s, eza 등)은 스크립트가 건너뛰고 알려준다

## 셸 플러그인 & 인터랙티브 툴 정리

zshrc의 `plugins=(...)` 배열과 6-1절 훅으로 로드된다. 전부 설치되어 있을 때만 로드되므로
일부가 없어도 셸이 깨지지 않는다.

### zsh 플러그인 (저장소에 스냅샷 포함, `dot_oh-my-zsh/custom/plugins/`)

| 플러그인 | 뭔지 | 활용법 |
|---|---|---|
| zsh-autosuggestions | 히스토리 기반 회색 자동제안 | 제안이 뜨면 →(오른쪽 화살표)로 수락 |
| zsh-syntax-highlighting | 커맨드 문법 실시간 색칠 | 오타/없는 커맨드는 빨간색으로 표시됨 |
| fzf-tab | **탭 완성을 fzf 팝업으로** | `cd <TAB>`, `git checkout <TAB>` 후 퍼지검색으로 선택 |
| zsh-history-substring-search | 입력 단어로 히스토리 탐색 | `git` 타이핑 후 ↑/↓ → git 커맨드만 순회 |
| zsh-completions | 추가 자동완성 정의 모음 | 설치만 하면 됨 (수백 개 툴 지원) |
| forgit | git을 fzf 인터랙티브로 | `ga`(add), `glo`(log), `gd`(diff), `gcf`(checkout file) |
| zsh-better-npm-completion | npm 자동완성 개선 | `npm run <TAB>`에 스크립트 목록 |

### oh-my-zsh 내장 플러그인 (이름만 활성화)

| 플러그인 | 뭔지 | 활용법 |
|---|---|---|
| git | git alias 모음 | `gst`(status), `gco`(checkout), `gcmsg`(commit -m) |
| dirhistory | 디렉토리 이동 히스토리 | Alt+←/→ 로 이전/다음 디렉토리 |
| extract | 만능 압축 해제 | `extract 파일.tar.gz` (포맷 자동 인식, alias `x`) |
| autojump | 자주 가는 디렉토리 점프 | `j 디렉토리키워드` |
| kubectl | k8s alias + 완성 | `k`(kubectl), `kgp`(get pods) |
| history / emoji / encode64 | 히스토리 alias, 이모지, base64 | `h`, `emoji`, `e64`/`d64` |

### 훅으로 로드되는 인터랙티브 툴 (zshrc 6-1절)

| 툴 | 뭔지 | 활용법 |
|---|---|---|
| pure | 미니멀 프롬프트 (테마) | 자동 적용 (git 상태/실행시간 표시) |
| atuin | 히스토리 SQLite DB + 동기화 | **Ctrl-R** → 전체 히스토리 퍼지검색 UI |
| zoxide | 스마트 디렉토리 점프 | `z 키워드` (방문 빈도 학습) |
| direnv | 디렉토리별 환경변수 | 프로젝트에 `.envrc` 두면 진입 시 자동 로드 |
| thefuck | 직전 커맨드 오타 교정 | 오타 후 `fuck` 입력 → 교정안 제시 |
| navi | 커맨드 치트시트 | **Ctrl-G** → 스니펫 검색/조립 |
| broot | 트리 탐색 + 점프 | `br` 실행, 타이핑으로 필터, Alt+Enter로 cd |
| yazi | 터미널 파일 매니저 | `y` 실행 (종료 시 마지막 위치로 cd됨) |
| fzf | 범용 퍼지 파인더 | **Ctrl-T**(파일 삽입), `**<TAB>` 완성 |

키 충돌 정리: **Ctrl-R**=atuin(히스토리), **Ctrl-T**=fzf(파일), **Ctrl-G**=navi(치트시트),
**↑/↓**=history-substring-search, **Tab**=fzf-tab.

OS별 차이 요약:
- **mac**: docker 데몬이 없어서 **colima**를 런타임으로 사용 (Docker Desktop 불필요, sudo 없이 설치됨)
- **mac**: brew는 `python3`/`pip3`만 제공하므로 `python`/`pip` 심링크를 걸어줌; 리눅스는 `python-is-python3` 패키지가 같은 역할
- **linux**: node를 apt로 깔면 구버전이라 **nvm** 경유로 설치; mac은 brew node가 최신이라 그대로 사용
- **linux**: docker 사용에 `sudo usermod -aG docker $USER` + 재로그인 필요
