#!/system/bin/sh
# KL5 Smart FastCharge charger edge and safety watcher.
MODDIR="${0%/*}"
BACKEND="$MODDIR/charging_backend.sh"
STATE="/data/adb/kl5_fastcharge"
LOG="$STATE/charger-events.log"
CHARGER="/sys/class/power_supply/charger"
BATTERY="/sys/class/power_supply/battery"
mkdir -p "$STATE"; chmod 0755 "$STATE"
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }
readv() { [ -r "$1" ] && cat "$1" 2>/dev/null || echo ""; }
last=""
last_safety=""
while true; do
    online="$(readv "$CHARGER/online")"; [ -n "$online" ] || online=0
    raw="$(readv "$CHARGER/usb_type")"
    usb="$(printf '%s\n' "$raw" | sed -n 's/.*\[\([^]]*\)\].*/\1/p')"
    max="$(readv "$CHARGER/current_max")"
    sig="$online|$usb|$max"
    if [ "$sig" != "$last" ]; then
        if [ -n "$last" ]; then "$BACKEND" event disconnected >> "$LOG" 2>&1; fi
        if [ "$online" = 1 ]; then
            log "Charger connected/source changed: type=${usb:-unknown} negotiated_max=${max:-unknown}"
            "$BACKEND" event connected >> "$LOG" 2>&1
            cmd notification post -t "KL5 Smart FastCharge" "kl5_charge" "Charger connected: ${usb:-detecting}" >/dev/null 2>&1 || true
        else
            log "Charger disconnected"
            cmd notification post -t "KL5 Smart FastCharge" "kl5_charge" "Charger disconnected" >/dev/null 2>&1 || true
        fi
        last="$sig"
    fi

    if [ "$online" = 1 ]; then
        applied="$(cat "$STATE/applied_profile" 2>/dev/null)"
        if [ "$applied" = fast ] || [ "$applied" = fastest ]; then
            temp="$(readv "$BATTERY/temp")"; level="$(readv "$BATTERY/capacity")"
            case "$temp:$level" in *[!0-9:]*|:*) safety="unknown" ;; *)
                if [ "$temp" -ge 400 ] || [ "$level" -ge 90 ]; then safety="triggered"; else safety="clear"; fi ;;
            esac
            if [ "$safety" = triggered ] && [ "$last_safety" != triggered ]; then
                echo normal > "$STATE/profile"
                "$BACKEND" profile normal >> "$LOG" 2>&1
                log "Safety fallback to Normal: battery_temp=${temp}deciC battery_level=${level}%"
                cmd notification post -t "KL5 Smart FastCharge" "kl5_safety" "Fast profile suspended: battery temperature or charge level reached safety threshold." >/dev/null 2>&1 || true
            fi
            last_safety="$safety"
        else
            last_safety=""
        fi
    fi
    sleep 0.5
done
