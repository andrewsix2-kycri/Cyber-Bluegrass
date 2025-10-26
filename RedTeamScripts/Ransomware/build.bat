@echo off
REM ============================================================================
REM Build Script for Rust Ransomware Simulation (Windows)
REM ============================================================================

echo ============================================================================
echo Building Rust Ransomware Simulation Tool
echo ============================================================================
echo.

REM Check if Rust is installed
where cargo >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [-] Cargo not found. Please install Rust:
    echo     https://rustup.rs/
    pause
    exit /b 1
)

for /f "delims=" %%i in ('cargo --version') do set CARGO_VERSION=%%i
echo [+] Cargo found: %CARGO_VERSION%

REM Build
echo.
echo [*] Building release binary...
echo.

cargo build --release

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================================
    echo [+] Build successful!
    echo ============================================================================
    echo.
    echo Binary location: target\release\encrypt_files.exe

    if exist "target\release\encrypt_files.exe" (
        for %%A in ("target\release\encrypt_files.exe") do (
            set SIZE=%%~zA
            set /a SIZE_KB=!SIZE! / 1024
            set /a SIZE_MB=!SIZE_KB! / 1024
            echo Binary size: !SIZE_MB! MB ^(!SIZE_KB! KB^)
        )
    )

    echo.
    echo To compress with UPX ^(optional^):
    echo   upx --best --lzma target\release\encrypt_files.exe
    echo.
    echo To deploy:
    echo   1. Copy target\release\encrypt_files.exe to target system
    echo   2. Optionally bundle with 7z.exe or 7z2501-x64.msi
    echo   3. Run in authorized test environment only
    echo.
) else (
    echo.
    echo [-] Build failed!
    pause
    exit /b 1
)

pause
