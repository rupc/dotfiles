# dotfiles

macOS / Linux 겸용 dotfiles. [chezmoi](https://chezmoi.io) 형식(`dot_`, `private_`, `executable_` 접두사)으로 관리.

## 새 맥으로 옮기기

이 저장소 하나로 맥을 다시 세운다. 단 **공개 저장소**라 비밀·사내 정보(ssh, git 신원,
앱 설정 plist 통째)는 올리지 않는다 — 그것들은 1단계대로 사적인 경로(AirDrop·USB)로 옮긴다.

### 1. 옛 맥에서 (끄기 전에)

1. 앱 GUI에서 바꾼 설정을 저장소로 되담고 push:
   `chezmoi re-add ~/.config/karabiner/karabiner.json ~/.config/linearmouse/linearmouse.json`
   (Hammerspoon lua를 고쳤다면 `~/.hammerspoon/*.lua`도).
   `~/.claude/settings.json`을 되담을 때는 **`hooks`를 빼고** — iTerm2가 넣은 것이라
   공용 서버에 배포되면 이벤트마다 실패한다.
2. 저장소에 없는 것 챙기기:

   | 무엇 | 방법 |
   |---|---|
   | `~/.ssh/` (키 + config) | 폴더째 복사 → 새 맥에서 `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*` |
   | iTerm2 프로필·설정 | `defaults export com.googlecode.iterm2 ~/iterm2.plist` |
   | Claude Code 스킬 | `~/.claude/skills/` 폴더 |
   | git 신원 | `git config --global user.name` / `user.email` 값 |
   | ollama 모델 | `ollama list`로 이름 적어 두기 (새 맥에서 `ollama pull`) |

   VS Code는 Settings Sync가 켜져 있으면 확장·설정이 계정으로 따라온다.

### 2. 새 맥에서

1. macOS 업데이트, Apple ID 로그인 (App Store 앱용).
2. `xcode-select --install` — git이 여기 들어 있다. 창이 뜨면 "설치".
3. iTerm2 설정 넣기 (iTerm2가 실행 중이 아닐 때 — 아직 안 깔려 있어도 된다):
   `defaults import com.googlecode.iterm2 ~/iterm2.plist`
4. 전체 셋업:
   ```sh
   git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-macos.sh
   ```
   Homebrew 설치 단계에서 비밀번호와 Enter를 한 번 묻는다. texlive(~5GB) 때문에 오래 걸린다.
   중간에 멈추면 원인을 고치고 그대로 다시 실행(멱등). 마지막 GUI 앱 설치(`Brewfile.apps`)는
   실패해도 셋업을 멈추지 않는다. 다만 그 단계에서 pkg로 깔리는 앱(Karabiner·Zoom 등)이
   비밀번호를 한 번 더 묻는다 — texlive 받는 동안 자리를 비웠다면 그 프롬프트에서 기다리고 있다.
5. 아래 체크리스트.
6. 로그아웃 후 다시 로그인 (트랙패드·다크 모드·입력 소스 반영) → `~/work/dotfiles/status.sh --missing`.

### 수동 체크리스트 (스크립트가 못 하는 것)

| 항목 | 할 일 | 주의 |
|---|---|---|
| Karabiner-Elements | 앱 한 번 실행 → 드라이버(시스템 확장) 허용, 입력 모니터링 허용 | 허용 전에도 한/영은 된다(hidutil 층). 다만 키를 *뗄 때* 전환돼서 빠르게 치면 첫 글자가 이전 언어로 들어간다 |
| 입력 소스 | 시스템 설정 → 키보드 → 입력 소스 → 편집 → + 한국어 2벌식 | 한/영 키 자체는 셋업이 맞춰 둔다 |
| 손쉬운 사용 권한 | Hammerspoon · LinearMouse · Rectangle · BetterDisplay — 첫 실행 안내대로 | |
| 전체 디스크 접근 | Cardinal(파일 이름 즉시 검색, Cmd+Shift+Space) | 안 주면 보호된 폴더는 검색에서 빠진다 |
| iTerm2 Claude Code 연동 | iTerm2의 Install Claude Code Integration | **셋업 다음에** — 셋업이 `~/.claude/settings.json`을 덮어 훅이 지워진다. 셋업을 다시 돌렸으면 연동도 다시 |
| 로그인 | `gh auth login` → `gh auth setup-git` · `claude` · Slack·카카오톡 등 | |
| git 신원 | `git config --global user.name "…"` · `user.email "…"` | |
| docker | `colima start` (로그인 때 자동: `brew services start colima`) | |
| Claude Code 플러그인 | `/plugin`으로 pptx-deck-plugin · tweenkit 다시 설치 | |
| App Store 앱 | Word · Excel · PowerPoint · Outlook · OneNote · OneDrive · Slack · KakaoTalk · Tailscale · 한컴 HWP Viewer · Polaris Office · ExcalidrawZ | Tailscale은 App Store판 — `setup-macos.sh`를 한 번 더 돌리면 `tailscale` CLI가 잡힌다 |
| 직접 받는 앱 | 한컴오피스 HWP(라이선스, 휴먼명조 폰트 포함) · VMware Fusion · Logi Options(구버전, 새 기기면 `brew install --cask logi-options+`) · Codex 앱 · 4X-Link | Homebrew cask가 없거나 폐기됨 |
| AI 에이전트 CLI | codex · openclaw(게이트웨이 LaunchAgent 포함) · hermes | 각 공식 설치법으로 |
| 은행 보안 플러그인 | AhnLab ASTx · TouchEn nxKey 등 | 은행 사이트가 요구할 때 깔리게 둔다 |

### 옛 맥에서 `setup-macos.sh`를 다시 돌린다면

- 먼저 한 번: `brew uninstall tldr && brew install tlrc` — Homebrew에서 tldr formula가
  빠졌고 tlrc가 같은 `tldr` 명령을 준다. 둘이 같은 실행 파일을 두고 부딪히면 `brew bundle`이
  실패할 수 있고, 그러면 `set -e`로 셋업이 거기서 멈춘다.
- `Brewfile.apps`는 손으로 깔아 둔 앱마다 "already an App" 실패를 찍는다 — 이미 있다는 뜻이라 무시.
- iTerm2 Claude Code 연동이 지워지니 다시 설치.

## 셋업

```sh
git clone https://github.com/rupc/dotfiles ~/work/dotfiles && cd ~/work/dotfiles
```

| 시나리오 | 커맨드 |
|---|---|
| 전체 셋업 (셸+에디터+런타임+docker) | mac: `./setup-macos.sh` ([새 맥 절차](#새-맥으로-옮기기)) · linux: `./setup-linux.sh` |
| 셸 환경만 (zsh/oh-my-zsh/CLI 툴) | `./setup-shell.sh` |
| neovim 환경만 (vimrc/플러그인/LSP/노트북) | `./setup-nvim.sh` |
| Claude Code만 — 공용 서버 (설정·로그인을 저장소 **상위 디렉토리**에) | `./setup-claude.sh` · 다 쓰면 `./setup-claude.sh --reset` |
| Claude Code만 — 내 머신 (`~/.claude`) | `./setup-claude.sh --global` |
| 공용 머신, sudo 없음 | `SKIP_PACKAGES=1 ./setup-shell.sh` (또는 `setup-nvim.sh`) |
| 컨테이너 | `containers/build.sh` → `containers/run.sh` ([상세](containers/README.md)) |
| **지금 상태 확인** (아무것도 설치 안 함) | `./status.sh` (빠진 것만: `./status.sh --missing`) |

- 전체 셋업은 내부적으로 `setup-shell.sh`/`setup-nvim.sh`를 재사용하고, 각 컴포넌트
  스크립트는 자기 영역의 dotfiles만 배포한다(공용 머신에서 남의 환경을 안 건드림).
- linux에서 nvim은 apt(0.6~0.7대, lua API 없음) 대신 **공식 릴리즈 바이너리를
  `~/.local`에 설치**한다(sudo 불필요). 0.11 미만이면 플러그인 설치 전에 즉시 실패.
- 모든 스크립트는 재실행해도 안전(idempotent). `SKIP_PACKAGES=1`이어도 zsh 플러그인은
  저장소에 번들되어 있고 모든 툴은 "있을 때만" 로드되므로 깨지지 않는다.
- `setup-shell.sh`/`setup-nvim.sh`는 끝에 **요약**을 찍는다 — 이미 있음 / 새로 설치 /
  생략(사유) / 실패(사유). 패키지 매니저 원본 출력은 `/tmp/setup-*.log`로 빠지고,
  생략·실패한 항목만 사유를 보고 조치한 뒤 재실행하면 그것만 마저 설치된다.
  (공용 로깅 헬퍼: `lib-report.sh`)
- `setup-claude.sh`는 claude CLI(공식 네이티브 설치, sudo 불필요)와 Claude 설정을
  배포한다. 기본은 **로컬 모드** — 저장소 바로 위 디렉토리에만 쓴다(공용 서버용, 아래
  [공용 서버에서 Claude Code](#공용-서버에서-claude-code-로컬-모드)). `--global`은 `~/.claude`에
  배포한다 — `setup-macos.sh`/`setup-linux.sh`가 이걸로 부르고, 내 머신에서 직접 돌릴
  때도 `--global`을 붙일 것(이 아래는 전역 모드 설명).
  핵심은 **상태줄** — 지금 어느 머신의 어느 경로에서, 어떤 계정·모델·effort로
  돌고 있고, 이 대화창(`ctx`)과 결제 플랜(`5h`/`7d`)이 얼마나 남았는지가 한 줄로 뜬다.
  머신을 옮겨다니며 세션을 여러 개 띄우면 이게 없을 때 어느 창이 어디에 붙어 있는지
  헷갈린다. `~/.claude` 자체는 `0700`으로 잠근다(세션 기록이 들어있다).
  세션 기록(`projects/`, `history.jsonl`)은 chezmoi 관리 대상이 아니라 그대로 남는다.
  단, `settings.json`은 Claude Code가 스스로도 쓴다(`/config`, 모델 변경 등) — 셋업을
  다시 돌리면 repo 내용으로 덮이므로, TUI에서 바꾼 걸 살리려면 먼저 되담을 것:
  `chezmoi re-add ~/.claude/settings.json`
- `status.sh`는 읽기 전용 점검이다 — 카테고리(사전 요구사항/CLI 툴/셸/neovim/LSP/
  AI 에이전트/런타임)별로 무엇이 있고 없는지, **없다면 왜 없는지**를 찍고 마지막에
  통계와 "사유별 묶음"을 보여준다. 사유 하나를 해결하면 몇 개가 같이 풀리는지가 보인다.
  (툴 목록/설명은 `lib-tools.sh`에서 setup-shell.sh와 공유)

### 공용 서버에서 Claude Code (로컬 모드)

한 리눅스 계정을 여러 사람이 같이 쓰는 서버에서는 `~/.claude`도 공용이라 내 설정·로그인·세션
기록이 남의 것과 섞인다. 내 작업 디렉토리 안에 clone해서 `setup-claude.sh`를 돌리면 그
디렉토리(저장소 바로 위)에만 쓰고, 다 쓴 뒤 `--reset` 한 번으로 원상복구된다.

```sh
cd /data/yongrae && git clone https://github.com/rupc/dotfiles && dotfiles/setup-claude.sh
source /data/yongrae/claude-env.sh && claude        # 셸마다 source 한 번 (첫 실행 때 로그인)

/data/yongrae/dotfiles/setup-claude.sh --reset      # 다 쓰면: 로그아웃 + 아래 세 개 삭제
/data/yongrae/dotfiles/setup-claude.sh --reset --yes  # 확인 질문 없이
```

| 생기는 것 | 내용 |
|---|---|
| `yongrae/.claude/` | 설정·로그인·세션 기록 (`CLAUDE_CONFIG_DIR`가 가리키는 곳) |
| `yongrae/.claude-setup/` | 서버에 없어서 받은 claude CLI(약 240MB)·jq, 셋업 로그 |
| `yongrae/claude-env.sh` | `CLAUDE_CONFIG_DIR`·PATH 설정 (claude를 여기 받았으면 자동 업데이트도 끈다) |

- 이 셋 밖(`~/.claude`, `~/.claude.json`, `~/.local`, `~/.config/chezmoi`, 셸 rc, apt)은
  건드리지 않는다 — jq도 apt 대신 정적 바이너리를 받고, claude 설치기는 `HOME`을
  `.claude-setup/home`으로 바꿔 돌린다. 그래서 `--reset`만으로 원래대로 돌아간다.
  저장소(`dotfiles/`)는 남으니 완전히 치우려면 그것도 지울 것.
- `source` 없이 그냥 `claude`를 치면 그 계정 공용 `~/.claude`(남의 로그인일 수 있음)를 쓴다.
- 같은 리눅스 계정 사용자는 `yongrae/.claude`의 로그인 토큰도 읽을 수 있다(`0700`은 다른
  uid만 막는다) — 다 쓰면 바로 `--reset`. 로그아웃이 서버 쪽 세션까지 끊는지는 확인하지
  않았으니, 확실히 하려면 claude.ai 계정 설정에서도 정리할 것.
- 작업은 `yongrae/` 바로 아래가 아니라 그 안의 저장소에서 — `yongrae/`에서 열면 설정
  디렉토리와 프로젝트 `.claude/`가 같은 곳이 된다.
- 경로에 공백·따옴표 등 특수문자가 있으면 셋업을 거부한다(상태줄 명령이 셸을 거친다).
- 저장소가 홈 바로 아래(`~/dotfiles`)면 상위가 곧 홈이라 전역 모드로 돈다(`--reset`은 거부).

## 컨테이너 devbox

docker만 있으면 어디서든 동일 환경. 컨테이너 빌드가 setup 스크립트를 그대로 재사용해
로컬과 같은 소스에서 재현된다 — 상세는 [containers/README.md](containers/README.md).

```sh
containers/build.sh          # rupc/devbox:latest 빌드 (vim 플러그인/LSP까지 이미지에 포함)
containers/run.sh [dir]      # dir(기본: 현재 디렉토리)를 /workspace로 마운트, zsh 진입
docker save rupc/devbox:latest | ssh 서버 docker load    # 레지스트리 없이 원격 배포
```

`--rm` 실행이라 환경은 불변, 작업물은 마운트한 디렉토리에만 남는다.
VSCode devcontainer는 `containers/devcontainer.json`을 프로젝트 `.devcontainer/`에 복사.

## 에디터 (nvim)

- vim 플러그인은 **vim-plug 하나로 통합**, nvim은 `~/.vimrc`를 그대로 source.
- LSP·자동완성·진단은 **nvim 내장 LSP**(0.11+) — coc.nvim은 2026-07 제거, Node 불필요.
  서버 실행파일이 있을 때만 자동 연결: basedpyright(python, `~/.venvs/nvim`에 설치됨) ·
  rust-analyzer · clangd(C++/CUDA) · go는 vim-go가 gopls를 직접 관리.
- 키맵: `gd`/`gy`/`gi`/`gr`, `[g`/`]g`(진단 이동), `,rn`(rename), `,f`(format),
  `K`(hover). 완성 팝업은 `<C-n>/<C-p>` 이동 + `<C-y>` 확정. 파일 탐색 `<C-p>`=fzf Files.
- vimrc에 **버전 가드**가 있어 0.11 미만 nvim에서는 lua 플러그인·LSP를 건너뛰고 경고
  한 줄만 띄운다 — 그 경우 `setup-nvim.sh` 재실행.

### Jupyter 노트북 (ipynb를 nvim에서 실행)

molten-nvim + image.nvim + jupytext. **그래프 인라인은 kitty 터미널 전용**.
파이썬 의존성은 `~/.venvs/nvim` 전용 venv에 격리(setup-nvim.sh가 생성).

kitty에서 `nvim notebook.ipynb` → `,mi`(커널 선택: `nvim-python`) → **Ctrl+Enter**로
셀 실행(결과·그래프 인라인). `,ml`=현재 줄, `,mr`=선택 실행, `,mo`/`,md`=출력 보기/삭제.
저장하면 jupytext가 .ipynb로 재변환.

## macOS 앱·설정 (setup-macos.sh)

| 대상 | 배포/설정 |
|---|---|
| 한/영 (오른쪽 Command, 외장 Varmilo는 오른쪽 Alt·한/영 키) | 시스템 단축키 60(F18)이 전환하고, Karabiner 규칙이 한/영을 **누르는 순간** F18을 눌렀다-뗀 것으로 보내 즉시 전환되게 한다 (Karabiner가 없으면 로그인 때 hidutil LaunchAgent가 오른쪽 Command를 F18로). macOS 단축키만 쓰면 키를 뗄 때 전환돼서 빠르게 치면 첫 글자가 이전 언어로 들어간다 |
| Karabiner (`~/.config/karabiner`) | 위 한/영 + Windows식 단축키(`WinKeys-min` 프로필) |
| Hammerspoon (`~/.hammerspoon`) | PPT 축소판 확대·리본 단축키, Finder → iTerm2, Word/PPT 평문 붙여넣기 |
| LinearMouse · kitty · git 전역 ignore | 설정 파일 그대로 |
| Rectangle | 옛 맥 설정을 처음 한 번만 (`defaults`) |
| macOS | Dock 자동 숨김·크기, 튀기기 끔 · Finder 경로/상태 막대·목록 보기 · 탭하여 클릭 · 자연스러운 스크롤 끔 · 다크 모드 |
| 앱 | `Brewfile`(셋업에 필요한 것, 실패하면 멈춤) · `Brewfile.apps`(일상 앱, 맨 끝, 실패해도 계속) |

앱 GUI에서 설정을 바꾸면 셋업을 다시 돌리기 전에 `chezmoi re-add <파일>`로 되담을 것 —
셋업은 저장소 내용으로 덮어쓴다(`--force`).

## 구조

- 셸 설정(`dot_zshrc` 등)은 최상단에서 OS를 감지해 `$DOTFILES_OS`(`mac`/`linux`)로
  분기 — 공통 설정은 무조건 로드, OS별(Homebrew, CUDA 등)만 if 분기.
- 수정은 항상 이 저장소에서 하고 `chezmoi apply`로 배포 (`~/.zshrc` 직접 수정 금지).
- zsh 플러그인은 `dot_oh-my-zsh/custom/plugins/`에 스냅샷으로 번들.

## 설치되는 툴

셋업 스크립트가 전부 자동 설치한다. Ubuntu 패키지명 차이(`bat`→`batcat`,
`fd`→`fdfind`)는 표준 이름으로 심링크하고, apt에 없는 툴은 건너뛰고 알려준다.

| 분류 | 툴 |
|---|---|
| 코어 | chezmoi · fzf/fzy · autojump · neovim · go · node(linux는 nvm 경유) · python3 · docker+compose · gh |
| 시스템 모니터링 | htop · btop · ncdu · duf · glances · mactop/asitop(mac) |
| 파일 탐색/검색 | tree · eza(ls) · bat(cat) · fd(find) · ripgrep(grep) · zoxide |
| 텍스트/데이터 | jq · yq · git-delta · hexyl |
| 워크플로우 | tmux · lazygit · direnv · entr · hyperfine · tldr · shellcheck · watch · navi · broot · yazi · thefuck(mac only) |
| 네트워크/컨테이너 | httpie · mtr · rsync(mac: 최신판) · lazydocker · dive · k9s |
| 모던 CLI 2세대 | fastfetch(새 터미널 스플래시) · onefetch · vivid · procs · dust · sd · gping · doggo · glow · bandwhich · cmatrix · genact |
| 에디터 보조 | shfmt · poppler(PDF) · taplo(TOML LSP) · imagemagick · kitty(노트북 그래프) |
| LaTeX (mac) | texlive · biber · latexindent · texlab · Skim(SyncTeX 역검색) · Libertine/Biolinum O 폰트 |
| 저장장치 (mac) | smartmontools(smartctl) · fio |

## 셸 인터랙티브 환경

zshrc가 전부 "설치되어 있을 때만" 로드하므로 일부가 없어도 셸이 깨지지 않는다.

- **zsh 플러그인**(번들): zsh-autosuggestions(→로 수락) · zsh-syntax-highlighting ·
  fzf-tab(탭 완성을 fzf 팝업으로) · zsh-history-substring-search(↑/↓) ·
  zsh-completions · forgit(`ga`/`glo`/`gd` 등 git을 fzf로) · zsh-better-npm-completion ·
  you-should-use(별칭이 있는 커맨드를 길게 치면 알려줌)
- **oh-my-zsh 내장**: git(`gst`/`gco`/`gcmsg`) · dirhistory(Alt+←/→) · extract(`x`) ·
  autojump(`j`) · kubectl(`k`/`kgp`) · history/emoji/encode64
- **훅 로드 툴**: pure(프롬프트) · zoxide(`z`) ·
  direnv(`.envrc`) · thefuck(`fuck`, mac only) · navi(**Ctrl-G** 치트시트) · broot(`br`) ·
  yazi(`y`) · fzf(**Ctrl-T** 파일 삽입)

키 정리: **Ctrl-R**=fzf 히스토리 · **Ctrl-T**=fzf 파일 · **Ctrl-G**=navi ·
**↑/↓**=substring-search · **Tab**=fzf-tab.

OS별 차이: mac은 docker 런타임으로 **colima** 사용, `python`/`pip` 심링크는 스크립트가
처리. linux는 node를 nvm으로 설치하고, docker는 `sudo usermod -aG docker $USER` +
재로그인 필요.
