# KB3125574-Lite milestone baseline

Date: 2026-07-09

Version: `3.0.0`

Build: `20260709.milestone-final-104`

Status: milestone baseline for subsequent work.

## Baseline conclusion

This snapshot records the validated `final-104` project state:

- Target payload scope: neutral + zh-CN + en-US, `1138/1138` physical terminal payloads.
- Validated integration profile: fresh Windows 7 SP1 x64 image with Features + KB2670838.
- Validated package set: `104/104` successful in one run.
- Execution manifest: `manifests/v3/full-feature-target-104-driver-last.txt`.
- Base original-WIM package set: `90` packages covering `1079` target payloads.
- Conditional package layers:
  - RSAT / KB958830: `10` packages.
  - Windows Virtual PC / KB958559: `1` package.
  - Platform Update / KB2670838: `3` packages.

## Baseline files

- `VERSION`
- `README.md`
- `README.zh-CN.md`
- `docs/BASELINE-v3.0.0.md`
- `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md`
- `analysis/baseline-v3-features-observed/combined-104-result.md`
- `manifests/v3/full-feature-target-104-driver-last.txt`

## Notes for future work

Use this directory as the stable reference point. New experiments should be branched or copied from this milestone, and any later conclusion may supersede this baseline only if backed by CBS/registry evidence and reproducible integration results.
