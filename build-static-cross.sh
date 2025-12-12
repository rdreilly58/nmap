#!/bin/bash

# Static Cross-Compilation Build Script for Nmap
# Builds statically linked nmap binaries for ARM64, ARM32, and x86_64

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_DIR="${SCRIPT_DIR}/static-binaries"

# Target architectures
TARGETS=(
    "x86_64-linux-gnu"
    "aarch64-linux-gnu"
    "arm-linux-gnueabihf"
)

# Architecture mappings
declare -A ARCH_NAMES=(
    ["x86_64-linux-gnu"]="x86_64"
    ["aarch64-linux-gnu"]="arm64"
    ["arm-linux-gnueabihf"]="arm32"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if cross-compilation toolchains are available
check_toolchains() {
    log "Checking for cross-compilation toolchains..."
    
    local missing_toolchains=()
    
    for target in "${TARGETS[@]}"; do
        if ! command -v "${target}-gcc" &> /dev/null; then
            missing_toolchains+=("$target")
        fi
    done
    
    if [ ${#missing_toolchains[@]} -ne 0 ]; then
        error "Missing cross-compilation toolchains:"
        for toolchain in "${missing_toolchains[@]}"; do
            echo "  - $toolchain"
        done
        echo
        echo "Install them with:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install gcc-multilib"
        echo "  sudo apt-get install gcc-aarch64-linux-gnu"
        echo "  sudo apt-get install gcc-arm-linux-gnueabihf"
        echo "  sudo apt-get install libc6-dev-arm64-cross"
        echo "  sudo apt-get install libc6-dev-armhf-cross"
        exit 1
    fi
    
    success "All required toolchains are available"
}

# Install build dependencies
install_dependencies() {
    log "Installing build dependencies..."
    
    # Check if we're on a Debian/Ubuntu system
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            autoconf \
            automake \
            libtool \
            pkg-config \
            libssl-dev \
            zlib1g-dev \
            libpcap-dev \
            libpcre3-dev \
            liblua5.4-dev \
            gcc-multilib \
            gcc-aarch64-linux-gnu \
            gcc-arm-linux-gnueabihf \
            libc6-dev-arm64-cross \
            libc6-dev-armhf-cross
    else
        warn "Non-Debian system detected. Please install cross-compilation toolchains manually."
    fi
}

# Clean previous builds
clean_build() {
    log "Cleaning previous builds..."
    rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
    mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
    
    # Clean the source tree
    if [ -f Makefile ]; then
        make distclean || true
    fi
}

# Configure and build for a specific target
build_target() {
    local target="$1"
    local arch_name="${ARCH_NAMES[$target]}"
    
    log "Building nmap for $arch_name ($target)..."
    
    local build_path="${BUILD_DIR}/${arch_name}"
    mkdir -p "$build_path"
    
    # Copy source to build directory
    rsync -av --exclude=build --exclude=static-binaries . "$build_path/"
    cd "$build_path"
    
    # Set cross-compilation environment variables
    export CC="${target}-gcc"
    export CXX="${target}-g++"
    export AR="${target}-ar"
    export STRIP="${target}-strip"
    export RANLIB="${target}-ranlib"
    export PKG_CONFIG_PATH=""
    
    # Configure build flags for static linking
    export CFLAGS="-static -O2 -fPIC"
    export CXXFLAGS="-static -O2 -fPIC"
    export LDFLAGS="-static -static-libgcc -static-libstdc++"
    
    # Configure with static options
    log "Configuring build for $arch_name..."
    ./configure \
        --host="$target" \
        --enable-static \
        --disable-shared \
        --with-libpcap=included \
        --with-libpcre=included \
        --with-libdnet=included \
        --with-liblua=included \
        --with-liblinear=included \
        --with-libssh2=included \
        --with-libz=included \
        --without-zenmap \
        --without-ndiff \
        --without-nping \
        --without-ncat \
        --with-openssl=no \
        --prefix="/usr/local"
    
    # Build the static binary
    log "Compiling nmap for $arch_name..."
    make static -j$(nproc)
    
    # Verify the binary is statically linked
    if file nmap | grep -q "statically linked"; then
        success "Successfully built static nmap for $arch_name"
    else
        warn "Binary may not be fully statically linked for $arch_name"
    fi
    
    # Copy binary to output directory
    cp nmap "${OUTPUT_DIR}/nmap-${arch_name}"
    "${STRIP}" "${OUTPUT_DIR}/nmap-${arch_name}"
    
    # Return to script directory
    cd "$SCRIPT_DIR"
}

# Build all targets
build_all() {
    for target in "${TARGETS[@]}"; do
        build_target "$target"
    done
}

# Verify built binaries
verify_binaries() {
    log "Verifying built binaries..."
    
    for target in "${TARGETS[@]}"; do
        local arch_name="${ARCH_NAMES[$target]}"
        local binary="${OUTPUT_DIR}/nmap-${arch_name}"
        
        if [ -f "$binary" ]; then
            echo "=== nmap-${arch_name} ==="
            file "$binary"
            ls -lh "$binary"
            echo
        else
            error "Binary not found: $binary"
        fi
    done
}

# Create distribution package
create_package() {
    log "Creating distribution package..."
    
    cd "$OUTPUT_DIR"
    
    # Create README
    cat > README.txt << 'EOF'
Nmap Static Binaries
===================

This package contains statically compiled Nmap binaries for multiple architectures:

- nmap-x86_64: Intel/AMD 64-bit (x86_64)
- nmap-arm64:  ARM 64-bit (aarch64)
- nmap-arm32:  ARM 32-bit (armhf)

All binaries are statically linked and should run on most Linux distributions
without additional dependencies.

Usage:
------
1. Choose the appropriate binary for your architecture
2. Make it executable: chmod +x nmap-<arch>
3. Run: ./nmap-<arch> [options] target

For help: ./nmap-<arch> --help

Note: These binaries may require root privileges for certain scan types.
EOF
    
    # Create tarball
    tar -czf "nmap-static-$(date +%Y%m%d).tar.gz" nmap-* README.txt
    
    success "Distribution package created: nmap-static-$(date +%Y%m%d).tar.gz"
    
    cd "$SCRIPT_DIR"
}

# Main execution
main() {
    log "Starting Nmap static cross-compilation build"
    
    # Parse command line arguments
    case "${1:-all}" in
        "deps")
            install_dependencies
            ;;
        "clean")
            clean_build
            ;;
        "x86_64")
            check_toolchains
            clean_build
            build_target "x86_64-linux-gnu"
            verify_binaries
            ;;
        "arm64")
            check_toolchains
            clean_build
            build_target "aarch64-linux-gnu"
            verify_binaries
            ;;
        "arm32")
            check_toolchains
            clean_build
            build_target "arm-linux-gnueabihf"
            verify_binaries
            ;;
        "all"|"")
            check_toolchains
            clean_build
            build_all
            verify_binaries
            create_package
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  deps     Install build dependencies"
            echo "  clean    Clean build directories"
            echo "  x86_64   Build only x86_64 binary"
            echo "  arm64    Build only ARM64 binary"
            echo "  arm32    Build only ARM32 binary"
            echo "  all      Build all binaries (default)"
            echo "  help     Show this help message"
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
    
    success "Build process completed!"
}

# Run main function
main "$@"