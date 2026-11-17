#!/system/bin/sh
# KL5 Smart FastCharge v2.0.1 guarded SGM41516D backend
# Copyright (c) 2026 Richard Musya. All rights reserved.
# No raw I2C access, register pokes, thermal bypass, or source spoofing.

MODDIR="${0%/*}"
STATE="/data/adb/kl5_fastcharge"
LOG="$STATE/profile-engine.log"
CHARGER="/sys/class/power_supply/charger"
BATTERY="/sys/class/power_supply/battery"
MASTER="/sys/class/power_supply/mtk-master-charger"
mkdir -p "$STATE"; chmod 0755 "$STATE"
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }
readv() { [ -r "$1" ] && cat "$1" 2>/dev/null || echo ""; }
num() { case "$1" in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }

active_usb_type() {
    raw="$(readv "$CHARGER/usb_type")"
    printf '%s\n' "$raw" | sed -n 's/.*\[\([^]]*\)\].*/\1/p'
}

driver_name() {
    physical="$(readlink -f "$CHARGER" 2>/dev/null)"
    case "$physical" in
        */power_supply/charger)
            device="${physical%/power_supply/charger}"
            if [ -L "$device/driver" ]; then basename "$(readlink -f "$device/driver" 2>/dev/null)"; return; fi
            ;;
    esac
    echo unknown
}

target_device() {
    props="$(getprop ro.product.device) $(getprop ro.product.vendor.device) $(getprop ro.product.model) $(getprop ro.product.vendor.model)"
    case "$props" in *KL5*|*kl5*|*'Spark 30C'*) return 0 ;; esac
    return 1
}

owner_writable() {
    f="$1"; [ -f "$f" ] || return 1
    owner="$(stat -c '%u' "$f" 2>/dev/null)"
    mode="$(stat -c '%a' "$f" 2>/dev/null)"
    [ "$owner" = 0 ] && [ -n "$mode" ] || return 1
    owner_digit=$((mode / 100 % 10))
    [ $((owner_digit & 2)) -ne 0 ]
}

capture_baseline() {
    [ "$(readv "$CHARGER/online")" = 1 ] || return 1
    input="$(readv "$CHARGER/input_current_limit")"
    charge="$(readv "$CHARGER/constant_charge_current")"
    case "$input" in ''|*[!0-9]*) return 1 ;; esac
    case "$charge" in ''|*[!0-9]*) return 1 ;; esac
    printf '%s\n' "$input" > "$STATE/original_input"
    printf '%s\n' "$charge" > "$STATE/original_charge"
    echo 1 > "$STATE/baseline_valid"
    log "Captured source baseline: input=${input}uA charge=${charge}uA"
}

restore_baseline() {
    [ -f "$STATE/baseline_valid" ] || return 0
    input="$(cat "$STATE/original_input" 2>/dev/null)"
    charge="$(cat "$STATE/original_charge" 2>/dev/null)"
    if owner_writable "$CHARGER/input_current_limit"; then
        case "$input" in ''|*[!0-9]*) ;; *) printf '%s\n' "$input" > "$CHARGER/input_current_limit" 2>/dev/null || true ;; esac
    fi
    if owner_writable "$CHARGER/constant_charge_current"; then
        case "$charge" in ''|*[!0-9]*) ;; *) printf '%s\n' "$charge" > "$CHARGER/constant_charge_current" 2>/dev/null || true ;; esac
    fi
    log "Requested restoration of source-session baseline."
}

fail() {
    reason="$1"
    restore_baseline
    echo normal > "$STATE/applied_profile"
    echo "RESULT=blocked"
    echo "APPLIED_PROFILE=normal"
    echo "MESSAGE=$reason"
    log "Profile blocked; baseline restoration requested: $reason"
    exit 0
}

status() {
    online="$(readv "$CHARGER/online")"; [ -n "$online" ] || online=0
    type="$(active_usb_type)"; [ -n "$type" ] || type=unknown
    input="$(readv "$CHARGER/input_current_limit")"
    maxin="$(readv "$CHARGER/current_max")"
    charge="$(readv "$CHARGER/constant_charge_current")"
    maxcharge="$(readv "$MASTER/constant_charge_current_max")"
    [ -n "$maxcharge" ] || maxcharge="$(readv "$CHARGER/constant_charge_current_max")"
    temp="$(readv "$BATTERY/temp")"; level="$(readv "$BATTERY/capacity")"
    voltage="$(readv "$BATTERY/voltage_now")"; current="$(readv "$BATTERY/current_now")"
    req="$(cat "$STATE/profile" 2>/dev/null)"; [ -n "$req" ] || req=normal
    applied="$(cat "$STATE/applied_profile" 2>/dev/null)"; [ -n "$applied" ] || applied=normal
    echo "RESULT=ok"
    echo "DRIVER=$(driver_name)"
    echo "ONLINE=$online"
    echo "USB_TYPE=$type"
    echo "INPUT_LIMIT=$input"
    echo "INPUT_MAX=$maxin"
    echo "CHARGE_LIMIT=$charge"
    echo "CHARGE_MAX=$maxcharge"
    echo "BATTERY_TEMP=$temp"
    echo "BATTERY_LEVEL=$level"
    echo "BATTERY_VOLTAGE=$voltage"
    echo "BATTERY_CURRENT=$current"
    echo "REQUESTED_PROFILE=$req"
    echo "APPLIED_PROFILE=$applied"
    echo "INPUT_WRITABLE=$(owner_writable "$CHARGER/input_current_limit" && echo yes || echo no)"
    echo "CHARGE_WRITABLE=$(owner_writable "$CHARGER/constant_charge_current" && echo yes || echo no)"
}

