<#
Hide-OfflineKB3125574.ps1

Hide injected KB3125574 sub-packages in an OFFLINE-mounted image by setting
their CBS 'Visibility' registry value to 2 (or 1 with -Show), operating on the
image's SOFTWARE hive. If -Numbers is supplied, only those Package_N_for_KB3125574
keys are processed; otherwise every KB3125574 sub-package key found in the image
is processed.

The CBS Packages keys are owned by TrustedInstaller; a plain admin token cannot
write them. This script therefore takes ownership + grants FullControl, writes
the value, then RESTORES the original owner/DACL -- all via native advapi32
calls (Reg* P/Invoke) so the .NET registry provider never pins a handle on the
hive (which would make `reg unload` fail with Access Denied).

ACKNOWLEDGEMENT
  The offline CBS 'Visibility' technique and the SeTakeOwnership/SeRestore +
  RegSetKeySecurity approach are inspired by community techniques (e.g. MAS,
  Abbodi1406's BypassESU). Independent implementation; no code copied.

LICENSE: MIT (see LICENSE file). Copyright (c) 2026 gwaijyut
#>

param(
    [Parameter(Mandatory=$true)][string]$Mount,
    [int[]]$Numbers = @(), # optional package-number scope; omit to process every KB3125574 subpackage key
    [switch]$NoUninstaller,  # suppress uninstaller generation (set by Install to avoid double-write)
    [switch]$Show,
    [switch]$WhatIf,
    [switch]$PassThru,
    [string]$ScriptsDir = "" # set by Install-KB3125574Lite.ps1 when delegating as a script block
                             # (there $MyInvocation.MyCommand.Path is empty); standalone use resolves it below
)

$ErrorActionPreference = 'Stop'
$targetVis = if ($Show) { 1 } else { 2 }

# Shared uninstaller generator (Write-UninstallScript). Loaded as a script block
# rather than dot-sourced so it is not subject to file-level execution-policy
# signature checks. Resolved from -ScriptsDir when the Install script delegates
# to this file as a script block; otherwise from this file's own directory.
if ([string]::IsNullOrWhiteSpace($ScriptsDir)) {
    $ScriptsDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
$commonFile = Join-Path $ScriptsDir 'Common-WriteUninstaller.ps1'
if (-not (Test-Path -LiteralPath $commonFile)) { throw "Common-WriteUninstaller.ps1 not found: $commonFile" }
. ([ScriptBlock]::Create([System.IO.File]::ReadAllText($commonFile, [System.Text.Encoding]::UTF8)))
$kbLiteAssetDir = Join-Path $ScriptsDir '..\assets'

$hive = Join-Path $Mount 'Windows\System32\config\SOFTWARE'
if (-not (Test-Path -LiteralPath $hive)) { throw "Offline SOFTWARE hive not found: $hive" }

# ---- native helpers: privileges + registry security + value write ----------
$native = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace OfflineCbs
{
    public static class Native
    {
        const int  TOKEN_QUERY = 0x0008, TOKEN_ADJUST_PRIVILEGES = 0x0020;
        const int  SE_PRIVILEGE_ENABLED = 0x0002;
        const int  ERROR_NOT_ALL_ASSIGNED = 1300;
        static readonly UIntPtr HKLM = new UIntPtr(0x80000002u);

        [StructLayout(LayoutKind.Sequential)] struct LUID { public uint Lo; public int Hi; }
        [StructLayout(LayoutKind.Sequential)] struct TOKEN_PRIVILEGES { public int Count; public LUID Luid; public int Attr; }

        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr h);
        [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr p,int acc,out IntPtr tok);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool LookupPrivilegeValue(string sys,string name,out LUID luid);
        [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr tok,bool dis,ref TOKEN_PRIVILEGES st,int len,IntPtr prev,IntPtr rl);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode)] static extern int RegOpenKeyEx(UIntPtr key,string sub,uint opt,int acc,out IntPtr res);
        [DllImport("advapi32.dll")] static extern int RegSetKeySecurity(IntPtr key,uint si,byte[] sd);
        [DllImport("advapi32.dll")] static extern int RegCloseKey(IntPtr key);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="RegQueryValueExW")]
        static extern int RegQueryValueEx(IntPtr key,string name,IntPtr reserved,out int type,byte[] data,ref int len);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="RegSetValueExW")]
        static extern int RegSetValueEx(IntPtr key,string name,int res,int type,byte[] data,int len);

        const int KEY_QUERY_VALUE = 0x0001;
        const int KEY_SET_VALUE = 0x0002;

        public static void Enable(string priv)
        {
            IntPtr tok = IntPtr.Zero;
            try {
                if(!OpenProcessToken(GetCurrentProcess(),TOKEN_QUERY|TOKEN_ADJUST_PRIVILEGES,out tok))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                LUID luid;
                if(!LookupPrivilegeValue(null,priv,out luid))
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
                tp.Count=1; tp.Luid=luid; tp.Attr=SE_PRIVILEGE_ENABLED;
                bool ok = AdjustTokenPrivileges(tok,false,ref tp,0,IntPtr.Zero,IntPtr.Zero);
                int err = Marshal.GetLastWin32Error();
                if(!ok) throw new Win32Exception(err);
                if(err==ERROR_NOT_ALL_ASSIGNED) throw new Win32Exception(err,"Token lacks "+priv);
                if(err!=0) throw new Win32Exception(err);
            } finally { if(tok!=IntPtr.Zero) CloseHandle(tok); }
        }

        // subKey is relative to HKLM, e.g. "OfflineLite_xxxx\...\Packages\Package_..."
        public static void SetSecurity(string subKey, byte[] sd, uint si, int access)
        {
            IntPtr key = IntPtr.Zero;
            int r = RegOpenKeyEx(HKLM, subKey, 0, access, out key);
            if(r!=0) throw new Win32Exception(r,"RegOpenKeyEx(sec) HKLM\\"+subKey);
            try {
                r = RegSetKeySecurity(key, si, sd);
                if(r!=0) throw new Win32Exception(r,"RegSetKeySecurity HKLM\\"+subKey);
            } finally { RegCloseKey(key); }
        }

        // read and validate REG_DWORD without letting the .NET provider pin the hive
        public static int GetDword(string subKey, string name)
        {
            IntPtr key = IntPtr.Zero;
            int r = RegOpenKeyEx(HKLM, subKey, 0, KEY_QUERY_VALUE, out key);
            if(r!=0) throw new Win32Exception(r,"RegOpenKeyEx(query) HKLM\\"+subKey);
            try {
                int type = 0, len = 4;
                byte[] data = new byte[4];
                r = RegQueryValueEx(key, name, IntPtr.Zero, out type, data, ref len);
                if(r!=0) throw new Win32Exception(r,"RegQueryValueEx HKLM\\"+subKey+"\\"+name);
                if(type!=4 || len!=4)
                    throw new InvalidOperationException("Registry value is not REG_DWORD: HKLM\\"+subKey+"\\"+name);
                return BitConverter.ToInt32(data,0);
            } finally { RegCloseKey(key); }
        }

        // write REG_DWORD without letting the .NET provider pin the hive
        public static void SetDword(string subKey, string name, int value)
        {
            IntPtr key = IntPtr.Zero;
            int r = RegOpenKeyEx(HKLM, subKey, 0, KEY_SET_VALUE, out key);
            if(r!=0) throw new Win32Exception(r,"RegOpenKeyEx(val) HKLM\\"+subKey);
            try {
                byte[] data = BitConverter.GetBytes(value); // 4 bytes, REG_DWORD=4
                r = RegSetValueEx(key, name, 0, 4, data, 4);
                if(r!=0) throw new Win32Exception(r,"RegSetValueEx HKLM\\"+subKey);
            } finally { RegCloseKey(key); }
        }
    }
}
'@
if (-not ('OfflineCbs.Native' -as [type])) {
    Add-Type -TypeDefinition $native -Language CSharp | Out-Null
}

