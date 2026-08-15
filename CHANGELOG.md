# Changelog

All notable public changes to KB3125574-Lite are recorded here.

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
