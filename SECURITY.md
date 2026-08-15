# Security Notes

KB3125574-Lite operates on the Windows servicing stack (CBS) and touches
protected areas. Understand these points before use.

## What the scripts do
- Integrate signed Microsoft sub-packages from an already-obtained KB3125574 into
  an offline Windows image via DISM.
- Optionally set the CBS `Visibility` value so the integrated updates do not appear
  in "Installed Updates". Doing so requires temporarily taking ownership of
  TrustedInstaller-owned registry keys in the OFFLINE hive, then restoring the
  original owner and ACL. The scripts verify ACL restoration.
- Refuse to create a missing `Visibility` value or overwrite a value that is not
  DWORD `1` or `2`. Every write is read back and verified.
- Treat package-write failures, ACL restoration mismatches, and offline-hive
  unload failures as fatal errors.
- Write a generated uninstaller to the offline image root. After deployment, its
  default action restores Installed Updates visibility on the running system.

## What the scripts do NOT do
- They do not modify a live/online system during offline integration. The only
  live-system CBS operation is the generated uninstaller, which is opt-in after
  deployment and operates only on the generated KB3125574 package-number list.
- They do not disable Windows Update, tamper with activation, or bypass licensing.
- They do not download anything. You supply KB3125574 and the prerequisites.

## Prerequisites are mandatory
KB4490628 + KB4474419 + KB4019990 must be integrated first. KB3125574 itself is
SHA-1 signed, but the fully-patched baseline also carries post-Aug-2019 SHA-2-signed
updates that a pristine RTM image cannot install without SHA-2 support; without these
prereqs, first boot fails signature verification.

## Uninstall
The main installer writes `Uninstall-KB3125574-Lite.{ps1,cmd}` and
`Uninstall-README.txt` to the image root after a clean integration run. The
standalone hide script also writes them unless `-NoUninstaller` is used. The
default action restores visibility (safe, reversible). A guarded, high-risk
option removes the packages (requires typing REMOVE to confirm).

The standalone offline hide script supports `-WhatIf`. Preview mode loads and
unloads the offline SOFTWARE hive but does not modify package values or ACLs.

## Execution policy
Scripts are unsigned. Use `Run-Install.cmd` (launches with -ExecutionPolicy Bypass)
or run PowerShell with an appropriate policy. See README.

## Report issues
Please open a GitHub issue. Do not include machine-identifying paths or logs.
