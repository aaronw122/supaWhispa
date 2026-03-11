#!/bin/bash
##listen for key click
#
# on click, record wav file
# on release:
# take transcription
# paste wherever the cursor is
# add into transcripts for that day
#

HISTORY_DIR="$HOME/.voice-history"

./key-listener | while read -r event; do
    if [ "$event" = "DOWN" ]; then
        /opt/homebrew/bin/rec /tmp/recording.wav rate 16k channels 1 &
        REC_PID=$!
    elif [ "$event" = "UP" ]; then
        kill $REC_PID
        TEXT=$(/opt/homebrew/bin/whisper-cli -m /opt/homebrew/share/whisper-cpp/ggml-base.en.bin \
            -f /tmp/recording.wav --no-timestamps -nt | xargs)
        if [ -z "$TEXT" ]; then
            continue
        fi
        printf "%s " "$TEXT" | pbcopy
        osascript -e 'tell application "System Events" to keystroke "v" using command down'
        TODAY="$HISTORY_DIR/$(date +%Y-%m-%d).md"
        echo -e "\n## $(date +%H:%M:%S)\n$TEXT" >> "$TODAY"
    fi
done
