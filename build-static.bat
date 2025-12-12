@echo off
REM Batch file to build static Nmap binaries using Docker
REM Simple wrapper around the PowerShell script

setlocal enabledelayedexpansion

echo Nmap Static Binary Builder
echo ==========================
echo.

REM Check if Docker is available
docker --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Docker is not available or not running
    echo Please install Docker Desktop and ensure it's running
    echo https://docs.docker.com/desktop/windows/install/
    pause
    exit /b 1
)

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell is not available
    echo This script requires PowerShell 5.0 or later
    pause
    exit /b 1
)

REM Parse command line arguments
set TARGET=all
if not "%1"=="" set TARGET=%1

REM Run the PowerShell script
echo Running PowerShell build script...
echo.
powershell -ExecutionPolicy Bypass -File "build-static-docker.ps1" %TARGET%

if errorlevel 1 (
    echo.
    echo Build failed. Check the output above for errors.
    pause
    exit /b 1
)

echo.
echo Build completed successfully!
echo Binaries are available in the 'static-binaries' directory
pause