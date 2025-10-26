# Password Configuration Methods

This document explains the password obfuscation methods available in the encryption scripts.

## Why Password Obfuscation?

Storing passwords in plain text within scripts is a security risk:
- Scripts can be discovered during incident response
- Network traffic analysis can expose plain text passwords
- File transfers may be logged or intercepted
- Memory dumps or process listings may reveal passwords

## Password Priority Order

Both scripts try the following methods in order (highest priority first):

### Method 1: Environment Variable (Recommended for Operations)

**Highest Security** - Password is passed externally and never stored in the script.

**Batch Script:**
```batch
set ENCRYPT_KEY=YourSecurePassword123! && encrypt_files.bat
```

**PowerShell Script:**
```powershell
$env:ENCRYPT_KEY="YourSecurePassword123!"; .\encrypt_files.ps1
```

**Advantages:**
- Password not stored in script
- Can be set remotely or via payload
- No script modification needed
- Easy to change per operation

**Use Case:** Production penetration testing where password is generated per engagement

---

### Method 2: Base64 Encoded (Obfuscated Storage)

**Medium Security** - Password is encoded but not encrypted (obfuscation, not security).

**Current Encoded Password:** `YW50YWk=` (decodes to "antai")

**To Create Your Own Encoded Password:**

**On Linux/Mac:**
```bash
echo -n "YourPassword123" | base64
```

**In PowerShell:**
```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("YourPassword123"))
```

**Update the script:**
- **Batch:** Edit line 33: `set "ENCODED_PASSWORD=YourBase64String"`
- **PowerShell:** Edit line 62: `$EncodedPassword = "YourBase64String"`

**Advantages:**
- Password not visible in plain text
- Quick visual inspection won't reveal it
- Simple to implement

**Disadvantages:**
- Base64 is easily decoded
- Not cryptographically secure
- Security through obscurity

**Use Case:** Training exercises, CTF competitions, or when basic obfuscation is sufficient

---

### Method 3: Random Generated (Maximum Operational Security)

**Highest OpSec** - Generates a unique random password each time the script runs.

**Characteristics:**
- 16 characters long
- Mixed case letters (A-Z, a-z)
- Numbers (0-9)
- Special characters (!, #, $, %, &, *, +, -, =)

**Example Generated Passwords:**
- `K7*mP2+Rq9#Wd5Yn`
- `3fL$8xZv+2Jc#9Mt`

**Advantages:**
- Unique password per execution
- Maximum security - password never stored
- Immune to script analysis
- No two operations use the same password

**Disadvantages:**
- Password must be retrieved from ransom note or script output
- Cannot be predetermined
- Requires careful documentation

**Use Case:** High-security red team operations where password reuse is unacceptable

---

## Usage Examples

### Example 1: Using Environment Variable

```batch
REM Windows - Batch Script
set ENCRYPT_KEY=MySecretKey2025! && encrypt_files.bat

REM The script will show:
REM Password Method: Environment Variable
```

```powershell
# Windows - PowerShell Script
$env:ENCRYPT_KEY="MySecretKey2025!"
.\encrypt_files.ps1

# The script will show:
# Password Method: Environment Variable
```

### Example 2: Using Custom Base64 Encoded Password

**Step 1:** Generate your Base64 password
```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("RedTeam2025!"))
# Output: UmVkVGVhbTIwMjUh
```

**Step 2:** Edit the script
- Open `encrypt_files.bat` or `encrypt_files.ps1`
- Find the `ENCODED_PASSWORD` line
- Replace with your Base64 string: `UmVkVGVhbTIwMjUh`

**Step 3:** Run the script
```batch
encrypt_files.bat
REM Shows: Password Method: Base64 Decoded
```

### Example 3: Let Script Generate Random Password

Simply run the script without setting environment variable or changing the Base64 password method will fail (if you comment it out):

```batch
encrypt_files.bat
REM Shows: Password Method: Random Generated
REM Password will be shown in the ransom note: README_IMPORTANT.txt
```

---

## Security Recommendations

### For Red Team Operations:
1. **Use Environment Variable Method** - Pass password via C2 framework or payload wrapper
2. **Never commit scripts with real passwords** - Use dummy Base64 values in version control
3. **Generate unique passwords per target** - Prevents cross-contamination if discovered
4. **Secure password transmission** - Use encrypted channels when sending password to operators

### For Training/Testing:
1. **Base64 encoding is acceptable** - Provides basic obfuscation
2. **Document password retrieval method** - Ensure blue team can recover data
3. **Use random generation for realistic simulation** - Mimics real ransomware behavior

### Defense Considerations:
Even with obfuscation, defenders may:
- Monitor process memory for password usage
- Capture network traffic during script download
- Perform string analysis on Base64 patterns
- Use memory forensics to extract passwords

**This is obfuscation, not encryption** - Determined defenders can still recover passwords.

---

## Password Retrieval

After encryption, the password is saved in:
- **Console output** during execution (Step 3/5)
- **README_IMPORTANT.txt** (ransom note) in the encrypted directory
- **Final summary** at script completion

**Example Ransom Note Content:**
```
============================================================================
YOUR FILES HAVE BEEN ENCRYPTED
============================================================================

[This is a SIMULATED attack for authorized red team testing]

Archive: encrypted_files.7z
Password: K7*mP2+Rq9#Wd5Yn

============================================================================
```

---

## Technical Implementation

### Batch Script Flow:
1. Check `%ENCRYPT_KEY%` environment variable
2. If not set, decode Base64 string using PowerShell
3. If decode fails, generate random password using PowerShell
4. If all fails, use fallback with timestamp and random number

### PowerShell Script Flow:
1. Check `$env:ENCRYPT_KEY` environment variable
2. If not set, decode Base64 string using .NET methods
3. If decode fails, generate random password using Get-Random
4. If all fails, use emergency fallback

---

## Advanced: XOR Obfuscation (Future Enhancement)

For additional security, consider implementing XOR encoding:

```powershell
# Encode password with XOR key
$password = "MyPassword"
$key = "SecretKey"
$encoded = 0..($password.Length-1) | ForEach-Object {
    $password[$_] -bxor $key[$_ % $key.Length]
} | ForEach-Object { $_.ToString("X2") }
$encoded -join ""

# Result: Hex string that can be embedded in script
# Decode at runtime using reverse XOR with same key
```

---

## Important Notes

⚠️ **SECURITY WARNING:**
- These methods provide **obfuscation**, not true cryptographic security
- Skilled analysts can still recover passwords
- Use in authorized testing only
- Always have password recovery documented
- Comply with all legal and ethical guidelines

✅ **BEST PRACTICES:**
- Use environment variables for operational security
- Rotate passwords between operations
- Document password method used in engagement notes
- Ensure authorized personnel can decrypt data if needed
- Test password recovery before production use

---

## Quick Reference

| Method | Security Level | Use Case | Password Visible in Script |
|--------|----------------|----------|---------------------------|
| Environment Variable | High | Production Ops | No |
| Base64 Encoded | Medium | Training/CTF | Yes (encoded) |
| Random Generated | Highest | High-Security Ops | No |
| Fallback | Low | Emergency Only | No |

---

**Last Updated:** 2025-10-25
**For:** Cyber-Bluegrass Red Team Scripts
**Purpose:** Authorized Penetration Testing Only
