#!/usr/bin/env python3
"""FOHstick build generator – (c) 2026 fristik.eu

Fills the source templates with texts (src/strings.tsv), the built-in console
list (data/consoles.json), icons and the version number.

  python3 build/gen.py [version]

Output:
  build/out/mac/   app.applescript, conv.sh, usbformat.sh, icon.png, fristik.png
  build/out/win/   FOHstick.ps1, FOHstick.cmd, fohstick.ico, launcher.cs
"""
import base64, io, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def p(*a): return os.path.join(ROOT, *a)
def read(*a): return open(p(*a), encoding='utf-8').read()

version = sys.argv[1] if len(sys.argv) > 1 else json.load(open(p('data', 'version.json'), encoding='utf-8'))['latest']
version = version.lstrip('v')

# ---------- texty ----------
rows = [l.rstrip('\n').split('\t') for l in read('src', 'strings.tsv').splitlines()[1:] if l.strip()]
for r in rows:
    assert len(r) == 3, r
consoles = json.load(open(p('data', 'consoles.json'), encoding='utf-8'))['consoles']

def asq(s):  # AppleScript string literal
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
def psq(s):  # PowerShell single-quoted literal
    return "'" + s.replace("'", "''") + "'"

# ---------- Mac ----------
os.makedirs(p('build', 'out', 'mac'), exist_ok=True)
l10n_as = '{¬\n' + ', ¬\n'.join('\t{%s, %s, %s}' % (asq(k), asq(sk), asq(en)) for k, sk, en in rows) + '}'
pres_as = '{¬\n' + ', ¬\n'.join('\t{%s}' % ', '.join(asq(str(x)) for x in (
    c['name'], c['fs'], c['cluster'], c['max'], c['label'], c['desc_sk'], c['desc_en'], c['tip_sk'], c['tip_en']))
    for c in consoles) + '}'
app = read('src', 'mac', 'app.applescript')
app = app.replace('@@VERSION@@', version).replace('@@L10N@@', l10n_as).replace('@@PRESETS@@', pres_as)
assert '@@' not in app
open(p('build', 'out', 'mac', 'app.applescript'), 'w', encoding='utf-8').write(app)
for f in ('conv.sh', 'usbformat.sh'):
    open(p('build', 'out', 'mac', f), 'w', encoding='utf-8', newline='\n').write(read('src', 'mac', f))
open(p('build', 'out', 'mac', 'icon.png'), 'wb').write(open(p('assets', 'icon.png'), 'rb').read())
open(p('build', 'out', 'mac', 'fristik.png'), 'wb').write(open(p('assets', 'fristik-logo.png'), 'rb').read())

# ---------- Windows ----------
os.makedirs(p('build', 'out', 'win'), exist_ok=True)
try:
    from PIL import Image
    Image.open(p('assets', 'icon.png')).save(p('build', 'out', 'win', 'fohstick.ico'),
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    ico = open(p('build', 'out', 'win', 'fohstick.ico'), 'rb').read()
except ImportError:
    ico = open(p('assets', 'fohstick.ico'), 'rb').read()
    open(p('build', 'out', 'win', 'fohstick.ico'), 'wb').write(ico)

l10n_ps = '@{\n' + '\n'.join('    %s = @(%s, %s)' % (psq(k), psq(sk), psq(en)) for k, sk, en in rows) + '\n}'
cons_json = json.dumps({'schema': 1, 'consoles': consoles}, ensure_ascii=False, indent=1)
fat = read('src', 'win', 'fat32.cs').strip('\n')
assert '$' not in fat
usb = read('src', 'win', 'usbchild.ps1').replace('FAT32_CS', fat)
conv = read('src', 'win', 'convert.ps1')
for name, part in (('consoles', cons_json), ('usbchild', usb)):
    assert "\n'@" not in part and not part.startswith("'@"), name
main = read('src', 'win', 'main.ps1')
main = (main.replace('@@VERSION@@', version).replace('@@L10N@@', l10n_ps)
            .replace('@@CONSOLES@@', cons_json).replace('@@CONVERT@@', conv).replace('@@USBCHILD@@', usb)
            .replace('@@ICON@@', base64.b64encode(ico).decode())
            .replace('@@LOGO@@', base64.b64encode(open(p('assets', 'fristik-logo-win.png'), 'rb').read()).decode()))
assert '@@' not in main
ps1 = main.replace('\r\n', '\n').replace('\n', '\r\n')
open(p('build', 'out', 'win', 'FOHstick.ps1'), 'w', encoding='utf-8-sig', newline='').write(ps1)

header = ('<# :\r\n@echo off\r\nset "K48=%~f0"\r\n'
          'start "" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden '
          '-Command "iex ([IO.File]::ReadAllText($env:K48))"\r\nexit /b\r\n#>\r\n')
open(p('build', 'out', 'win', 'FOHstick.cmd'), 'w', encoding='utf-8', newline='').write(header + ps1)
open(p('build', 'out', 'win', 'launcher.cs'), 'w', encoding='utf-8').write(
    read('build', 'launcher.cs').replace('@@VERSION@@', version))
print('FOHstick', version, '– build/out ready')
