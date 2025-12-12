# Building Static Nmap Binaries

This directory contains scripts to build statically compiled Nmap binaries for multiple architectures: x86_64, ARM64, and ARM32. The binaries are fully self-contained and don't require external dependencies.

## Quick Start

### Windows Users

**Option 1: Using Batch File (Easiest)**
```cmd
build-static.bat
```

**Option 2: Using PowerShell**
```powershell
.\build-static-docker.ps1
```

### Linux/macOS Users

**Option 1: Using Docker (Recommended)**
```bash
# Make script executable
chmod +x build-static-cross.sh

# Build using Docker
docker build -f Dockerfile.build -t nmap-static-builder .
docker create --name nmap-build-container nmap-static-builder
docker cp nmap-build-container:/ static-binaries/
docker rm nmap-build-container
```

**Option 2: Native Cross-Compilation**
```bash
# Install dependencies first
./build-static-cross.sh deps

# Build all architectures
./build-static-cross.sh all
```

## Prerequisites

### Docker Method (Recommended)
- Docker Desktop installed and running
- At least 4GB free disk space
- Internet connection for downloading base images

### Native Cross-Compilation Method (Linux only)
- Ubuntu/Debian-based system
- Cross-compilation toolchains:
  ```bash
  sudo apt-get update
  sudo apt-get install gcc-multilib gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf
  sudo apt-get install libc6-dev-arm64-cross libc6-dev-armhf-cross
  ```

## Build Options

### All Scripts Support These Targets:
- `all` - Build all architectures (default)
- `x86_64` - Build only Intel/AMD 64-bit
- `arm64` - Build only ARM 64-bit
- `arm32` - Build only ARM 32-bit
- `clean` - Clean build artifacts
- `help` - Show help information

### Examples:

**PowerShell:**
```powershell
.\build-static-docker.ps1 all          # Build all architectures
.\build-static-docker.ps1 x86_64       # Build only x86_64
.\build-static-docker.ps1 clean        # Clean build artifacts
.\build-static-docker.ps1 help         # Show help
```

**Bash:**
```bash
./build-static-cross.sh all            # Build all architectures
./build-static-cross.sh arm64          # Build only ARM64
./build-static-cross.sh clean          # Clean build artifacts
```

## Output

After a successful build, you'll find:

```
static-binaries/
├── nmap-x86_64          # Intel/AMD 64-bit binary
├── nmap-arm64           # ARM 64-bit binary
├── nmap-arm32           # ARM 32-bit binary
├── README.txt           # Usage instructions
└── nmap-static-YYYYMMDD.zip  # Distribution package
```

## Binary Information

### Architecture Details:
- **nmap-x86_64**: Intel/AMD 64-bit processors (most desktop/server systems)
- **nmap-arm64**: ARM 64-bit processors (Apple M1/M2, AWS Graviton, Raspberry Pi 4+)
- **nmap-arm32**: ARM 32-bit processors (older Raspberry Pi, embedded systems)

### Features Included:
- ✅ Core Nmap scanning functionality
- ✅ NSE (Nmap Scripting Engine)
- ✅ All built-in libraries (libpcap, libpcre, etc.)
- ✅ Statically linked (no external dependencies)
- ❌ OpenSSL (disabled for static linking compatibility)
- ❌ Zenmap GUI
- ❌ Ndiff, Ncat, Nping utilities

## Usage

1. **Choose the right binary** for your target architecture
2. **Make it executable** (Linux/macOS):
   ```bash
   chmod +x nmap-x86_64
   ```
3. **Run the binary**:
   ```bash
   ./nmap-x86_64 -sn 192.168.1.0/24    # Network discovery
   ./nmap-x86_64 -sS -O target.com     # SYN scan with OS detection
   ./nmap-x86_64 --help                # Show help
   ```

## Troubleshooting

### Docker Issues:
- **"Docker is not available"**: Install Docker Desktop and ensure it's running
- **"Build failed"**: Check Docker has enough disk space (4GB+)
- **Permission denied**: On Linux, add user to docker group or use sudo

### Cross-Compilation Issues:
- **"Toolchain not found"**: Install cross-compilation packages
- **"Configure failed"**: Check that all dependencies are installed
- **"Static linking failed"**: Some distributions may need additional static libraries

### Runtime Issues:
- **"Permission denied"**: Some scan types require root privileges
- **"Binary not found"**: Ensure the binary is executable (`chmod +x`)
- **"Segmentation fault"**: Try a different architecture binary

## Build Process Details

### Docker Method:
1. Creates Ubuntu 22.04 container with cross-compilation toolchains
2. Configures Nmap with static linking options
3. Builds for each target architecture sequentially
4. Strips debug symbols to reduce binary size
5. Extracts binaries to host system

### Native Method:
1. Installs cross-compilation toolchains
2. Configures build environment for each architecture
3. Uses included libraries (libpcap, libpcre, etc.)
4. Links statically with musl or glibc
5. Strips and packages binaries

## Security Considerations

- These binaries are built from the official Nmap source code
- Static linking eliminates dependency vulnerabilities
- Binaries are stripped of debug symbols
- No network access required after build
- Suitable for air-gapped environments

## Performance Notes

- Static binaries are larger than dynamic ones (~15-20MB vs ~2-3MB)
- Startup time may be slightly slower due to static linking
- Runtime performance is equivalent to dynamic builds
- Memory usage is similar to standard Nmap builds

## Contributing

To modify the build process:

1. **Edit configuration**: Modify the configure flags in the build scripts
2. **Add architectures**: Add new targets to the TARGETS array
3. **Change options**: Modify CFLAGS/LDFLAGS for different optimizations
4. **Test builds**: Always test on target architecture before distributing

## License

These build scripts are provided under the same license as Nmap itself. The resulting binaries are subject to Nmap's license terms.

## Support

For build script issues:
- Check this README first
- Verify Docker/toolchain installation
- Review build logs for specific errors

For Nmap functionality issues:
- Consult official Nmap documentation
- Visit https://nmap.org/book/
- Use Nmap community forums