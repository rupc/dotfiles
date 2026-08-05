# containers — 어디서든 동일한 터미널 개발환경

이 저장소의 `setup-shell.sh` / `setup-nvim.sh` 를 **컨테이너 빌드에 그대로 재사용**해서,
로컬 맥북·리눅스 서버·컨테이너가 전부 같은 소스에서 재현되도록 한다.
zsh(oh-my-zsh + pure + 플러그인 전부) + neovim(vim-plug + 내장 LSP, 빌드 타임에
사전 설치) + python/go/node 런타임이 이미지 하나에 들어 있다.

## 기존 방법들 비교 (왜 이 구성인가)

| 방법 | 뭔지 | 판단 |
|---|---|---|
| **Dev Containers** | `.devcontainer/devcontainer.json` 표준. VSCode·devcontainer CLI·GitHub Codespaces가 지원 | 표준이라 채택. 단, 스펙의 dotfiles 기능은 VSCode 위주라 우리는 **이미지에 환경을 미리 굽는 방식**으로 사용 |
| 순수 Dockerfile | docker만 있으면 어디서든 동작 | 본체로 채택 — devcontainer.json은 이 이미지를 참조하는 얇은 껍데기 |
| distrobox / toolbox | 컨테이너를 호스트에 밀착 통합(홈 공유, GUI) | 리눅스 데스크톱 전용이라 제외. 리눅스에서 원하면 `distrobox create -i rupc/devbox` 로 이 이미지 그대로 사용 가능 |
| Nix / home-manager | 선언적 패키지·dotfiles 관리 | 재현성은 최강이지만 러닝커브가 커서 보류. chezmoi + 스크립트로 충분 |

## 빌드

```sh
cd ~/work/dotfiles/containers
./build.sh                    # rupc/devbox:latest
./build.sh myname/devbox:v1   # 태그 지정
```

- 빌드 컨텍스트는 저장소 루트 — dotfiles 전체가 이미지에 들어간다 (`.dockerignore`가 .git 제외)
- dotfiles를 수정했으면 다시 `./build.sh` (스크립트가 idempotent라 레이어 캐시 활용됨)
- 다른 아키텍처용: `docker build --platform linux/amd64 ...` (기본은 현재 머신 아키텍처)

## 실행

```sh
containers/run.sh                # 현재 디렉토리를 /workspace로 마운트하고 zsh 진입
containers/run.sh ~/work/myproj  # 특정 프로젝트 디렉토리로
```

컨테이너 안은 로컬과 동일: pure 프롬프트, `z`/`j` 점프, fzf-tab, nvim 내장
LSP(basedpyright 사전 설치), `,mi` 노트북 커널까지. `--rm`이라 나가면 컨테이너는 사라지고
**작업물은 마운트한 /workspace에만 남는다** (환경은 불변, 데이터는 밖에).

## VSCode / devcontainer CLI로 쓰기

프로젝트에서 devcontainer로 쓰려면 이 폴더의 `devcontainer.json`을 복사:

```sh
mkdir -p ~/work/myproj/.devcontainer
cp ~/work/dotfiles/containers/devcontainer.json ~/work/myproj/.devcontainer/
# VSCode: "Reopen in Container" / CLI: devcontainer up --workspace-folder ~/work/myproj
```

## 원격 서버에 이미지 배포

레지스트리를 쓰거나 (`docker push`), 레지스트리 없이 직접 전송:

```sh
docker save rupc/devbox:latest | ssh 서버 docker load
```

## 포함 안 된 것 (의도적)

- **docker/k9s/lazydocker**: 컨테이너 안에서 docker는 소켓 마운트가 필요해 보안상 기본 제외.
  필요하면 `run.sh`에 `-v /var/run/docker.sock:/var/run/docker.sock` 추가
- **kitty**: GUI 터미널이라 제외 — 호스트의 kitty에서 `run.sh`로 들어오면 그래프 인라인
  렌더링도 동작한다 (kitty 그래픽 프로토콜은 ssh/컨테이너 경계를 통과함)
- **eza/lazygit 등 apt에 없는 툴**: 이미지 경량화를 위해 제외. zshrc가 "있을 때만
  로드"라 없어도 안 깨짐. 꼭 필요하면 Dockerfile에 추가
- **CUDA**: GPU 개발은 `nvidia/cuda` 베이스로 별도 이미지를 파는 게 맞음 (원하면 추가 구성)
