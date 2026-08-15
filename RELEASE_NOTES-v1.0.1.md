# KB3125574-Lite v1.0.1

Public build: `20260815.public-v1.0.1`

Source baseline: `3.0.0 / 20260709.milestone-final-104`

This patch release keeps every package manifest and coverage result from v1.0.0
unchanged. It hardens only the offline CBS Installed Updates visibility path.

## Fixed

- Require an existing DWORD `Visibility` value of `1` or `2` before changing a
  selected `Package_N_for_KB3125574` key.
- Read back and verify every `Visibility` write.
- Fail the run when any package write fails, ACL restoration differs, or the
  offline SOFTWARE hive cannot be unloaded.
- Stop the default installer path when the hide helper is missing.
- Generate the visibility-restore script only for package numbers that actually
  changed from visible (`1`) to hidden (`2`).
- Do not generate a visibility-restore script when `-NoHide` is selected.

## Added

- `-WhatIf` support for `Hide-OfflineKB3125574.ps1`.
- Separate changed, already-target, preview, and failed counters.

## Unchanged baseline

- Original-WIM profile: 90 packages, 1079/1138 target payloads.
- Features profile: 101 packages, 1126/1138 target payloads.
- Features + KB2670838 profile: 104 packages, 1138/1138 target payloads.
- Full target manifest SHA-256:
  `8FEA0CA9EEAC748D8A33BECF16442FE0315BF9CEAAD9D7B2F7B93251922FE210`.
