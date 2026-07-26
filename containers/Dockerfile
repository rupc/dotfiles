# ============================================================================
# rupc/devbox — 어느 머신에서든 동일한 내 터미널 개발환경
# 이 저장소의 setup-shell.sh / setup-nvim.sh 를 그대로 재사용해서 빌드하므로,
# 로컬(맥/리눅스) 환경과 컨테이너 환경이 같은 소스에서 재현된다.
#
# 빌드: containers/build.sh   (컨텍스트 = 저장소 루트)
# ============================================================================
FROM ubuntu:24.04

ARG USERNAME=jyr
ENV DEBIAN_FRONTEND=noninteractive

# --- 기반 패키지 (setup 스크립트의 apt 대상 중 컨테이너에 유효한 것) ---
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo ca-certificates locales git curl zsh tmux openssh-client \
        build-essential \
        python3 python3-pip python3-venv python-is-python3 \
        golang-go \
        fzf fzy autojump zoxide direnv entr \
        ripgrep fd-find bat tree jq \
        htop ncdu duf shellcheck tldr \
        imagemagick \
    && rm -rf /var/lib/apt/lists/* \
    && locale-gen en_US.UTF-8 \
    && ln -sf /usr/bin/batcat /usr/local/bin/bat \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# --- Node 22 (NodeSource): apt의 node 18은 전역 crypto가 없어 coc.nvim이 안 돎 ---
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# --- neovim: apt 버전이 낡아서 공식 릴리즈 바이너리 사용 (amd64/arm64) ---
# 주의: ARG TARGETARCH는 클래식 빌더(colima 기본)에서 안 채워지므로 dpkg로 판별
RUN NVIM_ARCH=$([ "$(dpkg --print-architecture)" = "arm64" ] && echo "arm64" || echo "x86_64") \
    && curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz" \
       | tar xz -C /opt \
    && ln -sf /opt/nvim-linux-*/bin/nvim /usr/local/bin/nvim \
    && nvim --version | head -1

# --- 유저 생성 (uid 1000; ubuntu:24.04 기본 유저 제거 후 대체) ---
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /usr/bin/zsh -u 1000 "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME

USER $USERNAME
WORKDIR /home/$USERNAME

# --- dotfiles 반입 + 셋업 스크립트 재사용 (패키지는 위에서 설치했으므로 SKIP) ---
COPY --chown=$USERNAME:$USERNAME . /home/$USERNAME/work/dotfiles
# go clean: gopls 빌드가 남기는 모듈/빌드 캐시(수 GB)를 같은 레이어에서 제거
RUN SKIP_PACKAGES=1 ~/work/dotfiles/setup-shell.sh \
    && SKIP_PACKAGES=1 ~/work/dotfiles/setup-nvim.sh \
    && go clean -cache -modcache 2>/dev/null || true

# --- 셋업 결과 검증 (스크립트 내부의 `|| true`가 실패를 숨기므로 여기서 강제 확인) ---
RUN test -d ~/.vim/plugged && test -x ~/.venvs/nvim/bin/jupytext && nvim --headless "+q"

# --- coc 확장을 빌드 타임에 미리 설치 (첫 실행 대기 제거) ---
RUN nvim --headless "+CocInstall -sync coc-pyright coc-rust-analyzer coc-clangd coc-yaml coc-json coc-toml coc-docker coc-sh coc-snippets" "+qall" \
    && test -s ~/.config/coc/extensions/package.json

WORKDIR /workspace
CMD ["zsh", "-l"]
