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

## 주요 설치 도구 (Brewfile)

chezmoi · fzf · fzy · autojump · neovim · go · node · nvm · python@3.14 · docker · docker-compose · colima

- docker는 Docker Desktop 대신 **colima** 런타임 사용 (`colima start`)
- `python`/`pip` 커맨드는 brew의 `python3`/`pip3`로 심링크됨 (setup 스크립트가 처리)
