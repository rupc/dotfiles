#!/usr/bin/env bash
# ============================================================================
# neovim 환경만 셋업 — nvim + vimrc + 플러그인 + 내장 LSP + 노트북(ipynb) 지원
# (셸 설정은 건드리지 않음. 공용 머신에서 내 에디터만 얹을 때 사용)
#
# LSP는 nvim 내장(0.11+)을 쓴다 — coc.nvim 제거(2026-07), Node 의존성 없음.
# linux에서 nvim은 apt가 아니라 공식 릴리즈 바이너리를 ~/.local에 설치한다.
# (apt nvim은 0.6~0.7대 — nvim_create_augroup 등 lua API가 없어서
#  toggleterm/coc/테마가 전부 startup 에러를 뿜던 사고의 재발 방지)
#
# 실행 흐름(전부 로그로 표시):
#   ① 사전 요구사항 점검 — 없으면 어떤 컴포넌트가 영향을 받는지 알려줌
#   ② 컴포넌트별 현황 — 이미 있으면 ✓ 스킵, 없으면 설치 진행
#   ③ 요약 — 이미 있음 / 새로 설치 / 생략(사유) / 실패(사유)
# 멱등: 몇 번을 다시 실행해도 없는 것만 골라 설치한다.
#
# 사용법:
#   ./setup-nvim.sh                  # 패키지 설치 포함 (mac: brew, linux: apt+sudo)
#   SKIP_PACKAGES=1 ./setup-nvim.sh  # sudo 없는 공용 머신 (nvim은 sudo 없이 ~/.local에 설치됨)
# ============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
NVIM_MIN="0.11.0"   # vim.lsp.config/enable + lua 플러그인들의 최소 요구 버전

case "$(uname -s)" in
    Darwin) OS="mac" ;;
    Linux)  OS="linux" ;;
    *)      echo "지원하지 않는 OS"; exit 1 ;;
esac

# --- 로깅/집계 헬퍼 (setup-shell.sh와 공용) ---------------------------------
SETUP_SCRIPT="./setup-nvim.sh"
source "$DOTFILES_DIR/lib-report.sh"

# --- 0. 사전 요구사항 점검 --------------------------------------------------
step "사전 요구사항 점검 (없으면 해당 컴포넌트는 아래 단계에서 '생략'으로 표시)"
if have curl; then ok "curl"; else
    err "curl 없음 — nvim/vim-plug/chezmoi 다운로드 불가. 설치 후 재실행하라."; exit 1
fi
if [ "$OS" = "mac" ]; then
    have brew && ok "brew" || warn "brew 없음 — 패키지 설치 단계 생략됨 (https://brew.sh)"
else
    have sudo && ok "sudo" || warn "sudo 없음 — apt 패키지 설치 불가 (SKIP_PACKAGES=1로 실행 권장)"
fi
have python3 && ok "python3" || warn "python3 없음 — 노트북 venv·python LSP(basedpyright) 생략됨"
have npm && ok "npm ($(npm --version 2>/dev/null || echo '?'))" \
    || warn "npm 없음 — bash/yaml LSP·typescript·tree-sitter CLI 생략됨 (node 설치: nvm 등)"
if have cc || have gcc || have clang; then ok "C 컴파일러"; else
    warn "C 컴파일러 없음 — treesitter 파서 컴파일 생략됨 (apt: build-essential / mac: xcode-select --install)"
fi
have go     && ok "go"     || warn "go 없음 — gopls(go LSP) 생략됨"
have rustup && ok "rustup" || warn "rustup 없음 — rust-analyzer(rust LSP) 생략됨"
[ "$OS" = "linux" ] && { have cargo && ok "cargo" || warn "cargo 없음 — (linux) taplo(toml LSP) 생략됨"; }
[ -n "${SKIP_PACKAGES:-}" ] && warn "SKIP_PACKAGES=1 — 패키지 매니저(brew/apt) 설치 단계 전부 생략"

