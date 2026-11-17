#!/system/bin/sh
# KL5 Smart FastCharge Control Center backend.
# All writes are allow-listed. Charging controller sysfs nodes are NEVER written.

DATA=/data/adb/kl5_fastcharge
CFG="$DATA/config.conf"
LOG="$DATA/control.log"
mkdir -p "$DATA"
chmod 0700 "$DATA"

logmsg() {
    echo "[$(date '+%F %T' 2>/dev/null)] $*" >> "$LOG"
}

getcfg() {
    KEY="$1"
    DEFAULT="$2"
    VALUE="$(grep -m1 "^${KEY}=" "$CFG" 2>/dev/null | cut -d= -f2-)"
    [ -n "$VALUE" ] && printf '%s' "$VALUE" || printf '%s' "$DEFAULT"
}

setcfg() {
    KEY="$1"
    VALUE="$2"
    TMP="$CFG.tmp"
    touch "$CFG"
    grep -v "^${KEY}=" "$CFG" > "$TMP" 2>/dev/null
    printf '%s=%s\n' "$KEY" "$VALUE" >> "$TMP"
    mv "$TMP" "$CFG"
    chmod 0600 "$CFG"
}

readnode() {
    [ -r "$1" ] && cat "$1" 2>/dev/null | head -n 1 || printf 'n/a'
}

