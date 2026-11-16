
#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/kl5_fastcharge
LOGFILE=$LOGDIR/charging.log

# ==========================================
# KL5 SMART FASTCHARGE
# TECNO SPARK 30C
# SC8950 / MEDIATEK
# ==========================================

# Create log directory.
mkdir -p "$LOGDIR"

# Correct script permissions.
chmod 0755 "$MODDIR/service.sh"
chmod 0755 "$MODDIR/post-fs-data.sh"
chmod 0755 "$MODDIR"

# Root verification.
if [ "$(id -u)" != "0" ]; then
    exit 1
fi

# Ensure log directory permissions.
chmod 0755 "$LOGDIR"

log() {
    echo "[$(date)] $1" >> "$LOGFILE"
}

read_node() {
    if [ -r "$1" ]; then
        cat "$1" 2>/dev/null
    else
        echo "unavailable"
    fi
}

log "=========================================="
log "KL5 SMART FASTCHARGE STARTING"
log "=========================================="

# Wait for Android boot.
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 5
done

sleep 30

MODEL=$(getprop ro.product.model)

if [ "$MODEL" != "TECNO KL5" ]; then
    log "Unsupported device: $MODEL"
    exit 0
fi

if [ ! -d /sys/module/sc8950 ]; then
    log "SC8950 controller not detected."
    exit 0
fi

log "TECNO KL5 verified."
log "SC8950 controller detected."

# Continuous monitoring.
while true; do

    CHARGER=/sys/class/power_supply/charger
    BATTERY=/sys/class/power_supply/battery

    MASTER=/sys/class/power_supply/mtk-master-charger

    ONLINE=$(read_node "$CHARGER/online")
    STATUS=$(read_node "$BATTERY/status")
    LEVEL=$(read_node "$BATTERY/capacity")
    TEMP=$(read_node "$BATTERY/temp")
    VOLTAGE=$(read_node "$BATTERY/voltage_now")
    CURRENT=$(read_node "$BATTERY/current_now")

    INPUT_LIMIT=$(read_node "$CHARGER/input_current_limit")
    CHARGE_LIMIT=$(read_node "$CHARGER/constant_charge_current")

    USB_TYPE=$(read_node "$CHARGER/usb_type")

    SCREEN=$(dumpsys power 2>/dev/null |
        grep -m1 'mWakefulness=')

    log "------------------------------------------"
    log "Screen state: $SCREEN"
    log "Charger online: $ONLINE"
    log "Charging status: $STATUS"
    log "Battery level: $LEVEL%"
    log "Battery temperature: $TEMP"
    log "Battery voltage: $VOLTAGE"
    log "Battery current: $CURRENT"
    log "USB type: $USB_TYPE"
    log "Input current limit: $INPUT_LIMIT"
    log "Charge current limit: $CHARGE_LIMIT"

    if [ "$ONLINE" = "1" ]; then
        log "External power detected."

        if [ "$STATUS" = "Charging" ]; then
            log "Charging active."
        elif [ "$STATUS" = "Full" ]; then
            log "Battery full. Controller managing charging."
        else
            log "Charging controller managing current state."
        fi
    else
        log "Charger disconnected."
    fi

    # Confirm controller remains loaded.
    if [ ! -d /sys/module/sc8950 ]; then
        log "WARNING: SC8950 driver unavailable."
    fi

    # Do not override controller limits.
    # Do not disable thermal protections.
    # Do not force charging while disconnected.

    sleep 60

done
