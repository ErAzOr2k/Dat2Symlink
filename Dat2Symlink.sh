#!/bin/bash

#
##
## Pid Lock...
##
#
PIDFILE="/tmp/dat2symlink.pid"

if [ -f "$PIDFILE" ]; then
  PID=$(cat "$PIDFILE")
  ps -p "$PID" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "Process already running"
    exit 1
  else
    ## Process not found assume not running
    echo $$ > "$PIDFILE"
    if [ $? -ne 0 ]; then
      echo "Could not create PID file"
      exit 1
    fi
  fi
else
  echo $$ > "$PIDFILE"
  if [ $? -ne 0 ]; then
    echo "Could not create PID file"
    exit 1
  fi
fi

function finish {
  echo "Script terminating. Exit code $?"
  finished=true
  killall zenity 2>/dev/null
  rm "$PIDFILE"
  rm "$PROGRESS"
}
trap finish EXIT

PROGRESS="/tmp/dat2symlink.log"

finished=false
echo "0" > "$PROGRESS"

(
  while [ $finished == false ]
  do
    cat "$PROGRESS"
    if grep -q "100" "$PROGRESS"; then
      finished=true
      break
    fi
  done
)  |  zenity --progress \
             --title="Symlink..." \
             --percentage=0 \
	     --time-remaining \
             --no-cancel \
             --pulsate \
             --auto-close \
             --width=300  2>/dev/null &

if [ "$?" == -1 ] ; then
  zenity --error \
         --text="Canceled." 2>/dev/null
fi

dat=$(zenity \
--file-selection \
--title="Select a Dat File" 2>/dev/null)
res=$?
if [ $res -ne 0 ]; then
  echo "No Dat file selected"
  exit
fi

count=$(xmlstarlet sel -t -c "count(//datafile/game)" "$dat" 2>/dev/null)
res=$?
if [ $res -ne 0 ]; then
  echo "No valid dat selected"
  exit
fi

romsource=$(zenity \
--file-selection \
--directory \
--title="Select roms source folder" 2>/dev/null)
res=$?
if [ $res -ne 0 ]; then
  echo "No roms source folder selected"
  exit
fi

romtarget=$(zenity \
--file-selection \
--directory \
--title="Select roms target folder" 2>/dev/null)
res=$?
if [ $res -ne 0 ]; then
  echo "No roms target folder selected"
  exit
fi

rm $romtarget/*

i=0
xmlstarlet sel -t -v "//datafile/game/@name" -nl "$dat" | while IFS= read -r game; do            
  file=$(find "$romsource" -type f -name "$game.*")
  if [ -n "$file" ]; then
    filename=$(basename "$file")

    if ln -sf "$file" "$romtarget"/"$filename"; then
	  echo "[OK]       $game"
    else
      echo "[ERROR]    $game"
    fi
  else
    echo "[NOTFOUND] $game"
  fi

  i=$((i+1))
  percentage=$(( $i * 100 / $count ))

  echo "$percentage" > "$PROGRESS"
  echo "# $percentage%" >> "$PROGRESS"
done
