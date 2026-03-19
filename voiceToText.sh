#!/bin/bash
##listen for key click
#
# on click, record wav file
# on release:
# take transcription
# paste wherever the cursor is
# add into transcripts for that day
#

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
HISTORY_DIR="$HOME/.voice-history"
LOG_FILE="$SCRIPT_DIR/logs/voiceToText.err"
REC_PID=""
CURRENT_WAV=""

mkdir -p "$HISTORY_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

# Truncate error log if it exceeds 1MB
if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    tail -c 524288 "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
fi

kill_rec() {
    local pid="$1"
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    kill -INT "$pid" 2>/dev/null
    for i in 1 2 3 4; do
        sleep 0.5
        kill -0 "$pid" 2>/dev/null || return 0
    done
    kill -TERM "$pid" 2>/dev/null
    for i in 1 2; do
        sleep 0.5
        kill -0 "$pid" 2>/dev/null || return 0
    done
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
}

cleanup_rec() {
    if [ -n "$REC_PID" ]; then
        kill_rec "$REC_PID"
        REC_PID=""
    fi
    if [ -n "$CURRENT_WAV" ] && [ -f "$CURRENT_WAV" ]; then
        rm -f "$CURRENT_WAV"
        CURRENT_WAV=""
    fi
}

transcribe_and_paste() {
    local wav_file="$1"
    local text
    text=$(/opt/homebrew/bin/whisper-cli -m /opt/homebrew/share/whisper-cpp/ggml-base.en.bin \
        -f "$wav_file" --no-timestamps -nt 2>>"$LOG_FILE" | tr -s '[:space:]' ' ' | sed 's/^ //;s/ $//')
    rm -f "$wav_file"
    if [ -z "$text" ]; then
        return
    fi
    printf "%s " "$text" | pbcopy
    osascript -e 'tell application "System Events" to keystroke "v" using command down'
    local today="$HISTORY_DIR/$(date +%Y-%m-%d).md"
    echo -e "\n## $(date +%H:%M:%S)\n$text" >> "$today"
}

trap 'cleanup_rec; exit' EXIT INT TERM

while read -r event; do
    if [ "$event" = "DOWN" ]; then
        cleanup_rec
        CURRENT_WAV=$(mktemp /tmp/voice-rec-XXXXXX.wav)
        /opt/homebrew/bin/rec "$CURRENT_WAV" rate 16k channels 1 2>>"$LOG_FILE" &
        REC_PID=$!

    elif [ "$event" = "UP" ]; then
        if [ -z "$REC_PID" ] || ! kill -0 "$REC_PID" 2>/dev/null; then
            continue
        fi
        local_pid="$REC_PID"
        local_wav="$CURRENT_WAV"
        REC_PID=""
        CURRENT_WAV=""
        kill_rec "$local_pid"
        wait "$local_pid" 2>/dev/null
        transcribe_and_paste "$local_wav" &
    fi
done < <("$SCRIPT_DIR/key-listener")
