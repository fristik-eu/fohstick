#!/bin/bash
# FOHstick helper (c) 2026 fristik.eu: "list" | "format <disk> <fs> <clusterSektory> <maxBajtov> <nazov>"
set -u
PATH=/usr/sbin:/usr/bin:/sbin:/bin
die() { echo "FAIL|$1|$(printf '%s' "${2:-}" | tr '\n|' '  ')"; exit 1; }
step() { echo "STEP $1|$2|${3:-}"; }
run() { local out; out=$("$@" 2>&1 </dev/null) || die cmd "$(printf '%s\n' "$out" | tail -4)"; }
field() { awk -F': +' -v k="$1" '$1 ~ k {print $2; exit}'; }

list_disks() {
  for d in $(diskutil list external physical 2>/dev/null </dev/null | awk '/^\/dev\/disk[0-9]+ /{print $1}'); do
    info=$(diskutil info "$d" 2>/dev/null </dev/null)
    name=$(printf '%s\n' "$info" | field 'Device / Media Name')
    size=$(printf '%s\n' "$info" | field 'Disk Size' | sed 's/ (.*//')
    proto=$(printf '%s\n' "$info" | field 'Protocol')
    id="${d#/dev/}"
    vols=$(for p in $(diskutil list "$d" 2>/dev/null </dev/null | awk '{print $NF}' | grep -E "^${id}s[0-9]+$"); do
      v=$(diskutil info "$p" 2>/dev/null </dev/null | field 'Volume Name')
      if [ -n "$v" ] && [ "$v" != "EFI" ] && [ "${v#Not applicable}" = "$v" ]; then printf '%s\n' "$v"; fi
    done | paste -sd, - | sed 's/,/, /g')
    echo "${id}|${name:-Neznámy disk}|${size:-?}|${proto:-?}|${vols}"
  done
}
disk_bytes() { diskutil info "$1" </dev/null | sed -nE 's/.*Disk Size:.*\(([0-9]+) Bytes\).*/\1/p' | head -1; }

if [ "${1:-}" = "list" ]; then list_disks; exit 0; fi
[ "${1:-}" = "format" ] || die cmd "unknown command"

disk="${2:-}"; fs="${3:-}"; cl="${4:-0}"; max="${5:-0}"; raw="${6:-}"
[[ "$disk" =~ ^disk[0-9]+$ ]] || die bad_disk
[[ "$cl" =~ ^[0-9]+$ ]] && [ "$cl" -le 128 ] || die cmd "bad cluster"
[[ "$max" =~ ^[0-9]+$ ]] || die cmd "bad size"
diskutil list external physical </dev/null | grep -q "^/dev/$disk " || die not_external "$disk"
boot=$(diskutil info / </dev/null | field 'Part of Whole')
[ "$boot" = "$disk" ] && die system

NAME=$(printf '%s' "$raw" | tr '[:lower:]' '[:upper:]' | LC_ALL=C tr -cd 'A-Z0-9_' | cut -c1-11)
[ -z "$NAME" ] && NAME="USB"

step 0 check
b=$(disk_bytes "/dev/$disk"); b=${b:-0}
TB2=2199023255552

if [ "$fs" = "AUTOX" ]; then
  if [ "$b" -gt "$TB2" ]; then fs=EXFAT; else fs=FAT32; fi
elif [ "$fs" = "AUTO16" ]; then
  if [ "$b" -le 2200000000 ]; then fs=FAT16; else fs=FAT32; fi
fi
if [ "$fs" = "FAT16" ] && [ "$b" -gt 2200000000 ] && { [ "$max" -eq 0 ] || [ "$max" -gt 2000000000 ]; }; then max=2000000000; fi

part=0
if [ "$max" -gt 0 ] && [ "$b" -gt $((max / 10 * 11)) ]; then part=$max; fi
eff=$b; [ "$part" -gt 0 ] && eff=$part
if [ "$fs" = "FAT32" ] && [ "$eff" -gt "$TB2" ]; then die fat32_2tb; fi
if [ "$cl" -eq 64 ] && [ "$b" -lt 2000000000 ]; then die ah_min; fi

case "$fs" in
  FAT32) dfs="FAT32" ;;
  FAT16) dfs="MS-DOS FAT16" ;;
  EXFAT) dfs="ExFAT" ;;
  *) die fs ;;
esac

step 1 unmount
run diskutil unmountDisk force "/dev/$disk"
step 2 partition
scheme=MBR
if [ "$fs" = "EXFAT" ] && [ "$eff" -gt "$TB2" ]; then scheme=GPT; fi
if [ "$part" -gt 0 ]; then
  run diskutil partitionDisk "/dev/$disk" 2 "$scheme" "$dfs" "$NAME" "${part}B" "Free Space" FREE R
else
  run diskutil partitionDisk "/dev/$disk" 1 "$scheme" "$dfs" "$NAME" 100%
fi
if [ "$fs" = "FAT32" ] && [ "$cl" -gt 0 ]; then
  step 3 cluster "$((cl / 2))"
  run diskutil unmount force "/dev/${disk}s1"
  run newfs_msdos -F 32 -c "$cl" -v "$NAME" "/dev/r${disk}s1"
  diskutil mount "/dev/${disk}s1" >/dev/null 2>&1 </dev/null || true
else
  step 3 finish
fi
step 4 verify
sleep 1
pfs=$(diskutil info "/dev/${disk}s1" 2>/dev/null </dev/null | field 'File System Personality')
psz=$(diskutil info "/dev/${disk}s1" 2>/dev/null </dev/null | field 'Disk Size' | sed 's/ (.*//')
echo "DONE|$NAME|${pfs:-$fs}|${psz:-?}"