function Get-ComparableSddl([string]$Sddl) {
    $d = $Sddl.IndexOf('D:', [StringComparison]::Ordinal)
    if ($d -lt 0) { return $Sddl }
    $fs = $d + 2
    $ace = $Sddl.IndexOf('(', $fs); if ($ace -lt 0) { $ace = $Sddl.Length }
    $flags = $Sddl.Substring($fs, $ace - $fs).Replace('AI','')
    return $Sddl.Substring(0,$fs) + $flags + $Sddl.Substring($ace)
}

# ---- load hive ----
$mn = 'OfflineLite_' + ([Guid]::NewGuid().ToString('N').Substring(0,8))
$loaded = $false
$chg = 0; $already = 0; $preview = 0; $failed = 0; $script:hiddenNums = @()
$unloadFailed = $false
try {
    & reg.exe load "HKLM\$mn" "$hive" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "reg load failed for $hive" }
    $loaded = $true

    [OfflineCbs.Native]::Enable('SeTakeOwnershipPrivilege')
    [OfflineCbs.Native]::Enable('SeRestorePrivilege')
    $admins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')

    $pkgRootRel = "$mn\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages"
    $pkgRootPS  = "HKLM:\$pkgRootRel"
    if (-not (Test-Path -LiteralPath $pkgRootPS)) { throw "CBS Packages not found in offline hive." }

    $numberScope = @{}
    foreach ($n in $Numbers) { $numberScope[[int]$n] = $true }
    $hasNumberScope = ($numberScope.Count -gt 0)

    # enumerate package subkey names ONCE, then drop the provider enumerator
    $names = @(Get-ChildItem -LiteralPath $pkgRootPS -ErrorAction SilentlyContinue |
        Where-Object { (Split-Path $_.Name -Leaf) -match '^Package_\d+_for_KB3125574~' } |
        ForEach-Object { Split-Path $_.Name -Leaf } |
        Where-Object {
            if (-not $hasNumberScope) { $true }
            else {
                $include = $false
                if ($_ -match '^Package_(\d+)_for_KB3125574~') {
                    $include = $numberScope.ContainsKey([int]$Matches[1])
                }
                $include
            }
        })
    Write-Host ("[*] {0} KB3125574 sub-package key(s) found; target Visibility={1}" -f $names.Count, $targetVis)
    if ($names.Count -eq 0) { throw "No matching KB3125574 package keys were found." }
    if ($WhatIf) { Write-Host "[*] WhatIf: registry values and ACLs will not be changed." -ForegroundColor Yellow }

    $sec = [Security.AccessControl.AccessControlSections]::Owner -bor `
           [Security.AccessControl.AccessControlSections]::Access

    foreach ($leaf in $names) {
        $rel   = "$pkgRootRel\$leaf"      # relative to HKLM, for native calls
        $psKey = "HKLM:\$rel"             # provider path, only for Get-Acl (read)
        $origSddl = $null
        $tookOwnership = $false
        $restoreFailed = $false
        try {
            $currentVis = [OfflineCbs.Native]::GetDword($rel, 'Visibility')
            if ($currentVis -ne 1 -and $currentVis -ne 2) {
                throw "Visibility=$currentVis; only 1 or 2 is supported."
            }
            if ($currentVis -eq $targetVis) {
                Write-Host ("  [already] {0} Visibility={1}" -f $leaf, $currentVis) -ForegroundColor DarkGray
                $already++
                continue
            }
            if ($WhatIf) {
                Write-Host ("  [preview] {0} Visibility {1} -> {2}" -f $leaf, $currentVis, $targetVis)
                $preview++
                continue
            }

            $origAcl  = Get-Acl -Path $psKey
            $origSddl = $origAcl.GetSecurityDescriptorSddlForm($sec)
            try {
                # take ownership (Administrators)
                $oAcl = New-Object Security.AccessControl.RegistrySecurity
                $oAcl.SetSecurityDescriptorSddlForm($origSddl, $sec)
                $oAcl.SetOwner($admins)
                [OfflineCbs.Native]::SetSecurity($rel, $oAcl.GetSecurityDescriptorBinaryForm(), 0x1, 0x00080000) # WRITE_OWNER
                $tookOwnership = $true

                # grant FullControl to Administrators
                $wAcl = Get-Acl -Path $psKey
                $rule = New-Object Security.AccessControl.RegistryAccessRule(
                    $admins,[Security.AccessControl.RegistryRights]::FullControl,
                    [Security.AccessControl.AccessControlType]::Allow)
                [void]$wAcl.SetAccessRule($rule)
                [OfflineCbs.Native]::SetSecurity($rel, $wAcl.GetSecurityDescriptorBinaryForm(), 0x4, 0x00040000) # WRITE_DAC

                # write and verify the value natively (no provider handle on the hive)
                [OfflineCbs.Native]::SetDword($rel, 'Visibility', $targetVis)
                $writtenVis = [OfflineCbs.Native]::GetDword($rel, 'Visibility')
                if ($writtenVis -ne $targetVis) {
                    throw "Visibility verification failed: expected $targetVis, read $writtenVis."
                }
            }
            finally {
                if ($tookOwnership -and $origSddl) {
                    try {
                        # restore original owner + DACL
                        $rAcl = New-Object Security.AccessControl.RegistrySecurity
                        $rAcl.SetSecurityDescriptorSddlForm($origSddl, $sec)
                        [OfflineCbs.Native]::SetSecurity($rel, $rAcl.GetSecurityDescriptorBinaryForm(), 0x5, 0x000C0000) # WRITE_OWNER|WRITE_DAC
                        # verify semantic restoration
                        $back = (Get-Acl -Path $psKey).GetSecurityDescriptorSddlForm($sec)
                        if ((Get-ComparableSddl $back) -ne (Get-ComparableSddl $origSddl)) {
                            throw "ACL restore verification differs."
                        }
                    }
                    catch {
                        $restoreFailed = $true
                        throw
                    }
                }
            }

            $chg++
            if (-not $Show -and $leaf -match '^Package_(\d+)_for_KB3125574~') {
                $script:hiddenNums += [int]$Matches[1]
            }
        }
        catch {
            $failed++
            Write-Warning ("[{0}] {1}" -f $leaf, $_.Exception.Message)
            if ($restoreFailed) {
                Write-Warning "ACL restoration failed; no further package keys will be modified."
                break
            }
        }
    }
    Write-Host ("[hide] Done: changed {0}, already {1}, preview {2}, failed {3} (of {4})" -f $chg, $already, $preview, $failed, $names.Count)
    if ($failed -eq 0 -and $script:hiddenNums.Count -gt 0 -and -not $NoUninstaller -and -not $WhatIf -and -not $Show) {
        try { Write-UninstallScript -RootDir $Mount -Numbers ([int[]]$script:hiddenNums) -AssetDir $kbLiteAssetDir }
        catch { Write-Warning "[uninstall] could not generate uninstaller: $_" }
    }
}
finally {
    # release every provider handle before unloading, or reg unload => Access Denied
    Remove-Variable origAcl,oAcl,wAcl,rAcl,back,origSddl -ErrorAction SilentlyContinue
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    if ($loaded) {
        & reg.exe unload "HKLM\$mn" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Start-Sleep -Seconds 2
            [GC]::Collect(); [GC]::WaitForPendingFinalizers()
            & reg.exe unload "HKLM\$mn" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                $unloadFailed = $true
                Write-Warning "reg unload still failing. Close this PowerShell window (frees handles), then: reg unload HKLM\$mn"
            }
        }
    }
}

if ($unloadFailed) { throw "Offline SOFTWARE hive could not be unloaded: HKLM\$mn" }
if ($failed -gt 0) { throw "$failed package visibility operation(s) failed." }
if ($PassThru) {
    New-Object PSObject -Property @{
        ChangedNumbers = [int[]]@($script:hiddenNums | Sort-Object -Unique)
        Changed = $chg
        Already = $already
        Preview = $preview
        Failed = $failed
    }
}
