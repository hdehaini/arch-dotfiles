#!/bin/bash

emit() {
  date '+{"time":"%-I:%M %p","hour":"%H","hour12":"%-I","ampm":"%p","minute":"%M","month":"%B","month_short":"%b","year":"%Y","day":"%d","day_name":"%A","day_short":"%a"}'
}

# Emit sekali langsung di awal
emit

# Sleep sampai detik ke-0 menit berikutnya
sleep $(( 60 - $(date +%S) ))

# Loop tiap menit tepat
while true; do
  emit
  sleep 60
done
