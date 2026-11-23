# 맥북 셋업

새 맥북을 이 저장소 하나로 지금 맥과 같은 환경으로 세운다.
리눅스·공용 서버·부분 셋업(셸만/nvim만/Claude Code만)은 [README.md](README.md).

**공개 저장소**라 비밀·사내 정보(ssh, git 신원, 앱 설정 plist 통째)는 올리지 않는다 —
그것들은 1단계대로 사적인 경로(AirDrop·USB)로 옮긴다.

## 한눈에

```sh
# 새 맥에서 (옛 맥에서 챙길 것은 1단계)
xcode-select --install                                  # git 포함. 창에서 "설치", 끝날 때까지 대기
defaults import com.googlecode.iterm2 ~/iterm2.plist    # iTerm2 설정을 옮겨 왔을 때만
git clone https://github.com/rupc/dotfiles ~/work/dotfiles && ~/work/dotfiles/setup-macos.sh
```

그다음 [수동 체크리스트](#3-수동-체크리스트-스크립트가-못-하는-것) → 로그아웃·다시 로그인 →
`~/work/dotfiles/status.sh --missing`으로 빠진 것 확인.

## 1. 옛 맥에서 (끄기 전에)

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

## 2. 새 맥에서

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
6. 로그아웃 후 다시 로그인 (트랙패드·마우스·다크 모드·입력 소스 반영) →
   `~/work/dotfiles/status.sh --missing`.

## 3. 수동 체크리스트 (스크립트가 못 하는 것)

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

## setup-macos.sh가 하는 일

순서: Homebrew → `Brewfile` → 셸·nvim·Claude Code(컴포넌트 스크립트 재사용) → mac 마무리 →
`Brewfile.apps`(맨 끝).

| 대상 | 배포/설정 |
|---|---|
| 한/영 (오른쪽 Command, 외장 Varmilo는 오른쪽 Alt·한/영 키) | 시스템 단축키 60(F18)이 전환하고, Karabiner 규칙이 한/영을 **누르는 순간** F18을 눌렀다-뗀 것으로 보내 즉시 전환되게 한다 (Karabiner가 없으면 로그인 때 hidutil LaunchAgent가 오른쪽 Command를 F18로). macOS 단축키만 쓰면 키를 뗄 때 전환돼서 빠르게 치면 첫 글자가 이전 언어로 들어간다 |
| Karabiner (`~/.config/karabiner`) | 위 한/영 + Windows식 단축키(`WinKeys-min` 프로필) |
| Hammerspoon (`~/.hammerspoon`) | PPT 축소판 확대·리본 단축키, Finder → iTerm2, Word/PPT 평문 붙여넣기 |
| LinearMouse · kitty · git 전역 ignore | 설정 파일 그대로 |
| Rectangle | 옛 맥 설정을 처음 한 번만 (`defaults`) |
| Dock | 자동 숨김 · 아이콘 70 · 확대 켬(43) · 아이콘 튀기기 끔 |
| Finder | 경로 막대 · 상태 막대 · 기본 목록 보기 |
| 화면 | 다크 모드 |
| 파이썬 툴 | pyhwp (`uv tool`, HWP → 텍스트) |
| 앱 | `Brewfile`(셋업에 필요한 것, 실패하면 멈춤) · `Brewfile.apps`(일상 앱, 맨 끝, 실패해도 계속) |

### 키 매핑 (Karabiner `WinKeys-min` 프로필)

| 범위 | 매핑 |
|---|---|
| 모든 키보드 | 오른쪽 Command → F18 (한/영) |
| Varmilo 외장 (Mac 모드, 1452/591) | 왼쪽 Option↔왼쪽 Command 맞바꿈(Alt 자리가 Command) · 오른쪽 Option·lang1(한/영 키) → F18 · 오른쪽 Command → 왼쪽 Command |
| Logitech 장치 (1133/45915, 1133/45098) | Karabiner가 처리하도록 켜 둠 |
| 복합 규칙 | 한/영 즉시 전환 · Finder 잘라내기 흉내(Ctrl+X/Ctrl+Shift+V) · 왼쪽 Ctrl 편집키 → Cmd(터미널 제외) · Ctrl+클릭 → Cmd+클릭 · Ctrl+화살표 단어 이동 · Home/End · Chrome Ctrl+K/L 주소창 |

장치는 제조사/제품 번호로 잡으므로 같은 키보드·마우스를 새 맥에 꽂으면 그대로 적용된다.
Karabiner 규칙에서 `right_command`를 내보내면 hidutil 층 때문에 다시 한/영이 된다 — `left_command`만 쓸 것.

### 트랙패드·마우스

| 설정 | 값 | |
|---|---|---|
| 탭하여 클릭 | 켬 | 셋업이 설정 |
| 트랙패드 이동 속도 | 3 | 셋업이 설정 |
| 마우스 이동 속도 | 3 | 셋업이 설정 (가속·스크롤은 LinearMouse) |
| 스크롤 방향 (자연스러운 스크롤) | 끔 — 트랙패드·마우스 공통 | 셋업이 설정 |
| 세·네 손가락 위/아래·좌/우 쓸기, 꼬집기 | macOS 기본값 | 옛 맥도 기본값이라 따로 안 씀 |
| 클릭 세기 · 강한 클릭 | macOS 기본값 (중간 · 켬) | 옛 맥도 기본값이라 따로 안 씀 |

값이 이미 같으면 아무것도 쓰지 않고, 바뀐 게 있을 때만 Dock/Finder를 재시작한다.
트랙패드·마우스·다크 모드는 다시 로그인해야 전부 반영된다.

## 설정을 바꿨을 때

앱 GUI에서 설정을 바꾸면 셋업을 다시 돌리기 전에 `chezmoi re-add <파일>`로 되담을 것 —
셋업은 저장소 내용으로 덮어쓴다(`--force`). 대상: `~/.config/karabiner/karabiner.json`,
`~/.config/linearmouse/linearmouse.json`, `~/.hammerspoon/*.lua`, `~/.config/kitty/kitty.conf`.
macOS 설정·Rectangle 값을 바꾸려면 `setup-macos.sh`의 해당 줄을 고친다.

## 옛 맥에서 `setup-macos.sh`를 다시 돌린다면

- 먼저 한 번: `brew uninstall tldr && brew install tlrc` — Homebrew에서 tldr formula가
  빠졌고 tlrc가 같은 `tldr` 명령을 준다. 둘이 같은 실행 파일을 두고 부딪히면 `brew bundle`이
  실패할 수 있고, 그러면 `set -e`로 셋업이 거기서 멈춘다.
- `Brewfile.apps`는 손으로 깔아 둔 앱마다 "already an App" 실패를 찍는다 — 이미 있다는 뜻이라 무시.
- iTerm2 Claude Code 연동이 지워지니 다시 설치.