case "$1" in
    status)
        B=/sys/class/power_supply/battery
        C=/sys/class/power_supply/charger
        M=/sys/class/power_supply/mtk-master-charger
        ONLINE="$(readnode "$C/online")"
        [ "$ONLINE" = "n/a" ] && ONLINE="$(readnode "$M/online")"
        [ "$ONLINE" = "n/a" ] && ONLINE="$(readnode "$B/online")"
        [ "$ONLINE" = "1" ] || ONLINE="0"
        USB="$(readnode "$C/usb_type" | tr ' ' '_')"
        [ -d /sys/module/sc8950 ] && SC8950="yes" || SC8950="no"
        BRIGHT="$(settings get system screen_brightness 2>/dev/null)"
        MODE="$(settings get system screen_brightness_mode 2>/dev/null)"
        MAXBL="n/a"
        for f in /sys/class/backlight/*/max_brightness; do
            [ -r "$f" ] && MAXBL="$(cat "$f" 2>/dev/null)" && break
        done
        [ -n "$BRIGHT" ] || BRIGHT="n/a"
        [ -n "$MODE" ] || MODE="n/a"
        printf 'MODEL=%s\n' "$(getprop ro.product.model)"
        printf 'ANDROID=%s\n' "$(getprop ro.build.version.release)"
        printf 'BUILD=%s\n' "$(getprop ro.build.display.id)"
        printf 'LEVEL=%s\n' "$(readnode "$B/capacity")"
        printf 'STATUS=%s\n' "$(readnode "$B/status")"
        printf 'TEMP=%s\n' "$(readnode "$B/temp")"
        printf 'VOLTAGE=%s\n' "$(readnode "$B/voltage_now")"
        printf 'CURRENT=%s\n' "$(readnode "$B/current_now")"
        printf 'ONLINE=%s\n' "$ONLINE"
        printf 'USB=%s\n' "$USB"
        printf 'SC8950=%s\n' "$SC8950"
        printf 'INPUT_LIMIT=%s\n' "$(readnode "$C/input_current_limit")"
        printf 'CHARGE_LIMIT=%s\n' "$(readnode "$C/constant_charge_current")"
        printf 'BRIGHTNESS=%s\n' "$BRIGHT"
        printf 'BRIGHTNESS_MODE=%s\n' "$MODE"
        printf 'BACKLIGHT_MAX=%s\n' "$MAXBL"
        printf 'PROFILE=%s\n' "$(getcfg profile normal)"
        printf 'CHARGE_ALERT=%s\n' "$(getcfg charge_alert 80)"
        printf 'TEMP_ALERT=%s\n' "$(getcfg temp_alert 42)"
        printf 'PROFILE_NOTE=Preference_only_no_kernel_limit_changed\n'
        ;;
    profile)
        case "$2" in
            normal|fast|fastest|adaptive) setcfg profile "$2" ;;
            *) echo "ERROR=Invalid_profile"; exit 2 ;;
        esac
        logmsg "Profile preference set to $2; no charging sysfs values changed."
        echo "OK=Profile preference saved: $2"
        echo "NOTICE=This selection does not force charging current or voltage."
        ;;
    brightness)
        case "$2" in
            ''|*[!0-9]*) echo "ERROR=Brightness_must_be_1_to_255"; exit 2 ;;
        esac
        [ "$2" -ge 1 ] && [ "$2" -le 255 ] || { echo "ERROR=Brightness_must_be_1_to_255"; exit 2; }
        settings put system screen_brightness_mode 0 >/dev/null 2>&1 || {
            echo "ERROR=Could_not_switch_to_manual_brightness"; exit 1;
        }
        settings put system screen_brightness "$2" >/dev/null 2>&1 || {
            echo "ERROR=Could_not_set_brightness"; exit 1;
        }
        ACTUAL="$(settings get system screen_brightness 2>/dev/null)"
        logmsg "Manual screen brightness requested=$2 readback=$ACTUAL"
        echo "OK=Manual brightness set"
        echo "BRIGHTNESS=$ACTUAL"
        ;;
    brightness-auto)
        settings put system screen_brightness_mode 1 >/dev/null 2>&1 || {
            echo "ERROR=Could_not_enable_automatic_brightness"; exit 1;
        }
        logmsg "Automatic brightness restored by user."
        echo "OK=Automatic brightness enabled"
        ;;
    charge-alert)
        case "$2" in ''|*[!0-9]*) echo "ERROR=Invalid_percentage"; exit 2 ;; esac
        [ "$2" -ge 50 ] && [ "$2" -le 100 ] || { echo "ERROR=Use_50_to_100"; exit 2; }
        setcfg charge_alert "$2"
        logmsg "Charge alert reference set to $2 percent."
        echo "OK=Charge alert reference saved"
        echo "NOTICE=Reference only; does not stop charging."
        ;;
    temp-alert)
        case "$2" in ''|*[!0-9]*) echo "ERROR=Invalid_temperature"; exit 2 ;; esac
        [ "$2" -ge 35 ] && [ "$2" -le 50 ] || { echo "ERROR=Use_35_to_50_C"; exit 2; }
        setcfg temp_alert "$2"
        logmsg "Temperature alert reference set to $2 C."
        echo "OK=Temperature alert reference saved"
        echo "NOTICE=Reference only; stock thermal control remains in charge."
        ;;
    report)
        OUT="$DATA/diagnostic-report.txt"
        {
            echo "KL5 SMART FASTCHARGE CONTROL CENTER - DIAGNOSTIC REPORT"
            echo "Generated: $(date)"
            echo "Developer: Richard Musya"
            echo "Model: $(getprop ro.product.model)"
            echo "Android: $(getprop ro.build.version.release)"
            echo "Fingerprint: $(getprop ro.build.fingerprint)"
            echo
            for d in /sys/class/power_supply/*; do
                [ -d "$d" ] || continue
                echo "[$d]"
                for n in online status capacity temp voltage_now current_now input_current_limit constant_charge_current constant_charge_voltage usb_type; do
                    [ -r "$d/$n" ] && echo "$n=$(cat "$d/$n" 2>/dev/null | tr '\n' ' ')"
                done
            done
            echo
            echo "[Backlight]"
            for f in /sys/class/backlight/*/brightness /sys/class/backlight/*/actual_brightness /sys/class/backlight/*/max_brightness; do
                [ -r "$f" ] && echo "$f=$(cat "$f" 2>/dev/null)"
            done
            echo
            echo "[Saved preferences]"
            cat "$CFG" 2>/dev/null
            echo
            echo "[Recent module log]"
            tail -n 80 "$LOG" 2>/dev/null
        } > "$OUT"
        chmod 0600 "$OUT"
        echo "OK=Report_created"
        echo "PATH=$OUT"
        logmsg "Diagnostic report generated."
        ;;
    logs)
        tail -n 100 "$LOG" 2>/dev/null
        ;;
    *)
        echo "ERROR=Unknown_command"
        echo "USAGE=status|profile|brightness|brightness-auto|charge-alert|temp-alert|report|logs"
        exit 2
        ;;
esac
