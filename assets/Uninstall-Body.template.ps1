# ============================================================================
# Uninstall-KB3125574-Lite.ps1
# See Uninstall-README.txt (next to this file) for bilingual usage notes.
# Run as Administrator. Default = restore visibility (safe). -RemovePackages =
# remove packages (high risk, type REMOVE to confirm).
# ============================================================================
# Uninstall-KB3125574-Lite.ps1  (auto-generated)
# Reverts the KB3125574-Lite integration on this system. Run as Administrator.
#
# LEVEL 1 (default): restore update visibility (Visibility=1) so the KB3125574
#   updates appear again in Installed Updates. Safe, reversible, removes nothing.
#   The CBS Package keys are owned by TrustedInstaller, so this script temporarily
#   takes ownership, writes the value, then restores the original owner and ACL.
# LEVEL 2 (-RemovePackages): additionally remove the packages via DISM. High risk.
param([switch]$RemovePackages)
$ErrorActionPreference = 'Stop'
$nums = @(__NUMS__)
$cbsRoot = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'

$id = [Security.Principal.WindowsIdentity]::GetCurrent()
if (-not (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Please run as Administrator.' -ForegroundColor Red; exit 1
}

function Enable-ProcessPrivilege {
    param([string]$PrivilegeName)

    if (-not ('Clean12.NativeTokenPrivileges' -as [type])) {
        $nativeCode = @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Clean12
{
    public static class NativeTokenPrivileges
    {
        private const UInt32 TOKEN_QUERY = 0x0008;
        private const UInt32 TOKEN_ADJUST_PRIVILEGES = 0x0020;
        private const UInt32 SE_PRIVILEGE_ENABLED = 0x00000002;
        private const Int32 ERROR_NOT_ALL_ASSIGNED = 1300;
        private static readonly UIntPtr HKEY_LOCAL_MACHINE =
            new UIntPtr(0x80000002U);

        [StructLayout(LayoutKind.Sequential)]
        private struct LUID
        {
            public UInt32 LowPart;
            public Int32 HighPart;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct TOKEN_PRIVILEGES
        {
            public UInt32 PrivilegeCount;
            public LUID Luid;
            public UInt32 Attributes;
        }

        [DllImport("kernel32.dll")]
        private static extern IntPtr GetCurrentProcess();

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool CloseHandle(IntPtr handle);

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool OpenProcessToken(
            IntPtr processHandle,
            UInt32 desiredAccess,
            out IntPtr tokenHandle
        );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool LookupPrivilegeValue(
            string systemName,
            string name,
            out LUID luid
        );

        [DllImport("advapi32.dll", SetLastError = true)]
        private static extern bool AdjustTokenPrivileges(
            IntPtr tokenHandle,
            bool disableAllPrivileges,
            ref TOKEN_PRIVILEGES newState,
            UInt32 bufferLength,
            IntPtr previousState,
            IntPtr returnLength
        );

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        private static extern Int32 RegOpenKeyEx(
            UIntPtr key,
            string subKey,
            UInt32 options,
            Int32 desiredAccess,
            out IntPtr result
        );

        [DllImport("advapi32.dll")]
        private static extern Int32 RegSetKeySecurity(
            IntPtr key,
            UInt32 securityInformation,
            byte[] securityDescriptor
        );

        [DllImport("advapi32.dll")]
        private static extern Int32 RegCloseKey(IntPtr key);

        public static void Enable(string privilegeName)
        {
            IntPtr token = IntPtr.Zero;
            try
            {
                if (!OpenProcessToken(
                    GetCurrentProcess(),
                    TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES,
                    out token
                ))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                LUID luid;
                if (!LookupPrivilegeValue(null, privilegeName, out luid))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error());
                }

                TOKEN_PRIVILEGES state = new TOKEN_PRIVILEGES();
                state.PrivilegeCount = 1;
                state.Luid = luid;
                state.Attributes = SE_PRIVILEGE_ENABLED;
                bool adjusted = AdjustTokenPrivileges(
                    token,
                    false,
                    ref state,
                    0,
                    IntPtr.Zero,
                    IntPtr.Zero
                );
                // Capture the last error immediately: AdjustTokenPrivileges
                // returns true even on partial failure (ERROR_NOT_ALL_ASSIGNED),
                // so the real result is only in GetLastError, and it must be read
                // before any other managed/native call can overwrite it.
                int error = Marshal.GetLastWin32Error();
                if (!adjusted)
                {
                    throw new Win32Exception(error);
                }
                if (error == ERROR_NOT_ALL_ASSIGNED)
                {
                    throw new Win32Exception(
                        error,
                        "The token does not contain " + privilegeName + "."
                    );
                }
                if (error != 0)
                {
                    throw new Win32Exception(error);
                }
            }
            finally
            {
                if (token != IntPtr.Zero)
                {
                    CloseHandle(token);
                }
            }
        }

        public static void SetRegistrySecurity(
            string subKey,
            byte[] securityDescriptor,
            UInt32 securityInformation,
            Int32 desiredAccess
        )
        {
            IntPtr key = IntPtr.Zero;
            Int32 result = RegOpenKeyEx(
                HKEY_LOCAL_MACHINE,
                subKey,
                0,
                desiredAccess,
                out key
            );
            if (result != 0)
            {
                throw new Win32Exception(
                    result,
                    "RegOpenKeyEx failed for HKLM\\" + subKey + "."
                );
            }
            try
            {
                result = RegSetKeySecurity(
                    key,
                    securityInformation,
                    securityDescriptor
                );
                if (result != 0)
                {
                    throw new Win32Exception(
                        result,
                        "RegSetKeySecurity failed for HKLM\\" + subKey + "."
                    );
                }
            }
            finally
            {
                RegCloseKey(key);
            }
        }
    }
}
'@
        Add-Type -TypeDefinition $nativeCode -Language CSharp
    }

    [Clean12.NativeTokenPrivileges]::Enable($PrivilegeName)
}

