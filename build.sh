#!/bin/bash

# build.sh - Build the dx developer image
# Supports both Docker and Apple's container command

set -e

IMAGE_NAME="dx:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    echo "Building ${IMAGE_NAME} using ${runtime}..."

    if [ "$runtime" = "container" ]; then
        container build -t "${IMAGE_NAME}" "$SCRIPT_DIR"
    else
        docker build -t "${IMAGE_NAME}" "$SCRIPT_DIR"
    fi

    echo ""
    echo "Build complete! You can now run:"
    echo "  ./dx                  # Start interactive shell"
    echo "  ./dx <command>        # Run command in container"
}

# Main execution
main() {
    local runtime=$(detect_runtime)
    echo "Detected runtime: ${runtime}"
    build_image "$runtime"
}

main "$@"
