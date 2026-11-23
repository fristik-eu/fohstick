# ---------------------------------------------------------------
#  FOHstick – fristik.eu  (Windows 10/11)
#  audio > WAV converter + USB formatting for mixing consoles
#  (c) 2026 fristik.eu · apps@fristik.eu · https://fristik.eu
# ---------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$APP_VERSION  = '@@VERSION@@'
$URL_CONSOLES = 'https://raw.githubusercontent.com/fristik-eu/fohstick/main/data/consoles.json'
$URL_VERSION  = 'https://raw.githubusercontent.com/fristik-eu/fohstick/main/data/version.json'
$URL_RELEASES = 'https://github.com/fristik-eu/fohstick/releases/latest'

# ================= Texty (SK / EN) =================
$L = @@L10N@@

# ================= Vstavaný zoznam pultov =================
$builtinConsoles = @'
@@CONSOLES@@
'@

# ================= Konvertor (bez práv správcu) =================
@@CONVERT@@

# ================= USB worker (spúšťa sa ako správca) =================
$usbChild = @'
@@USBCHILD@@
'@

$iconBytes = [Convert]::FromBase64String('@@ICON@@')
$logoBytes = [Convert]::FromBase64String('@@LOGO@@')

$appDir = Join-Path $env:LOCALAPPDATA 'fristik.eu'
try { if (-not (Test-Path $appDir)) { New-Item -ItemType Directory -Path $appDir | Out-Null } } catch {}
$prefsPath = Join-Path $appDir 'fohstick.json'

# ================= Nastavenia =================
$script:lang = 'en'
try { if ((Get-Culture).TwoLetterISOLanguageName -in @('sk', 'cs')) { $script:lang = 'sk' } } catch {}
$script:themeMode = 'auto'
try {
    if (Test-Path -LiteralPath $prefsPath) {
        $pr = Get-Content -LiteralPath $prefsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pr.lang -in @('sk', 'en')) { $script:lang = $pr.lang }
        if ($pr.theme -in @('auto', 'light', 'dark')) { $script:themeMode = $pr.theme }
    }
} catch {}
function Save-Prefs {
    try { (@{ lang = $script:lang; theme = $script:themeMode } | ConvertTo-Json) | Set-Content -LiteralPath $prefsPath -Encoding UTF8 } catch {}
}

function T([string]$k) {
    if ($L.ContainsKey($k)) { if ($script:lang -eq 'en') { return $L[$k][1] } else { return $L[$k][0] } }
    return $k
}
function TF([string]$k, $a1, $a2) { return ((T $k) -replace '%1', [string]$a1) -replace '%2', [string]$a2 }

# ================= Pulty =================
function Parse-Consoles([string]$json) {
    $out = @()
    try {
        $o = $json | ConvertFrom-Json
        foreach ($c in $o.consoles) {
            if ($c.fs -notin @('AUTOX', 'AUTO16', 'FAT32', 'FAT16', 'EXFAT')) { continue }
            $cl = [int]$c.cluster; $mx = [int64]$c.max
            if ($cl -lt 0 -or $cl -gt 128 -or $mx -lt 0) { continue }
            $out += ,@([string]$c.name, [string]$c.fs, [string]$cl, [string]$mx, [string]$c.label, [string]$c.desc_sk, [string]$c.desc_en, [string]$c.tip_sk, [string]$c.tip_en)
        }
    } catch { return @() }
    return ,$out
}
$script:presets = Parse-Consoles $builtinConsoles
$cachePath = Join-Path $appDir 'consoles.json'
try {
    if (Test-Path -LiteralPath $cachePath) {
        $cached = Parse-Consoles (Get-Content -LiteralPath $cachePath -Raw -Encoding UTF8)
        if ($cached.Count -gt 0) { $script:presets = $cached }
    }
} catch {}

# ================= Téma =================
Add-Type -Namespace FOH -Name Dwm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
'@ -ErrorAction SilentlyContinue

function C($r, $g, $b) { [System.Drawing.Color]::FromArgb($r, $g, $b) }
$palettes = @{
    light = @{ bg = (C 246 246 248); card = (C 255 255 255); text = (C 24 24 28); sub = (C 104 104 114); border = (C 222 222 228)
               input = (C 255 255 255); btn = (C 240 240 244); btnHover = (C 226 226 232); hdr = (C 24 25 29); hdrText = (C 255 255 255); hdrSub = (C 170 172 180)
               navOff = (C 44 45 51); accent = (C 0 120 212); accentHover = (C 0 100 180); danger = (C 214 48 48); dangerHover = (C 180 36 36); link = (C 0 102 204) }
    dark  = @{ bg = (C 28 29 33); card = (C 38 39 44); text = (C 236 236 240); sub = (C 158 160 170); border = (C 58 60 68)
               input = (C 48 49 56); btn = (C 54 56 63); btnHover = (C 68 70 78); hdr = (C 16 17 20); hdrText = (C 255 255 255); hdrSub = (C 150 152 160)
               navOff = (C 36 37 43); accent = (C 30 136 229); accentHover = (C 20 110 200); danger = (C 214 48 48); dangerHover = (C 180 36 36); link = (C 110 170 255) }
}
function Is-SystemDark {
    try { return ((Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name AppsUseLightTheme -ErrorAction Stop).AppsUseLightTheme -eq 0) } catch { return $false }
}
function Get-Pal { if ($script:themeMode -eq 'dark' -or ($script:themeMode -eq 'auto' -and (Is-SystemDark))) { return $palettes.dark } else { return $palettes.light } }