# --- 1. nvim 확보 (버전 검사 포함) ---
# ~/.local/bin/nvim이 있으면 시스템 nvim보다 우선 (공용 머신의 낡은 /usr/bin/nvim 회피)
nvim_bin() {
    if [ -x "$HOME/.local/bin/nvim" ]; then
        echo "$HOME/.local/bin/nvim"
    else
        command -v nvim || true
    fi
}
nvim_ok() {
    local bin ver
    bin=$(nvim_bin); [ -n "$bin" ] || return 1
    ver=$("$bin" --version 2>/dev/null | head -1 | sed 's/^NVIM v//') || return 1
    [ -n "$ver" ] || return 1
    [ "$(printf '%s\n' "$NVIM_MIN" "$ver" | sort -V | head -1)" = "$NVIM_MIN" ]
}

step "1/8 nvim (>= $NVIM_MIN)"
if nvim_ok; then
    already "nvim" "$("$(nvim_bin)" --version | head -1)"
else
    echo "  … nvim 설치 중"
    if [ "$OS" = "mac" ]; then
        brew install neovim || brew upgrade neovim || true
    else
        # 공식 릴리즈 tarball → ~/.local (sudo 불필요, SKIP_PACKAGES와 무관하게 실행).
        # 공식 빌드는 최신 glibc 기준이라 구형 배포판에서 실행이 안 될 수 있는데,
        # 그 경우 같은 파일명을 제공하는 neovim-releases(구 glibc용 빌드)로 폴백.
        ARCH=$([ "$(uname -m)" = "aarch64" ] && echo "arm64" || echo "x86_64")
        TARBALL="nvim-linux-${ARCH}.tar.gz"
        NVIM_TMP=$(mktemp -d)
        mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
        for REPO in neovim/neovim neovim/neovim-releases; do
            echo "  … ${REPO} 릴리즈 다운로드 시도"
            curl -fsSL "https://github.com/${REPO}/releases/download/stable/${TARBALL}" \
                -o "$NVIM_TMP/$TARBALL" || continue
            rm -rf "$HOME/.local/opt/nvim-linux-${ARCH}"
            tar xzf "$NVIM_TMP/$TARBALL" -C "$HOME/.local/opt"
            ln -sf "$HOME/.local/opt/nvim-linux-${ARCH}/bin/nvim" "$HOME/.local/bin/nvim"
            "$HOME/.local/bin/nvim" --version >/dev/null 2>&1 && break   # glibc 호환 확인
        done
        rm -rf "$NVIM_TMP"
    fi
    # 버전 미달이면 여기서 즉시 실패 — 구버전 위에 플러그인만 깔린 어중간한 상태를 만들지 않는다
    if nvim_ok; then
        newly "nvim ($("$(nvim_bin)" --version | head -1))"
    else
        failed "nvim" "${NVIM_MIN}+ 확보 실패 (현재: $(nvim_bin || echo 없음))"
        print_summary
        echo "에러: nvim --version 확인 후 다시 실행하라." >&2
        exit 1
    fi
fi
NVIM=$(nvim_bin)

# --- 2. 에디터 보조 패키지 (ripgrep=:Rg, imagemagick=그래프 인라인 렌더링,
#        진단/포맷팅용 shfmt·shellcheck는 bash-language-server가 사용) ---
step "2/8 에디터 보조 패키지 (ripgrep·imagemagick·kitty·shellcheck·shfmt)"
# pkg이름:확인용실행파일 (imagemagick은 v6=convert, v7=magick)
AUX_PKGS="ripgrep:rg imagemagick:convert,magick kitty:kitty shellcheck:shellcheck shfmt:shfmt"
AUX_MISSING=()
for entry in $AUX_PKGS; do
    pkg=${entry%%:*}
    found=""
    IFS=',' read -ra cmds <<<"${entry#*:}"
    for cmd in "${cmds[@]}"; do have "$cmd" && found=1 && break; done
    if [ -n "$found" ]; then already "$pkg"; else AUX_MISSING+=("$pkg"); fi
