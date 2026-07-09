# KB3125574-Lite 3.0.0 milestone baseline

Build: `20260709.milestone-final-104`

## Final result

The complete execution manifest was tested on a fresh Microsoft WIM prepared
with NTLite Features and KB2670838:

- Manifest: `full-feature-target-104-driver-last.txt`
- SHA-256:
  `8fea0ca9eeac748d8a33becf16442fe0315bf9ceaad9d7b2f7b93251922fe210`
- Attempted: 104
- Successful: 104
- Failed: 0
- Fatal errors: 0

All seven explicit driver packages were executed at the tail and completed
with S_OK. DISM subsequently reported that all registry hives were successfully
unloaded.

## Proven optimum

The target universe is 1138 physical terminal payloads for neutral, zh-CN and
en-US identities.

Exact set cover over all 194 relevant full-sample Installed owner candidates
proves that at least 104 packages are required. The validated manifest contains
104 packages and covers 1138/1138, so it reaches the global lower bound.

The separate all-language archive universe remains 1228 payloads with a
152-package minimum.

## Layered deployment

| Target image | Required KB3125574 sub-packages | Coverage |
|---|---:|---:|
| Original Win7 SP1 Ultimate | 90 | 1079/1138 |
| + KB958830 and KB958559 feature parents | 101 | 1126/1138 |
| + KB2670838 | 104 | 1138/1138 |

Prerequisite mapping:

- inbox original image: 90 packages;
- KB958830 RSAT: 10 packages;
- KB958559 Virtual PC: one package;
- KB2670838 Platform Update: three packages.

See `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md`.

## Recommended execution manifest

`manifests/v3/full-feature-target-104-driver-last.txt`

The installer preserves authored order. Its portable default remains the
90-package original-WIM base; select the 101- or 104-package manifest only when
the corresponding exact parents are present.

The offline sub-package selection and integration baseline is released.
Committing and booting a produced image remains deployment QA for each image
build rather than a package-set optimization requirement.
