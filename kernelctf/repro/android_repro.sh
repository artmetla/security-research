#!/bin/bash
set -e

TRY_ID="$1"
RELEASE_PATH="$2"
EXPLOIT_PATH="$3"
APK_PATH="$4"
STDOUT_TIMEOUT=240
CUTTLEFISH_TXT=cuttlefish_$TRY_ID.txt

FLAG="kernelCTF{$(uuidgen)}"
echo $FLAG > flag_$TRY_ID

STOP_MARKER=$(uuidgen)
echo "::stop-commands::$STOP_MARKER"

touch $CUTTLEFISH_TXT

START_TIME=$(date +%s)

echo "[REPRO $TRY_ID] Starting Cuttlefish with exploit..."
echo "[REPRO $TRY_ID] Release path: $RELEASE_PATH"
echo "[REPRO $TRY_ID] Exploit path: $EXPLOIT_PATH"
echo "[REPRO $TRY_ID] APK path: $APK_PATH"
echo "[REPRO $TRY_ID] Flag file: flag_$TRY_ID"

# Run cuttlefish.sh with correct groups using sg command
# Note: We need to nest sg commands to activate all three groups (kvm, cvdnetwork, render)
sg kvm -c "sg cvdnetwork -c 'sg render -c \"timeout ${STDOUT_TIMEOUT}s bash ./cuttlefish.sh --release_path=$RELEASE_PATH --bin_path=$EXPLOIT_PATH --flag_path=flag_$TRY_ID --apk_path=$APK_PATH\"'" 2>&1 | tee $CUTTLEFISH_TXT &
CUTTLEFISH_PID="$!"

echo "[REPRO $TRY_ID] Cuttlefish PID: $CUTTLEFISH_PID"

# Wait for Cuttlefish to complete or timeout
wait $CUTTLEFISH_PID
CUTTLEFISH_EXIT=$?

echo "[REPRO $TRY_ID] Cuttlefish exited with code: $CUTTLEFISH_EXIT"

echo "::$STOP_MARKER::"

# Copy log to repro_log file
cp $CUTTLEFISH_TXT repro_log_$TRY_ID.txt

# Calculate run time
RUN_TIME=$(expr $(date +%s) - $START_TIME)
echo "RUN_TIME=$RUN_TIME" >> "$GITHUB_OUTPUT"
echo "[REPRO $TRY_ID] Run time: ${RUN_TIME}s"

# Check if we got the flag
if grep -q "$FLAG" $CUTTLEFISH_TXT; then
    echo "[REPRO $TRY_ID] Got the flag! Congrats!"
    exit 0
else
    echo "[REPRO $TRY_ID] Failed, did not get the flag."
    
    # Provide some debugging info
    if [ $CUTTLEFISH_EXIT -eq 124 ]; then
        echo "[REPRO $TRY_ID] Timeout: Cuttlefish did not complete within ${STDOUT_TIMEOUT}s"
    elif [ $CUTTLEFISH_EXIT -ne 0 ]; then
        echo "[REPRO $TRY_ID] Cuttlefish failed with exit code: $CUTTLEFISH_EXIT"
    fi
    
    exit 1
fi