done
if [ "${#AUX_MISSING[@]}" -gt 0 ]; then
    if [ -n "${SKIP_PACKAGES:-}" ]; then
        for pkg in "${AUX_MISSING[@]}"; do skipped "$pkg" "SKIP_PACKAGES=1"; done
    elif [ "$OS" = "mac" ]; then
        if have brew; then
            for pkg in "${AUX_MISSING[@]}"; do
                echo "  … $pkg 설치 중 (brew)"
                if [ "$pkg" = "kitty" ]; then
                    brew install --cask kitty && newly kitty || failed kitty "brew cask 설치 실패"
                else
                    brew install "$pkg" && newly "$pkg" || failed "$pkg" "brew 설치 실패"
                fi
            done
        else
            for pkg in "${AUX_MISSING[@]}"; do skipped "$pkg" "brew 없음"; done
        fi
    else
        if have sudo; then
            sudo apt-get update
            for pkg in "${AUX_MISSING[@]}"; do
                echo "  … $pkg 설치 중 (apt)"
                sudo apt-get install -y "$pkg" && newly "$pkg" || failed "$pkg" "이 배포판 apt에 없음"
            done
        else
            for pkg in "${AUX_MISSING[@]}"; do skipped "$pkg" "sudo 없음"; done
        fi
    fi
fi

# --- 3. chezmoi + vim-plug ---
step "3/8 chezmoi + vim-plug"
if have chezmoi; then
    already "chezmoi"
else
    echo "  … chezmoi 설치 중 (~/.local/bin)"
    if sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"; then
        export PATH="$HOME/.local/bin:$PATH"
        newly "chezmoi"
    else
        failed "chezmoi" "설치 스크립트 실패"; print_summary; exit 1
    fi
fi
if [ -f "$HOME/.vim/autoload/plug.vim" ]; then
    already "vim-plug"
else
    echo "  … vim-plug 다운로드 중"
    curl -fsSLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim \
        && newly "vim-plug" || { failed "vim-plug" "다운로드 실패"; print_summary; exit 1; }
fi

# --- 4. vim/nvim dotfiles만 배포 ---
# sourceDir은 항상 이 repo로 강제. 예전 셋업이 남긴 chezmoi.toml이 옛 clone을
# 가리키면 coc 시절 vimrc가 배포되어 "client coc abnormal exit with 1"이 재발한다.
step "4/8 vimrc·nvim 설정 배포 (chezmoi apply — 매번 실행)"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$DOTFILES_DIR" > "$HOME/.config/chezmoi/chezmoi.toml"
if chezmoi apply --source "$DOTFILES_DIR" "$HOME/.vimrc" "$HOME/.config/nvim"; then
    ok "적용됨: ~/.vimrc, ~/.config/nvim (소스: $DOTFILES_DIR)"
else
    failed "설정 배포(chezmoi apply)" "명령 실패"; print_summary; exit 1
fi

# --- 5. 전용 venv — 노트북(pynvim/jupyter/jupytext) + python LSP(basedpyright) ---
# basedpyright는 pip 패키지 하나로 language server까지 들어와서 node가 필요 없다
step "5/8 python venv (노트북 + basedpyright LSP) — ~/.venvs/nvim"
NVIM_VENV="$HOME/.venvs/nvim"
if ! have python3; then
    skipped "python venv(노트북·basedpyright)" "python3 없음"
elif [ -x "$NVIM_VENV/bin/python" ] && [ -x "$NVIM_VENV/bin/basedpyright-langserver" ]; then
    already "python venv(pynvim·jupytext·basedpyright)"
elif [ -x "$NVIM_VENV/bin/python" ]; then
    # 기존 venv 마이그레이션: basedpyright만 없으면 추가
    echo "  … 기존 venv에 basedpyright 추가 중"
    "$NVIM_VENV/bin/pip" install --quiet basedpyright \
        && newly "basedpyright(기존 venv에 추가)" \
        || failed "basedpyright" "pip 설치 실패 (python LSP 제외하고 계속)"
