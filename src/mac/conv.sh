#!/bin/bash
ch="$1"; bits="$2"; rate="$3"; f="$4"
case "$rate" in 44100) suf="_44k1" ;; 96000) suf="_96k" ;; *) rate=48000; suf="_48k" ;; esac
b="${f%.*}"; o="${b}${suf}.wav"; n=2
while [ -e "$o" ]; do o="${b}${suf}_${n}.wav"; n=$((n+1)); done
fmt="LEI${bits}@${rate}"
if /usr/bin/afconvert -f WAVE -d "$fmt" -c "$ch" --mix --src-complexity bats -r 127 "$f" "$o" 2>/dev/null \
 || /usr/bin/afconvert -f WAVE -d "$fmt" -c "$ch" --mix "$f" "$o" 2>/dev/null \
 || /usr/bin/afconvert -f WAVE -d "$fmt" -c "$ch" "$f" "$o"; then
  echo "$o"
else
  rm -f "$o"; exit 1
fi
