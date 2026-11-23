# FOHstick – USB format worker (runs elevated). (c) 2026 fristik.eu
param([string]$Log, [int]$Disk, [string]$Fs, [int]$Cl, [string]$Max, [string]$Name)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding $false
function Out-Log([string]$s) { [IO.File]::AppendAllText($Log, $s + "`r`n", $utf8) }
function Step([int]$n, [string]$code, [string]$arg = '') { Out-Log ("STEP $n|" + $code + "|" + $arg) }
function Fail([string]$code, [string]$detail = '') { Out-Log ("FAIL|" + $code + "|" + ($detail -replace "[`r`n|]+", ' ')); exit 1 }
try {
    $n = $Disk; $fs = $Fs; $cl = $Cl; $max = [int64]$Max; $name = $Name
    if ($fs -notin @('AUTOX','AUTO16','FAT32','FAT16','EXFAT')) { Fail 'fs' }
    if ($cl -lt 0 -or $cl -gt 128 -or $max -lt 0) { Fail 'cmd' 'bad parameters' }
    $d = Get-Disk -Number $n
    if ($d.IsBoot -or $d.IsSystem -or ($d.BusType -notin @('USB','SD','MMC'))) { Fail 'not_external' }
    Step 0 'check'
    $b = [int64]$d.Size
    $TB2 = [int64]2199023255552
    if ($fs -eq 'AUTOX') { if ($b -gt $TB2) { $fs = 'EXFAT' } else { $fs = 'FAT32' } }
    elseif ($fs -eq 'AUTO16') { if ($b -le 2200000000) { $fs = 'FAT16' } else { $fs = 'FAT32' } }
    if ($fs -eq 'FAT16' -and $b -gt 2200000000 -and ($max -eq 0 -or $max -gt 2000000000)) { $max = 2000000000 }
    $part = [int64]0
    if ($max -gt 0 -and $b -gt [int64]($max / 10 * 11)) { $part = $max }
    $eff = $b; if ($part -gt 0) { $eff = $part }
    if ($fs -eq 'FAT32' -and $eff -gt $TB2) { Fail 'fat32_2tb' }
    if ($cl -eq 64 -and $b -lt 2000000000) { Fail 'ah_min' }
    $style = 'MBR'; if ($fs -eq 'EXFAT' -and $eff -gt $TB2) { $style = 'GPT' }

    Step 1 'erase'
    if ($d.PartitionStyle -ne 'RAW') { Clear-Disk -Number $n -RemoveData -RemoveOEM -Confirm:$false }
    $d = Get-Disk -Number $n
    if ($d.PartitionStyle -eq 'RAW') { Initialize-Disk -Number $n -PartitionStyle $style }
    elseif ($d.PartitionStyle -ne $style) { Set-Disk -Number $n -PartitionStyle $style }

    Step 2 'partition'
    $np = @{ DiskNumber = $n }
    if ($part -gt 0) { $np.Size = $part } else { $np.UseMaximumSize = $true }
    if ($style -eq 'MBR') { if ($fs -eq 'FAT32') { $np.MbrType = 'FAT32' } elseif ($fs -eq 'FAT16') { $np.MbrType = 'Huge' } else { $np.MbrType = 'IFS' } }
    $p = New-Partition @np
    $ps = [int64]$p.Size

    if ($fs -eq 'EXFAT') {
        Step 3 'fmt' 'exFAT'
        Format-Volume -Partition $p -FileSystem exFAT -NewFileSystemLabel $name -Confirm:$false -Force | Out-Null
    } elseif ($fs -eq 'FAT16') {
        Step 3 'fmt' 'FAT16'
        Format-Volume -Partition $p -FileSystem FAT -NewFileSystemLabel $name -Confirm:$false -Force | Out-Null
    } else {
        $bps = [int]$d.LogicalSectorSize
        if ($cl -gt 0) { $cb = $cl * 512 }
        elseif ($ps -le 8GB) { $cb = 4096 } elseif ($ps -le 16GB) { $cb = 8192 } elseif ($ps -le 32GB) { $cb = 16384 } else { $cb = 32768 }
        Step 3 'fmt' ('FAT32 / ' + ($cb / 1024) + ' KB')
        $native = $false
        if ($ps -le 32GB) {
            try {
                Format-Volume -Partition $p -FileSystem FAT32 -AllocationUnitSize $cb -NewFileSystemLabel $name -Confirm:$false -Force | Out-Null
                $native = $true
            } catch { }
        }
        if (-not $native) {
            Format-Volume -Partition $p -FileSystem exFAT -NewFileSystemLabel $name -Confirm:$false -Force | Out-Null
            $p = Get-Partition -DiskNumber $n -PartitionNumber $p.PartitionNumber
            if ([int][char]$p.DriveLetter -eq 0) {
                Add-PartitionAccessPath -DiskNumber $n -PartitionNumber $p.PartitionNumber -AssignDriveLetter
                Start-Sleep -Seconds 2
                $p = Get-Partition -DiskNumber $n -PartitionNumber $p.PartitionNumber
            }
            if ([int][char]$p.DriveLetter -eq 0) { Fail 'no_letter' }
            $fatCs = @"
FAT32_CS
"@
            Add-Type -TypeDefinition $fatCs -Language CSharp -IgnoreWarnings
            [void][Fat32Fmt]::Format(('\\.\' + $p.DriveLetter + ':'), [int64]($p.Offset / $bps), [int64]($ps / $bps), $bps, [int]($cb / $bps), $name)
        }
    }

    Step 4 'mount'
    Start-Sleep -Seconds 2
    try {
        $p = Get-Partition -DiskNumber $n -PartitionNumber $p.PartitionNumber
        if ([int][char]$p.DriveLetter -eq 0) {
            Add-PartitionAccessPath -DiskNumber $n -PartitionNumber $p.PartitionNumber -AssignDriveLetter
            Start-Sleep -Seconds 2
        }
    } catch { }
    $v = $null
    try { $v = Get-Partition -DiskNumber $n -PartitionNumber $p.PartitionNumber | Get-Volume } catch { }
    $fsOut = $fs; $sz = ''
    if ($v) { if ($v.FileSystem) { $fsOut = $v.FileSystem }; $sz = '{0:N1} GB' -f ($v.Size / 1GB) }
    Out-Log ("DONE|" + $name + "|" + $fsOut + "|" + $sz)
    exit 0
} catch {
    $e = $_.Exception
    while ($e.InnerException) { $e = $e.InnerException }
    Fail 'cmd' $e.Message
}
