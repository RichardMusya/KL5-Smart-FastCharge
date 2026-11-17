# KL5 Smart FastCharge Control Center v2.0.1

**Developer:** Richard Musya  
**Device target:** TECNO Spark 30C (KL5)  
**Root manager:** Magisk  
**Interface host:** KsuWebUI standalone  
**Charging controller observed on the tested device:** SGM41516D (`/sys/bus/i2c/devices/5-006b`)

## v2.0.1 functions

- Retains the v2.0 KsuWebUI dashboard and boot greeting.
- Retains manual brightness control through Android Settings.
- Retains charge/temperature reference thresholds, diagnostic report generation and log viewing.
- Adds guarded Normal, Fast and Fastest profile requests through the active SGM41516D power-supply interface; Adaptive maps to Normal stock control.
- Detects the currently negotiated USB source from the bracketed `usb_type` value. A PC USB SDP connection is treated as SDP, not as a wall charger.
- Checks reported input/charge ceilings, battery temperature, battery level and sysfs write permissions before requesting elevated current.
- Verifies values by reading the kernel nodes back. A rejected or unverified request restores the captured baseline and reports Normal as applied.
- Watches charger attach/detach and source changes at 500 ms intervals; checks thermal and state-of-charge fallback.
- Displays the developer's GitHub avatar in place of the RM initials.

## Profile request targets

| Profile | Input-current request | Battery charge-current request |
|---|---:|---:|
| Normal | Stock MediaTek policy | Stock MediaTek policy |
| Fast | 1,500,000 µA | 1,000,000 µA |
| Fastest | 2,400,000 µA | 1,500,000 µA |
| Adaptive | Stock MediaTek policy | Stock MediaTek policy |

These are request ceilings, not promises of measured charging speed or power. The active adapter classification, SGM41516D driver, MediaTek charging framework, battery state and kernel-exposed limits determine what can actually be applied. For example, a PC USB SDP source normally negotiates a 500 mA class and will be refused for Fast/Fastest. CDP and DCP/PD classifications are handled according to the current negotiated and driver-reported limits. High battery state-of-charge and battery temperature at/above 40°C suspend elevated profiles; the watcher returns an applied elevated profile to Normal at 90% or 40°C.

## Kernel-level limitation

This release does not replace the phone's kernel or patch the SGM41516D driver. The supplied device diagnostics establish the active `sgm41516d` binding but do not provide the exact matching kernel source tree, defconfig, device tree build configuration, toolchain or a reproducible boot image. Shipping a generic or mismatched boot image would be unsafe. This module therefore uses only the kernel's existing power-supply sysfs interface and refuses requests if the nodes are not writable or do not report sufficient limits. It does not poke raw I2C registers, change sysfs permissions, spoof USB source types, or bypass stock thermal/protocol control.

## Install

1. In Magisk, open **Modules** and choose **Install from storage**.
2. Select `KL5_Smart_FastCharge_v2.0.1.zip`.
3. Reboot.
4. Open KL5 Smart FastCharge through KsuWebUI and grant root access.
5. Connect a suitable wall adapter/cable to evaluate Fast/Fastest. A PC USB connection will normally report SDP and be limited accordingly.

This is a Magisk module ZIP. It is not a recovery-flashable boot image and does not flash a kernel.

## Developer

Richard Musya  
GitHub: https://github.com/RichardMusya  
Project: https://github.com/RichardMusya/KL5-Smart-FastCharge

## Copyright and disclaimer

Copyright © 2026 Richard Musya. All Rights Reserved.

Software is provided AS IS, without warranties, to the maximum extent permitted by applicable law. Use at your own risk. The developer is not responsible for device damage, data loss, charging faults, display issues, or other losses arising from use, modification, or installation, to the maximum extent permitted by applicable law. Nothing here excludes liability where prohibited by law.
