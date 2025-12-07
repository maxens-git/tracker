#!/usr/bin/env bash

# deploy.sh — Script de build & push pour le projet Tracker
# Usage: ./deploy.sh [tag] [--no-push]

set -euo pipefail

# Configuration par défaut
REGISTRY="ghcr.io"
USERNAME="maxens-git"
REPO_NAME="tracker"
IMAGE_NAME="${REGISTRY}/${USERNAME}/${REPO_NAME}"
TAG="${1:-latest}"
NO_PUSH=false
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Environment helpers (optional): GHCR_USERNAME / GHCR_TOKEN

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() { echo -e "${YELLOW}🔄 $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

usage() {
    cat <<EOF
Usage: $0 [tag] [--no-push]

Build and (optionally) push multi-platform Docker images to ${REGISTRY}.

Environment variables:
  GHCR_USERNAME, GHCR_TOKEN  Optional, used to login to ${REGISTRY} if pushing.
  PLATFORMS                  Comma-separated platforms (default: ${PLATFORMS}).

Examples:
  $0 v1.2.3           # build and push ${IMAGE_NAME}:v1.2.3
  $0 local --no-push  # build image locally but do not push
EOF
}

# Parse flags
for arg in "${@:2}"; do
    case "$arg" in
        --no-push) NO_PUSH=true ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $arg"; usage; exit 1 ;;
    esac
done

# Backup current script
if [ -f deploy.sh ] && [ ! -f deploy.sh.bak ]; then
    cp deploy.sh deploy.sh.bak
    print_step "Backup created: deploy.sh.bak"
fi

# Check Docker availability
if ! command -v docker >/dev/null 2>&1; then
    print_error "Docker n'est pas installé ou n'est pas dans le PATH."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    print_error "Docker ne répond pas. Assurez-vous que le démon Docker est démarré."
    exit 1
fi

# Ensure buildx builder exists
if ! docker buildx inspect multi-builder >/dev/null 2>&1; then
    print_step "Creating buildx builder 'multi-builder'"
    docker buildx create --name multi-builder --use || docker buildx create --use
fi

print_step "Building image ${IMAGE_NAME}:${TAG} for platforms: ${PLATFORMS}"

BUILD_CMD=(docker buildx build --platform "${PLATFORMS}" -t "${IMAGE_NAME}:${TAG}" -f Dockerfile .)

if [ "$NO_PUSH" = true ]; then
    BUILD_CMD+=(--load)
else
    BUILD_CMD+=(--push)
fi

# Login to GHCR if needed and credentials provided
if [ "$NO_PUSH" = false ]; then
    if [ -n "${GHCR_TOKEN:-}" ] && [ -n "${GHCR_USERNAME:-}" ]; then
        print_step "Logging in to ${REGISTRY} as ${GHCR_USERNAME}"
        echo "${GHCR_TOKEN}" | docker login "${REGISTRY}" -u "${GHCR_USERNAME}" --password-stdin
    else
        print_step "No GHCR credentials found in env (GHCR_USERNAME/GHCR_TOKEN). Docker might already be logged in."
    fi
fi

set +e
"${BUILD_CMD[@]}"
RC=$?
set -e

if [ $RC -ne 0 ]; then
    print_error "Docker buildx failed (exit code $RC)."
    exit $RC
fi

print_success "Image built: ${IMAGE_NAME}:${TAG}"

if [ "$NO_PUSH" = false ]; then
    print_success "Image pushed to ${REGISTRY}"
else
    print_success "Image available locally (loaded into docker)"
fi

echo ""
echo "📦 Image: ${IMAGE_NAME}:${TAG}"
echo "💡 To run locally: docker run -p 8080:8080 ${IMAGE_NAME}:${TAG}"

exit 0