function Set-NativeRegistrySecurity {
    param(
        [string]$RegistryPath,
        [Security.AccessControl.RegistrySecurity]$Security,
        [uint32]$SecurityInformation,
        [int]$DesiredAccess
    )

    if (-not $RegistryPath.StartsWith(
        'HKLM:\',
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Only HKLM registry paths are supported: $RegistryPath"
    }
    $subKey = $RegistryPath.Substring(6)
    [byte[]]$binary = $Security.GetSecurityDescriptorBinaryForm()
    [Clean12.NativeTokenPrivileges]::SetRegistrySecurity(
        $subKey,
        $binary,
        $SecurityInformation,
        $DesiredAccess
    )
}

function Get-ComparableSddl {
    param([string]$Sddl)

    $daclStart = $Sddl.IndexOf('D:', [StringComparison]::Ordinal)
    if ($daclStart -lt 0) {
        return $Sddl
    }
    $flagsStart = $daclStart + 2
    $aceStart = $Sddl.IndexOf('(', $flagsStart)
    if ($aceStart -lt 0) {
        $aceStart = $Sddl.Length
    }
    $flags = $Sddl.Substring($flagsStart, $aceStart - $flagsStart)
    $normalizedFlags = $flags.Replace('AI', '')
    return (
        $Sddl.Substring(0, $flagsStart) +
        $normalizedFlags +
        $Sddl.Substring($aceStart)
    )
}

function Set-CbsVisibilityValue {
    param(
        [string]$RegistryPath,
        [int]$Value,
        [string]$AclBackupPath,
        [bool]$AllowTemporaryAccess
    )

    $accessSections =
        [Security.AccessControl.AccessControlSections]::Owner -bor
        [Security.AccessControl.AccessControlSections]::Access
    # Windows 7 PowerShell 2.0 Get-Acl exposes -Path, not -LiteralPath.
    # Registry package identities contain no wildcard characters.
    $originalAcl = Get-Acl -Path $RegistryPath
    $originalSddl = $originalAcl.GetSecurityDescriptorSddlForm($accessSections)
    $originalSddl | Out-File -FilePath $AclBackupPath -Encoding ASCII

    $aclChanged = $false
    try {
        try {
            Set-ItemProperty -LiteralPath $RegistryPath `
                -Name Visibility `
                -Value $Value `
                -ErrorAction Stop
            return
        }
        catch {
            if (-not $AllowTemporaryAccess) {
                throw
            }
        }

        Enable-ProcessPrivilege -PrivilegeName 'SeTakeOwnershipPrivilege'
        Enable-ProcessPrivilege -PrivilegeName 'SeRestorePrivilege'

        $administratorsSid = New-Object Security.Principal.SecurityIdentifier(
            'S-1-5-32-544'
        )

        $ownerAcl = New-Object Security.AccessControl.RegistrySecurity
        $ownerAcl.SetSecurityDescriptorSddlForm(
            $originalSddl,
            $accessSections
        )
        $ownerAcl.SetOwner($administratorsSid)
        Set-NativeRegistrySecurity `
            -RegistryPath $RegistryPath `
            -Security $ownerAcl `
            -SecurityInformation 0x00000001 `
            -DesiredAccess 0x00080000
        $aclChanged = $true

        $writeAcl = Get-Acl -Path $RegistryPath
        $writeRule = New-Object Security.AccessControl.RegistryAccessRule(
            $administratorsSid,
            [Security.AccessControl.RegistryRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$writeAcl.SetAccessRule($writeRule)
        Set-NativeRegistrySecurity `
            -RegistryPath $RegistryPath `
            -Security $writeAcl `
            -SecurityInformation 0x00000004 `
            -DesiredAccess 0x00040000

        Set-ItemProperty -LiteralPath $RegistryPath `
            -Name Visibility `
            -Value $Value `
            -ErrorAction Stop
    }
    finally {
        if ($aclChanged) {
            $restoreAcl = New-Object Security.AccessControl.RegistrySecurity
            $restoreAcl.SetSecurityDescriptorSddlForm(
                $originalSddl,
                $accessSections
            )
            Set-NativeRegistrySecurity `
                -RegistryPath $RegistryPath `
                -Security $restoreAcl `
                -SecurityInformation 0x00000005 `
                -DesiredAccess 0x000C0000

            $restoredAcl = Get-Acl -Path $RegistryPath
            $restoredSddl =
                $restoredAcl.GetSecurityDescriptorSddlForm($accessSections)
            $restoredSddl |
                Out-File -FilePath ($AclBackupPath + '.restored.txt') `
                    -Encoding ASCII

            # Treat a DACL_AUTO_INHERITED marker-only normalization as
            # equivalent; any owner or ACE difference still fails. Scope the
            # normalization to the DACL flags segment (between "D:" and its
            # first ACE "(") so a literal "AI" elsewhere in the descriptor
            # cannot mask a real difference.
            $originalComparable = Get-ComparableSddl -Sddl $originalSddl
            $restoredComparable = Get-ComparableSddl -Sddl $restoredSddl
            if ($restoredComparable -ne $originalComparable) {
                throw (
                    'Owner/DACL semantic restoration verification failed. Restore from: {0}' -f
                    $AclBackupPath
                )
            }
        }
    }
}


# ---- LEVEL 1: restore visibility with proper TrustedInstaller takeover ----
Write-Host 'Restoring visibility of KB3125574 packages (Visibility=1)...'
$restored = 0; $failed = 0
$aclBackupDir = Join-Path $env:TEMP 'kb3125574_uninstall_acl'
if (-not (Test-Path $aclBackupDir)) { New-Item -ItemType Directory -Path $aclBackupDir -Force | Out-Null }
foreach ($n in $nums) {
    $keys = Get-ChildItem -Path $cbsRoot -ErrorAction SilentlyContinue |
            Where-Object { (Split-Path $_.Name -Leaf) -match ("^Package_{0}_for_KB3125574~" -f $n) }
    foreach ($k in $keys) {
        $leaf = Split-Path $k.Name -Leaf
        # NOTE: do NOT use $k.PSPath here. It is provider-qualified
        # (Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\...)
        # and fails the 'HKLM:\' guard in Set-NativeRegistrySecurity,
        # which made the default restore path fail on every key.
        $regPath = Join-Path $cbsRoot $leaf
        $aclBackup = Join-Path $aclBackupDir ($leaf + '.sddl')
        try {
            Set-CbsVisibilityValue -RegistryPath $regPath -Value 1 -AclBackupPath $aclBackup -AllowTemporaryAccess $true
            $restored++
        }
        catch {
            $failed++
            Write-Warning ("[{0}] restore failed: {1}" -f $leaf, $_.Exception.Message)
        }
    }
}
if ($failed -eq 0) {
    Write-Host ("Done. Visibility restored on {0} package key(s); updates are visible again." -f $restored) -ForegroundColor Green
} else {
    Write-Host ("Restored {0}, failed {1}. See warnings above." -f $restored, $failed) -ForegroundColor Yellow
}

# ---- LEVEL 2 (OPTIONAL, HIGH RISK): full package removal ----
if ($RemovePackages) {
    Write-Host ''
    Write-Host 'WARNING: removing these packages rolls terminal components back to older/missing' -ForegroundColor Yellow
    Write-Host 'versions and MAY BREAK the system or later updates that depend on them.' -ForegroundColor Yellow
    if ((Read-Host 'Type REMOVE to proceed, anything else to cancel') -ne 'REMOVE') { Write-Host 'Cancelled.'; exit 0 }
    foreach ($n in $nums) {
        $keys = Get-ChildItem -Path $cbsRoot -ErrorAction SilentlyContinue |
                Where-Object { (Split-Path $_.Name -Leaf) -match ("^Package_{0}_for_KB3125574~" -f $n) }
        foreach ($k in $keys) {
            $name = Split-Path $k.Name -Leaf
            Write-Host ("Removing {0} ..." -f $name)
            & dism /online /Remove-Package /PackageName:$name /NoRestart | Out-Null
        }
    }
    Write-Host 'Package removal submitted. Reboot to complete.' -ForegroundColor Cyan
}
