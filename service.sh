#!/system/bin/sh
MODDIR=${0%/*}
DATA=/data/adb/kl5_fastcharge
LOG="$DATA/boot.log"

mkdir -p "$DATA"
chmod 0700 "$DATA"

# Wait briefly for Android framework boot completion; never block boot.
COUNT=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$COUNT" -lt 36 ]; do
    sleep 5
    COUNT=$((COUNT + 1))
done

STAMP="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
MODEL="$(getprop ro.product.model)"
BUILD="$(getprop ro.build.display.id)"

{
    echo "=============================================="
    echo "KL5 SMART FASTCHARGE CONTROL CENTER"
    echo "Welcome back. Your device is starting safely."
    echo "Developer: Richard Musya"
    echo "GitHub: https://github.com/RichardMusya"
    echo "Time: $STAMP"
    echo "Model: $MODEL"
    echo "Build: $BUILD"
    echo "Charging policy: stock hardware limits preserved"
    echo "=============================================="
} >> "$LOG"

log -t KL5SmartFastCharge "Welcome. KL5 Smart FastCharge by Richard Musya is ready."

# Start the 500 ms charger edge/safety watcher without blocking Android boot.
WATCH_PID="$DATA/charger-watch.pid"
if [ -x "$MODDIR/charger-watch.sh" ]; then
    if [ -f "$WATCH_PID" ] && kill -0 "$(cat "$WATCH_PID" 2>/dev/null)" 2>/dev/null; then
        : # Existing watcher is already running.
    else
        nohup "$MODDIR/charger-watch.sh" >/dev/null 2>&1 &
        echo $! > "$WATCH_PID"
    fi
fi

# Android 16/AOSP notification shell command. Failure is harmless on ROMs
# that remove or restrict this command.
if command -v cmd >/dev/null 2>&1; then
    cmd notification post -t "KL5 Smart FastCharge" \
        "kl5_boot" \
        "Welcome! Control Center is ready. Developer: Richard Musya | github.com/RichardMusya" \
        >/dev/null 2>&1
fi

exit 0
