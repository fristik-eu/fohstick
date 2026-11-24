use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

-- FOHstick – fristik.eu  (© 2026 fristik.eu · apps@fristik.eu · https://fristik.eu)

property APP_VERSION : "@@VERSION@@"
property URL_CONSOLES : "https://raw.githubusercontent.com/fristik-eu/fohstick/main/data/consoles.json"
property URL_VERSION : "https://raw.githubusercontent.com/fristik-eu/fohstick/main/data/version.json"
property URL_RELEASES : "https://github.com/fristik-eu/fohstick/releases/latest"

property L10N : @@L10N@@
property presets : @@PRESETS@@

property lang : "sk"
property themeMode : "auto"
property i18n : {}
property updateURL : ""
property updateVer : ""

property theWindow : missing value
property tabView : missing value
property langPopup : missing value
property themePopup : missing value
property updateBtn : missing value
property listView : missing value
property chanSeg : missing value
property bitsSeg : missing value
property rateSeg : missing value
property convStatus : missing value
property convertBtn : missing value
property convBar : missing value
property theFiles : {}
property diskPopup : missing value
property modeSeg : missing value
property presetLabel : missing value
property presetPopup : missing value
property fsLabel : missing value
property fsPopup : missing value
property clLabel : missing value
property clPopup : missing value
property szLabel : missing value
property szPopup : missing value
property descLabel : missing value
property nameField : missing value
property formatBtn : missing value
property usbStatus : missing value
property usbBar : missing value
property isBusy : false
property diskIds : {}

-- ================= Štart =================
on run
	my buildUI()
end run

on reopen
	my buildUI()
end reopen

on open dropped
	my buildUI()
	repeat with x in dropped
		my addPath(POSIX path of x)
	end repeat
	my updateList()
	tabView's selectTabViewItemAtIndex:0
end open

-- ================= Pomocné =================
on tr(k)
	if k starts with "=" then return text 2 thru -1 of k
	repeat with t in L10N
		if (item 1 of t) is k then
			if lang is "en" then return item 3 of t
			return item 2 of t
		end if
	end repeat
	return k
end tr

on trf(k, a1, a2)
	set s to my tr(k)
	set s to my replaceText(s, "%1", a1 as text)
	set s to my replaceText(s, "%2", a2 as text)
	return s
end trf

on replaceText(s, f, r)
	set AppleScript's text item delimiters to f
	set parts to text items of s
	set AppleScript's text item delimiters to r
	set s to parts as text
	set AppleScript's text item delimiters to ""
	return s
end replaceText

on reg(ctrl, k, ctype)
	set end of i18n to {ctrl, k, ctype}
end reg

on supportDir()
	set d to (POSIX path of (path to application support folder from user domain)) & "FOHstick/"
	do shell script "mkdir -p " & quoted form of d
	return d
end supportDir

on resPath(fileName)
	return quoted form of ((POSIX path of (path to me)) & "Contents/Resources/" & fileName)
end resPath

on lbl(pv, k, x, y, w, h, sz, isBold, isGrey)
	if k starts with "=" then
		set txt to text 2 thru -1 of k
	else if k is "" then
		set txt to ""
	else
		set txt to my tr(k)
	end if
	set l to current application's NSTextField's wrappingLabelWithString:txt
	l's setFrame:{{x, y}, {w, h}}
	if isBold then
		l's setFont:(current application's NSFont's boldSystemFontOfSize:sz)
	else
		l's setFont:(current application's NSFont's systemFontOfSize:sz)
	end if
	if isGrey then l's setTextColor:(current application's NSColor's secondaryLabelColor())
	pv's addSubview:l
	if k is not "" and not (k starts with "=") then my reg(l, k, "label")
	return l
end lbl

on btn(pv, k, act, x, y, w, h)
	if k starts with "=" then
		set t to text 2 thru -1 of k
	else
		set t to my tr(k)
	end if
	set b to current application's NSButton's buttonWithTitle:t target:me action:act
	b's setFrame:{{x, y}, {w, h}}
	pv's addSubview:b
	if not (k starts with "=") then my reg(b, k, "button")
	return b
end btn

on seg(pv, keys, x, y, w, sel, act)
	set titles to {}
	repeat with k in keys
		set end of titles to my tr(k as text)
	end repeat
	if act is "" then
		set s to current application's NSSegmentedControl's segmentedControlWithLabels:titles trackingMode:0 target:(missing value) action:(missing value)
	else
		set s to current application's NSSegmentedControl's segmentedControlWithLabels:titles trackingMode:0 target:me action:act
	end if
	s's setFrame:{{x, y}, {w, 24}}
	s's setSelectedSegment:sel
	pv's addSubview:s
	my reg(s, keys, "seg")
	return s
end seg

on popup(pv, keys, x, y, w, translate)
	set p to current application's NSPopUpButton's alloc()'s initWithFrame:{{x, y}, {w, 28}} pullsDown:false
	repeat with k in keys
		if translate then
			(p's addItemWithTitle:(my tr(k as text)))
		else
			(p's addItemWithTitle:(k as text))
		end if
	end repeat
	p's setTarget:me
	p's setAction:"settingsChanged:"
	pv's addSubview:p
	if translate then my reg(p, keys, "popup")
	return p
end popup

on bar(pv, x, y, w)
	set b to current application's NSProgressIndicator's alloc()'s initWithFrame:{{x, y}, {w, 20}}
	b's setStyle:0
	b's setIndeterminate:false
	b's setMinValue:0
	b's setHidden:true
	pv's addSubview:b
	return b
end bar

on card(pv, k, x, y, w, h)
	set bx to current application's NSBox's alloc()'s initWithFrame:{{x, y}, {w, h}}
	bx's setBoxType:4
	bx's setTitlePosition:0
	bx's setCornerRadius:12
	bx's setBorderWidth:1
	try
		bx's setBorderColor:(current application's NSColor's separatorColor())
	end try
	bx's setFillColor:(current application's NSColor's controlBackgroundColor())
	bx's setContentViewMargins:{0, 0}
	pv's addSubview:bx
	set cvw to bx's contentView()
	if k is not "" then my lbl(cvw, k, 14, h - 28, w - 28, 18, 12, true, true)
	return cvw
end card

on sym(b, symName)
	try
		set img to current application's NSImage's imageWithSystemSymbolName:symName accessibilityDescription:(missing value)
		if img is not missing value then
			b's setImage:img
			b's setImagePosition:2
		end if
	end try
end sym

on bigBtn(pv, k, act, x, y, w, symName)
	set b to my btn(pv, k, act, x, y, w, 40)
	try
		b's setControlSize:3
	end try
	b's setFont:(current application's NSFont's boldSystemFontOfSize:14)
	my sym(b, symName)
	return b
end bigBtn

on pump()
	(current application's NSRunLoop's currentRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.02))
end pump

-- ================= Nastavenia (jazyk, téma) =================
on loadPrefs()
	set ud to current application's NSUserDefaults's standardUserDefaults()
	set l to ud's stringForKey:"lang"
	if l is missing value then
		set pl to ((current application's NSLocale's preferredLanguages()'s firstObject()) as text)
		if pl starts with "sk" or pl starts with "cs" then
			set lang to "sk"
		else
			set lang to "en"
		end if
	else
		set lang to l as text
	end if
	set t to ud's stringForKey:"theme"
	if t is missing value then
		set themeMode to "auto"
	else
		set themeMode to t as text
	end if
end loadPrefs

on savePrefs()
	set ud to current application's NSUserDefaults's standardUserDefaults()
	ud's setObject:lang forKey:"lang"
	ud's setObject:themeMode forKey:"theme"
end savePrefs

on applyTheme()
	try
		if themeMode is "light" then
			current application's NSApp's setAppearance:(current application's NSAppearance's appearanceNamed:"NSAppearanceNameAqua")
		else if themeMode is "dark" then
			current application's NSApp's setAppearance:(current application's NSAppearance's appearanceNamed:"NSAppearanceNameDarkAqua")
		else
			current application's NSApp's setAppearance:(missing value)
		end if
	end try
end applyTheme

on langChanged:sender
	if ((langPopup's indexOfSelectedItem()) as integer) is 1 then
		set lang to "en"
	else
		set lang to "sk"
	end if
	my savePrefs()
	my applyLang()
end langChanged:

on themeChanged:sender
	set i to (themePopup's indexOfSelectedItem()) as integer
	set themeMode to item (i + 1) of {"auto", "light", "dark"}
	my savePrefs()
	my applyTheme()
end themeChanged:

on applyLang()
	repeat with e in i18n
		try
			set c to item 1 of e
			set k to item 2 of e
			set ctype to item 3 of e
			if ctype is "label" then
				(c's setStringValue:(my tr(k)))
			else if ctype is "button" then
				(c's setTitle:(my tr(k)))
			else if ctype is "seg" then
				repeat with i from 1 to count of k
					(c's setLabel:(my tr(item i of k)) forSegment:(i - 1))
				end repeat
			else if ctype is "popup" then
				repeat with i from 1 to count of k
					((c's itemAtIndex:(i - 1))'s setTitle:(my tr(item i of k)))
				end repeat
			else if ctype is "tab" then
				(c's setLabel:(my tr(k)))
			end if
		end try
	end repeat
	my updateList()
	my applyMode(false)
	my loadDisks()
	my showUpdate()
end applyLang

-- ================= Dáta z GitHubu =================
on parseConsoles(pathText)
	try
		set d to current application's NSData's dataWithContentsOfFile:pathText
		if d is missing value then return {}
		set obj to current application's NSJSONSerialization's JSONObjectWithData:d options:0 |error|:(missing value)
		if obj is missing value then return {}
		set arr to obj's objectForKey:"consoles"
		if arr is missing value then return {}
		set out to {}
		set okFs to {"AUTOX", "AUTO16", "FAT32", "FAT16", "EXFAT"}
		repeat with i from 0 to ((arr's |count|()) - 1)
			set c to (arr's objectAtIndex:i)
			set nm to (c's objectForKey:"name") as text
			set fs to (c's objectForKey:"fs") as text
			set cl to ((c's objectForKey:"cluster") as integer)
			set mx to ((c's objectForKey:"max") as real)
			set lb to (c's objectForKey:"label") as text
			if okFs contains fs and cl ≥ 0 and cl ≤ 128 and mx ≥ 0 then
				set mxT to do shell script "printf '%.0f' " & mx
				set end of out to {nm, fs, cl as text, mxT, lb, (c's objectForKey:"desc_sk") as text, (c's objectForKey:"desc_en") as text, (c's objectForKey:"tip_sk") as text, (c's objectForKey:"tip_en") as text}
			end if
		end repeat
		return out
	on error
		return {}
	end try
end parseConsoles

on loadCachedConsoles()
	set f to (my supportDir()) & "consoles.json"
	set lst to my parseConsoles(f)
	if (count of lst) > 0 then set presets to lst
end loadCachedConsoles

on startRemoteFetch()
	set d to my supportDir()
	try
		do shell script "cd " & quoted form of d & " && rm -f consoles.new version.new; (/usr/bin/curl -fsSL --max-time 8 " & quoted form of URL_CONSOLES & " -o consoles.new; /usr/bin/curl -fsSL --max-time 8 " & quoted form of URL_VERSION & " -o version.new) >/dev/null 2>&1 &"
	end try
	current application's NSTimer's scheduledTimerWithTimeInterval:5 target:me selector:"remoteCheck:" userInfo:(missing value) repeats:false
	current application's NSTimer's scheduledTimerWithTimeInterval:12 target:me selector:"remoteCheck:" userInfo:(missing value) repeats:false
end startRemoteFetch

on remoteCheck:aTimer
	if theWindow is missing value then return
	set d to my supportDir()
	set newC to d & "consoles.new"
	set lst to my parseConsoles(newC)
	if (count of lst) > 0 then
		do shell script "cd " & quoted form of d & " && mv -f consoles.new consoles.json"
		if not isBusy then
			set presets to lst
			my rebuildPresetPopup()
		end if
	end if
	try
		set vf to d & "version.new"
		set vd to current application's NSData's dataWithContentsOfFile:vf
		if vd is not missing value then
			set vo to current application's NSJSONSerialization's JSONObjectWithData:vd options:0 |error|:(missing value)
			if vo is not missing value then
				set latest to (vo's objectForKey:"latest") as text
				set u to (vo's objectForKey:"url") as text
				if my isNewer(latest, APP_VERSION) then
					set updateVer to latest
					if u starts with "https://github.com/fristik-eu/" then
						set updateURL to u
					else
						set updateURL to URL_RELEASES
					end if
					my showUpdate()
				end if
			end if
			do shell script "rm -f " & quoted form of vf
		end if
	end try
end remoteCheck:

on isNewer(a, b)
	try
		set AppleScript's text item delimiters to "."
		set pa to text items of a
		set pb to text items of b
		set AppleScript's text item delimiters to ""
		repeat with i from 1 to 3
			set x to 0
			set y to 0
			if (count of pa) ≥ i then set x to (item i of pa) as integer
			if (count of pb) ≥ i then set y to (item i of pb) as integer
			if x > y then return true
			if x < y then return false
		end repeat
	end try
	set AppleScript's text item delimiters to ""
	return false
end isNewer

on showUpdate()
	if updateBtn is missing value then return
	if updateVer is "" then
		updateBtn's setHidden:true
	else
		updateBtn's setTitle:(my trf("update_avail", updateVer, ""))
		updateBtn's setHidden:false
	end if
end showUpdate

on openUpdate:sender
	if updateURL is not "" then do shell script "open " & quoted form of updateURL
end openUpdate:

on rebuildPresetPopup()
	set sel to (presetPopup's indexOfSelectedItem()) as integer
	presetPopup's removeAllItems()
	repeat with p in presets
		(presetPopup's addItemWithTitle:(item 1 of p))
	end repeat
	if sel < 0 or sel ≥ (count of presets) then set sel to 0
	presetPopup's selectItemAtIndex:sel
	my applyMode(false)
end rebuildPresetPopup

-- ================= Okno =================
on buildUI()
	current application's NSApp's activateIgnoringOtherApps:true
	if theWindow is not missing value then
		theWindow's makeKeyAndOrderFront:me
		return
	end if
	my loadPrefs()
	my applyTheme()
	my loadCachedConsoles()
	set i18n to {}

	set theWindow to current application's NSWindow's alloc()'s initWithContentRect:{{0, 0}, {600, 700}} styleMask:7 backing:2 defer:false
	theWindow's setTitle:"FOHstick – fristik.eu"
	theWindow's setReleasedWhenClosed:false
	theWindow's setDelegate:me
	set cv to theWindow's contentView()

	-- Hlavička
	try
		set appIcon to current application's NSImageView's imageViewWithImage:(current application's NSApp's applicationIconImage())
		appIcon's setFrame:{{18, 640}, {48, 48}}
		cv's addSubview:appIcon
	end try
	my lbl(cv, "=FOHstick", 74, 662, 260, 26, 22, true, false)
	my lbl(cv, "subtitle", 75, 642, 330, 18, 12, false, true)
	set langPopup to current application's NSPopUpButton's alloc()'s initWithFrame:{{420, 660}, {80, 26}} pullsDown:false
	langPopup's addItemsWithTitles:{"SK", "EN"}
	if lang is "en" then langPopup's selectItemAtIndex:1
	langPopup's setTarget:me
	langPopup's setAction:"langChanged:"
	cv's addSubview:langPopup
	set themePopup to current application's NSPopUpButton's alloc()'s initWithFrame:{{505, 660}, {85, 26}} pullsDown:false
	repeat with k in {"theme_auto", "theme_light", "theme_dark"}
		(themePopup's addItemWithTitle:(my tr(k as text)))
	end repeat
	my reg(themePopup, {"theme_auto", "theme_light", "theme_dark"}, "popup")
	if themeMode is "light" then themePopup's selectItemAtIndex:1
	if themeMode is "dark" then themePopup's selectItemAtIndex:2
	themePopup's setTarget:me
	themePopup's setAction:"themeChanged:"
	cv's addSubview:themePopup
	set updateBtn to current application's NSButton's buttonWithTitle:"" target:me action:"openUpdate:"
	updateBtn's setFrame:{{330, 636}, {260, 22}}
	updateBtn's setBordered:false
	updateBtn's setAlignment:1
	updateBtn's setFont:(current application's NSFont's boldSystemFontOfSize:12)
	try
		updateBtn's setContentTintColor:(current application's NSColor's systemOrangeColor())
	end try
	updateBtn's setHidden:true
	cv's addSubview:updateBtn

	set tabView to current application's NSTabView's alloc()'s initWithFrame:{{10, 34}, {580, 600}}
	cv's addSubview:tabView
	set t1 to current application's NSTabViewItem's alloc()'s initWithIdentifier:"conv"
	t1's setLabel:(my tr("tab_conv"))
	set t2 to current application's NSTabViewItem's alloc()'s initWithIdentifier:"usb"
	t2's setLabel:(my tr("tab_fmt"))
	my reg(t1, "tab_conv", "tab")
	my reg(t2, "tab_fmt", "tab")
	tabView's addTabViewItem:t1
	tabView's addTabViewItem:t2
	set cr to tabView's contentRect()
	set v1 to current application's NSView's alloc()'s initWithFrame:cr
	set v2 to current application's NSView's alloc()'s initWithFrame:cr
	t1's setView:v1
	t2's setView:v2

	-- ===== Convert =====
	set c1 to my card(v1, "card_files", 10, 300, 540, 240)
	my lbl(c1, "files_hint_mac", 14, 190, 512, 18, 12, false, true)
	set sv to current application's NSScrollView's alloc()'s initWithFrame:{{12, 54}, {516, 132}}
	sv's setHasVerticalScroller:true
	sv's setBorderType:2
	set listView to current application's NSTextView's alloc()'s initWithFrame:{{0, 0}, {500, 132}}
	listView's setEditable:false
	listView's setTextContainerInset:{6, 6}
	sv's setDocumentView:listView
	c1's addSubview:sv
	set b1 to my btn(c1, "btn_add", "addFiles:", 8, 10, 170, 36)
	my sym(b1, "plus.circle")
	set b2 to my btn(c1, "btn_clear", "clearFiles:", 180, 10, 170, 36)
	my sym(b2, "trash")

	set c2 to my card(v1, "card_output", 10, 120, 540, 170)
	my lbl(c2, "channels", 14, 110, 112, 20, 13, true, false)
	set chanSeg to my seg(c2, {"mono", "stereo"}, 130, 106, 180, 1, "")
	my lbl(c2, "bitdepth", 14, 76, 112, 20, 13, true, false)
	set bitsSeg to my seg(c2, {"=16-bit", "=24-bit"}, 130, 72, 180, 1, "")
	my lbl(c2, "rate", 14, 42, 112, 20, 13, true, false)
	set rateSeg to my seg(c2, {"=44,1 kHz", "=48 kHz", "=96 kHz"}, 130, 38, 270, 1, "")
	my lbl(c2, "out_hint", 14, 10, 512, 18, 11, false, true)

	set convBar to my bar(v1, 12, 76, 340)
	set convertBtn to my bigBtn(v1, "btn_convert", "convertFiles:", 370, 66, 180, "waveform")
	convertBtn's setKeyEquivalent:return
	set convStatus to my lbl(v1, "", 12, 16, 536, 40, 12, false, true)

	-- ===== Format =====
	set c3 to my card(v2, "card_usb", 10, 438, 540, 102)
	my lbl(c3, "usb_intro", 14, 52, 512, 18, 12, false, true)
	set diskPopup to current application's NSPopUpButton's alloc()'s initWithFrame:{{12, 14}, {394, 28}} pullsDown:false
	c3's addSubview:diskPopup
	set rb to my btn(c3, "btn_refresh", "refreshDisks:", 412, 11, 116, 34)
	my sym(rb, "arrow.clockwise")

	set c4 to my card(v2, "card_settings", 10, 186, 540, 242)
	my lbl(c4, "mode", 14, 186, 112, 20, 13, true, false)
	set modeSeg to my seg(c4, {"mode_preset", "mode_custom"}, 130, 182, 300, 0, "settingsChanged:")
	set presetLabel to my lbl(c4, "console", 14, 148, 112, 20, 13, true, false)
	set ptitles to {}
	repeat with p in presets
		set end of ptitles to item 1 of p
	end repeat
	set presetPopup to my popup(c4, ptitles, 128, 143, 398, false)
	set fsLabel to my lbl(c4, "filesystem", 14, 148, 112, 20, 13, true, false)
	set fsPopup to my popup(c4, {"FAT32", "exFAT", "FAT16"}, 128, 143, 120, false)
	set clLabel to my lbl(c4, "cluster", 262, 148, 66, 20, 13, true, false)
	set clPopup to my popup(c4, {"cl_default", "cl_32"}, 330, 143, 196, true)
	set szLabel to my lbl(c4, "size", 14, 112, 112, 20, 13, true, false)
	set szPopup to my popup(c4, {"sz_whole", "sz_32", "sz_16", "sz_2"}, 128, 107, 220, true)
	set descLabel to my lbl(c4, "", 132, 50, 394, 54, 12, false, true)
	my lbl(c4, "disk_name", 14, 18, 112, 20, 13, true, false)
	set nameField to current application's NSTextField's alloc()'s initWithFrame:{{130, 14}, {200, 26}}
	c4's addSubview:nameField
	my lbl(c4, "name_hint", 340, 18, 186, 20, 12, false, true)

	set usbBar to my bar(v2, 12, 140, 330)
	usbBar's setMaxValue:4
	set formatBtn to my bigBtn(v2, "btn_format", "formatClicked:", 350, 130, 200, "externaldrive.badge.checkmark")
	try
		formatBtn's setBezelColor:(current application's NSColor's systemRedColor())
	end try
	set usbStatus to my lbl(v2, "", 12, 74, 536, 44, 12, false, true)
	my lbl(v2, "warn_mac", 12, 16, 536, 36, 11, false, true)

	-- ===== Pätička (majiteľ) =====
	try
		set logoImg to current application's NSImage's alloc()'s initWithContentsOfFile:((POSIX path of (path to me)) & "Contents/Resources/fristik.png")
		logoImg's setTemplate:true
		set iv to current application's NSImageView's imageViewWithImage:logoImg
		iv's setImageScaling:3
		iv's setFrame:{{20, 7}, {26, 20}}
		iv's setToolTip:"fristik.eu"
		try
			iv's setContentTintColor:(current application's NSColor's secondaryLabelColor())
		end try
		cv's addSubview:iv
	end try
	my lbl(cv, "=© 2026 fristik.eu", 50, 10, 120, 16, 11, false, true)
	set w1 to my btn(cv, "=fristik.eu", "openWeb:", 165, 8, 70, 20)
	set w2 to my btn(cv, "=apps@fristik.eu", "openMail:", 240, 8, 110, 20)
	repeat with wRef in {w1, w2}
		set w to contents of wRef
		(w's setBordered:false)
		(w's setFont:(current application's NSFont's systemFontOfSize:11))
		try
			(w's setContentTintColor:(current application's NSColor's linkColor()))
		end try
	end repeat
	set verLbl to my lbl(cv, "=v" & APP_VERSION, 500, 10, 90, 16, 11, false, true)
	verLbl's setAlignment:1

	set nc to current application's NSWorkspace's sharedWorkspace()'s notificationCenter()
	nc's addObserver:me selector:"volumesChanged:" |name|:"NSWorkspaceDidMountNotification" object:(missing value)
	nc's addObserver:me selector:"volumesChanged:" |name|:"NSWorkspaceDidUnmountNotification" object:(missing value)

	my updateList()
	my applyMode(true)
	my loadDisks()
	theWindow's |center|()
	theWindow's makeKeyAndOrderFront:me
	my startRemoteFetch()
end buildUI

-- ================= CONVERT =================
on addPath(p)
	if theFiles does not contain p then set end of theFiles to p
end addPath

on updateList()
	if listView is missing value then return
	if theFiles is {} then
		listView's setString:(my tr("files_empty"))
	else
		set AppleScript's text item delimiters to linefeed
		set s to theFiles as text
		set AppleScript's text item delimiters to ""
		listView's setString:s
	end if
	convStatus's setStringValue:(my trf("files_count", count of theFiles, ""))
end updateList

on addFiles:sender
	try
		set f to choose file with prompt (my tr("choose_audio")) of type {"public.audio", "public.mp3", "com.microsoft.waveform-audio", "org.xiph.flac", "public.aiff-audio", "public.aifc-audio", "com.apple.m4a-audio", "public.aac-audio", "public.mpeg-4-audio"} with multiple selections allowed
	on error
		return
	end try
	repeat with x in f
		my addPath(POSIX path of x)
	end repeat
	my updateList()
end addFiles:

on clearFiles:sender
	set theFiles to {}
	my updateList()
end clearFiles:

on convertFiles:sender
	if theFiles is {} then
		convStatus's setStringValue:(my tr("add_first"))
		return
	end if
	if ((chanSeg's selectedSegment()) as integer) is 0 then
		set ch to "1"
	else
		set ch to "2"
	end if
	if ((bitsSeg's selectedSegment()) as integer) is 0 then
		set bits to "16"
	else
		set bits to "24"
	end if
	set rSel to (rateSeg's selectedSegment()) as integer
	if rSel is 0 then
		set rate to "44100"
	else if rSel is 2 then
		set rate to "96000"
	else
		set rate to "48000"
	end if
	set conv to my resPath("conv.sh")
	convertBtn's setEnabled:false
	set okCount to 0
	set failCount to 0
	set lastOut to ""
	set n to count of theFiles
	convBar's setMaxValue:n
	convBar's setDoubleValue:0
	convBar's setHidden:false
	repeat with i from 1 to n
		set p to item i of theFiles
		convStatus's setStringValue:(my trf("converting", i, n))
		my pump()
		try
			set lastOut to do shell script conv & " " & ch & " " & bits & " " & rate & " " & quoted form of p
			set okCount to okCount + 1
		on error
			set failCount to failCount + 1
		end try
		convBar's setDoubleValue:i
	end repeat
	convertBtn's setEnabled:true
	convBar's setHidden:true
	set msg to my trf("conv_done", okCount, "")
	if failCount > 0 then set msg to msg & my trf("conv_failed_n", failCount, "")
	convStatus's setStringValue:msg
	if lastOut is not "" then do shell script "open -R " & quoted form of lastOut
end convertFiles:

-- ================= FORMAT =================
on presetDesc(p)
	if lang is "en" then return item 7 of p
	return item 6 of p
end presetDesc

on presetTip(p)
	if lang is "en" then return item 9 of p
	return item 8 of p
end presetTip

on applyMode(resetName)
	if modeSeg is missing value then return
	set isPreset to ((modeSeg's selectedSegment()) as integer) is 0
	presetLabel's setHidden:(not isPreset)
	presetPopup's setHidden:(not isPreset)
	repeat with cRef in {fsLabel, fsPopup, clLabel, clPopup, szLabel, szPopup}
		set c to contents of cRef
		(c's setHidden:isPreset)
	end repeat
	if isPreset then
		set idx to ((presetPopup's indexOfSelectedItem()) as integer) + 1
		if idx < 1 then set idx to 1
		set p to item idx of presets
		descLabel's setStringValue:(my presetDesc(p))
		if resetName then nameField's setStringValue:(item 5 of p)
	else
		set fsT to (fsPopup's titleOfSelectedItem()) as text
		set clT to (clPopup's titleOfSelectedItem()) as text
		set szT to (szPopup's titleOfSelectedItem()) as text
		set d to fsT & " · MBR · " & szT
		if fsT is "FAT32" then set d to d & (my tr("custom_cluster")) & clT
		if fsT is "FAT16" then set d to d & my tr("custom_fat16")
		if fsT is "exFAT" then set d to d & my tr("custom_exfat")
		descLabel's setStringValue:d
		if resetName and ((nameField's stringValue()) as text) is "" then nameField's setStringValue:"USB"
	end if
end applyMode

on settingsChanged:sender
	my applyMode(true)
end settingsChanged:

on loadDisks()
	if diskPopup is missing value then return
	set prevId to ""
	try
		if diskIds is not {} then set prevId to item (((diskPopup's indexOfSelectedItem()) as integer) + 1) of diskIds
	end try
	set raw to ""
	try
		set raw to do shell script (my resPath("usbformat.sh")) & " list"
	end try
	diskPopup's removeAllItems()
	set diskIds to {}
	set selIdx to 0
	repeat with ln in paragraphs of raw
		set AppleScript's text item delimiters to "|"
		set parts to text items of (ln as text)
		set AppleScript's text item delimiters to ""
		if (count of parts) ≥ 4 then
			set vols to ""
			if (count of parts) ≥ 5 then set vols to item 5 of parts
			if vols is "" then set vols to my tr("no_name")
			set end of diskIds to item 1 of parts
			if (item 1 of parts) is prevId then set selIdx to (count of diskIds) - 1
			(diskPopup's addItemWithTitle:("„" & vols & "“  –  " & (item 2 of parts) & ", " & (item 3 of parts) & "   (" & (item 1 of parts) & ")"))
		end if
	end repeat
	if diskIds is {} then
		diskPopup's addItemWithTitle:(my tr("no_usb"))
		formatBtn's setEnabled:false
		usbStatus's setStringValue:(my tr("only_external"))
	else
		diskPopup's selectItemAtIndex:selIdx
		formatBtn's setEnabled:(not isBusy)
		usbStatus's setStringValue:(my trf("disks_found", count of diskIds, ""))
	end if
end loadDisks

on refreshDisks:sender
	my loadDisks()
end refreshDisks:

on volumesChanged:aNotification
	if not isBusy then my loadDisks()
end volumesChanged:

on stepText(code, arg)
	if code is "check" then return my tr("st_check")
	if code is "unmount" then return my tr("st_unmount")
	if code is "partition" then return my tr("st_partition")
	if code is "cluster" then return my trf("st_cluster", arg, "")
	if code is "finish" then return my tr("st_finish")
	if code is "verify" then return my tr("st_verify")
	return code
end stepText

on failText(code, detail)
	if code is "bad_disk" then return my tr("err_bad_disk")
	if code is "not_external" then return my tr("err_not_external")
	if code is "system" then return my tr("err_system")
	if code is "fat32_2tb" then return my tr("err_fat32_2tb")
	if code is "ah_min" then return my tr("err_ah_min")
	if code is "fs" then return my tr("err_fs")
	return my trf("err_cmd", detail, "")
end failText

on formatClicked:sender
	if diskIds is {} then return
	set dId to item (((diskPopup's indexOfSelectedItem()) as integer) + 1) of diskIds
	set dTitle to (diskPopup's titleOfSelectedItem()) as text
	set nm to (nameField's stringValue()) as text
	if ((modeSeg's selectedSegment()) as integer) is 0 then
		set p to item (((presetPopup's indexOfSelectedItem()) as integer) + 1) of presets
		set fsArg to item 2 of p
		set clArg to item 3 of p
		set mxArg to item 4 of p
		set what to item 1 of p
		set tip to my presetTip(p)
	else
		set fi to ((fsPopup's indexOfSelectedItem()) as integer)
		set fsArg to item (fi + 1) of {"FAT32", "EXFAT", "FAT16"}
		set clArg to item (((clPopup's indexOfSelectedItem()) as integer) + 1) of {"0", "64"}
		set mxArg to item (((szPopup's indexOfSelectedItem()) as integer) + 1) of {"0", "32000000000", "16000000000", "2000000000"}
		set what to my trf("custom_what", (fsPopup's titleOfSelectedItem()) as text, "")
		set tip to my tr("custom_tip")
	end if
	try
		display alert (my tr("confirm_title")) message ((my tr("confirm_disk")) & dTitle & return & (my tr("confirm_format")) & what & return & (my tr("confirm_name")) & nm & return & return & (my tr("confirm_warn"))) as critical buttons {my tr("btn_cancel"), my tr("btn_erase")} default button (my tr("btn_cancel")) cancel button (my tr("btn_cancel"))
	on error
		return
	end try
	set isBusy to true
	formatBtn's setEnabled:false
	usbBar's setDoubleValue:0
	usbBar's setHidden:false
	usbStatus's setStringValue:(my tr("wait_pw"))
	my pump()
	set logPath to "/tmp/fohstick_" & (do shell script "date +%s") & ".log"
	do shell script "touch " & quoted form of logPath
	try
		do shell script ((my resPath("usbformat.sh")) & " format " & dId & " " & fsArg & " " & clArg & " " & mxArg & " " & quoted form of nm & " >> " & quoted form of logPath & " 2>&1 &") with prompt (my tr("pw_prompt")) with administrator privileges
	on error errMsg number errNum
		my endBusy()
		usbBar's setHidden:true
		if errNum is -128 then
			usbStatus's setStringValue:(my tr("cancelled"))
		else
			usbStatus's setStringValue:(my tr("not_started"))
			display alert (my tr("not_started")) message errMsg as warning
		end if
		return
	end try
	set finished to false
	set okRes to ""
	set failMsg to ""
	set t0 to current date
	repeat until finished
		(current application's NSRunLoop's currentRunLoop()'s runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.25))
		set logTxt to ""
		try
			set logTxt to do shell script "cat " & quoted form of logPath
		end try
		repeat with ln in paragraphs of logTxt
			set l to ln as text
			set AppleScript's text item delimiters to "|"
			set parts to text items of l
			set AppleScript's text item delimiters to ""
			if l starts with "STEP " and (count of parts) ≥ 2 then
				set n to (text 6 thru -1 of (item 1 of parts)) as integer
				set arg to ""
				if (count of parts) ≥ 3 then set arg to item 3 of parts
				usbBar's setDoubleValue:n
				usbStatus's setStringValue:(my trf("step_line", n, my stepText(item 2 of parts, arg)))
			else if l starts with "DONE|" and (count of parts) ≥ 4 then
				set finished to true
				set okRes to (item 2 of parts) & " · " & (item 3 of parts) & " · " & (item 4 of parts)
			else if l starts with "FAIL|" then
				set finished to true
				set fcode to ""
				set fdet to ""
				if (count of parts) ≥ 2 then set fcode to item 2 of parts
				if (count of parts) ≥ 3 then set fdet to item 3 of parts
				set failMsg to my failText(fcode, fdet)
			end if
		end repeat
		if not finished and ((current date) - t0) > 900 then
			set finished to true
			set failMsg to my tr("err_timeout")
		end if
	end repeat
	do shell script "rm -f " & quoted form of logPath
	my endBusy()
	if failMsg is not "" then
		usbBar's setHidden:true
		usbStatus's setStringValue:(my tr("fail_title"))
		display alert (my tr("fail_title")) message failMsg as warning
	else
		usbBar's setDoubleValue:4
		usbStatus's setStringValue:((my tr("done_title")) & "  " & okRes)
		display alert (my tr("done_title")) message ((my trf("done_text", what, "")) & return & okRes & return & return & tip)
		usbBar's setHidden:true
	end if
	my loadDisks()
end formatClicked:

on endBusy()
	set isBusy to false
	formatBtn's setEnabled:true
end endBusy

-- ================= Spoločné =================
on openWeb:sender
	do shell script "open https://fristik.eu"
end openWeb:

on openMail:sender
	do shell script "open mailto:apps@fristik.eu"
end openMail:

on cleanup()
	try
		current application's NSWorkspace's sharedWorkspace()'s notificationCenter()'s removeObserver:me
	end try
	set i18n to {}
	set theWindow to missing value
	set tabView to missing value
	set langPopup to missing value
	set themePopup to missing value
	set updateBtn to missing value
	set listView to missing value
	set chanSeg to missing value
	set bitsSeg to missing value
	set rateSeg to missing value
	set convStatus to missing value
	set convertBtn to missing value
	set convBar to missing value
	set theFiles to {}
	set diskPopup to missing value
	set modeSeg to missing value
	set presetLabel to missing value
	set presetPopup to missing value
	set fsLabel to missing value
	set fsPopup to missing value
	set clLabel to missing value
	set clPopup to missing value
	set szLabel to missing value
	set szPopup to missing value
	set descLabel to missing value
	set nameField to missing value
	set formatBtn to missing value
	set usbStatus to missing value
	set usbBar to missing value
	set isBusy to false
	set diskIds to {}
end cleanup

on windowWillClose:aNotification
	my cleanup()
	current application's NSApp's terminate:(missing value)
end windowWillClose:

on quit
	my cleanup()
	continue quit
end quit