# ================= Okno =================
$font = New-Object System.Drawing.Font('Segoe UI', 9)
$fontB = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'FOHstick – fristik.eu'
$form.ClientSize = New-Object System.Drawing.Size(600, 720)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = $font
try { $form.Icon = New-Object System.Drawing.Icon((New-Object System.IO.MemoryStream(,$iconBytes))) } catch {}

$script:i18n = New-Object System.Collections.ArrayList
function Reg($c, $k, [string]$kind = 'text') { [void]$script:i18n.Add(@($c, $k, $kind)) }

function New-Lbl($parent, [string]$k, [int]$x, [int]$y, [int]$w, [int]$h, [string]$role = 'text', [float]$size = 9, [switch]$Bold) {
    $l = New-Object System.Windows.Forms.Label
    if ($k.StartsWith('=')) { $l.Text = $k.Substring(1) } elseif ($k) { $l.Text = T $k; Reg $l $k }
    $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, $h)
    if ($Bold) { $l.Font = New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]::Bold) } else { $l.Font = New-Object System.Drawing.Font('Segoe UI', $size) }
    $l.Tag = $role; $l.BackColor = [System.Drawing.Color]::Transparent
    $parent.Controls.Add($l); return $l
}
function New-Btn($parent, [string]$k, [int]$x, [int]$y, [int]$w, [int]$h, [string]$role = 'secondary', [string]$glyph = '') {
    $b = New-Object System.Windows.Forms.Button
    $b.Location = New-Object System.Drawing.Point($x, $y); $b.Size = New-Object System.Drawing.Size($w, $h)
    $b.FlatStyle = 'Flat'; $b.Cursor = [System.Windows.Forms.Cursors]::Hand; $b.Tag = $role
    if ($role -eq 'secondary') { $b.Font = $font } else { $b.Font = New-Object System.Drawing.Font('Segoe UI', 10, [System.Drawing.FontStyle]::Bold) }
    if ($k) { $b.Text = $glyph + (T $k); Reg $b @($k, $glyph) 'btn' }
    $parent.Controls.Add($b); return $b
}
function New-Combo($parent, $items, [int]$x, [int]$y, [int]$w, [bool]$translate = $false) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'; $c.FlatStyle = 'Flat'
    $c.Location = New-Object System.Drawing.Point($x, $y); $c.Width = $w; $c.Font = $font; $c.Tag = 'input'
    foreach ($i in $items) { if ($translate) { [void]$c.Items.Add((T $i)) } else { [void]$c.Items.Add($i) } }
    if ($c.Items.Count -gt 0) { $c.SelectedIndex = 0 }
    if ($translate) { Reg $c $items 'items' }
    $parent.Controls.Add($c); return $c
}
function New-Card($parent, [string]$k, [int]$x, [int]$y, [int]$w, [int]$h) {
    $p = New-Object System.Windows.Forms.Panel
    $p.Location = New-Object System.Drawing.Point($x, $y); $p.Size = New-Object System.Drawing.Size($w, $h); $p.Tag = 'card'
    $p.Add_Paint({ param($s, $e)
        $pen = New-Object System.Drawing.Pen((Get-Pal).border)
        $e.Graphics.DrawRectangle($pen, 0, 0, $s.Width - 1, $s.Height - 1); $pen.Dispose() })
    $parent.Controls.Add($p)
    if ($k) { [void](New-Lbl $p $k 14 10 ($w - 28) 20 'sub' 9 -Bold) }
    return $p
}
function New-Radios($parent, $keys, [int]$x, [int]$y, [int]$step, [int]$sel) {
    $host_ = New-Object System.Windows.Forms.Panel
    $host_.Location = New-Object System.Drawing.Point($x, $y); $host_.Size = New-Object System.Drawing.Size(($keys.Count * $step), 26); $host_.Tag = 'clear'
    $rs = @()
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $r = New-Object System.Windows.Forms.RadioButton
        $k = $keys[$i]
        if ($k.StartsWith('=')) { $r.Text = $k.Substring(1) } else { $r.Text = T $k; Reg $r $k }
        $r.Location = New-Object System.Drawing.Point(($i * $step), 2); $r.Size = New-Object System.Drawing.Size(($step - 6), 22)
        $r.Font = $font; $r.Tag = 'text'
        if ($i -eq $sel) { $r.Checked = $true }
        $host_.Controls.Add($r); $rs += $r
    }
    $parent.Controls.Add($host_)
    return ,$rs
}