else
    echo "  … venv 생성 + pynvim/jupyter/jupytext/basedpyright 설치 중"
    if python3 -m venv "$NVIM_VENV" \
        && "$NVIM_VENV/bin/pip" install --quiet --upgrade pip \
        && "$NVIM_VENV/bin/pip" install --quiet pynvim jupyter_client ipykernel jupytext basedpyright \
        && "$NVIM_VENV/bin/python" -m ipykernel install --user --name nvim-python >/dev/null; then
        newly "python venv(pynvim·jupytext·basedpyright)"
    else
        failed "python venv" "구성 실패 (molten·python LSP 제외하고 계속)"
    fi
fi

# --- 6. 언어 서버들 — 없으면 해당 언어 LSP만 조용히 빠짐 (vimrc가 바이너리 유무로 판단) ---
step "6/8 언어 서버 (sh·yaml·js/ts·toml·rust)"
# node 기반: sh=bash-language-server / yaml=yaml-language-server
# mac은 brew 우선, 그 외(또는 SKIP_PACKAGES)는 npm 폴백
for srv in bash-language-server yaml-language-server; do
    if have "$srv"; then already "$srv"; continue; fi
    if [ "$OS" = "mac" ] && [ -z "${SKIP_PACKAGES:-}" ] && have brew; then
        echo "  … $srv 설치 중 (brew)"
        brew install "$srv" || true
    fi
    if ! have "$srv" && have npm; then
        echo "  … $srv 설치 중 (npm -g)"
        npm install -g "$srv" || true
    fi
    if have "$srv"; then newly "$srv"
    elif have npm; then failed "$srv" "npm 설치 실패"
    else skipped "$srv" "npm 없음 (node 설치 필요)"
    fi
done

# js/ts: typescript 7+는 LSP를 네이티브 내장(tsc --lsp; Go 바이너리, node 래퍼 불필요).
# 머신마다 TS 세대가 다르므로 감지 후 ~/.local/bin/ts-lsp 로 진입점 통일 (vimrc가 사용)
if ! have tsc; then
    if [ "$OS" = "mac" ] && [ -z "${SKIP_PACKAGES:-}" ] && have brew; then
        echo "  … typescript 설치 중 (brew)"
        brew install typescript || true
    fi
    if ! have tsc && have npm; then
        echo "  … typescript 설치 중 (npm -g)"
        npm install -g typescript || true
    fi
fi
mkdir -p "$HOME/.local/bin"
TS_LSP_EXISTED=$([ -x "$HOME/.local/bin/ts-lsp" ] && echo 1 || true)
if have tsc && tsc --version 2>/dev/null | grep -qE 'Version ([7-9]|[1-9][0-9])\.'; then
    printf '#!/bin/sh\nexec tsc --lsp -stdio\n' > "$HOME/.local/bin/ts-lsp"
    chmod +x "$HOME/.local/bin/ts-lsp"
    [ -n "$TS_LSP_EXISTED" ] && already "ts-lsp" "tsc --lsp (TS7+ 네이티브)" || newly "ts-lsp(tsc --lsp)"
elif have typescript-language-server; then
    # 구세대(TS5 이하) 머신 폴백 — tsserver.js 기반 래퍼
    printf '#!/bin/sh\nexec typescript-language-server --stdio\n' > "$HOME/.local/bin/ts-lsp"
    chmod +x "$HOME/.local/bin/ts-lsp"
    [ -n "$TS_LSP_EXISTED" ] && already "ts-lsp" "typescript-language-server 래퍼" || newly "ts-lsp(typescript-language-server)"
elif have npm; then
    failed "ts-lsp(js/ts LSP)" "typescript 설치 실패"
else
    skipped "ts-lsp(js/ts LSP)" "npm 없음 (node 설치 필요)"
fi

# toml=taplo (단일 바이너리)
if have taplo; then
    already "taplo"
elif [ -n "${SKIP_PACKAGES:-}" ]; then
    skipped "taplo(toml LSP)" "SKIP_PACKAGES=1"
elif [ "$OS" = "mac" ]; then
    if have brew; then
        echo "  … taplo 설치 중 (brew)"
        brew install taplo && newly "taplo" || failed "taplo" "brew 설치 실패"
    else
        skipped "taplo(toml LSP)" "brew 없음"
    fi
