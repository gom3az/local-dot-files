#!/bin/bash

if [[ -f /tmp/recording.info ]]; then
    IFS='|' read -r pid filepath < /tmp/recording.info
    rm -f /tmp/recording.info

    if kill -0 "$pid" 2>/dev/null; then
        kill -INT "$pid"
    fi

    notify-send "Recording saved" "${filepath:-"$HOME/Pictures/Screenshots"}"
else
    killall -INT wf-recorder 2>/dev/null
    notify-send "Recording saved"
fi
