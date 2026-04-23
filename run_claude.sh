#!/bin/bash

set -euo pipefail

TARGET_DIR=$(pwd)
READONLY=""
VOLUME_NAME="claude-config"
TOOLCHAIN="base"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKERFILES_DIR="$SCRIPT_DIR/dockerfiles"

usage() {
    echo "Bruk: $0 [-d katalog] [-r] [-v volumnavn] [-t toolchain]"
    echo "  -d    Katalog Claude skal jobbe i (standard: nåværende)"
    echo "  -r    Monter som skrivebeskyttet (read-only)"
    echo "  -v    Docker volumnavn for konfigurasjon (standard: claude-config)"
    echo "  -t    Toolchain (standard: base). Tilgjengelige:"
    for f in "$DOCKERFILES_DIR"/*.Dockerfile; do
        [ -e "$f" ] || continue
        name=$(basename "$f" .Dockerfile)
        echo "          - $name"
    done
    exit 1
}

while getopts "d:rv:t:h" opt; do
    case $opt in
        d) TARGET_DIR=$(realpath "$OPTARG") ;;
        r) READONLY=":ro" ;;
        v) VOLUME_NAME="$OPTARG" ;;
        t) TOOLCHAIN="$OPTARG" ;;
        *) usage ;;
    esac
done

DOCKERFILE="$DOCKERFILES_DIR/${TOOLCHAIN}.Dockerfile"
if [ ! -f "$DOCKERFILE" ]; then
    echo "Feil: fant ikke $DOCKERFILE"
    usage
fi

echo "Bygger claude-code-base..."
docker build -t claude-code-base -f "$DOCKERFILES_DIR/base.Dockerfile" "$DOCKERFILES_DIR"

IMAGE_TAG="claude-code-${TOOLCHAIN}"
if [ "$TOOLCHAIN" != "base" ]; then
    echo "Bygger $IMAGE_TAG..."
    docker build -t "$IMAGE_TAG" -f "$DOCKERFILE" "$DOCKERFILES_DIR"
fi

echo "Starter Claude ($TOOLCHAIN) i: $TARGET_DIR (ReadOnly: ${READONLY:-false})"

docker run -it \
  --rm \
  -v "$TARGET_DIR:/app$READONLY" \
  -v "$VOLUME_NAME:/root/.claude" \
  --workdir /app \
  "$IMAGE_TAG"
