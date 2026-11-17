# Changelog

## 2.0.1 - 2026-11-17
- Preserved the v2.0 KsuWebUI dashboard, manual brightness controls, reference thresholds, diagnostics, logs, boot greeting and module identity.
- Replaced preference-only charging profile actions with a guarded SGM41516D-aware backend.
- Added source-type detection (SDP/CDP/DCP/USB-PD), negotiated-current and MediaTek ceiling checks, writable-node checks, write/read-back verification and baseline restoration on rejected requests.
- Added 500 ms charger connection/source-change watcher and thermal/state-of-charge fallback to Normal.
- Replaced the RM footer monogram with the developer's GitHub profile avatar.
- No raw I2C register access, kernel-module insertion, adapter spoofing or thermal-protection bypass.

## 2.0
- Initial KsuWebUI control center, battery telemetry, manual brightness, thresholds, diagnostics, logs and boot greeting.
