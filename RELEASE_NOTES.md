# KB3125574-Lite v1.0.0

Public build: `20260709.public-v1.0.0`

Source baseline: `3.0.0 / 20260709.milestone-final-104`

This is the first public release of the validated final-104 baseline.

Included:

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