elif have cargo; then
    echo "  … taplo 설치 중 (cargo — 소스 빌드라 몇 분 걸릴 수 있음)"
    cargo install taplo-cli --locked && newly "taplo" || failed "taplo" "cargo 빌드 실패"
else
    skipped "taplo(toml LSP)" "cargo 없음"
fi

# rust=rust-analyzer — rustup이 있는 머신에서만 (rust 툴체인 없이는 어차피 무용)
if have rust-analyzer; then
    already "rust-analyzer"
elif have rustup; then
    echo "  … rust-analyzer 설치 중 (rustup component)"
    rustup component add rust-analyzer && newly "rust-analyzer" || failed "rust-analyzer" "rustup component 실패"
else
    skipped "rust-analyzer(rust LSP)" "rustup 없음"
fi

# --- 7. tree-sitter CLI — nvim-treesitter(main 브랜치)의 파서 설치/컴파일에 필요 ---
# (brew의 tree-sitter formula는 라이브러리 전용 — CLI는 tree-sitter-cli)
step "7/8 tree-sitter CLI (파서 컴파일용)"
ts_cli_runs() { tree-sitter --version >/dev/null 2>&1; }
if ! have tree-sitter; then
    if [ "$OS" = "mac" ] && [ -z "${SKIP_PACKAGES:-}" ] && have brew; then
        echo "  … tree-sitter-cli 설치 중 (brew)"
        brew install tree-sitter-cli || true
    fi
    if ! have tree-sitter && have npm; then
        echo "  … tree-sitter-cli 설치 중 (npm -g)"
        npm install -g tree-sitter-cli || true
    fi
fi
# npm/릴리즈 prebuilt 0.26+는 glibc 2.39 링크라 구형 배포판(예: jammy 22.04=2.35)에서
# 실행 자체가 안 됨("GLIBC_2.39 not found"). 설치됐어도 실행 검사 후,
# 안 돌면 구 glibc(2.34)로 빌드된 마지막 prebuilt인 0.25.10으로 강제 교체.
if have tree-sitter && ! ts_cli_runs && have npm; then
    warn "tree-sitter CLI가 설치됐지만 실행 불가(glibc 비호환) — 0.25.10으로 교체 시도"
    npm install -g tree-sitter-cli@0.25.10 || true
fi
if have tree-sitter && ts_cli_runs; then
    already "tree-sitter CLI" "$(tree-sitter --version 2>/dev/null | head -1)"
elif have tree-sitter; then
    failed "tree-sitter CLI" "이 배포판 glibc에서 실행 불가 (파서 신규 설치 제외하고 계속)"
elif have npm; then
    failed "tree-sitter CLI" "npm 설치 실패 (파서 신규 설치 제외하고 계속)"
else
    skipped "tree-sitter CLI" "npm 없음 (node 설치 필요)"
fi

# --- 8. 플러그인 설치/정리 + treesitter 파서 + molten 원격플러그인 등록 ---
step "8/8 vim 플러그인 + treesitter 파서 + 원격플러그인"
# coc 잔재는 명시적으로 삭제 (PlugClean은 || true라 실패해도 조용히 지나가므로)
rm -rf "$HOME/.vim/plugged/coc.nvim" "$HOME/.config/coc"
PLUGS_BEFORE=$(ls "$HOME/.vim/plugged" 2>/dev/null || true)
# PlugClean!: vimrc에서 제거된 플러그인 디렉토리 정리
echo "  … vim-plug 플러그인 설치/정리 중 (PlugInstall --sync + PlugClean!)"
"$NVIM" --headless "+PlugInstall --sync" "+PlugClean!" "+qall" || true
PLUGS_AFTER=$(ls "$HOME/.vim/plugged" 2>/dev/null || true)
PLUGS_NEW=$(comm -13 <(echo "$PLUGS_BEFORE") <(echo "$PLUGS_AFTER") | tr '\n' ' ')
if [ -n "${PLUGS_NEW// /}" ]; then
    newly "vim 플러그인: ${PLUGS_NEW}"
