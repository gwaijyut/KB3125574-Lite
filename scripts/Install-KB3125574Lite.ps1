<#
.SYNOPSIS
    Integrate KB3125574 sub-packages from the original unpacked directory into an
    offline-mounted image, then silently hide them from the Installed Updates list.
    Aborts up front if the three prerequisite updates are not already integrated.

.DESCRIPTION
    Pipeline:
      1. Validate mount point, source directory, and package list.
      2. Detect prerequisites KB4490628 / KB4474419 / KB4019990 in the image.
         All three are REQUIRED. KB3125574 itself is SHA-1 signed, but the
         deployment baseline also includes post-Aug-2019 Win7 updates that are
         SHA-2 signed. A pristine Win7 RTM image only ships SHA-1 verification,
         so those later SHA-2 updates cannot install and first boot fails
         (surfaces as "The specified program could not be found"). The prereqs
         serve those later SHA-2 updates, not KB3125574 itself.
      3. Integrate the listed sub-packages from the source with /Add-Package.
      4. Load the offline SOFTWARE hive and set Visibility=2 to hide the packages.

    All console output and comments are in English on purpose (GitHub release):
    non-UTF-8 consoles would otherwise render localized text as garbage.

.PARAMETER Mount   Offline image mount directory (must contain \Windows\WinSxS).
.PARAMETER Source  Original full KB3125574 unpacked directory (payloads + .mum).
.PARAMETER List    Package number/name list. Defaults to
                   manifests\v3\base-original-observed-90.txt.
.PARAMETER Batch   Submit all paths in one DISM command. Diagnostic only; this
                   does not make DISM compute a safe package order.
.PARAMETER NoHide  Integrate only; skip the hide step.
.PARAMETER SkipPrereqCheck  Bypass the prerequisite check (not recommended).
.PARAMETER WhatIf  Dry run: resolve the package list against the source and print
                   the ordered integration plan without calling DISM or touching
                   the image. The hide/uninstaller stages are skipped.

.EXAMPLE
    .\Install-KB3125574Lite.ps1 -Mount "D:\M" -Source "C:\KB3125574-v4-x64"

.NOTES
    install_result.txt is written next to this script (script directory), not
    into the source directory. Run from an elevated session. DISM is required.
#>
#
# ACKNOWLEDGEMENT
#   The package-hide logic (offline CBS registry 'Visibility' manipulation) is
#   inspired by community techniques for offline CBS registry manipulation (as
#   seen in projects like MAS and Abbodi1406's BypassESU). This is an independent
#   PowerShell implementation with no code derived from those projects.
#
# LICENSE: MIT (see LICENSE file). Copyright (c) 2026 gwaijyut
#


