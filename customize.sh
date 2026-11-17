
#!/system/bin/sh

# KL5 Smart FastCharge Control Center
# Dynamically read module identity and version from module.prop

MODULE_PROP="$MODPATH/module.prop"

MODULE_NAME="$(sed -n 's/^name=//p' "$MODULE_PROP" | head -n 1)"
MODULE_VERSION="$(sed -n 's/^version=//p' "$MODULE_PROP" | head -n 1)"

[ -n "$MODULE_NAME" ] || MODULE_NAME="KL5 Smart FastCharge Control Center"
[ -n "$MODULE_VERSION" ] || MODULE_VERSION="Unknown"

ui_print " "
ui_print "  $MODULE_NAME"
ui_print "  Version $MODULE_VERSION | Richard Musya"
ui_print " "
ui_print "- Updating dashboard and charging diagnostics"
ui_print "- Target: TECNO Spark 30C (KL5) / SGM41516D-aware backend"
ui_print "- Brightness, thresholds, reports and boot greeting retained"
ui_print "- Fast profiles require confirmed source/driver limits"
ui_print "- No raw I2C writes, source spoofing or thermal bypass"
ui_print "- KsuWebUI host is required for the interface"
ui_print " "

# Installation completion notice
ui_print " "
ui_print "Installation successful. Reboot required to activate $MODULE_NAME $MODULE_VERSION."
ui_print " "
