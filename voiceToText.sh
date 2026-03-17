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
REC_PID=""

cleanup_rec() {
    if [ -n "$REC_PID" ] && kill -0 "$REC_PID" 2>/dev/null; then
        kill -INT "$REC_PID" 2>/dev/null
        wait "$REC_PID" 2>/dev/null
    fi
    REC_PID=""
}

trap 'cleanup_rec; exit' EXIT INT TERM

./key-listener | while read -r event; do
    if [ "$event" = "DOWN" ]; then
        cleanup_rec
        /opt/homebrew/bin/rec /tmp/recording.wav rate 16k channels 1 &
        REC_PID=$!
    elif [ "$event" = "UP" ]; then
        if [ -z "$REC_PID" ] || ! kill -0 "$REC_PID" 2>/dev/null; then
            continue
        fi
        kill -INT "$REC_PID"
        wait "$REC_PID" 2>/dev/null
        REC_PID=""
        TEXT=$(/opt/homebrew/bin/whisper-cli -m /opt/homebrew/share/whisper-cpp/ggml-base.en.bin \
            -f /tmp/recording.wav --no-timestamps -nt | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')
        if [ -z "$TEXT" ]; then
            continue
        fi
        printf "%s " "$TEXT" | pbcopy
        osascript -e 'tell application "System Events" to keystroke "v" using command down'
        TODAY="$HISTORY_DIR/$(date +%Y-%m-%d).md"
        echo -e "\n## $(date +%H:%M:%S)\n$TEXT" >> "$TODAY"
    fi
done