# ---------- Hlavička ----------
$header = New-Object System.Windows.Forms.Panel
$header.Location = '0,0'; $header.Size = '600,112'; $header.Tag = 'hdr'
$form.Controls.Add($header)
$hdrIcon = New-Object System.Windows.Forms.PictureBox
try { $hdrIcon.Image = (New-Object System.Drawing.Icon((New-Object System.IO.MemoryStream(,$iconBytes)), 48, 48)).ToBitmap() } catch {}
$hdrIcon.SizeMode = 'Zoom'; $hdrIcon.Location = '16,12'; $hdrIcon.Size = '48,48'; $hdrIcon.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($hdrIcon)
$hdrTitle = New-Lbl $header '=FOHstick' 72 10 260 32 'hdrText' 17 -Bold
$hdrSub = New-Lbl $header 'subtitle' 74 42 330 18 'hdrSub' 9
$langCombo = New-Combo $header @('SK', 'EN') 420 16 64
if ($script:lang -eq 'en') { $langCombo.SelectedIndex = 1 }
$themeCombo = New-Combo $header @('theme_auto', 'theme_light', 'theme_dark') 490 16 94 $true
$themeCombo.SelectedIndex = @('auto', 'light', 'dark').IndexOf($script:themeMode)
$updateLink = New-Object System.Windows.Forms.LinkLabel
$updateLink.Location = '300,48'; $updateLink.Size = '284,18'; $updateLink.TextAlign = 'MiddleRight'; $updateLink.Visible = $false
$updateLink.Font = $fontB; $updateLink.Tag = 'update'; $updateLink.BackColor = [System.Drawing.Color]::Transparent
$header.Controls.Add($updateLink)
$navConv = New-Btn $header 'tab_conv' 16 72 150 32 'nav'
$navFmt = New-Btn $header 'tab_fmt' 172 72 150 32 'nav'

# ---------- Stránky ----------
$pageConv = New-Object System.Windows.Forms.Panel
$pageConv.Location = '0,112'; $pageConv.Size = '600,570'; $pageConv.Tag = 'page'; $pageConv.AllowDrop = $true
$pageFmt = New-Object System.Windows.Forms.Panel
$pageFmt.Location = '0,112'; $pageFmt.Size = '600,570'; $pageFmt.Tag = 'page'; $pageFmt.Visible = $false
$form.Controls.AddRange(@($pageConv, $pageFmt))

# ===== Convert =====
$cFiles = New-Card $pageConv 'card_files' 16 14 568 252
[void](New-Lbl $cFiles 'files_hint_win' 14 32 540 18 'sub')
$list = New-Object System.Windows.Forms.ListBox
$list.Location = '14,56'; $list.Size = '540,140'; $list.Tag = 'input'; $list.BorderStyle = 'FixedSingle'
$list.HorizontalScrollbar = $true; $list.SelectionMode = 'MultiExtended'; $list.AllowDrop = $true; $list.Font = $font
$cFiles.Controls.Add($list)
$btnAdd = New-Btn $cFiles 'btn_add' 14 206 172 34 'secondary' '+  '
$btnRem = New-Btn $cFiles 'btn_remove' 198 206 172 34 'secondary' '−  '
$btnClr = New-Btn $cFiles 'btn_clear' 382 206 172 34 'secondary' '✕  '

$cOut = New-Card $pageConv 'card_output' 16 278 568 172
[void](New-Lbl $cOut 'channels' 14 42 120 20 'text' 9 -Bold)
$rCh = New-Radios $cOut @('mono', 'stereo') 140 38 110 1
[void](New-Lbl $cOut 'bitdepth' 14 74 120 20 'text' 9 -Bold)
$rBits = New-Radios $cOut @('=16-bit', '=24-bit') 140 70 110 1
[void](New-Lbl $cOut 'rate' 14 106 120 20 'text' 9 -Bold)
$rRate = New-Radios $cOut @('=44,1 kHz', '=48 kHz', '=96 kHz') 140 102 110 1
[void](New-Lbl $cOut 'out_hint' 14 138 540 20 'sub' 8.5)

$convBar = New-Object System.Windows.Forms.ProgressBar
$convBar.Location = '16,466'; $convBar.Size = '568,12'
$pageConv.Controls.Add($convBar)
$convStatus = New-Lbl $pageConv '' 16 492 380 44 'sub'
$btnConv = New-Btn $pageConv 'btn_convert' 404 488 180 46 'primary' '▶  '

# ===== Format =====
$cUsb = New-Card $pageFmt 'card_usb' 16 14 568 104
[void](New-Lbl $cUsb 'usb_intro' 14 32 540 18 'sub')
$diskCombo = New-Combo $cUsb @() 14 62 410
$btnRefresh = New-Btn $cUsb 'btn_refresh' 432 59 122 30 'secondary' '↻  '

$cSet = New-Card $pageFmt 'card_settings' 16 130 568 270
[void](New-Lbl $cSet 'mode' 14 42 120 20 'text' 9 -Bold)
$rMode = New-Radios $cSet @('mode_preset', 'mode_custom') 140 38 160 0
$rPreset = $rMode[0]; $rCustom = $rMode[1]
$lblPreset = New-Lbl $cSet 'console' 14 80 120 20 'text' 9 -Bold
$presetCombo = New-Combo $cSet @() 140 76 414
$lblFs = New-Lbl $cSet 'filesystem' 14 80 120 20 'text' 9 -Bold
$fsCombo = New-Combo $cSet @('FAT32', 'exFAT', 'FAT16') 140 76 120
$lblCl = New-Lbl $cSet 'cluster' 276 80 70 20 'text' 9 -Bold
$clCombo = New-Combo $cSet @('cl_default', 'cl_32') 350 76 204 $true
$lblSz = New-Lbl $cSet 'size' 14 116 120 20 'text' 9 -Bold
$szCombo = New-Combo $cSet @('sz_whole', 'sz_32', 'sz_16', 'sz_2') 140 112 230 $true
$desc = New-Lbl $cSet '' 140 148 414 54 'sub'
[void](New-Lbl $cSet 'disk_name' 14 218 120 20 'text' 9 -Bold)
$nameBox = New-Object System.Windows.Forms.TextBox
$nameBox.Location = '140,214'; $nameBox.Width = 200; $nameBox.MaxLength = 11; $nameBox.CharacterCasing = 'Upper'
$nameBox.Font = $font; $nameBox.Tag = 'input'; $nameBox.BorderStyle = 'FixedSingle'
$cSet.Controls.Add($nameBox)
[void](New-Lbl $cSet 'name_hint' 350 218 204 20 'sub')

