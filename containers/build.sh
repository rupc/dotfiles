#!/usr/bin/env bash
# devbox 이미지 빌드 — 컨텍스트는 저장소 루트 (dotfiles 전체가 이미지에 들어감)
# 사용법: ./build.sh [태그]   (기본 태그: rupc/devbox:latest)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${1:-rupc/devbox:latest}"

docker build \
    --file "$REPO_ROOT/containers/Dockerfile" \
    --tag "$TAG" \
    "$REPO_ROOT"

echo ""
echo "빌드 완료: $TAG"
echo "실행: containers/run.sh [작업디렉토리]"
