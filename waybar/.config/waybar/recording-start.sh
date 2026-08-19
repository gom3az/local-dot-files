#!/bin/bash

audio=false
geometry=""
filepath=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--audio)
            audio=true
            shift
            ;;
        -g|--geometry)
            geometry="$2"
            shift 2
            ;;
        *)
            filepath="$1"
            shift
            ;;
    esac
done

if [[ -z "$filepath" ]]; then
    notify-send "Recording error" "No file path specified"
    exit 1
fi

if pgrep -x wf-recorder > /dev/null; then
    notify-send "Recording error" "A recording is already in progress"
    exit 1
fi

cmd=(wf-recorder -c av1_vaapi -r 30 -p b=5M -p maxrate=5M)

[[ -n "$geometry" ]] && cmd+=(-g "$geometry")
$audio && cmd+=(--audio-backend=pipewire -a)

cmd+=(-f "$filepath")

mkdir -p "$(dirname "$filepath")"

"${cmd[@]}" &
pid=$!
disown "$pid"

echo "$pid|$filepath" > /tmp/recording.info
notify-send "Recording started" "$filepath"