$usbBar = New-Object System.Windows.Forms.ProgressBar
$usbBar.Location = '16,422'; $usbBar.Size = '350,18'; $usbBar.Minimum = 0; $usbBar.Maximum = 4; $usbBar.Visible = $false
$pageFmt.Controls.Add($usbBar)
$btnGo = New-Btn $pageFmt 'btn_format' 384 410 200 46 'danger' '⚠  '
$usbStatus = New-Lbl $pageFmt '' 16 466 568 44 'sub'
[void](New-Lbl $pageFmt 'warn_win' 16 516 568 40 'sub' 8.5)

# ---------- Pätička ----------
$footer = New-Object System.Windows.Forms.Panel
$footer.Location = '0,682'; $footer.Size = '600,38'; $footer.Tag = 'page'
$form.Controls.Add($footer)
$logoBox = New-Object System.Windows.Forms.PictureBox
try { $logoBox.Image = [System.Drawing.Image]::FromStream((New-Object System.IO.MemoryStream(,$logoBytes))) } catch {}
$logoBox.SizeMode = 'Zoom'; $logoBox.Location = '16,9'; $logoBox.Size = '26,20'; $logoBox.BackColor = [System.Drawing.Color]::Transparent
$footer.Controls.Add($logoBox)
[void](New-Lbl $footer '=© 2026 fristik.eu' 46 12 110 18 'sub')
$lnkWeb = New-Object System.Windows.Forms.LinkLabel
$lnkWeb.Text = 'fristik.eu'; $lnkWeb.Location = '158,12'; $lnkWeb.Size = '70,18'; $lnkWeb.Tag = 'link'; $lnkWeb.BackColor = [System.Drawing.Color]::Transparent
$lnkWeb.Add_LinkClicked({ Start-Process 'https://fristik.eu' })
$lnkMail = New-Object System.Windows.Forms.LinkLabel
$lnkMail.Text = 'apps@fristik.eu'; $lnkMail.Location = '230,12'; $lnkMail.Size = '120,18'; $lnkMail.Tag = 'link'; $lnkMail.BackColor = [System.Drawing.Color]::Transparent
$lnkMail.Add_LinkClicked({ Start-Process 'mailto:apps@fristik.eu' })
$footer.Controls.AddRange(@($lnkWeb, $lnkMail))
$verLbl = New-Lbl $footer ('=v' + $APP_VERSION) 480 12 104 18 'sub'
$verLbl.TextAlign = 'TopRight'

# ================= Téma – aplikovanie =================
function Paint-Tree($ctrl, $pal) {
    foreach ($c in $ctrl.Controls) {
        $role = [string]$c.Tag
        switch ($role) {
            'hdr'      { $c.BackColor = $pal.hdr }
            'page'     { $c.BackColor = $pal.bg }
            'card'     { $c.BackColor = $pal.card; $c.Invalidate() }
            'clear'    { $c.BackColor = [System.Drawing.Color]::Transparent }
            'text'     { $c.ForeColor = $pal.text }
            'sub'      { $c.ForeColor = $pal.sub }
            'hdrText'  { $c.ForeColor = $pal.hdrText }
            'hdrSub'   { $c.ForeColor = $pal.hdrSub }
            'input'    { $c.BackColor = $pal.input; $c.ForeColor = $pal.text }
            'link'     { $c.LinkColor = $pal.link; $c.ActiveLinkColor = $pal.link; $c.VisitedLinkColor = $pal.link }
            'update'   { $c.LinkColor = [System.Drawing.Color]::Orange; $c.ActiveLinkColor = [System.Drawing.Color]::Orange }
            'secondary' { $c.BackColor = $pal.btn; $c.ForeColor = $pal.text; $c.FlatAppearance.BorderSize = 1; $c.FlatAppearance.BorderColor = $pal.border; $c.FlatAppearance.MouseOverBackColor = $pal.btnHover }
            'primary'  { $c.BackColor = $pal.accent; $c.ForeColor = [System.Drawing.Color]::White; $c.FlatAppearance.BorderSize = 0; $c.FlatAppearance.MouseOverBackColor = $pal.accentHover }
            'danger'   { $c.BackColor = $pal.danger; $c.ForeColor = [System.Drawing.Color]::White; $c.FlatAppearance.BorderSize = 0; $c.FlatAppearance.MouseOverBackColor = $pal.dangerHover }
        }
        if ($c.Controls.Count -gt 0) { Paint-Tree $c $pal }
    }
}
function Update-Nav {
    $pal = Get-Pal
    foreach ($pair in @(@($navConv, $pageConv.Visible), @($navFmt, $pageFmt.Visible))) {
        $b = $pair[0]; $on = $pair[1]
        $b.FlatAppearance.BorderSize = 0
        if ($on) { $b.BackColor = $pal.accent; $b.ForeColor = [System.Drawing.Color]::White; $b.FlatAppearance.MouseOverBackColor = $pal.accent }
        else { $b.BackColor = $pal.navOff; $b.ForeColor = $pal.hdrSub; $b.FlatAppearance.MouseOverBackColor = $pal.btnHover }
    }
}
function Apply-Theme {
    $pal = Get-Pal
    $form.BackColor = $pal.bg
    Paint-Tree $form $pal
    Update-Nav
    try {
        $v = 0; if ($pal -eq $palettes.dark) { $v = 1 }
        [void][FOH.Dwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4)
        [void][FOH.Dwm]::DwmSetWindowAttribute($form.Handle, 19, [ref]$v, 4)
    } catch {}
    $form.Refresh()
}

