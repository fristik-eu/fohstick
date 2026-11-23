# FOHstick – audio > WAV converter parts (Media Foundation). (c) 2026 fristik.eu
$convChild = @'
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$tmpWav = $null
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    function Get-WinRT([string]$t, [string[]]$asms) {
        foreach ($a in $asms) {
            try { $x = Invoke-Expression "[$t,$a,ContentType=WindowsRuntime]"; if ($x) { return $x } } catch {}
        }
        throw "Cannot load $t"
    }
    $null = Get-WinRT 'Windows.Storage.StorageFile' @('Windows.Storage','Windows.Foundation')
    $null = Get-WinRT 'Windows.Storage.StorageFolder' @('Windows.Storage','Windows.Foundation')
    $null = Get-WinRT 'Windows.Media.MediaProperties.MediaEncodingProfile' @('Windows.Media.MediaProperties','Windows.Media','Windows.Foundation')
    $null = Get-WinRT 'Windows.Media.Transcoding.MediaTranscoder' @('Windows.Media.Transcoding','Windows.Media','Windows.Foundation')

    $methods = [System.WindowsRuntimeSystemExtensions].GetMethods()
    $asTaskOp = $methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' } | Select-Object -First 1
    $asTaskAP = $methods | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncActionWithProgress`1' } | Select-Object -First 1
    function Await-Op($op, [type]$rt) { $t = $asTaskOp.MakeGenericMethod($rt).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
    function Await-AP($op, [type]$pt) { $t = $asTaskAP.MakeGenericMethod($pt).Invoke($null, @($op)); $t.Wait(-1) | Out-Null }

    $inPath  = $env:K48_IN
    if ($inPath -match '\.(aif|aiff|aifc)$') {

$aiffCs = @"
using System;
using System.IO;
public static class AiffConv {
    static string Str(BinaryReader r, int n) { return System.Text.Encoding.ASCII.GetString(r.ReadBytes(n)); }
    static uint U32(BinaryReader r) { byte[] b = r.ReadBytes(4); return (uint)((b[0] << 24) | (b[1] << 16) | (b[2] << 8) | b[3]); }
    static int U16(BinaryReader r) { byte[] b = r.ReadBytes(2); return (b[0] << 8) | b[1]; }
    static double Ext(BinaryReader r) {
        byte[] b = r.ReadBytes(10);
        int exp = ((b[0] & 0x7F) << 8) | b[1];
        ulong mant = 0;
        for (int i = 2; i < 10; i++) mant = (mant << 8) | b[i];
        if (exp == 0 && mant == 0) return 0;
        double v = mant * Math.Pow(2, exp - 16383 - 63);
        return ((b[0] & 0x80) != 0) ? -v : v;
    }
    static void W32(BinaryWriter w, uint v) { w.Write(v); }
    public static void ToWav(string inPath, string outPath) {
        using (FileStream fs = File.OpenRead(inPath))
        using (BinaryReader br = new BinaryReader(fs)) {
            if (Str(br, 4) != "FORM") throw new Exception("Not an AIFF file.");
            U32(br);
            string form = Str(br, 4);
            bool aifc = form == "AIFC";
            if (form != "AIFF" && !aifc) throw new Exception("Not an AIFF file.");
            int ch = 0, bits = 0; uint frames = 0; double rate = 0; string comp = "NONE";
            long dataPos = -1, dataLen = 0;
            while (fs.Position + 8 <= fs.Length) {
                string cid = Str(br, 4);
                long clen = U32(br);
                long start = fs.Position;
                if (cid == "COMM") {
                    ch = U16(br); frames = U32(br); bits = U16(br); rate = Ext(br);
                    if (aifc && clen >= 22) comp = Str(br, 4);
                } else if (cid == "SSND") {
                    uint offset = U32(br); U32(br);
                    dataPos = fs.Position + offset;
                    dataLen = Math.Min(clen - 8 - offset, fs.Length - dataPos);
                }
                fs.Position = start + clen + (clen & 1);
            }
            if (ch <= 0 || dataPos < 0) throw new Exception("Damaged AIFF file (missing COMM or SSND).");
            bool little = comp == "sowt";
            bool isFloat = comp == "fl32" || comp == "FL32";
            if (!(comp == "NONE" || little || isFloat)) throw new Exception("Unsupported AIFF-C compression: " + comp);
            if (isFloat) bits = 32;
            int bps = (bits + 7) / 8;
            int frameBytes = ch * bps;
            long n = (long)frames * frameBytes;
            if (n > dataLen || n == 0) n = dataLen - (dataLen % frameBytes);
            int sr = (int)Math.Round(rate);
            bool pad = (n & 1) == 1;
            using (FileStream os = File.Create(outPath))
            using (BinaryWriter w = new BinaryWriter(os)) {
                w.Write(System.Text.Encoding.ASCII.GetBytes("RIFF")); W32(w, (uint)(36 + n + (pad ? 1 : 0)));
                w.Write(System.Text.Encoding.ASCII.GetBytes("WAVEfmt ")); W32(w, 16);
                w.Write((ushort)(isFloat ? 3 : 1)); w.Write((ushort)ch); W32(w, (uint)sr);
                W32(w, (uint)(sr * frameBytes)); w.Write((ushort)frameBytes); w.Write((ushort)(bps * 8));
                w.Write(System.Text.Encoding.ASCII.GetBytes("data")); W32(w, (uint)n);
                fs.Position = dataPos;
                byte[] buf = new byte[frameBytes * 16384];
                long left = n;
                while (left > 0) {
                    int want = (int)Math.Min(buf.Length, left);
                    int got = fs.Read(buf, 0, want);
                    if (got <= 0) break;
                    got -= got % bps;
                    if (bps == 1) {
                        for (int i = 0; i < got; i++) buf[i] = (byte)(buf[i] ^ 0x80);
                    } else if (!little) {
                        for (int i = 0; i < got; i += bps) Array.Reverse(buf, i, bps);
                    }
                    w.Write(buf, 0, got);
                    left -= got;
                }
                if (pad) w.Write((byte)0);
            }
        }
    }
}
"@
        Add-Type -TypeDefinition $aiffCs -Language CSharp -IgnoreWarnings
        $tmpWav = Join-Path $env:TEMP ([guid]::NewGuid().ToString() + '.wav')
        [AiffConv]::ToWav($inPath, $tmpWav)
        $inPath = $tmpWav
    }
    $outPath = $env:K48_OUT
    $ch   = [uint32]$env:K48_CH
    $bits = [uint32]$env:K48_BITS

    $src = Await-Op ([Windows.Storage.StorageFile]::GetFileFromPathAsync($inPath)) ([Windows.Storage.StorageFile])
    $folder = Await-Op ([Windows.Storage.StorageFolder]::GetFolderFromPathAsync([IO.Path]::GetDirectoryName($outPath))) ([Windows.Storage.StorageFolder])
    $dst = Await-Op ($folder.CreateFileAsync([IO.Path]::GetFileName($outPath), [Windows.Storage.CreationCollisionOption]::FailIfExists)) ([Windows.Storage.StorageFile])

    $prof = [Windows.Media.MediaProperties.MediaEncodingProfile]::CreateWav([Windows.Media.MediaProperties.AudioEncodingQuality]::High)
    $rate = [uint32]$env:K48_RATE
    $prof.Audio.SampleRate    = $rate
    $prof.Audio.ChannelCount  = $ch
    $prof.Audio.BitsPerSample = $bits
    $prof.Audio.Bitrate       = [uint32]($rate * $ch * $bits)

    $tc = New-Object Windows.Media.Transcoding.MediaTranscoder
    $prep = Await-Op ($tc.PrepareFileTranscodeAsync($src, $dst, $prof)) ([Windows.Media.Transcoding.PrepareTranscodeResult])
    if (-not $prep.CanTranscode) { [Console]::Error.WriteLine("Cannot convert: " + $prep.FailureReason); exit 2 }
    Await-AP ($prep.TranscodeAsync()) ([double])
    if ($tmpWav) { Remove-Item -LiteralPath $tmpWav -Force -ErrorAction SilentlyContinue }
    exit 0
} catch {
    if ($tmpWav) { Remove-Item -LiteralPath $tmpWav -Force -ErrorAction SilentlyContinue }
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    [Console]::Error.WriteLine($e.Message)
    exit 1
}
'@
$convEnc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($convChild))

function Get-OutPath([string]$in, [int]$rate) {
    $suf = switch ($rate) { 44100 { '_44k1' } 96000 { '_96k' } default { '_48k' } }
    $dir  = [IO.Path]::GetDirectoryName($in)
    $name = [IO.Path]::GetFileNameWithoutExtension($in)
    $out  = Join-Path $dir ($name + $suf + '.wav')
    $n = 2
    while (Test-Path -LiteralPath $out) { $out = Join-Path $dir ($name + $suf + '_' + $n + '.wav'); $n++ }
    return $out
}

function Convert-One([string]$in, [int]$ch, [int]$bits, [int]$rate) {
    $out = Get-OutPath $in $rate
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'powershell.exe'
    $psi.Arguments = "-NoProfile -MTA -ExecutionPolicy Bypass -EncodedCommand $convEnc"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardError = $true
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.EnvironmentVariables['K48_IN']   = $in
    $psi.EnvironmentVariables['K48_OUT']  = $out
    $psi.EnvironmentVariables['K48_CH']   = "$ch"
    $psi.EnvironmentVariables['K48_BITS'] = "$bits"
    $psi.EnvironmentVariables['K48_RATE'] = "$rate"
    $p = [System.Diagnostics.Process]::Start($psi)
    $errTask = $p.StandardError.ReadToEndAsync()
    while (-not $p.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 40 }
    $p.WaitForExit()
    $err = $errTask.Result
    if ($p.ExitCode -eq 0 -and (Test-Path -LiteralPath $out) -and (Get-Item -LiteralPath $out).Length -gt 44) {
        return @{ ok = $true; out = $out }
    }
    if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
    return @{ ok = $false; err = ($err.Trim()) }
}

