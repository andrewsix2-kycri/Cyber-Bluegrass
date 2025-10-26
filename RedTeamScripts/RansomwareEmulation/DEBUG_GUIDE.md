# Debug Mode Guide

## Overview

Both `encrypt_files.bat` and `encrypt_files.ps1` now include comprehensive debugging capabilities to help troubleshoot issues with downloads, 7-Zip execution, archive creation, and file operations.

---

## Enabling Debug Mode

### Batch Script (encrypt_files.bat)

**Method 1: Environment Variable**
```batch
set DEBUG=1
encrypt_files.bat
```

**Method 2: One-liner**
```batch
set DEBUG=1 && encrypt_files.bat
```

### PowerShell Script (encrypt_files.ps1)

**Method 1: Environment Variable**
```powershell
$env:DEBUG="1"
.\encrypt_files.ps1
```

**Method 2: One-liner**
```powershell
$env:DEBUG="1"; .\encrypt_files.ps1
```

---

## What Debug Mode Shows

### 1. Script Initialization
- Script start time
- PowerShell version (PS only)
- Execution policy status
- Script and working directories
- Temp directory location
- Remote server configuration

### 2. Password Configuration
- Which password method is being attempted
- Success/failure of each method
- Final password method used
- Password decode/generation results

### 3. 7-Zip Location
- Local 7z.exe search results
- System installation checks
- Download attempt details:
  - Download URL
  - Destination path
  - Download method used (PowerShell/certutil/etc.)
  - File size after download
  - Exit codes from download operations

### 4. Archive Creation
- 7-Zip executable path being used
- 7-Zip version test results
- Full command-line arguments
- Current directory file listing
- Disk space available
- Archive creation process output
- Archive size verification
- Exit codes from 7-Zip

### 5. File Operations
- Files being deleted
- Success/failure of each deletion
- Directory cleanup operations

---

## Debug Output Examples

### Successful Debug Session

```
[DEBUG] Debug mode enabled
[DEBUG] Script started at 2025-10-25 14:30:22
[DEBUG] Starting password configuration...
[DEBUG] Checking for ENCRYPT_KEY environment variable...
[DEBUG] ENCRYPT_KEY not found
[DEBUG] Attempting Base64 password decode...
[DEBUG] Password decoded from Base64
[DEBUG] Password configured using: Base64 Decoded

[DEBUG] Script directory: C:\PentestTools\
[DEBUG] Current directory: C:\TestTarget\
[DEBUG] TEMP directory: C:\Users\Admin\AppData\Local\Temp
[DEBUG] Remote server: http://10.10.10.5

[DEBUG] Looking for: C:\PentestTools\7z.exe
[DEBUG] Using local 7z.exe at: C:\PentestTools\7z.exe

[DEBUG] 7-Zip executable: C:\PentestTools\7z.exe
[DEBUG] Archive path: C:\TestTarget\encrypted_files.7z
[DEBUG] Testing 7-Zip executable...
[DEBUG] 7-Zip test exit code: 0
[DEBUG] Free space: 45.2 GB

[DEBUG] Running 7-Zip with full output...
7-Zip 25.01 (x64) : Copyright (c) 1999-2025 Igor Pavlov
...
[DEBUG] 7-Zip archive creation exit code: 0
[DEBUG] Archive file size: 15728640 bytes
```

### Failed Download Debug Session

```
[DEBUG] Download URL: http://192.168.1.100/7z.exe
[DEBUG] Download destination: C:\Users\Admin\AppData\Local\Temp\7z_temp\7z.exe
[DEBUG] Running PowerShell download command...
[ERROR] Download failed: The remote name could not be resolved: '192.168.1.100'
[DEBUG] PowerShell exit code: 1
[DEBUG] File not found after download

[DEBUG] Running certutil command...
[DEBUG] Certutil exit code: 11
[DEBUG] Certutil download failed
```

### Archive Creation Failure

```
[DEBUG] 7-Zip process completed with exit code: 2
[-] Failed to create archive (Error Level: 2)
[!] Possible causes:
[!]   - Insufficient disk space
[!]   - Permission denied
[!]   - 7-Zip executable error
[!]   - No files to archive
[DEBUG] Attempting to run 7-Zip help to verify it works...
[DEBUG] 7-Zip help exit code: 0
```

---

## Troubleshooting Common Issues

### Issue: "Failed to create archive"

**Debug Steps:**
1. Enable DEBUG mode
2. Check the debug output for:
   - 7-Zip test exit code (should be 0 or 1)
   - Free disk space
   - Directory contents listing
   - Archive creation exit code

**Common Causes:**
- **Exit code 2:** No files matched the archive pattern
  - Check if directory is empty
  - Verify exclusion patterns aren't excluding everything
- **Exit code 7:** Command line error
  - Check password has no special chars causing issues
  - Verify paths don't have problematic characters
- **Exit code 8:** Not enough memory
  - Reduce compression level (-mx=5 instead of -mx=9)
  - Check available RAM

### Issue: "Download failed"