# ================= Jazyk – aplikovanie =================
function Apply-Lang {
    foreach ($e in $script:i18n) {
        $c = $e[0]; $k = $e[1]; $kind = $e[2]
        if ($kind -eq 'text') { $c.Text = T $k }
        elseif ($kind -eq 'btn') { $c.Text = $k[1] + (T $k[0]) }
        elseif ($kind -eq 'items') {
            $sel = $c.SelectedIndex
            $c.Items.Clear(); foreach ($i in $k) { [void]$c.Items.Add((T $i)) }
            if ($sel -ge 0) { $c.SelectedIndex = $sel }
        }
    }
    Update-ConvStatus
    Update-Mode $false
    Load-Disks
    Show-Update
}

# ================= Navigácia =================
function Show-Page([string]$which) {
    $pageConv.Visible = ($which -eq 'conv'); $pageFmt.Visible = ($which -eq 'fmt')
    Update-Nav
}
$navConv.Add_Click({ Show-Page 'conv' })
$navFmt.Add_Click({ Show-Page 'fmt' })
$langCombo.Add_SelectedIndexChanged({
    $script:lang = @('sk', 'en')[$langCombo.SelectedIndex]
    Save-Prefs; Apply-Lang
})
$themeCombo.Add_SelectedIndexChanged({
    if ($themeCombo.SelectedIndex -lt 0) { return }
    $script:themeMode = @('auto', 'light', 'dark')[$themeCombo.SelectedIndex]
    Save-Prefs; Apply-Theme
})

