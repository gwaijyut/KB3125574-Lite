# KB3125574-Lite v1.0.1

Public build: `20260815.public-v1.0.1`

Source baseline: `3.0.0 / 20260709.milestone-final-104`

This patch release keeps the validated final-104 package manifests unchanged
and hardens the offline Installed Updates visibility workflow.

Visibility safety changes:

- accept only existing DWORD `Visibility` values of `1` or `2`;
- verify every write by reading it back;
- fail on any package write, ACL restoration, or hive unload error;
- add standalone `-WhatIf` preview support;
- generate the restore script only for values actually changed from `1` to `2`;
- stop the default install path if the hide helper is missing.

The package-set baseline remains unchanged:

- 90-package original-WIM baseline manifest covering 1079/1138 target payloads.
- 11-package Features add-on, producing the 101-package Features profile covering 1126/1138.
- 3-package KB2670838 add-on, producing the 104-package full target profile covering 1138/1138.
- Driver-last full target manifest validated 104/104 in one run.
- Prerequisite-split manifests for inbox, RSAT / KB958830, Windows Virtual PC / KB958559, and KB2670838.
- Installer hides only the selected manifest's matched KB3125574 package numbers.
- Generated uninstaller defaults to restoring Installed Updates visibility only; package removal requires the explicit `remove` mode and `REMOVE` confirmation.

Full target manifest SHA-256:

```text
8FEA0CA9EEAC748D8A33BECF16442FE0315BF9CEAAD9D7B2F7B93251922FE210
```
