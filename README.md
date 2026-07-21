# dotfiles

macOS / Linux 겸용 dotfiles. [chezmoi](https://chezmoi.io) 형식(`dot_`, `private_`, `executable_` 접두사)으로 관리.

## 새 머신 셋업 (OS별 시나리오)

```sh
git clone https://github.com/rupc/dotfiles ~/work/dotfiles

# macOS
~/work/dotfiles/setup-macos.sh     # Homebrew + Brewfile 기반

# Ubuntu/Debian
~/work/dotfiles/setup-linux.sh     # apt 기반
```

스크립트 하나로 패키지 설치(macOS: [Brewfile](Brewfile), 리눅스: apt), oh-my-zsh,
pure prompt, vim 플러그인(Vundle + vim-plug), chezmoi 배포까지 전부 재현된다.
두 스크립트 모두 재실행해도 안전하다(idempotent).

## 구조

- 셸 설정(`dot_zshrc`, `dot_bash_profile`, `dot_bashrc`)은 최상단에서 OS를 감지해
  `$DOTFILES_OS`(`mac`/`linux`) 변수로 분기한다. 공통 설정은 무조건 로드, OS별 설정
  (Homebrew, pnpm, fzf, clipboard, CUDA 등)만 if 분기.
- 수정은 항상 이 저장소에서 하고 `chezmoi apply`로 홈에 배포한다. (`~/.zshrc` 직접 수정 금지)
- zsh 플러그인(zsh-autosuggestions 등)은 `dot_oh-my-zsh/custom/plugins/`에 스냅샷으로 포함.
- vim은 Vundle(`~/.vim/bundle`)과 vim-plug(`~/.vim/plugged`)를 둘 다 사용하며,
  nvim은 `~/.vimrc`를 그대로 source 한다. LSP는 coc.nvim 담당.

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

OS별 차이 요약:
- **mac**: docker 데몬이 없어서 **colima**를 런타임으로 사용 (Docker Desktop 불필요, sudo 없이 설치됨)
- **mac**: brew는 `python3`/`pip3`만 제공하므로 `python`/`pip` 심링크를 걸어줌; 리눅스는 `python-is-python3` 패키지가 같은 역할
- **linux**: node를 apt로 깔면 구버전이라 **nvm** 경유로 설치; mac은 brew node가 최신이라 그대로 사용
- **linux**: docker 사용에 `sudo usermod -aG docker $USER` + 재로그인 필요
