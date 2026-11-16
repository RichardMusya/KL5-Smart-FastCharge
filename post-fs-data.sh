
#!/system/bin/sh

MODDIR=${0%/*}
LOGDIR=/data/adb/kl5_fastcharge
LOGFILE=$LOGDIR/boot.log

mkdir -p "$LOGDIR"
chmod 0755 "$LOGDIR"

exec >> "$LOGFILE" 2>&1

echo "=================================="
echo "KL5 Smart FastCharge"
echo "Early boot initialization"
echo "$(date)"
echo "=================================="

MODEL=$(getprop ro.product.model)
FINGERPRINT=$(getprop ro.build.fingerprint)

echo "Model: $MODEL"
echo "Fingerprint: $FINGERPRINT"

if [ "$MODEL" != "TECNO KL5" ]; then
    echo "WARNING: Unexpected device model."
    exit 0
fi

if [ ! -d /sys/module/sc8950 ]; then
    echo "WARNING: SC8950 driver not detected."
    exit 0
fi

echo "SC8950 driver detected."

for NODE in \
    /sys/class/power_supply/charger \
    /sys/class/power_supply/battery \
    /sys/class/power_supply/mtk-master-charger
do
    if [ -d "$NODE" ]; then
        echo "Detected: $NODE"
    fi
done

echo "No charging limits modified."
echo "Original thermal protections preserved."
echo "Early initialization complete."
