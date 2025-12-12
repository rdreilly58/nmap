# PowerShell script to build static Nmap binaries using Docker
# Works on Windows, macOS, and Linux

param(
    [Parameter(Position=0)]
    [ValidateSet("all", "x86_64", "arm64", "arm32", "clean", "help")]
    [string]$Target = "all",
    
    [switch]$NoPull,
    [switch]$Verbose
)

# Configuration
$ErrorActionPreference = "Stop"
$OutputDir = "static-binaries"
$ImageName = "nmap-static-builder"
$ContainerName = "nmap-build-container"

# Colors for output (if supported)
$Colors = @{
    Red = "`e[31m"
    Green = "`e[32m"
    Yellow = "`e[33m"
    Blue = "`e[34m"
    Reset = "`e[0m"
}

function Write-Log {
    param([string]$Message, [string]$Color = "Blue")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($Host.UI.SupportsVirtualTerminal) {
        Write-Host "$($Colors[$Color])[$timestamp]$($Colors.Reset) $Message"
    } else {
        Write-Host "[$timestamp] $Message"
    }
}

function Write-Error-Log {
    param([string]$Message)
    Write-Log $Message "Red"
}

function Write-Success {
    param([string]$Message)
    Write-Log $Message "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-Log $Message "Yellow"
}

function Test-Docker {
    Write-Log "Checking Docker availability..."
    
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed"
        }
        Write-Success "Docker is available: $dockerVersion"
        return $true
    }
    catch {
        Write-Error-Log "Docker is not available or not running"
        Write-Host "Please install Docker Desktop and ensure it's running:"
        Write-Host "  Windows: https://docs.docker.com/desktop/windows/install/"
        Write-Host "  macOS: https://docs.docker.com/desktop/mac/install/"
        Write-Host "  Linux: https://docs.docker.com/engine/install/"
        return $false
    }
}

function Build-Image {
    Write-Log "Building Docker image for Nmap static compilation..."
    
    try {
        if ($Verbose) {
            docker build -f Dockerfile.build -t $ImageName .
        } else {
            docker build -f Dockerfile.build -t $ImageName . | Out-Null
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Docker build failed"
        }
        
        Write-Success "Docker image built successfully"
    }
    catch {
        Write-Error-Log "Failed to build Docker image: $_"
        exit 1
    }
}

function Extract-Binaries {
    Write-Log "Extracting compiled binaries..."
    
    # Create output directory
    if (Test-Path $OutputDir) {
        Remove-Item $OutputDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    
    try {
        # Create a temporary container to extract files
        Write-Log "Creating temporary container..."
        docker create --name $ContainerName $ImageName | Out-Null
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create container"
        }
        
        # Copy binaries from container
        Write-Log "Copying binaries from container..."
        docker cp "${ContainerName}:/" $OutputDir
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy binaries"
        }
        
        # Remove temporary container
        docker rm $ContainerName | Out-Null
        
        Write-Success "Binaries extracted to $OutputDir"
    }
    catch {
        Write-Error-Log "Failed to extract binaries: $_"
        # Cleanup on error
        docker rm $ContainerName 2>$null | Out-Null
        exit 1
    }
}

function Verify-Binaries {
    Write-Log "Verifying extracted binaries..."
    
    $binaries = Get-ChildItem -Path $OutputDir -Name "nmap-*"
    
    if ($binaries.Count -eq 0) {
        Write-Error-Log "No binaries found in $OutputDir"
        return
    }
    
    foreach ($binary in $binaries) {
        $fullPath = Join-Path $OutputDir $binary
        $size = (Get-Item $fullPath).Length
        $sizeKB = [math]::Round($size / 1KB, 2)
        
        Write-Host "=== $binary ==="
        Write-Host "  Size: $sizeKB KB"
        Write-Host "  Path: $fullPath"
        Write-Host ""
    }
    
    Write-Success "Found $($binaries.Count) compiled binaries"
}

function Create-Package {
    Write-Log "Creating distribution package..."
    
    # Create README
    $readmeContent = @"
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

Build Information:
-----------------
Built on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss UTC")
Builder: Docker-based cross-compilation
Source: Nmap project (https://nmap.org)
"@
    
    $readmePath = Join-Path $OutputDir "README.txt"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    
    # Create archive
    $archiveName = "nmap-static-$(Get-Date -Format 'yyyyMMdd').zip"
    
    try {
        Compress-Archive -Path "$OutputDir\*" -DestinationPath $archiveName -Force
        Write-Success "Distribution package created: $archiveName"
    }
    catch {
        Write-Warning "Failed to create ZIP archive: $_"
        Write-Log "Binaries are available in the $OutputDir directory"
    }
}

function Clean-Build {
    Write-Log "Cleaning build artifacts..."
    
    # Remove output directory
    if (Test-Path $OutputDir) {
        Remove-Item $OutputDir -Recurse -Force
        Write-Log "Removed $OutputDir directory"
    }
    
    # Remove Docker image
    try {
        docker rmi $ImageName 2>$null | Out-Null
        Write-Log "Removed Docker image: $ImageName"
    }
    catch {
        # Image might not exist, ignore error
    }
    
    # Remove any leftover containers
    try {
        docker rm $ContainerName 2>$null | Out-Null
    }
    catch {
        # Container might not exist, ignore error
    }
    
    Write-Success "Cleanup completed"
}

function Show-Help {
    Write-Host @"
Nmap Static Binary Builder

Usage: .\build-static-docker.ps1 [Target] [Options]

Targets:
  all      Build all architectures (x86_64, arm64, arm32) [default]
  x86_64   Build only x86_64 binary
  arm64    Build only ARM64 binary  
  arm32    Build only ARM32 binary
  clean    Clean build artifacts and Docker images
  help     Show this help message

Options:
  -NoPull   Don't pull base Docker images (use cached)
  -Verbose  Show detailed build output

Examples:
  .\build-static-docker.ps1                    # Build all architectures
  .\build-static-docker.ps1 x86_64            # Build only x86_64
  .\build-static-docker.ps1 all -Verbose      # Build all with verbose output
  .\build-static-docker.ps1 clean             # Clean build artifacts

Requirements:
  - Docker Desktop installed and running
  - Internet connection (for downloading base images)
  - At least 4GB free disk space

Output:
  - Binaries will be placed in the 'static-binaries' directory
  - A ZIP archive will be created with all binaries and documentation
"@
}

# Main execution
function Main {
    Write-Log "Starting Nmap static binary build process"
    Write-Log "Target: $Target"
    
    switch ($Target) {
        "help" {
            Show-Help
            return
        }
        
        "clean" {
            if (-not (Test-Docker)) { return }
            Clean-Build
            return
        }
        
        default {
            if (-not (Test-Docker)) { return }
            
            Build-Image
            Extract-Binaries
            Verify-Binaries
            Create-Package
            
            Write-Success "Build process completed successfully!"
            Write-Log "Binaries are available in the '$OutputDir' directory"
        }
    }
}

# Run main function
try {
    Main
}
catch {
    Write-Error-Log "Build process failed: $_"
    exit 1
}