#!/usr/bin/env bash
# devbox 컨테이너 실행 — 지정한 디렉토리(기본: 현재 디렉토리)를 /workspace로 마운트
# 사용법:
#   ./run.sh                 # 현재 디렉토리에서 작업
#   ./run.sh ~/work/myproj   # 특정 프로젝트에서 작업
#   DEVBOX_TAG=... ./run.sh  # 다른 태그 사용
set -euo pipefail

TAG="${DEVBOX_TAG:-rupc/devbox:latest}"
WORKDIR="$(cd "${1:-$PWD}" && pwd)"

exec docker run --rm -it \
    --hostname devbox \
    -v "$WORKDIR":/workspace \
    -w /workspace \
    "$TAG"
