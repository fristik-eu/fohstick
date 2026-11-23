# FOHstick - build Windows package (FOHstick.exe + FOHstick.cmd)
# (c) 2026 fristik.eu - apps@fristik.eu
# Run on Windows after:  python build/gen.py [version]
# Usage:  powershell -ExecutionPolicy Bypass -File build/build_win.ps1 -Version 1.0.0
param([string]$Version = '')
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)
if (-not $Version) { $Version = (Get-Content data/version.json -Raw | ConvertFrom-Json).latest }
$Version = $Version.TrimStart('v')

$out = 'build/out/win'
$dist = 'dist'
$pkg = Join-Path $dist "FOHstick-$Version-windows"
if (Test-Path $pkg) { Remove-Item $pkg -Recurse -Force }
New-Item -ItemType Directory -Path $pkg -Force | Out-Null

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
Write-Host "> csc: $csc"
& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
    "/out:$pkg\FOHstick.exe" "/win32icon:$out\fohstick.ico" `
    "/resource:$out\FOHstick.ps1,FOHstick.ps1" `
    /reference:System.Windows.Forms.dll `
    "$out\launcher.cs"
if ($LASTEXITCODE -ne 0) { throw 'csc failed' }

Copy-Item "$out\FOHstick.cmd" "$pkg\FOHstick (alternative).cmd"
Copy-Item 'docs\INSTALL-windows.txt' "$pkg\README.txt"

# syntax check of the generated PowerShell UI
$tokens = $null; $errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "$out\FOHstick.ps1"), [ref]$tokens, [ref]$errs)
if ($errs.Count) { $errs | ForEach-Object { Write-Host $_ }; throw 'PowerShell parse errors' }
foreach ($f in @('src\win\usbchild.ps1', 'src\win\convert.ps1')) {
    [void][System.Management.Automation.Language.Parser]::ParseInput((Get-Content $f -Raw -Encoding UTF8), [ref]$tokens, [ref]$errs)
    if ($errs.Count) { $errs | ForEach-Object { Write-Host "$f : $_" }; throw 'PowerShell parse errors' }
}
$convSrc = Get-Content 'src\win\convert.ps1' -Raw -Encoding UTF8
if ($convSrc -match "(?s)\`$convChild = @'\r?\n(.*?)\r?\n'@") {
    [void][System.Management.Automation.Language.Parser]::ParseInput($matches[1], [ref]$tokens, [ref]$errs)
    if ($errs.Count) { $errs | ForEach-Object { Write-Host "convChild : $_" }; throw 'PowerShell parse errors' }
}
Write-Host '> PowerShell syntax OK'

$zip = Join-Path $dist "FOHstick-$Version-windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$pkg\*" -DestinationPath $zip
Write-Host "OK $zip"
