# KB3125574-Lite

**English** | [中文](README.zh-CN.md)

**Public release v1.0.2**
Source baseline: `3.0.0 / 20260709.milestone-final-104`

Install only the still-terminal payload carriers from the Windows 7 x64 Convenience Rollup (**KB3125574**), directly from an unpacked KB3125574 source directory.

This release is a manifest-and-installer distribution. It does **not** distribute Microsoft update packages.

## Validated result

Target scope: Windows 7 SP1 x64, neutral + zh-CN + en-US payloads, `1138/1138` total.

| Layer | Manifest | External prerequisite | Packages | Cumulative packages | Cumulative coverage | Validated result | Use when |
|---|---|---|---:|---:|---:|---|---|
| Original-WIM base | `manifests/v3/base-original-observed-90.txt` | Microsoft original Win7 SP1 x64 zh-CN Ultimate + required servicing prerequisites | 90 | 90 | 1079/1138 | 90/90 succeeded | Base validated profile |
| Features add-on | `manifests/v3/features-addon-observed-11.txt` | Required optional Windows Features | +11 | 101 | 1126/1138 | Derived from successful Features-profile test | Add on top of the 90-package base |
| Features profile | `manifests/v3/features-observed-101.txt` | Original-WIM base + required optional Windows Features | 101 | 101 | 1126/1138 | 59 applicable conditional packages succeeded; 3 Win8IP packages correctly returned 0x800f081e before KB2670838 | Use on a Features-prepared image without KB2670838 |
| KB2670838 add-on | `manifests/v3/platform-update-kb2670838-addon-3.txt` | KB2670838 Platform Update | +3 | 104 | 1138/1138 | 3/3 succeeded after KB2670838 | Add on top of the Features profile |
| Full target profile | `manifests/v3/full-feature-target-104-driver-last.txt` | Required optional Windows Features + KB2670838 | 104 | 104 | 1138/1138 | 104/104 succeeded in one run | Recommended complete target manifest |
| All-language archive artifact | `manifests/v3/all-terminal-152.txt` | Full sample Installed candidate universe | 152 | 152 | 1228/1228 all-language archive universe | Optimization artifact, not the recommended install default | Audit/reference only |

The full target manifest SHA-256 is:

```text
8FEA0CA9EEAC748D8A33BECF16442FE0315BF9CEAAD9D7B2F7B93251922FE210
```

## Final 104-package prerequisite split

The validated 104 packages are split into four mutually disjoint groups:

| Category | Prerequisite component | Manifest | Subpackages |
|---|---|---|---:|
| Original inbox directly integrable | No external feature KB | `manifests/v3/by-prerequisite/inbox-original-90.txt` | 90 |
| RSAT | KB958830 | `manifests/v3/by-prerequisite/kb958830-rsat-10.txt` | 10 |
| Windows Virtual PC | KB958559 | `manifests/v3/by-prerequisite/kb958559-virtualpc-1.txt` | 1 |
| Platform Update | KB2670838 | `manifests/v3/by-prerequisite/kb2670838-platform-update-3.txt` | 3 |

Specific conditional package numbers:

- KB958830: `366`, `374`, `382`, `798`, `799`, `808`, `816`, `818`, `834`, `1101`
- KB958559: `859`
- KB2670838: `965`, `2627`, `3152`

See `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md` for details.

## Required servicing prerequisites

The installer checks for these updates before adding KB3125574 subpackages:

1. KB4490628
2. KB4474419
3. KB4019990

For the 104-package full target manifest, also prepare the image with:

- the required optional Windows Features; and
- KB2670838 Platform Update.

If a package parent is missing, DISM returns `0x800f081e`. That means “not applicable”, not necessarily a corrupt package.

## Quick start

Mount your image and integrate the servicing prerequisites first:

```cmd
dism /Mount-Image /ImageFile:"install.wim" /Index:1 /MountDir:D:\Mount
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4490628.msu"
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4474419.msu"
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4019990.msu"
```

Then run one manifest from an elevated command prompt:

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\base-original-observed-90.txt
```

For a prepared Features + KB2670838 image, use the complete target manifest:

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\full-feature-target-104-driver-last.txt
```

Finally commit the image:

```cmd
dism /Unmount-Image /MountDir:D:\Mount /Commit
```

If `-List` is omitted, the installer defaults to `manifests/v3/base-original-observed-90.txt`.

## Hidden Installed Updates entries and uninstaller

After a clean integration run, `Install-KB3125574Lite.ps1` hides the integrated KB3125574 subpackages from the offline image's CBS Installed Updates view by setting their CBS `Visibility` value to `2`.

Important behavior:

- The integrated packages are still installed; only their Installed Updates visibility is changed.
- The installer hides only the package numbers matched from the selected manifest.
- Only an existing DWORD `Visibility` value of `1` or `2` is accepted. The script never creates a missing value.
- Every write is read back and verified.
- ACLs on TrustedInstaller-owned CBS package keys are temporarily changed and then restored; a write, ACL restoration, or offline-hive unload failure stops the run.
- To skip this step, pass `-NoHide`.

Example:

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\base-original-observed-90.txt -NoHide
```

When at least one value changes from visible to hidden, the installer writes these files to the offline image root, which becomes `C:\` after deployment:

- `Uninstall-KB3125574-Lite.ps1`
- `Uninstall-KB3125574-Lite.cmd`
- `Uninstall-README.txt`

Default uninstall action:

```cmd
Uninstall-KB3125574-Lite.cmd
```

This only restores visibility (`Visibility=1`). It does not remove packages.

High-risk package removal:

```cmd
Uninstall-KB3125574-Lite.cmd remove
```

This calls `dism /online /Remove-Package` for the generated package list and asks you to type `REMOVE` before proceeding. Use it only if you intentionally want to roll back the integrated packages; removing terminal components can break later updates or component state.

The standalone `scripts\Hide-OfflineKB3125574.ps1` is also included for maintenance use. When called without `-Numbers`, it processes every KB3125574 subpackage key found in the offline image. The main installer calls it with an explicit package-number scope. Use `-WhatIf` to preview current and target values without changing registry values or ACLs.

```powershell
.\scripts\Hide-OfflineKB3125574.ps1 -Mount D:\Mount -Numbers 366,374,382 -WhatIf
```

## Scope and limits

- Validated on Microsoft original Windows 7 SP1 x64 zh-CN Ultimate.
- The target payload scope is neutral + zh-CN + en-US.
- Other SKUs, languages, Server 2008 R2, Enterprise, and custom sysprep images need separate validation.
- Do not integrate while the image is in Audit Mode with unsettled CBS operations. Integrate before Audit Mode, or reboot once after enabling features and then integrate.

## Documentation

- `docs/BASELINE-v3.0.0.md`
- `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md`
- `RELEASE_NOTES.md`
- `CHANGELOG.md`

## License

MIT (c) 2026 gwaijyut. See LICENSE.
