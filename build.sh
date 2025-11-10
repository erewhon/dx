#!/bin/bash

# build.sh - Build the dx developer image
# Supports both Docker and Apple's container command
#
# Usage:
#   ./build.sh                           # Build with local tag only
#   ./build.sh --current-user            # Build with current user's UID/GID
#   ./build.sh username                  # Build and tag for GitHub registry
#   ./build.sh username v1.0.0           # Build with specific version tag
#   ./build.sh --current-user username   # Build with current user and GitHub tags

set -e

IMAGE_NAME="dx"
VERSION="latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_USER=""
USE_CURRENT_USER=false
BUILD_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --current-user)
            USE_CURRENT_USER=true
            shift
            ;;
        *)
            if [ -z "$GITHUB_USER" ]; then
                GITHUB_USER="$1"
            else
                VERSION="$1"
            fi
            shift
            ;;
    esac
done

# Set build args for user if requested
if [ "$USE_CURRENT_USER" = true ]; then
    USER_UID=$(id -u)
    USER_GID=$(id -g)
    BUILD_ARGS+=("--build-arg" "USER_UID=${USER_UID}")
    BUILD_ARGS+=("--build-arg" "USER_GID=${USER_GID}")
    echo "Building with current user: UID=${USER_UID}, GID=${USER_GID}"
fi

# Detect which container runtime is available
detect_runtime() {
    if command -v container &> /dev/null; then
        echo "container"
    elif command -v docker &> /dev/null; then
        echo "docker"
    else
        echo "error: neither 'container' nor 'docker' command found" >&2
        echo "Please install Docker Desktop or Apple's container tools" >&2
        exit 1
    fi
}

# Build the image
build_image() {
    local runtime=$1
    local build_cmd=""
    local tags=()

    # Always include local tag
    tags+=("-t" "${IMAGE_NAME}:latest")

    # Add GitHub registry tags if username provided
    if [ -n "$GITHUB_USER" ]; then
        tags+=("-t" "ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${VERSION}")
        if [ "$VERSION" != "latest" ]; then
            tags+=("-t" "ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:latest")
        fi
    fi

    echo "Building ${IMAGE_NAME} using ${runtime}..."
    echo "Tags: ${tags[*]}"

    if [ "$runtime" = "container" ]; then
        container build "${tags[@]}" "${BUILD_ARGS[@]}" "$SCRIPT_DIR"
    else
        docker build "${tags[@]}" "${BUILD_ARGS[@]}" "$SCRIPT_DIR"
    fi

    echo ""
    echo "Build complete! You can now run:"
    echo "  ./dx                  # Start interactive shell"
    echo "  ./dx <command>        # Run command in container"

    if [ -n "$GITHUB_USER" ]; then
        echo ""
        echo "To push to GitHub Container Registry:"
        if [ "$runtime" = "container" ]; then
            echo "  container push ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${VERSION}"
            [ "$VERSION" != "latest" ] && echo "  container push ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:latest"
        else
            echo "  docker push ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:${VERSION}"
            [ "$VERSION" != "latest" ] && echo "  docker push ghcr.io/${GITHUB_USER}/${IMAGE_NAME}:latest"
        fi
        echo ""
        echo "Make sure you're logged in first:"
        echo "  echo \$GITHUB_TOKEN | ${runtime} login ghcr.io -u ${GITHUB_USER} --password-stdin"
    fi
}

# Main execution
main() {
    local runtime=$(detect_runtime)
    echo "Detected runtime: ${runtime}"
    build_image "$runtime"
}

main