**Debug Steps:**
1. Enable DEBUG mode
2. Check debug output for:
   - Exact URL being accessed
   - Download method attempted
   - Error messages from PowerShell/certutil
   - Network connectivity

**Common Causes:**
- **DNS resolution failure:** Remote server hostname not resolvable
  - Use IP address instead
  - Check DNS settings
- **Connection timeout:** Firewall blocking
  - Check firewall rules
  - Verify web server is running
- **TLS/SSL errors:** Certificate issues
  - Update to use HTTP instead of HTTPS for testing
  - Add TLS 1.2 support

### Issue: "Password decode failed"

**Debug Steps:**
1. Enable DEBUG mode
2. Check which password method succeeded
3. Verify Base64 string is valid

**Common Causes:**
- **Invalid Base64:** Corrupted encoding string
  - Re-encode the password: `echo -n "pass" | base64`
  - Update the script with correct string
- **PowerShell not available:** Base64 decode requires PowerShell
  - Will fallback to random generation

---

## Advanced Debugging

### Capture Full Debug Log

**Batch Script:**
```batch
set DEBUG=1
encrypt_files.bat > debug_log.txt 2>&1
```

**PowerShell Script:**
```powershell
$env:DEBUG="1"
.\encrypt_files.ps1 | Tee-Object -FilePath debug_log.txt
```

### Test Only 7-Zip Without Running Script

**From Debug Output:**
```batch
REM Get the exact command from debug output
"C:\path\to\7z.exe" a -t7z -m0=lzma2 -mx=9 -mfb=64 -md=32m -ms=on -mhe=on -pYourPass "archive.7z" "*" -r
```

### Check 7-Zip Version

```batch
7z.exe
```
Should show version and copyright info with exit code 0.

### Verify Downloads Manually

```powershell
# Test if server is reachable
Test-NetConnection -ComputerName yourserver.com -Port 80

# Test download manually
Invoke-WebRequest -Uri "http://yourserver.com/7z.exe" -OutFile "test.exe"
```

---

## Debug Output Reference

### Exit Codes

**7-Zip Exit Codes:**
- `0` - Success
- `1` - Warning (non-fatal)
- `2` - Fatal error
- `7` - Command line error
- `8` - Not enough memory
- `255` - User stopped the process

**Download Exit Codes:**
- `0` - Success
- `1` - General failure
- `11` - Certutil: Cannot retrieve data

### File Size Indicators

- **0 bytes:** Archive created but empty (no files matched)
- **< 100 bytes:** Likely error, archive header only
- **Expected size:** Check against source files

---

## Performance Impact

Debug mode will:
- ✅ Show detailed output for troubleshooting
- ✅ Display 7-Zip full output (normally hidden)
- ⚠️ Make the script run slightly slower
- ⚠️ Produce verbose console output
- ⚠️ May display sensitive paths/info

**Recommendation:** Only use debug mode when troubleshooting. Disable for production operations.

---

## Production vs Debug Comparison

| Feature | Normal Mode | Debug Mode |
|---------|-------------|------------|
| 7-Zip Output | Hidden | Full output shown |
| Password Display | Method only | Method + details |
| Download Errors | Generic message | Detailed error + exit codes |
| File Operations | Summary only | Every file listed |
| Disk Space | Not shown | Free space displayed |
| Exit Codes | Error level only | Detailed explanation |
| Performance | Fast | Slightly slower |

---

## Example Troubleshooting Workflow

**Scenario:** Script fails to create archive

**Step 1:** Enable debug mode
```batch
set DEBUG=1 && encrypt_files.bat
```

**Step 2:** Review debug output
```
[DEBUG] 7-Zip test exit code: 0      ← 7-Zip works
[DEBUG] Free space: 2.3 GB            ← Plenty of space
[DEBUG] Current directory contents:
[DEBUG]   - document.txt (1024 bytes)
[DEBUG]   - photo.jpg (2048000 bytes)
[DEBUG] 7-Zip archive creation exit code: 2  ← Fatal error
```

**Step 3:** Look for exit code 2 meaning
- Check if files exist to archive
- Review exclusion patterns
- Verify files aren't locked

**Step 4:** Test manually
```batch
"C:\path\to\7z.exe" a test.7z document.txt
```

**Step 5:** Fix issue
- Adjust exclusion patterns
- Close programs locking files
- Check file permissions

---

## Support Information

If you encounter issues even with debug mode:

1. **Capture full debug log:**
   ```batch
   set DEBUG=1
   encrypt_files.bat > full_debug.txt 2>&1
   ```

2. **Include in report:**
   - Operating system version
   - PowerShell version (if applicable)
   - Full debug log
   - Description of what fails
   - Network environment (if download fails)

3. **Check basics:**
   - Is PowerShell available? `powershell -Command "Write-Host 'Test'"`
   - Is 7-Zip working? Place 7z.exe in script directory
   - Is there disk space? `dir /-c`
   - Are files present? `dir /b`

---

**Last Updated:** 2025-10-25
**For:** Cyber-Bluegrass Red Team Scripts
**Purpose:** Troubleshooting Guide for Authorized Penetration Testing
