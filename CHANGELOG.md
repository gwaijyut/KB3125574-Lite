# Changelog

All notable public changes to KB3125574-Lite are recorded here.

## [v1.0.2] - 2026-10-01

### Fixed

- Fix the generated `Uninstall-KB3125574-Lite.ps1` default restore path: LEVEL 1
  previously passed the provider-qualified `$k.PSPath` into the
  `Set-NativeRegistrySecurity` `HKLM:\` guard, so every key failed and the
  script reported `Restored 0, failed N`. It now rebuilds the registry path
  from the CBS root plus the key leaf, and the advertised safe default
  (restore Installed Updates visibility) works as documented.

### Changed

- Extract the duplicated `Write-UninstallScript` implementation from both
  scripts into the shared `scripts/Common-WriteUninstaller.ps1`; the generated
  uninstaller body and bilingual README are now plain-text templates under
  `assets/` read at generation time instead of two 20 KB base64 blobs
  duplicated across scripts.
- The source-directory scan in step 2 is now a single enumeration indexed by
  package number instead of one scan per requested package number.
- `install_result.txt` falls back to the temp directory when the script
  directory is not writable, instead of aborting after a successful
  integration.
- `Run-Install.cmd` honors a `NOPAUSE` environment variable for unattended
  runs.
- `Install-KB3125574Lite.ps1` gains a `-WhatIf` dry-run mode that prints the
  ordered DISM integration plan without touching the image.

## [v1.0.1] - 2026-08-15

### Fixed

- Validate that every selected package has an existing DWORD `Visibility` value
  of `1` or `2`; missing or nonstandard values are no longer created or overwritten.
- Read back every written value and fail if verification differs.
- Treat per-package failures, ACL restoration mismatches, and offline SOFTWARE
  hive unload failures as fatal instead of allowing a misleading successful run.
- Abort the default install path when the hide helper is missing.
- Generate a visibility-restore script only for package numbers whose values
  actually changed from `1` to `2`; `-NoHide` no longer generates one.

### Added

- Add `-WhatIf` preview support to the standalone offline hide script.
- Report changed, already-target, previewed, and failed package counts separately.

## [v1.0.0] - 2026-07-09

### Released

- First public release.
- Published from source baseline `3.0.0 / 20260709.milestone-final-104`.
- Included the validated 104-package full target manifest for neutral + zh-CN + en-US payload scope.
- Included layered manifests for original WIM, Windows Features, and KB2670838 profiles.
- Included prerequisite-split manifests and baseline documentation.