else
    already "vim 플러그인" "$(echo "$PLUGS_AFTER" | grep -c . || true)개 모두 최신"
fi

# treesitter 파서 설치/컴파일 (tree-sitter CLI + cc 필요) — 실패해도 regex syntax 폴백
# 언어 목록은 vimrc의 vim.g.my_ts_langs 한 곳에서 관리
# CLI가 "존재"만 하는 게 아니라 실제 "실행"되는지 확인 후 진행 (glibc 비호환 대비 —
# 안 돌면 파서마다 컴파일 에러가 수십 줄 쏟아지므로 여기서 한 줄로 끊는다)
if ! { have tree-sitter && ts_cli_runs; }; then
    skipped "treesitter 파서" "실행 가능한 tree-sitter CLI 없음 (nvim 내장 파서 + regex syntax로 동작)"
elif ! { have cc || have gcc || have clang; }; then
    skipped "treesitter 파서" "C 컴파일러 없음 (apt: build-essential)"
else
    echo "  … treesitter 파서 설치/갱신 중 (목록: vimrc vim.g.my_ts_langs — 아래 진행 로그는 nvim-treesitter 출력)"
    "$NVIM" --headless \
        "+lua local ok,ts=pcall(require,'nvim-treesitter'); if ok then ts.install(vim.g.my_ts_langs or {}):wait(600000) end" \
        "+qall" || true
    echo ""
    ok "treesitter 파서 갱신 완료 (개별 파서의 error는 위 로그 참고)"
fi

echo "  … molten 원격플러그인 등록 중 (UpdateRemotePlugins)"
"$NVIM" --headless "+UpdateRemotePlugins" "+qall" || true

# --- ACP 에이전트 브리지 — agentic.nvim이 claude/gemini/codex에 붙는 통로 ---
# 브리지가 없으면 그 provider만 못 쓰는 것이라, 하나씩 독립적으로 처리한다.
# (에이전트 CLI 자체(claude/codex/gemini)는 각자 설치 경로가 달라 여기서 안 건드림)
step "ACP 에이전트 브리지 (agentic.nvim용)"
# 브리지이름:실행파일
ACP_BRIDGES="@agentclientprotocol/claude-agent-acp:claude-agent-acp @google/gemini-cli:gemini @zed-industries/codex-acp:codex-acp"
for entry in $ACP_BRIDGES; do
    pkg=${entry%:*}; bin=${entry##*:}
    if have "$bin"; then
        already "$bin"
    elif ! have npm; then
        skipped "$bin(ACP 브리지)" "npm 없음 (node 설치 필요)"
    else
        echo "  … $pkg 설치 중 (npm -g)"
        if npm install -g "$pkg" && have "$bin"; then newly "$bin"
        else failed "$bin(ACP 브리지)" "npm 설치 실패 — 이 provider만 제외하고 계속"; fi
    fi
done

# gopls (go가 있으면 — vim-go가 사용)
if have gopls; then
    already "gopls"
elif have go; then
    echo "  … gopls 설치 중 (go install — 몇 분 걸릴 수 있음)"
    go install golang.org/x/tools/gopls@latest && newly "gopls" || failed "gopls" "go install 실패"
else
    skipped "gopls(go LSP)" "go 없음"
fi

print_summary

echo ""
echo "neovim 환경 셋업 완료. LSP는 nvim 내장(0.11+) — 서버 실행파일이 있으면 자동 연결:"
echo "  python=basedpyright(venv 포함) / rust=rust-analyzer(rustup) / c,cpp=clangd / go=gopls"
echo "  sh=bash-language-server / js,ts=ts-lsp(TS7 네이티브) / yaml=yaml-language-server / toml=taplo"
echo "자동완성=nvim-cmp(LSP+ultisnips+버퍼+경로), 하이라이팅=treesitter"
echo "노트북: kitty 터미널에서 nvim으로 .ipynb 열기 -> ,mi (MoltenInit) -> Ctrl+Enter로 셀 실행"