apply_profile() {
    profile="$1"
    case "$profile" in normal|fast|fastest|adaptive) ;; *) fail "Unknown profile: $profile" ;; esac
    echo "$profile" > "$STATE/profile"
    if [ "$profile" = normal ] || [ "$profile" = adaptive ]; then
        restore_baseline
        echo normal > "$STATE/applied_profile"
        echo "RESULT=ok"
        echo "APPLIED_PROFILE=normal"
        echo "MESSAGE=Stock MediaTek charging policy restored; adapter negotiation and thermal controls remain authoritative."
        log "Normal/Adaptive selected; stock charging policy restored."
        exit 0
    fi

    target_device || fail "This charging profile is restricted to the KL5 device family."
    [ "$(driver_name)" = sgm41516d ] || fail "The active charger device is not bound to SGM41516D. No charging limits were changed."
    [ "$(readv "$CHARGER/online")" = 1 ] || fail "No wired charger is connected."
    [ -f "$STATE/baseline_valid" ] || capture_baseline || fail "Unable to capture the original charging limits; elevated profile refused."

    usb="$(active_usb_type)"
    case "$usb" in
        DCP|PD|PD_DRP|CDP) ;;
        SDP) fail "Active source is USB SDP (500 mA class), consistent with a PC USB connection. Use a suitable wall adapter and cable for higher negotiated current." ;;
        *) fail "Active adapter type '$usb' is not verified for elevated current. No limit was raised." ;;
    esac

    temp="$(num "$(readv "$BATTERY/temp")")"
    level="$(num "$(readv "$BATTERY/capacity")")"
    [ "$temp" -lt 400 ] || fail "Battery temperature is 40°C or higher. Elevated charging is suspended."
    [ "$level" -lt 90 ] || fail "Battery level is 90% or higher. Elevated charging is suspended to respect charge tapering."

    input_max="$(num "$(readv "$CHARGER/current_max")")"
    charge_max="$(num "$(readv "$MASTER/constant_charge_current_max")")"
    [ "$charge_max" -gt 0 ] || charge_max="$(num "$(readv "$CHARGER/constant_charge_current_max")")"
    case "$profile" in
        fast) requested_input=1500000; requested_charge=1000000 ;;
        fastest)
            case "$usb" in DCP|PD|PD_DRP) ;; *) fail "Fastest requires an active DCP or USB-PD source." ;; esac
            requested_input=2400000; requested_charge=1500000 ;;
    esac
    [ "$input_max" -ge "$requested_input" ] || fail "Driver-reported negotiated input ceiling (${input_max} µA) is below the $profile request (${requested_input} µA)."
    [ "$charge_max" -ge "$requested_charge" ] || fail "MediaTek charge-current ceiling (${charge_max} µA) is below the $profile request (${requested_charge} µA)."

    input_node="$CHARGER/input_current_limit"; charge_node="$CHARGER/constant_charge_current"
    owner_writable "$input_node" || fail "Kernel exposes input_current_limit as read-only. A matching kernel-driver change is required; no permissions were altered."
    owner_writable "$charge_node" || fail "Kernel exposes constant_charge_current as read-only. A matching kernel-driver change is required; no permissions were altered."
    old_input="$(readv "$input_node")"; old_charge="$(readv "$charge_node")"
    case "$old_input:$old_charge" in *[!0-9:]*|:*) fail "Could not read the existing charging limits." ;; esac

    printf '%s\n' "$requested_input" > "$input_node" 2>/dev/null || fail "Kernel rejected the input-current request."
    printf '%s\n' "$requested_charge" > "$charge_node" 2>/dev/null || {
        printf '%s\n' "$old_input" > "$input_node" 2>/dev/null || true
        fail "Kernel rejected the battery charge-current request; original limits were restored."
    }
    actual_input="$(num "$(readv "$input_node")")"; actual_charge="$(num "$(readv "$charge_node")")"
    if [ "$actual_input" -lt "$requested_input" ] || [ "$actual_charge" -lt "$requested_charge" ]; then
        printf '%s\n' "$old_input" > "$input_node" 2>/dev/null || true
        printf '%s\n' "$old_charge" > "$charge_node" 2>/dev/null || true
        fail "Kernel read-back did not confirm both requested values; original limits were restored."
    fi
    echo "$profile" > "$STATE/applied_profile"
    log "$profile applied/read-back verified: input=$actual_input charge=$actual_charge usb=$usb temp=$temp level=$level"
    echo "RESULT=ok"; echo "APPLIED_PROFILE=$profile"
    echo "INPUT_LIMIT=$actual_input"; echo "CHARGE_LIMIT=$actual_charge"
    echo "MESSAGE=Kernel accepted and returned both requested limits. Adapter negotiation and hardware thermal controls remain active."
}

case "$1" in
    status) status ;;
    profile) apply_profile "$2" ;;
    capture) capture_baseline && echo RESULT=ok || { echo RESULT=blocked; echo MESSAGE=Unable_to_capture_baseline; } ;;
    restore) restore_baseline; echo normal > "$STATE/applied_profile"; echo RESULT=ok ;;
    event)
        if [ "$2" = connected ]; then
            sleep 2
            capture_baseline || true
            p="$(cat "$STATE/profile" 2>/dev/null)"; [ -n "$p" ] || p=normal
            apply_profile "$p"
        else
            restore_baseline
            echo normal > "$STATE/applied_profile"
            rm -f "$STATE/baseline_valid" "$STATE/original_input" "$STATE/original_charge"
            log "Charger disconnected; source baseline cleared."
            echo RESULT=ok
        fi ;;
    logs) tail -80 "$LOG" 2>/dev/null ;;
    *) echo "Usage: $0 {status|profile normal|fast|fastest|adaptive|capture|restore|event connected|disconnected|logs}" ;;
esac