param(
    [Parameter(Mandatory=$true)][string]$Mount,
    [Parameter(Mandatory=$true)][string]$Source,
    [string]$List = "",
    [switch]$Batch,
    [string]$ScratchDir = "",
    [switch]$NoHide,
    [switch]$SkipPrereqCheck,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# Resolve the script's own directory (report + default list live here)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Shared uninstaller generator (Write-UninstallScript). Loaded as a script block
# rather than dot-sourced so it is not subject to file-level execution-policy
# signature checks (same technique used below for the Hide delegation).
$commonFile = Join-Path $ScriptDir 'Common-WriteUninstaller.ps1'
if (-not (Test-Path -LiteralPath $commonFile)) { Fail "Common-WriteUninstaller.ps1 not found next to this script." }
. ([ScriptBlock]::Create([System.IO.File]::ReadAllText($commonFile, [System.Text.Encoding]::UTF8)))
$kbLiteAssetDir = Join-Path $ScriptDir '..\assets'

function Fail($msg) { Write-Host ""; Write-Host "[ABORT] $msg" -ForegroundColor Red; exit 1 }

# ---------- 0. Basic validation ----------
if (-not (Test-Path (Join-Path $Mount "Windows\WinSxS"))) {
    Fail "Invalid mount point: $Mount\Windows\WinSxS not found. Check dism /Get-MountedImageInfo"
}
if (-not (Test-Path $Source)) { Fail "Source directory not found: $Source" }
$Source = (Resolve-Path $Source).Path

if ([string]::IsNullOrWhiteSpace($List)) {
    $List = Join-Path $ScriptDir "..\manifests\v3\base-original-observed-90.txt"
}
if (-not (Test-Path $List)) { Fail "Package list not found: $List" }

# ---------- 1. Prerequisite check (hard gate; all three required) ----------
# KB3125574 itself is SHA-1 signed. The deployment baseline also includes
# post-Aug-2019 Win7 updates that are SHA-2 signed; a pristine Win7 RTM image only
# has SHA-1 verification, so those later updates cannot install and first boot
# fails. All three below are mandatory: SSU (servicing-stack base), SHA-2 support, and its
# dependency update.
$prereqs = @(
    @{ KB = 'KB4490628'; Role = 'Servicing Stack Update (base)' },
    @{ KB = 'KB4474419'; Role = 'SHA-2 code signing support (core)' },
    @{ KB = 'KB4019990'; Role = 'dependency update' }
)

if ($SkipPrereqCheck) {
    Write-Host "[!] -SkipPrereqCheck set: skipping prerequisite check (at your own risk)." -ForegroundColor Yellow
}
else {
    Write-Host "[*] Checking prerequisites (reading integrated package list)..."
    $installed = & dism /Image:$Mount /Get-Packages /English 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $installed) {
        Fail "Failed to read image package list (dism /Get-Packages)."
    }
    $installedText = ($installed -join "`n")

    $missing = @()
    foreach ($p in $prereqs) {
        # Match the CBS package identity: Package_for_KBxxxxxxx~
        $pattern = "Package_for_$($p.KB)~"
        $present = $installedText -match [regex]::Escape($pattern)
        $mark  = if ($present) { "[ OK ]" } else { "[MISS]" }
        $color = if ($present) { "Green" }  else { "Red" }
        Write-Host ("  {0} {1}  {2}" -f $mark, $p.KB, $p.Role) -ForegroundColor $color
        if (-not $present) { $missing += $p }
    }

    # All three are required: abort if any is missing.
    if ($missing.Count -gt 0) {
        Write-Host ""
        Write-Host "[ABORT] Missing required prerequisite update(s); the image would" -ForegroundColor Red
        Write-Host "        fail to reach the desktop after integration:" -ForegroundColor Red
        foreach ($p in $missing) { Write-Host ("          - {0}  {1}" -f $p.KB, $p.Role) -ForegroundColor Red }
        Write-Host ""
        Write-Host "  All three prerequisites are required. Integrate them into the image first, in order:" -ForegroundColor Yellow
        Write-Host "    1) KB4490628 (SSU)  ->  2) KB4474419 (SHA-2)  ->  3) KB4019990" -ForegroundColor Yellow
        Write-Host "  Example: dism /Image:`"$Mount`" /Add-Package /PackagePath:`"X:\KB4474419.msu`"" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[*] Prerequisite check passed (all three present)." -ForegroundColor Green
}

# ---------- 2. Resolve list -> real .mum files in the source ----------
$nums = @()
$seenNums = @{}
Get-Content $List | ForEach-Object {
    $t = $_.Trim()
    $n = $null
    if     ($t -match '^\d+$')                       { $n = [int]$t }
    elseif ($t -match 'Package_(\d+)_for_KB3125574') { $n = [int]$Matches[1] }
    if ($null -ne $n -and -not $seenNums.ContainsKey($n)) {
        $seenNums[$n] = $true
        $nums += $n
    }
}

if (-not $nums -or @($nums).Count -eq 0) { Fail "No valid package numbers in list: $List" }

$mums = @(); $matchedNums = @(); $notfound = @()
# Enumerate the source directory ONCE and index .mum files by package number,
# instead of scanning the directory once per requested package number.
# (PS 2.0: no -File switch; filter out containers explicitly.)
$mumIndex = @{}
Get-ChildItem -Path $Source -Filter 'package_*_for_kb3125574~*~amd64~~*.mum' -ErrorAction SilentlyContinue |
    Where-Object { -not $_.PSIsContainer } |
    ForEach-Object {
        if ($_.Name -match '^package_(\d+)_for_kb3125574') {
            $key = [int]$Matches[1]
            if (-not $mumIndex.ContainsKey($key)) { $mumIndex[$key] = $_.FullName }
        }
    }
foreach ($n in $nums) {
    if ($mumIndex.ContainsKey($n)) { $mums += $mumIndex[$n]; $matchedNums += $n }
    else { $notfound += $n }
}
if ($notfound.Count -gt 0) {
    Write-Host ("[WARN] Package number(s) not found in source: {0}" -f ($notfound -join ',')) -ForegroundColor Yellow
}
if ($mums.Count -eq 0) { Fail "No .mum matched in the source directory." }
Write-Host ("[*] Matched {0} sub-package(s); starting integration..." -f $mums.Count)

if ($WhatIf) {
    Write-Host "[*] WhatIf: dry run only. No DISM call will be made and the image will not be modified." -ForegroundColor Yellow
    Write-Host ("[*] Integration plan ({0} package(s) in list order):" -f $mums.Count)
    $i = 0
    foreach ($m in $mums) {
        $i++
        Write-Host ("  [{0}/{1}] dism /Add-Package /PackagePath:`"{2}`"" -f $i, $mums.Count, $m)
    }
    Write-Host "[*] Hide/uninstaller stages are skipped in WhatIf mode."
    exit 0
}

# ---------- 3. Integrate packages ----------
$fail = @(); $ok = 0; $i = 0; $aborted = $false; $abortReason = ""
$pendingPath = Join-Path $Mount "Windows\WinSxS\pending.xml"
$pendingBefore = Test-Path -LiteralPath $pendingPath
$pendingBeforeSize = if ($pendingBefore) {
    (Get-Item -LiteralPath $pendingPath).Length
} else { 0 }
if ($pendingBefore) {
    Write-Warning ("The image already has pending.xml ({0} bytes). Results may depend on unresolved offline transactions." -f $pendingBeforeSize)
}
$dismGlobal = @("/Image:$Mount")
if (-not [string]::IsNullOrWhiteSpace($ScratchDir)) {
    if (-not (Test-Path -LiteralPath $ScratchDir)) {
        New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
    }
    $dismGlobal += "/ScratchDir:$ScratchDir"
}

if ($Batch) {
    # Diagnostic mode only. The rc.2 batch test proved that one command does not
    # make DISM infer a safe dependency/order topology for extracted subpackages.
    Write-Warning "Batch mode is diagnostic only and is not the rc.3 validation path."
    $dismArgs = @($dismGlobal + "/Add-Package")
    foreach ($m in $mums) { $dismArgs += "/PackagePath:$m" }
    Write-Host ("[*] Batch mode: submitting {0} packages in one DISM session." -f $mums.Count)
    & dism @dismArgs | Out-Null
    $i = $mums.Count
    if ($LASTEXITCODE -eq 0) {
        $ok = $mums.Count
    } else {
        $exitHex = "0x{0:x8}" -f ($LASTEXITCODE -band 0xffffffff)
        $line = "BATCH  ->  $exitHex"
        Write-Warning $line; $fail += $line
        $aborted = $true
        $abortReason = "batch DISM failed with $exitHex; inspect DISM log"
    }
} else {
    foreach ($m in $mums) {
        $i++
        Write-Host ("[{0}/{1}] {2}" -f $i, $mums.Count, (Split-Path $m -Leaf))
        & dism @dismGlobal /Add-Package /PackagePath:"$m" | Out-Null
        if ($LASTEXITCODE -eq 0) { $ok++ }
        else {
            $line = "{0}  ->  0x{1:x8}" -f (Split-Path $m -Leaf), $LASTEXITCODE
            Write-Warning $line; $fail += $line
            $exitHex = "0x{0:x8}" -f ($LASTEXITCODE -band 0xffffffff)
            if ($exitHex -ne "0x800f081e") {
                $aborted = $true
                $abortReason = "fatal package error $exitHex at $(Split-Path $m -Leaf)"
                Write-Warning "[ABORT] $abortReason; remaining packages were not attempted."
                break
            }
        }
    }
}

# Report is written next to THIS SCRIPT, never into the source directory.
# If the script directory is not writable (e.g. read-only checkout), fall back
# to the temp directory instead of aborting after a successful integration.
$report = Join-Path $ScriptDir "install_result.txt"
$listHash = try { (Get-FileHash -LiteralPath $List -Algorithm SHA256).Hash.ToLowerInvariant() } catch { "unavailable" }
$reportLines = @("timestamp: $([DateTime]::Now.ToString('s'))", "mount : $Mount", "source: $Source",
  "list  : $List", "list-sha256: $listHash",
  "requested-order: $($nums -join ',')",
  "matched-order  : $($matchedNums -join ',')",
  "pending-before: $pendingBefore", "pending-before-size: $pendingBeforeSize",
  "mode  : $(if ($Batch) { 'batch' } else { 'per-package' })", "scratch: $ScratchDir",
  "total : $($mums.Count)", "attempted: $i", "ok    : $ok", "failed: $($fail.Count)",
  "aborted: $aborted", "abort-reason: $abortReason",
  "", "---- failures ----") + $fail
try {
    $reportLines | Set-Content $report -Encoding UTF8
}
catch {
    $report = Join-Path $env:TEMP "install_result.txt"
    $reportLines | Set-Content $report -Encoding UTF8
    Write-Warning "Script directory is not writable; report written to $report"
}
Write-Host ("[*] Integration done: ok {0} / failed {1} / total {2}   report: {3}" -f $ok, $fail.Count, $mums.Count, $report)

if ($fail.Count -gt 0 -or $aborted) {
    Write-Warning "Integration was not clean; hide/uninstaller stages are skipped."
    exit 2
}

# ---------- 4. Silent hide (offline SOFTWARE hive) ----------
function Invoke-OfflineHide {
    param(
        [string]$MountDir,
        [int[]]$Numbers
    )
    # Delegate to the standalone offline-hive hide script, which takes ownership
    # of the TrustedInstaller-owned CBS keys via native advapi32 calls, writes
    # Visibility, restores the ACL, and releases all handles before reg unload.
    $hideScript = Join-Path $ScriptDir 'Hide-OfflineKB3125574.ps1'
    if (-not (Test-Path -LiteralPath $hideScript)) {
        throw "[hide] Hide-OfflineKB3125574.ps1 not found next to this script."
    }
    # Load the hide script as a script block rather than invoking the file
    # directly. Invoking a .ps1 file (& $path) is subject to the execution
    # policy and fails with "not digitally signed" under AllSigned/RemoteSigned.
    # Reading the content and running it as a script block runs in-process and
    # is not gated by the file-level signature check.
    # (PS 2.0: no -Raw switch; use .NET file read.)
    $hideContent = [System.IO.File]::ReadAllText($hideScript, [System.Text.Encoding]::UTF8)
    $hideBlock   = [ScriptBlock]::Create($hideContent)
    # Pass the scripts directory explicitly: inside the script block,
    # $MyInvocation.MyCommand.Path is empty, so the callee cannot resolve it.
    $result = & $hideBlock -Mount $MountDir -Numbers $Numbers -NoUninstaller -PassThru -ScriptsDir $ScriptDir
    if ($null -eq $result) { throw "[hide] Hide script returned no result." }
    if ([int]$result.Failed -ne 0) { throw "[hide] Hide script reported failures." }
    return $result
}

$hideResult = $null
if ($NoHide)       { Write-Host "[*] -NoHide set; skipping hide step." }
elseif ($ok -eq 0) { Write-Host "[*] No package integrated successfully; skipping hide step." }
else {
    Write-Host "[*] Silently hiding integrated KB3125574 sub-packages..."
    $hideResult = Invoke-OfflineHide -MountDir $Mount -Numbers ([int[]]$matchedNums)
}

# generate uninstaller at the image root (offline: $Mount ; deploys as C:\)
if ($null -ne $hideResult -and @($hideResult.ChangedNumbers).Count -gt 0) {
    try { Write-UninstallScript -RootDir $Mount -Numbers ([int[]]$hideResult.ChangedNumbers) -AssetDir $kbLiteAssetDir }
    catch { Write-Warning "[uninstall] could not generate uninstaller: $_" }
}
elseif ($null -ne $hideResult) {
    Write-Host "[*] No visibility values changed; no visibility-restore script was generated."
}

Write-Host ""
$visibilitySummary = "hide skipped"
if (-not $NoHide) {
    if (($null -ne $hideResult) -and (@($hideResult.ChangedNumbers).Count -gt 0)) {
        $visibilitySummary = "hidden=$($hideResult.Changed); restore script written"
    } else {
        $visibilitySummary = "hidden=0; restore script not needed"
    }
}
Write-Host "[DONE] Integrated ok=$ok / failed=$($fail.Count); $visibilitySummary. Now: dism /Unmount-Image /Commit, then deploy & verify." -ForegroundColor Cyan
