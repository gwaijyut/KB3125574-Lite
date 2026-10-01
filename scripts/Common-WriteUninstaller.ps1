<#
Common-WriteUninstaller.ps1

Shared uninstaller generator for KB3125574-Lite. Used by both
Install-KB3125574Lite.ps1 and Hide-OfflineKB3125574.ps1 so the generated
Uninstall-KB3125574-Lite.* payload has exactly one source of truth.

Loading: dot-source this file via ScriptBlock::Create (see the callers) so it
is not subject to file-level execution-policy signature checks:

    . ([ScriptBlock]::Create([System.IO.File]::ReadAllText($commonFile, [System.Text.Encoding]::UTF8)))

The generated .ps1 body and README live as plain-text templates under
assets/ (Uninstall-Body.template.ps1 / Uninstall-README.template.txt) and are
read at generation time -- no more base64 blobs duplicated across scripts.

PowerShell 2.0 compatible: no -Raw, no -File, no $PSScriptRoot.

LICENSE: MIT (see LICENSE file). Copyright (c) 2026 gwaijyut
#>

function Write-UninstallScript {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][int[]]$Numbers,
        [Parameter(Mandatory=$true)][string]$AssetDir
    )
    if (-not (Test-Path -LiteralPath $RootDir)) { Write-Warning "[uninstall] root not found: $RootDir"; return }
    $bodyTpl   = Join-Path $AssetDir 'Uninstall-Body.template.ps1'
    $readmeTpl = Join-Path $AssetDir 'Uninstall-README.template.txt'
    if (-not (Test-Path -LiteralPath $bodyTpl))   { Write-Warning "[uninstall] template not found: $bodyTpl"; return }
    if (-not (Test-Path -LiteralPath $readmeTpl)) { Write-Warning "[uninstall] template not found: $readmeTpl"; return }

    $numList = (($Numbers | Sort-Object -Unique) | ForEach-Object { $_.ToString() }) -join ','

    $ps1    = Join-Path $RootDir 'Uninstall-KB3125574-Lite.ps1'
    $cmd    = Join-Path $RootDir 'Uninstall-KB3125574-Lite.cmd'
    $readme = Join-Path $RootDir 'Uninstall-README.txt'

    # Body template carries the __NUMS__ placeholder; substitute the actual list.
    # Written as ASCII (body is English-only), same as the previous embedded version.
    $utf8 = [System.Text.Encoding]::UTF8
    $body = ([System.IO.File]::ReadAllText($bodyTpl, $utf8)).Replace('__NUMS__', $numList)
    Set-Content -LiteralPath $ps1 -Value $body -Encoding ASCII

    # README template is bilingual (contains Chinese); write UTF-8 with BOM so
    # Notepad renders it correctly, same as the previous embedded version.
    $readmeText = [System.IO.File]::ReadAllText($readmeTpl, $utf8)
    [System.IO.File]::WriteAllText($readme, $readmeText, (New-Object System.Text.UTF8Encoding($true)))

    # .cmd launcher (goto-style, robust)
    $launch = @'
@echo off
REM Uninstall-KB3125574-Lite launcher. Right-click -> Run as administrator.
REM Default: restores update visibility (safe). Pass "remove" for full removal.
REM See Uninstall-README.txt for bilingual usage notes.
net session >nul 2>&1
if %errorlevel% neq 0 goto :notadmin
if /i "%~1"=="remove" goto :remove
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-KB3125574-Lite.ps1"
goto :done
:remove
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-KB3125574-Lite.ps1" -RemovePackages
goto :done
:notadmin
echo Please run this from an elevated Administrator command prompt.
:done
pause
'@
    Set-Content -LiteralPath $cmd -Value $launch -Encoding ASCII
    Write-Host ("[uninstall] wrote {0}, .cmd, and Uninstall-README.txt (covers {1} package numbers)" -f $ps1, ($Numbers | Sort-Object -Unique).Count)
}