# ================= CONVERT =================
function Update-ConvStatus { $convStatus.Text = TF 'files_count' $list.Items.Count '' }
function Add-Paths($paths) {
    foreach ($p in $paths) {
        if ((Test-Path -LiteralPath $p -PathType Leaf) -and ($p -match '\.(mp3|wav|flac|aif|aiff|aifc|m4a|aac)$') -and -not $list.Items.Contains($p)) { [void]$list.Items.Add($p) }
    }
    Update-ConvStatus
}
$onEnter = { param($s, $e) if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = 'Copy' } else { $e.Effect = 'None' } }
$onDrop = { param($s, $e) Add-Paths ($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)); Show-Page 'conv' }
$list.Add_DragEnter($onEnter); $list.Add_DragDrop($onDrop)
$pageConv.Add_DragEnter($onEnter); $pageConv.Add_DragDrop($onDrop)
$btnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = 'Audio (MP3, WAV, FLAC, AIFF, AAC/M4A)|*.mp3;*.wav;*.flac;*.aif;*.aiff;*.aifc;*.m4a;*.aac|' + (T 'all_files') + ' (*.*)|*.*'
    $dlg.Multiselect = $true; $dlg.Title = T 'choose_audio'
    if ($dlg.ShowDialog($form) -eq 'OK') { Add-Paths $dlg.FileNames }
})
$btnRem.Add_Click({ foreach ($x in @($list.SelectedItems)) { $list.Items.Remove($x) }; Update-ConvStatus })
$btnClr.Add_Click({ $list.Items.Clear(); Update-ConvStatus })
$btnConv.Add_Click({
    if ($list.Items.Count -eq 0) { $convStatus.Text = T 'add_first'; return }
    $ch = if ($rCh[0].Checked) { 1 } else { 2 }
    $bits = if ($rBits[0].Checked) { 16 } else { 24 }
    $rate = if ($rRate[0].Checked) { 44100 } elseif ($rRate[2].Checked) { 96000 } else { 48000 }
    $files = @($list.Items)
    $ctrls = @($btnConv, $btnAdd, $btnRem, $btnClr, $navFmt)
    foreach ($c in $ctrls) { $c.Enabled = $false }
    $convBar.Minimum = 0; $convBar.Maximum = $files.Count; $convBar.Value = 0
    $ok = 0; $fails = @(); $last = $null
    for ($i = 0; $i -lt $files.Count; $i++) {
        $convStatus.Text = (TF 'converting' ($i + 1) $files.Count) + '  ' + [IO.Path]::GetFileName($files[$i])
        [System.Windows.Forms.Application]::DoEvents()
        try { $r = Convert-One $files[$i] $ch $bits $rate } catch { $r = @{ ok = $false; err = $_.Exception.Message } }
        if ($r.ok) { $ok++; $last = $r.out } else { $fails += ([IO.Path]::GetFileName($files[$i]) + ' – ' + $r.err) }
        $convBar.Value = $i + 1
    }
    foreach ($c in $ctrls) { $c.Enabled = $true }
    $msg = TF 'conv_done' $ok ''
    if ($fails.Count) { $msg += (TF 'conv_failed_n' $fails.Count '') }
    $convStatus.Text = $msg
    if ($fails.Count) { [void][System.Windows.Forms.MessageBox]::Show($form, ((T 'conv_failed_list') + "`r`n`r`n" + ($fails -join "`r`n")), 'FOHstick', 'OK', 'Warning') }
    if ($last) { Start-Process explorer.exe -ArgumentList "/select,`"$last`"" }
})

# ================= FORMAT =================
$script:diskNums = @()
$script:busy = $false
$script:driveSig = ''
$script:updateVer = ''
$script:updateUrl = $URL_RELEASES

function P-Desc($p) { if ($script:lang -eq 'en') { $p[6] } else { $p[5] } }
function P-Tip($p) { if ($script:lang -eq 'en') { $p[8] } else { $p[7] } }

function Fill-Presets {
    $sel = $presetCombo.SelectedIndex
    $presetCombo.Items.Clear()
    foreach ($p in $script:presets) { [void]$presetCombo.Items.Add($p[0]) }
    if ($sel -lt 0 -or $sel -ge $presetCombo.Items.Count) { $sel = 0 }
    if ($presetCombo.Items.Count) { $presetCombo.SelectedIndex = $sel }
}

function Update-Mode([bool]$resetName) {
    $isPreset = $rPreset.Checked
    $lblPreset.Visible = $isPreset; $presetCombo.Visible = $isPreset
    foreach ($c in @($lblFs, $fsCombo, $lblCl, $clCombo, $lblSz, $szCombo)) { $c.Visible = -not $isPreset }
    if ($isPreset) {
        if ($presetCombo.SelectedIndex -lt 0) { return }
        $p = $script:presets[$presetCombo.SelectedIndex]
        $desc.Text = P-Desc $p
        if ($resetName) { $nameBox.Text = $p[4] }
    } else {
        $t = $fsCombo.Text + ' · MBR · ' + $szCombo.Text
        if ($fsCombo.Text -eq 'FAT32') { $t += (T 'custom_cluster') + $clCombo.Text }
        if ($fsCombo.Text -eq 'FAT16') { $t += T 'custom_fat16' }
        if ($fsCombo.Text -eq 'exFAT') { $t += T 'custom_exfat' }
        $desc.Text = $t
        if ($resetName -and $nameBox.Text -eq '') { $nameBox.Text = 'USB' }
    }
}

function Load-Disks {
    $prev = $null
    if ($diskCombo.SelectedIndex -ge 0 -and $script:diskNums.Count -gt $diskCombo.SelectedIndex) { $prev = $script:diskNums[$diskCombo.SelectedIndex] }
    $diskCombo.Items.Clear(); $script:diskNums = @()
    $disks = @(); $err = $null
    try { $disks = @(Get-Disk -ErrorAction Stop | Where-Object { $_.BusType -in @('USB', 'SD', 'MMC') -and -not $_.IsBoot -and -not $_.IsSystem } | Sort-Object Number) } catch { $err = $_.Exception.Message }
    $sel = 0
    foreach ($d in $disks) {
        $labels = @()
        try { $labels = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel } | ForEach-Object { $_.FileSystemLabel }) } catch {}
        $lab = T 'no_name'
        if ($labels.Count) { $lab = $labels -join ', ' }
        $title = '„' + $lab + '“  –  ' + $d.FriendlyName + ', ' + ('{0:N1} GB' -f ($d.Size / 1GB)) + '   (disk ' + $d.Number + ')'
        if ($prev -ne $null -and $d.Number -eq $prev) { $sel = $script:diskNums.Count }
        [void]$diskCombo.Items.Add($title); $script:diskNums += $d.Number
    }
    if ($script:diskNums.Count -eq 0) {
        [void]$diskCombo.Items.Add((T 'no_usb')); $diskCombo.SelectedIndex = 0
        $btnGo.Enabled = $false
        if ($err) { $usbStatus.Text = TF 'disk_list_fail' $err '' } else { $usbStatus.Text = T 'only_external' }
    } else {
        $diskCombo.SelectedIndex = $sel
        $btnGo.Enabled = -not $script:busy
        $usbStatus.Text = TF 'disks_found' $script:diskNums.Count ''
    }
}
function Get-DriveSig { try { (([IO.DriveInfo]::GetDrives() | ForEach-Object { $_.Name + $_.DriveType }) -join ';') } catch { '' } }

function Step-Text([string]$code, [string]$arg) {
    switch ($code) {
        'check' { return T 'st_check' }
        'erase' { return T 'st_erase' }
        'partition' { return T 'st_partition' }
        'fmt' { return TF 'st_fmt' $arg '' }
        'mount' { return T 'st_mount' }
        default { return $code }
    }
}
function Fail-Text([string]$code, [string]$detail) {
    switch ($code) {
        'not_external' { return T 'err_not_external' }
        'fat32_2tb' { return T 'err_fat32_2tb' }
        'ah_min' { return T 'err_ah_min' }
        'fs' { return T 'err_fs' }
        'no_letter' { return T 'err_no_letter' }
        default { return TF 'err_cmd' $detail '' }
    }
}

$rPreset.Add_CheckedChanged({ Update-Mode $true })
$presetCombo.Add_SelectedIndexChanged({ Update-Mode $true })
$fsCombo.Add_SelectedIndexChanged({ Update-Mode $false })
$clCombo.Add_SelectedIndexChanged({ Update-Mode $false })
$szCombo.Add_SelectedIndexChanged({ Update-Mode $false })
$btnRefresh.Add_Click({ Load-Disks })

$btnGo.Add_Click({
    if ($script:diskNums.Count -eq 0) { return }
    $dn = $script:diskNums[$diskCombo.SelectedIndex]
    $name = ($nameBox.Text.ToUpper() -replace '[^A-Z0-9_]', '')
    if ($name.Length -gt 11) { $name = $name.Substring(0, 11) }
    if (-not $name) { $name = 'USB' }
    if ($rPreset.Checked) {
        $p = $script:presets[$presetCombo.SelectedIndex]
        $fsA = $p[1]; $clA = $p[2]; $mxA = $p[3]; $what = $p[0]; $tip = P-Tip $p
    } else {
        $fsA = @('FAT32', 'EXFAT', 'FAT16')[$fsCombo.SelectedIndex]
        $clA = @('0', '64')[$clCombo.SelectedIndex]
        $mxA = @('0', '32000000000', '16000000000', '2000000000')[$szCombo.SelectedIndex]
        $what = TF 'custom_what' $fsCombo.Text ''; $tip = T 'custom_tip'
    }
    $msg = (T 'confirm_disk') + $diskCombo.Text + "`r`n" + (T 'confirm_format') + $what + "`r`n" + (T 'confirm_name') + $name + "`r`n`r`n" + (T 'confirm_warn') + ' ' + (T 'confirm_continue')
    $ans = [System.Windows.Forms.MessageBox]::Show($form, $msg, (T 'confirm_title'), 'YesNo', 'Warning', 'Button2')
    if ($ans -ne 'Yes') { return }

    $script:busy = $true
    $ctrls = @($btnGo, $btnRefresh, $diskCombo, $rPreset, $rCustom, $presetCombo, $fsCombo, $clCombo, $szCombo, $nameBox, $navConv)
    foreach ($c in $ctrls) { $c.Enabled = $false }
    $usbBar.Value = 0; $usbBar.Visible = $true
    $usbStatus.Text = T 'wait_uac'
    [System.Windows.Forms.Application]::DoEvents()

    $okRes = ''; $failMsg = ''; $cancelled = $false
    $stamp = [DateTime]::Now.ToString('yyyyMMddHHmmss')
    $childPath = Join-Path $appDir ('fohstick-format-' + $stamp + '.ps1')
    $log = Join-Path $appDir ('fohstick-format-' + $stamp + '.log')
    try {
        [IO.File]::WriteAllText($childPath, $usbChild, (New-Object System.Text.UTF8Encoding $true))
        [IO.File]::WriteAllText($log, '', (New-Object System.Text.UTF8Encoding $false))
        $argStr = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $childPath + '" -Log "' + $log + '" -Disk ' + $dn + ' -Fs ' + $fsA + ' -Cl ' + $clA + ' -Max ' + $mxA + ' -Name ' + $name
        $proc = $null
        try { $proc = Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList $argStr -PassThru } catch { $cancelled = $true }
        if (-not $cancelled) {
            $done = $false
            while (-not $done) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 150
                $lines = @()
                try { $lines = [IO.File]::ReadAllLines($log, [Text.Encoding]::UTF8) } catch {}
                foreach ($l in $lines) {
                    $parts = $l -split '\|'
                    if ($l -match '^STEP (\d)\|') {
                        $n = [int]$matches[1]; $usbBar.Value = $n
                        $arg = ''; if ($parts.Count -ge 3) { $arg = $parts[2] }
                        $usbStatus.Text = TF 'step_line' $n (Step-Text $parts[1] $arg)
                    } elseif ($l -match '^DONE\|') {
                        $done = $true; $okRes = (($parts | Select-Object -Skip 1) | Where-Object { $_ }) -join ' · '
                    } elseif ($l -match '^FAIL\|') {
                        $done = $true; $det = ''; if ($parts.Count -ge 3) { $det = $parts[2] }
                        $failMsg = Fail-Text $parts[1] $det
                    }
                }
                if (-not $done -and $proc -and $proc.HasExited) {
                    Start-Sleep -Milliseconds 400
                    try { $lines = [IO.File]::ReadAllLines($log, [Text.Encoding]::UTF8) } catch {}
                    $last = $lines | Where-Object { $_ -match '^(DONE|FAIL)\|' } | Select-Object -Last 1
                    if ($last) {
                        $parts = $last -split '\|'
                        if ($parts[0] -eq 'DONE') { $okRes = (($parts | Select-Object -Skip 1) | Where-Object { $_ }) -join ' · ' }
                        else { $det = ''; if ($parts.Count -ge 3) { $det = $parts[2] }; $failMsg = Fail-Text $parts[1] $det }
                    } else { $failMsg = T 'err_noresult' }
                    $done = $true
                }
            }
        }
    } catch { $failMsg = TF 'err_cmd' $_.Exception.Message '' }
    foreach ($f in @($childPath, $log)) { try { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } catch {} }

    foreach ($c in $ctrls) { $c.Enabled = $true }
    $script:busy = $false
    if ($cancelled) {
        $usbBar.Visible = $false; $usbStatus.Text = T 'cancelled_uac'
    } elseif ($failMsg) {
        $usbBar.Visible = $false; $usbStatus.Text = T 'fail_title'
        [void][System.Windows.Forms.MessageBox]::Show($form, $failMsg, (T 'fail_title'), 'OK', 'Warning')
    } else {
        $usbBar.Value = 4; $usbStatus.Text = (T 'done_title') + '  ' + $okRes
        [void][System.Windows.Forms.MessageBox]::Show($form, ((TF 'done_text' $what '') + "`r`n" + $okRes + "`r`n`r`n" + $tip), (T 'done_title'), 'OK', 'Information')
        $usbBar.Visible = $false
    }
    $script:driveSig = Get-DriveSig
    Load-Disks
    Update-Mode $false
})

# ================= Dáta z GitHubu =================
function Show-Update {
    if ($script:updateVer) { $updateLink.Text = TF 'update_avail' $script:updateVer ''; $updateLink.Visible = $true } else { $updateLink.Visible = $false }
}
$updateLink.Add_LinkClicked({ Start-Process $script:updateUrl })

function Start-RemoteFetch {
    $ad = $appDir -replace "'", "''"
    $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " +
           "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri '$URL_CONSOLES' -OutFile '$ad\consoles.new' } catch {}; " +
           "try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri '$URL_VERSION' -OutFile '$ad\version.new' } catch {}"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = 'powershell.exe'; $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        [void][System.Diagnostics.Process]::Start($psi)
    } catch {}
}
function Check-Remote {
    $cn = Join-Path $appDir 'consoles.new'
    if (Test-Path -LiteralPath $cn) {
        try {
            $lst = Parse-Consoles (Get-Content -LiteralPath $cn -Raw -Encoding UTF8)
            if ($lst.Count -gt 0) {
                Move-Item -LiteralPath $cn -Destination $cachePath -Force
                if (-not $script:busy) { $script:presets = $lst; Fill-Presets; Update-Mode $false }
            } else { Remove-Item -LiteralPath $cn -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
    $vn = Join-Path $appDir 'version.new'
    if (Test-Path -LiteralPath $vn) {
        try {
            $vo = Get-Content -LiteralPath $vn -Raw -Encoding UTF8 | ConvertFrom-Json
            if ([version]$vo.latest -gt [version]$APP_VERSION) {
                $script:updateVer = [string]$vo.latest
                if ([string]$vo.url -like 'https://github.com/fristik-eu/*') { $script:updateUrl = [string]$vo.url }
                Show-Update
            }
        } catch {}
        Remove-Item -LiteralPath $vn -Force -ErrorAction SilentlyContinue
    }
}

# ================= Časovač =================
$script:ticks = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 2500
$timer.Add_Tick({
    $script:ticks++
    if ($script:ticks -eq 2 -or $script:ticks -eq 5) { Check-Remote }
    if ($script:busy) { return }
    $s = Get-DriveSig
    if ($s -ne $script:driveSig) { $script:driveSig = $s; Load-Disks }
})

# ================= Zástupca s ikonou (plocha + Štart) =================
try {
    $icoPath = Join-Path $appDir 'fohstick.ico'
    [IO.File]::WriteAllBytes($icoPath, $iconBytes)
    $target = $env:K48
    if ($target -and (Test-Path -LiteralPath $target)) {
        $iconLoc = "$icoPath,0"
        if ($target -like '*.exe') { $iconLoc = "$target,0" }
        $ws = New-Object -ComObject WScript.Shell
        foreach ($pl in @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))) {
            if (-not $pl) { continue }
            $lnkPath = Join-Path $pl 'FOHstick.lnk'
            $need = $true
            if (Test-Path -LiteralPath $lnkPath) {
                $old = $ws.CreateShortcut($lnkPath)
                if ($old.TargetPath -eq $target -and $old.IconLocation -eq $iconLoc) { $need = $false }
            }
            if ($need) {
                $lnk = $ws.CreateShortcut($lnkPath)
                $lnk.TargetPath = $target
                $lnk.WorkingDirectory = [IO.Path]::GetDirectoryName($target)
                $lnk.IconLocation = $iconLoc
                if ($target -like '*.cmd') { $lnk.WindowStyle = 7 }
                $lnk.Description = 'FOHstick – fristik.eu'
                $lnk.Save()
            }
        }
    }
} catch {}

$form.Add_Shown({
    Fill-Presets
    Update-ConvStatus
    Update-Mode $true
    Apply-Theme
    $script:driveSig = Get-DriveSig
    Load-Disks
    $timer.Start()
    Start-RemoteFetch
})
[void]$form.ShowDialog()
$timer.Stop()
