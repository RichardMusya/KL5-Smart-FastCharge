# KL5 Smart FastCharge

**A Magisk module for TECNO Spark 30C (KL5)**

Developed and maintained by **Richard Musya**.

---

## Copyright and Ownership

Copyright © 2026 Richard Musya. All Rights Reserved.

This project, including its source code, scripts, documentation, configuration files, and associated materials, is the intellectual property of Richard Musya.

No part of this project may be copied, redistributed, republished, sold, sublicensed, or modified for redistribution without prior written permission from the copyright holder, except where applicable law expressly permits otherwise.

Downloading or using this project does not transfer ownership or grant permission to commercially exploit the project.

## Project Description

KL5 Smart FastCharge is a Magisk module developed for the TECNO Spark 30C (KL5).

The current implementation provides:

- Device compatibility checks.
- SC8950 charging-controller detection.
- Boot-time initialization.
- Charging status monitoring.
- Battery level, temperature, voltage, and current monitoring.
- Charging diagnostic logs.
- Screen-state monitoring.
- Preservation of the device's existing charging and thermal protections.

**Important:** The current implementation is a charging-monitoring and diagnostic module. It does not independently unlock, force, or guarantee 18W fast charging. Actual charging performance depends on the phone's hardware, charger, cable, kernel, charging controller, battery condition, and software configuration.

## Compatibility

| Component | Target |
|---|---|
| Device | TECNO Spark 30C |
| Device model | KL5 |
| Root solution | Magisk |
| Charging controller | SC8950 |
| Android | Android 16 / compatible ROMs |

Compatibility with other devices or Android versions is not guaranteed.

## Installation

1. Make sure your device is rooted with Magisk.
2. Download the module ZIP from the project's GitHub Releases page.
3. Open the Magisk application.
4. Navigate to Modules.
5. Select Install from storage.
6. Choose the downloaded ZIP file.
7. Restart your device.
8. Check the module logs if troubleshooting is required.

## Diagnostic Logs

The module stores its diagnostic logs under:

```text
/data/adb/kl5_fastcharge/
