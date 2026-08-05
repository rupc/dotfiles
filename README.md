# dotfiles

macOS / Linux 겸용 dotfiles. [chezmoi](https://chezmoi.io) 형식(`dot_`, `private_`, `executable_` 접두사)으로 관리.

## 셋업

```sh
git clone https://github.com/rupc/dotfiles ~/work/dotfiles && cd ~/work/dotfiles
```

| 시나리오 | 커맨드 |
|---|---|
| 전체 셋업 (셸+에디터+런타임+docker) | mac: `./setup-macos.sh` · linux: `./setup-linux.sh` |
| 셸 환경만 (zsh/oh-my-zsh/CLI 툴) | `./setup-shell.sh` |
| neovim 환경만 (vimrc/플러그인/LSP/노트북) | `./setup-nvim.sh` |
| 공용 머신, sudo 없음 | `SKIP_PACKAGES=1 ./setup-shell.sh` (또는 `setup-nvim.sh`) |
| 컨테이너 | `containers/build.sh` → `containers/run.sh` ([상세](containers/README.md)) |

- 전체 셋업은 내부적으로 `setup-shell.sh`/`setup-nvim.sh`를 재사용하고, 각 컴포넌트
  스크립트는 자기 영역의 dotfiles만 배포한다(공용 머신에서 남의 환경을 안 건드림).
- linux에서 nvim은 apt(0.6~0.7대, lua API 없음) 대신 **공식 릴리즈 바이너리를
  `~/.local`에 설치**한다(sudo 불필요). 0.11 미만이면 플러그인 설치 전에 즉시 실패.
- 모든 스크립트는 재실행해도 안전(idempotent). `SKIP_PACKAGES=1`이어도 zsh 플러그인은
  저장소에 번들되어 있고 모든 툴은 "있을 때만" 로드되므로 깨지지 않는다.

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
| 워크플로우 | tmux · lazygit · direnv · entr · hyperfine · tldr · shellcheck · thefuck(mac only) |
| 네트워크/컨테이너 | httpie · mtr · lazydocker · dive · k9s |

## 셸 인터랙티브 환경

zshrc가 전부 "설치되어 있을 때만" 로드하므로 일부가 없어도 셸이 깨지지 않는다.

- **zsh 플러그인**(번들): zsh-autosuggestions(→로 수락) · zsh-syntax-highlighting ·
  fzf-tab(탭 완성을 fzf 팝업으로) · zsh-history-substring-search(↑/↓) ·
  zsh-completions · forgit(`ga`/`glo`/`gd` 등 git을 fzf로) · zsh-better-npm-completion
- **oh-my-zsh 내장**: git(`gst`/`gco`/`gcmsg`) · dirhistory(Alt+←/→) · extract(`x`) ·
  autojump(`j`) · kubectl(`k`/`kgp`) · history/emoji/encode64
- **훅 로드 툴**: pure(프롬프트) · atuin(**Ctrl-R** 히스토리 검색) · zoxide(`z`) ·
  direnv(`.envrc`) · thefuck(`fuck`, mac only) · navi(**Ctrl-G** 치트시트) · broot(`br`) ·
  yazi(`y`) · fzf(**Ctrl-T** 파일 삽입)

키 정리: **Ctrl-R**=atuin · **Ctrl-T**=fzf · **Ctrl-G**=navi ·
**↑/↓**=substring-search · **Tab**=fzf-tab.

OS별 차이: mac은 docker 런타임으로 **colima** 사용, `python`/`pip` 심링크는 스크립트가
처리. linux는 node를 nvm으로 설치하고, docker는 `sudo usermod -aG docker $USER` +
재로그인 필요.
