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
    [switch]$Show
)

$ErrorActionPreference = 'Stop'
$targetVis = if ($Show) { 1 } else { 2 }

# ---- uninstaller generator (writes Uninstall-KB3125574-Lite.{ps1,cmd} + README) ----
# The .ps1 body includes full TrustedInstaller-takeover logic so the visibility
# restore actually works (a plain Set-ItemProperty is blocked by the CBS ACL).
# Body and bilingual README are embedded base64 to avoid here-string nesting with
# the inlined C# block.
function Write-UninstallScript {
    param(
        [Parameter(Mandatory=$true)][string]$RootDir,
        [Parameter(Mandatory=$true)][int[]]$Numbers
    )
    if (-not (Test-Path -LiteralPath $RootDir)) { Write-Warning "[uninstall] root not found: $RootDir"; return }
    $numList = (($Numbers | Sort-Object -Unique) | ForEach-Object { $_.ToString() }) -join ','

    $bodyB64 = @'
IyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09CiMgVW5pbnN0YWxsLUtCMzEyNTU3NC1MaXRlLnBzMQojIFNl
ZSBVbmluc3RhbGwtUkVBRE1FLnR4dCAobmV4dCB0byB0aGlzIGZpbGUpIGZvciBiaWxpbmd1YWwg
dXNhZ2Ugbm90ZXMuCiMgUnVuIGFzIEFkbWluaXN0cmF0b3IuIERlZmF1bHQgPSByZXN0b3JlIHZp
c2liaWxpdHkgKHNhZmUpLiAtUmVtb3ZlUGFja2FnZXMgPQojIHJlbW92ZSBwYWNrYWdlcyAoaGln
aCByaXNrLCB0eXBlIFJFTU9WRSB0byBjb25maXJtKS4KIyA9PT09PT09PT09PT09PT09PT09PT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CiMg
VW5pbnN0YWxsLUtCMzEyNTU3NC1MaXRlLnBzMSAgKGF1dG8tZ2VuZXJhdGVkKQojIFJldmVydHMg
dGhlIEtCMzEyNTU3NC1MaXRlIGludGVncmF0aW9uIG9uIHRoaXMgc3lzdGVtLiBSdW4gYXMgQWRt
aW5pc3RyYXRvci4KIwojIExFVkVMIDEgKGRlZmF1bHQpOiByZXN0b3JlIHVwZGF0ZSB2aXNpYmls
aXR5IChWaXNpYmlsaXR5PTEpIHNvIHRoZSBLQjMxMjU1NzQKIyAgIHVwZGF0ZXMgYXBwZWFyIGFn
YWluIGluIEluc3RhbGxlZCBVcGRhdGVzLiBTYWZlLCByZXZlcnNpYmxlLCByZW1vdmVzIG5vdGhp
bmcuCiMgICBUaGUgQ0JTIFBhY2thZ2Uga2V5cyBhcmUgb3duZWQgYnkgVHJ1c3RlZEluc3RhbGxl
ciwgc28gdGhpcyBzY3JpcHQgdGVtcG9yYXJpbHkKIyAgIHRha2VzIG93bmVyc2hpcCwgd3JpdGVz
IHRoZSB2YWx1ZSwgdGhlbiByZXN0b3JlcyB0aGUgb3JpZ2luYWwgb3duZXIgYW5kIEFDTC4KIyBM
RVZFTCAyICgtUmVtb3ZlUGFja2FnZXMpOiBhZGRpdGlvbmFsbHkgcmVtb3ZlIHRoZSBwYWNrYWdl
cyB2aWEgRElTTS4gSGlnaCByaXNrLgpwYXJhbShbc3dpdGNoXSRSZW1vdmVQYWNrYWdlcykKJEVy
cm9yQWN0aW9uUHJlZmVyZW5jZSA9ICdTdG9wJwokbnVtcyA9IEAoX19OVU1TX18pCiRjYnNSb290
ID0gJ0hLTE06XFNPRlRXQVJFXE1pY3Jvc29mdFxXaW5kb3dzXEN1cnJlbnRWZXJzaW9uXENvbXBv
bmVudCBCYXNlZCBTZXJ2aWNpbmdcUGFja2FnZXMnCgokaWQgPSBbU2VjdXJpdHkuUHJpbmNpcGFs
LldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKQppZiAoLW5vdCAoTmV3LU9iamVjdCBTZWN1
cml0eS5QcmluY2lwYWwuV2luZG93c1ByaW5jaXBhbCgkaWQpKS5Jc0luUm9sZShbU2VjdXJpdHku
UHJpbmNpcGFsLldpbmRvd3NCdWlsdEluUm9sZV06OkFkbWluaXN0cmF0b3IpKSB7CiAgICBXcml0
ZS1Ib3N0ICdQbGVhc2UgcnVuIGFzIEFkbWluaXN0cmF0b3IuJyAtRm9yZWdyb3VuZENvbG9yIFJl
ZDsgZXhpdCAxCn0KCmZ1bmN0aW9uIEVuYWJsZS1Qcm9jZXNzUHJpdmlsZWdlIHsKICAgIHBhcmFt
KFtzdHJpbmddJFByaXZpbGVnZU5hbWUpCgogICAgaWYgKC1ub3QgKCdDbGVhbjEyLk5hdGl2ZVRv
a2VuUHJpdmlsZWdlcycgLWFzIFt0eXBlXSkpIHsKICAgICAgICAkbmF0aXZlQ29kZSA9IEAnCnVz
aW5nIFN5c3RlbTsKdXNpbmcgU3lzdGVtLkNvbXBvbmVudE1vZGVsOwp1c2luZyBTeXN0ZW0uUnVu
dGltZS5JbnRlcm9wU2VydmljZXM7CgpuYW1lc3BhY2UgQ2xlYW4xMgp7CiAgICBwdWJsaWMgc3Rh
dGljIGNsYXNzIE5hdGl2ZVRva2VuUHJpdmlsZWdlcwogICAgewogICAgICAgIHByaXZhdGUgY29u
c3QgVUludDMyIFRPS0VOX1FVRVJZID0gMHgwMDA4OwogICAgICAgIHByaXZhdGUgY29uc3QgVUlu
dDMyIFRPS0VOX0FESlVTVF9QUklWSUxFR0VTID0gMHgwMDIwOwogICAgICAgIHByaXZhdGUgY29u
c3QgVUludDMyIFNFX1BSSVZJTEVHRV9FTkFCTEVEID0gMHgwMDAwMDAwMjsKICAgICAgICBwcml2
YXRlIGNvbnN0IEludDMyIEVSUk9SX05PVF9BTExfQVNTSUdORUQgPSAxMzAwOwogICAgICAgIHBy
aXZhdGUgc3RhdGljIHJlYWRvbmx5IFVJbnRQdHIgSEtFWV9MT0NBTF9NQUNISU5FID0KICAgICAg
ICAgICAgbmV3IFVJbnRQdHIoMHg4MDAwMDAwMlUpOwoKICAgICAgICBbU3RydWN0TGF5b3V0KExh
eW91dEtpbmQuU2VxdWVudGlhbCldCiAgICAgICAgcHJpdmF0ZSBzdHJ1Y3QgTFVJRAogICAgICAg
IHsKICAgICAgICAgICAgcHVibGljIFVJbnQzMiBMb3dQYXJ0OwogICAgICAgICAgICBwdWJsaWMg
SW50MzIgSGlnaFBhcnQ7CiAgICAgICAgfQoKICAgICAgICBbU3RydWN0TGF5b3V0KExheW91dEtp
bmQuU2VxdWVudGlhbCldCiAgICAgICAgcHJpdmF0ZSBzdHJ1Y3QgVE9LRU5fUFJJVklMRUdFUwog
ICAgICAgIHsKICAgICAgICAgICAgcHVibGljIFVJbnQzMiBQcml2aWxlZ2VDb3VudDsKICAgICAg
ICAgICAgcHVibGljIExVSUQgTHVpZDsKICAgICAgICAgICAgcHVibGljIFVJbnQzMiBBdHRyaWJ1
dGVzOwogICAgICAgIH0KCiAgICAgICAgW0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildCiAgICAg
ICAgcHJpdmF0ZSBzdGF0aWMgZXh0ZXJuIEludFB0ciBHZXRDdXJyZW50UHJvY2VzcygpOwoKICAg
ICAgICBbRGxsSW1wb3J0KCJrZXJuZWwzMi5kbGwiLCBTZXRMYXN0RXJyb3IgPSB0cnVlKV0KICAg
ICAgICBwcml2YXRlIHN0YXRpYyBleHRlcm4gYm9vbCBDbG9zZUhhbmRsZShJbnRQdHIgaGFuZGxl
KTsKCiAgICAgICAgW0RsbEltcG9ydCgiYWR2YXBpMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1
ZSldCiAgICAgICAgcHJpdmF0ZSBzdGF0aWMgZXh0ZXJuIGJvb2wgT3BlblByb2Nlc3NUb2tlbigK
ICAgICAgICAgICAgSW50UHRyIHByb2Nlc3NIYW5kbGUsCiAgICAgICAgICAgIFVJbnQzMiBkZXNp
cmVkQWNjZXNzLAogICAgICAgICAgICBvdXQgSW50UHRyIHRva2VuSGFuZGxlCiAgICAgICAgKTsK
CiAgICAgICAgW0RsbEltcG9ydCgiYWR2YXBpMzIuZGxsIiwgQ2hhclNldCA9IENoYXJTZXQuVW5p
Y29kZSwgU2V0TGFzdEVycm9yID0gdHJ1ZSldCiAgICAgICAgcHJpdmF0ZSBzdGF0aWMgZXh0ZXJu
IGJvb2wgTG9va3VwUHJpdmlsZWdlVmFsdWUoCiAgICAgICAgICAgIHN0cmluZyBzeXN0ZW1OYW1l
LAogICAgICAgICAgICBzdHJpbmcgbmFtZSwKICAgICAgICAgICAgb3V0IExVSUQgbHVpZAogICAg
ICAgICk7CgogICAgICAgIFtEbGxJbXBvcnQoImFkdmFwaTMyLmRsbCIsIFNldExhc3RFcnJvciA9
IHRydWUpXQogICAgICAgIHByaXZhdGUgc3RhdGljIGV4dGVybiBib29sIEFkanVzdFRva2VuUHJp
dmlsZWdlcygKICAgICAgICAgICAgSW50UHRyIHRva2VuSGFuZGxlLAogICAgICAgICAgICBib29s
IGRpc2FibGVBbGxQcml2aWxlZ2VzLAogICAgICAgICAgICByZWYgVE9LRU5fUFJJVklMRUdFUyBu
ZXdTdGF0ZSwKICAgICAgICAgICAgVUludDMyIGJ1ZmZlckxlbmd0aCwKICAgICAgICAgICAgSW50
UHRyIHByZXZpb3VzU3RhdGUsCiAgICAgICAgICAgIEludFB0ciByZXR1cm5MZW5ndGgKICAgICAg
ICApOwoKICAgICAgICBbRGxsSW1wb3J0KCJhZHZhcGkzMi5kbGwiLCBDaGFyU2V0ID0gQ2hhclNl
dC5Vbmljb2RlKV0KICAgICAgICBwcml2YXRlIHN0YXRpYyBleHRlcm4gSW50MzIgUmVnT3Blbktl
eUV4KAogICAgICAgICAgICBVSW50UHRyIGtleSwKICAgICAgICAgICAgc3RyaW5nIHN1YktleSwK
ICAgICAgICAgICAgVUludDMyIG9wdGlvbnMsCiAgICAgICAgICAgIEludDMyIGRlc2lyZWRBY2Nl
c3MsCiAgICAgICAgICAgIG91dCBJbnRQdHIgcmVzdWx0CiAgICAgICAgKTsKCiAgICAgICAgW0Rs
bEltcG9ydCgiYWR2YXBpMzIuZGxsIildCiAgICAgICAgcHJpdmF0ZSBzdGF0aWMgZXh0ZXJuIElu
dDMyIFJlZ1NldEtleVNlY3VyaXR5KAogICAgICAgICAgICBJbnRQdHIga2V5LAogICAgICAgICAg
ICBVSW50MzIgc2VjdXJpdHlJbmZvcm1hdGlvbiwKICAgICAgICAgICAgYnl0ZVtdIHNlY3VyaXR5
RGVzY3JpcHRvcgogICAgICAgICk7CgogICAgICAgIFtEbGxJbXBvcnQoImFkdmFwaTMyLmRsbCIp
XQogICAgICAgIHByaXZhdGUgc3RhdGljIGV4dGVybiBJbnQzMiBSZWdDbG9zZUtleShJbnRQdHIg
a2V5KTsKCiAgICAgICAgcHVibGljIHN0YXRpYyB2b2lkIEVuYWJsZShzdHJpbmcgcHJpdmlsZWdl
TmFtZSkKICAgICAgICB7CiAgICAgICAgICAgIEludFB0ciB0b2tlbiA9IEludFB0ci5aZXJvOwog
ICAgICAgICAgICB0cnkKICAgICAgICAgICAgewogICAgICAgICAgICAgICAgaWYgKCFPcGVuUHJv
Y2Vzc1Rva2VuKAogICAgICAgICAgICAgICAgICAgIEdldEN1cnJlbnRQcm9jZXNzKCksCiAgICAg
ICAgICAgICAgICAgICAgVE9LRU5fUVVFUlkgfCBUT0tFTl9BREpVU1RfUFJJVklMRUdFUywKICAg
ICAgICAgICAgICAgICAgICBvdXQgdG9rZW4KICAgICAgICAgICAgICAgICkpCiAgICAgICAgICAg
ICAgICB7CiAgICAgICAgICAgICAgICAgICAgdGhyb3cgbmV3IFdpbjMyRXhjZXB0aW9uKE1hcnNo
YWwuR2V0TGFzdFdpbjMyRXJyb3IoKSk7CiAgICAgICAgICAgICAgICB9CgogICAgICAgICAgICAg
ICAgTFVJRCBsdWlkOwogICAgICAgICAgICAgICAgaWYgKCFMb29rdXBQcml2aWxlZ2VWYWx1ZShu
dWxsLCBwcml2aWxlZ2VOYW1lLCBvdXQgbHVpZCkpCiAgICAgICAgICAgICAgICB7CiAgICAgICAg
ICAgICAgICAgICAgdGhyb3cgbmV3IFdpbjMyRXhjZXB0aW9uKE1hcnNoYWwuR2V0TGFzdFdpbjMy
RXJyb3IoKSk7CiAgICAgICAgICAgICAgICB9CgogICAgICAgICAgICAgICAgVE9LRU5fUFJJVklM
RUdFUyBzdGF0ZSA9IG5ldyBUT0tFTl9QUklWSUxFR0VTKCk7CiAgICAgICAgICAgICAgICBzdGF0
ZS5Qcml2aWxlZ2VDb3VudCA9IDE7CiAgICAgICAgICAgICAgICBzdGF0ZS5MdWlkID0gbHVpZDsK
ICAgICAgICAgICAgICAgIHN0YXRlLkF0dHJpYnV0ZXMgPSBTRV9QUklWSUxFR0VfRU5BQkxFRDsK
ICAgICAgICAgICAgICAgIGJvb2wgYWRqdXN0ZWQgPSBBZGp1c3RUb2tlblByaXZpbGVnZXMoCiAg
ICAgICAgICAgICAgICAgICAgdG9rZW4sCiAgICAgICAgICAgICAgICAgICAgZmFsc2UsCiAgICAg
ICAgICAgICAgICAgICAgcmVmIHN0YXRlLAogICAgICAgICAgICAgICAgICAgIDAsCiAgICAgICAg
ICAgICAgICAgICAgSW50UHRyLlplcm8sCiAgICAgICAgICAgICAgICAgICAgSW50UHRyLlplcm8K
ICAgICAgICAgICAgICAgICk7CiAgICAgICAgICAgICAgICAvLyBDYXB0dXJlIHRoZSBsYXN0IGVy
cm9yIGltbWVkaWF0ZWx5OiBBZGp1c3RUb2tlblByaXZpbGVnZXMKICAgICAgICAgICAgICAgIC8v
IHJldHVybnMgdHJ1ZSBldmVuIG9uIHBhcnRpYWwgZmFpbHVyZSAoRVJST1JfTk9UX0FMTF9BU1NJ
R05FRCksCiAgICAgICAgICAgICAgICAvLyBzbyB0aGUgcmVhbCByZXN1bHQgaXMgb25seSBpbiBH
ZXRMYXN0RXJyb3IsIGFuZCBpdCBtdXN0IGJlIHJlYWQKICAgICAgICAgICAgICAgIC8vIGJlZm9y
ZSBhbnkgb3RoZXIgbWFuYWdlZC9uYXRpdmUgY2FsbCBjYW4gb3ZlcndyaXRlIGl0LgogICAgICAg
ICAgICAgICAgaW50IGVycm9yID0gTWFyc2hhbC5HZXRMYXN0V2luMzJFcnJvcigpOwogICAgICAg
ICAgICAgICAgaWYgKCFhZGp1c3RlZCkKICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAg
ICAgICB0aHJvdyBuZXcgV2luMzJFeGNlcHRpb24oZXJyb3IpOwogICAgICAgICAgICAgICAgfQog
ICAgICAgICAgICAgICAgaWYgKGVycm9yID09IEVSUk9SX05PVF9BTExfQVNTSUdORUQpCiAgICAg
ICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgdGhyb3cgbmV3IFdpbjMyRXhjZXB0aW9u
KAogICAgICAgICAgICAgICAgICAgICAgICBlcnJvciwKICAgICAgICAgICAgICAgICAgICAgICAg
IlRoZSB0b2tlbiBkb2VzIG5vdCBjb250YWluICIgKyBwcml2aWxlZ2VOYW1lICsgIi4iCiAgICAg
ICAgICAgICAgICAgICAgKTsKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIGlmIChl
cnJvciAhPSAwKQogICAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgICAgIHRocm93IG5l
dyBXaW4zMkV4Y2VwdGlvbihlcnJvcik7CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0K
ICAgICAgICAgICAgZmluYWxseQogICAgICAgICAgICB7CiAgICAgICAgICAgICAgICBpZiAodG9r
ZW4gIT0gSW50UHRyLlplcm8pCiAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAg
Q2xvc2VIYW5kbGUodG9rZW4pOwogICAgICAgICAgICAgICAgfQogICAgICAgICAgICB9CiAgICAg
ICAgfQoKICAgICAgICBwdWJsaWMgc3RhdGljIHZvaWQgU2V0UmVnaXN0cnlTZWN1cml0eSgKICAg
ICAgICAgICAgc3RyaW5nIHN1YktleSwKICAgICAgICAgICAgYnl0ZVtdIHNlY3VyaXR5RGVzY3Jp
cHRvciwKICAgICAgICAgICAgVUludDMyIHNlY3VyaXR5SW5mb3JtYXRpb24sCiAgICAgICAgICAg
IEludDMyIGRlc2lyZWRBY2Nlc3MKICAgICAgICApCiAgICAgICAgewogICAgICAgICAgICBJbnRQ
dHIga2V5ID0gSW50UHRyLlplcm87CiAgICAgICAgICAgIEludDMyIHJlc3VsdCA9IFJlZ09wZW5L
ZXlFeCgKICAgICAgICAgICAgICAgIEhLRVlfTE9DQUxfTUFDSElORSwKICAgICAgICAgICAgICAg
IHN1YktleSwKICAgICAgICAgICAgICAgIDAsCiAgICAgICAgICAgICAgICBkZXNpcmVkQWNjZXNz
LAogICAgICAgICAgICAgICAgb3V0IGtleQogICAgICAgICAgICApOwogICAgICAgICAgICBpZiAo
cmVzdWx0ICE9IDApCiAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgIHRocm93IG5ldyBXaW4z
MkV4Y2VwdGlvbigKICAgICAgICAgICAgICAgICAgICByZXN1bHQsCiAgICAgICAgICAgICAgICAg
ICAgIlJlZ09wZW5LZXlFeCBmYWlsZWQgZm9yIEhLTE1cXCIgKyBzdWJLZXkgKyAiLiIKICAgICAg
ICAgICAgICAgICk7CiAgICAgICAgICAgIH0KICAgICAgICAgICAgdHJ5CiAgICAgICAgICAgIHsK
ICAgICAgICAgICAgICAgIHJlc3VsdCA9IFJlZ1NldEtleVNlY3VyaXR5KAogICAgICAgICAgICAg
ICAgICAgIGtleSwKICAgICAgICAgICAgICAgICAgICBzZWN1cml0eUluZm9ybWF0aW9uLAogICAg
ICAgICAgICAgICAgICAgIHNlY3VyaXR5RGVzY3JpcHRvcgogICAgICAgICAgICAgICAgKTsKICAg
ICAgICAgICAgICAgIGlmIChyZXN1bHQgIT0gMCkKICAgICAgICAgICAgICAgIHsKICAgICAgICAg
ICAgICAgICAgICB0aHJvdyBuZXcgV2luMzJFeGNlcHRpb24oCiAgICAgICAgICAgICAgICAgICAg
ICAgIHJlc3VsdCwKICAgICAgICAgICAgICAgICAgICAgICAgIlJlZ1NldEtleVNlY3VyaXR5IGZh
aWxlZCBmb3IgSEtMTVxcIiArIHN1YktleSArICIuIgogICAgICAgICAgICAgICAgICAgICk7CiAg
ICAgICAgICAgICAgICB9CiAgICAgICAgICAgIH0KICAgICAgICAgICAgZmluYWxseQogICAgICAg
ICAgICB7CiAgICAgICAgICAgICAgICBSZWdDbG9zZUtleShrZXkpOwogICAgICAgICAgICB9CiAg
ICAgICAgfQogICAgfQp9CidACiAgICAgICAgQWRkLVR5cGUgLVR5cGVEZWZpbml0aW9uICRuYXRp
dmVDb2RlIC1MYW5ndWFnZSBDU2hhcnAKICAgIH0KCiAgICBbQ2xlYW4xMi5OYXRpdmVUb2tlblBy
aXZpbGVnZXNdOjpFbmFibGUoJFByaXZpbGVnZU5hbWUpCn0KCmZ1bmN0aW9uIFNldC1OYXRpdmVS
ZWdpc3RyeVNlY3VyaXR5IHsKICAgIHBhcmFtKAogICAgICAgIFtzdHJpbmddJFJlZ2lzdHJ5UGF0
aCwKICAgICAgICBbU2VjdXJpdHkuQWNjZXNzQ29udHJvbC5SZWdpc3RyeVNlY3VyaXR5XSRTZWN1
cml0eSwKICAgICAgICBbdWludDMyXSRTZWN1cml0eUluZm9ybWF0aW9uLAogICAgICAgIFtpbnRd
JERlc2lyZWRBY2Nlc3MKICAgICkKCiAgICBpZiAoLW5vdCAkUmVnaXN0cnlQYXRoLlN0YXJ0c1dp
dGgoCiAgICAgICAgJ0hLTE06XCcsCiAgICAgICAgW1N0cmluZ0NvbXBhcmlzb25dOjpPcmRpbmFs
SWdub3JlQ2FzZQogICAgKSkgewogICAgICAgIHRocm93ICJPbmx5IEhLTE0gcmVnaXN0cnkgcGF0
aHMgYXJlIHN1cHBvcnRlZDogJFJlZ2lzdHJ5UGF0aCIKICAgIH0KICAgICRzdWJLZXkgPSAkUmVn
aXN0cnlQYXRoLlN1YnN0cmluZyg2KQogICAgW2J5dGVbXV0kYmluYXJ5ID0gJFNlY3VyaXR5Lkdl
dFNlY3VyaXR5RGVzY3JpcHRvckJpbmFyeUZvcm0oKQogICAgW0NsZWFuMTIuTmF0aXZlVG9rZW5Q
cml2aWxlZ2VzXTo6U2V0UmVnaXN0cnlTZWN1cml0eSgKICAgICAgICAkc3ViS2V5LAogICAgICAg
ICRiaW5hcnksCiAgICAgICAgJFNlY3VyaXR5SW5mb3JtYXRpb24sCiAgICAgICAgJERlc2lyZWRB
Y2Nlc3MKICAgICkKfQoKZnVuY3Rpb24gR2V0LUNvbXBhcmFibGVTZGRsIHsKICAgIHBhcmFtKFtz
dHJpbmddJFNkZGwpCgogICAgJGRhY2xTdGFydCA9ICRTZGRsLkluZGV4T2YoJ0Q6JywgW1N0cmlu
Z0NvbXBhcmlzb25dOjpPcmRpbmFsKQogICAgaWYgKCRkYWNsU3RhcnQgLWx0IDApIHsKICAgICAg
ICByZXR1cm4gJFNkZGwKICAgIH0KICAgICRmbGFnc1N0YXJ0ID0gJGRhY2xTdGFydCArIDIKICAg
ICRhY2VTdGFydCA9ICRTZGRsLkluZGV4T2YoJygnLCAkZmxhZ3NTdGFydCkKICAgIGlmICgkYWNl
U3RhcnQgLWx0IDApIHsKICAgICAgICAkYWNlU3RhcnQgPSAkU2RkbC5MZW5ndGgKICAgIH0KICAg
ICRmbGFncyA9ICRTZGRsLlN1YnN0cmluZygkZmxhZ3NTdGFydCwgJGFjZVN0YXJ0IC0gJGZsYWdz
U3RhcnQpCiAgICAkbm9ybWFsaXplZEZsYWdzID0gJGZsYWdzLlJlcGxhY2UoJ0FJJywgJycpCiAg
ICByZXR1cm4gKAogICAgICAgICRTZGRsLlN1YnN0cmluZygwLCAkZmxhZ3NTdGFydCkgKwogICAg
ICAgICRub3JtYWxpemVkRmxhZ3MgKwogICAgICAgICRTZGRsLlN1YnN0cmluZygkYWNlU3RhcnQp
CiAgICApCn0KCmZ1bmN0aW9uIFNldC1DYnNWaXNpYmlsaXR5VmFsdWUgewogICAgcGFyYW0oCiAg
ICAgICAgW3N0cmluZ10kUmVnaXN0cnlQYXRoLAogICAgICAgIFtpbnRdJFZhbHVlLAogICAgICAg
IFtzdHJpbmddJEFjbEJhY2t1cFBhdGgsCiAgICAgICAgW2Jvb2xdJEFsbG93VGVtcG9yYXJ5QWNj
ZXNzCiAgICApCgogICAgJGFjY2Vzc1NlY3Rpb25zID0KICAgICAgICBbU2VjdXJpdHkuQWNjZXNz
Q29udHJvbC5BY2Nlc3NDb250cm9sU2VjdGlvbnNdOjpPd25lciAtYm9yCiAgICAgICAgW1NlY3Vy
aXR5LkFjY2Vzc0NvbnRyb2wuQWNjZXNzQ29udHJvbFNlY3Rpb25zXTo6QWNjZXNzCiAgICAjIFdp
bmRvd3MgNyBQb3dlclNoZWxsIDIuMCBHZXQtQWNsIGV4cG9zZXMgLVBhdGgsIG5vdCAtTGl0ZXJh
bFBhdGguCiAgICAjIFJlZ2lzdHJ5IHBhY2thZ2UgaWRlbnRpdGllcyBjb250YWluIG5vIHdpbGRj
YXJkIGNoYXJhY3RlcnMuCiAgICAkb3JpZ2luYWxBY2wgPSBHZXQtQWNsIC1QYXRoICRSZWdpc3Ry
eVBhdGgKICAgICRvcmlnaW5hbFNkZGwgPSAkb3JpZ2luYWxBY2wuR2V0U2VjdXJpdHlEZXNjcmlw
dG9yU2RkbEZvcm0oJGFjY2Vzc1NlY3Rpb25zKQogICAgJG9yaWdpbmFsU2RkbCB8IE91dC1GaWxl
IC1GaWxlUGF0aCAkQWNsQmFja3VwUGF0aCAtRW5jb2RpbmcgQVNDSUkKCiAgICAkYWNsQ2hhbmdl
ZCA9ICRmYWxzZQogICAgdHJ5IHsKICAgICAgICB0cnkgewogICAgICAgICAgICBTZXQtSXRlbVBy
b3BlcnR5IC1MaXRlcmFsUGF0aCAkUmVnaXN0cnlQYXRoIGAKICAgICAgICAgICAgICAgIC1OYW1l
IFZpc2liaWxpdHkgYAogICAgICAgICAgICAgICAgLVZhbHVlICRWYWx1ZSBgCiAgICAgICAgICAg
ICAgICAtRXJyb3JBY3Rpb24gU3RvcAogICAgICAgICAgICByZXR1cm4KICAgICAgICB9CiAgICAg
ICAgY2F0Y2ggewogICAgICAgICAgICBpZiAoLW5vdCAkQWxsb3dUZW1wb3JhcnlBY2Nlc3MpIHsK
ICAgICAgICAgICAgICAgIHRocm93CiAgICAgICAgICAgIH0KICAgICAgICB9CgogICAgICAgIEVu
YWJsZS1Qcm9jZXNzUHJpdmlsZWdlIC1Qcml2aWxlZ2VOYW1lICdTZVRha2VPd25lcnNoaXBQcml2
aWxlZ2UnCiAgICAgICAgRW5hYmxlLVByb2Nlc3NQcml2aWxlZ2UgLVByaXZpbGVnZU5hbWUgJ1Nl
UmVzdG9yZVByaXZpbGVnZScKCiAgICAgICAgJGFkbWluaXN0cmF0b3JzU2lkID0gTmV3LU9iamVj
dCBTZWN1cml0eS5QcmluY2lwYWwuU2VjdXJpdHlJZGVudGlmaWVyKAogICAgICAgICAgICAnUy0x
LTUtMzItNTQ0JwogICAgICAgICkKCiAgICAgICAgJG93bmVyQWNsID0gTmV3LU9iamVjdCBTZWN1
cml0eS5BY2Nlc3NDb250cm9sLlJlZ2lzdHJ5U2VjdXJpdHkKICAgICAgICAkb3duZXJBY2wuU2V0
U2VjdXJpdHlEZXNjcmlwdG9yU2RkbEZvcm0oCiAgICAgICAgICAgICRvcmlnaW5hbFNkZGwsCiAg
ICAgICAgICAgICRhY2Nlc3NTZWN0aW9ucwogICAgICAgICkKICAgICAgICAkb3duZXJBY2wuU2V0
T3duZXIoJGFkbWluaXN0cmF0b3JzU2lkKQogICAgICAgIFNldC1OYXRpdmVSZWdpc3RyeVNlY3Vy
aXR5IGAKICAgICAgICAgICAgLVJlZ2lzdHJ5UGF0aCAkUmVnaXN0cnlQYXRoIGAKICAgICAgICAg
ICAgLVNlY3VyaXR5ICRvd25lckFjbCBgCiAgICAgICAgICAgIC1TZWN1cml0eUluZm9ybWF0aW9u
IDB4MDAwMDAwMDEgYAogICAgICAgICAgICAtRGVzaXJlZEFjY2VzcyAweDAwMDgwMDAwCiAgICAg
ICAgJGFjbENoYW5nZWQgPSAkdHJ1ZQoKICAgICAgICAkd3JpdGVBY2wgPSBHZXQtQWNsIC1QYXRo
ICRSZWdpc3RyeVBhdGgKICAgICAgICAkd3JpdGVSdWxlID0gTmV3LU9iamVjdCBTZWN1cml0eS5B
Y2Nlc3NDb250cm9sLlJlZ2lzdHJ5QWNjZXNzUnVsZSgKICAgICAgICAgICAgJGFkbWluaXN0cmF0
b3JzU2lkLAogICAgICAgICAgICBbU2VjdXJpdHkuQWNjZXNzQ29udHJvbC5SZWdpc3RyeVJpZ2h0
c106OkZ1bGxDb250cm9sLAogICAgICAgICAgICBbU2VjdXJpdHkuQWNjZXNzQ29udHJvbC5BY2Nl
c3NDb250cm9sVHlwZV06OkFsbG93CiAgICAgICAgKQogICAgICAgIFt2b2lkXSR3cml0ZUFjbC5T
ZXRBY2Nlc3NSdWxlKCR3cml0ZVJ1bGUpCiAgICAgICAgU2V0LU5hdGl2ZVJlZ2lzdHJ5U2VjdXJp
dHkgYAogICAgICAgICAgICAtUmVnaXN0cnlQYXRoICRSZWdpc3RyeVBhdGggYAogICAgICAgICAg
ICAtU2VjdXJpdHkgJHdyaXRlQWNsIGAKICAgICAgICAgICAgLVNlY3VyaXR5SW5mb3JtYXRpb24g
MHgwMDAwMDAwNCBgCiAgICAgICAgICAgIC1EZXNpcmVkQWNjZXNzIDB4MDAwNDAwMDAKCiAgICAg
ICAgU2V0LUl0ZW1Qcm9wZXJ0eSAtTGl0ZXJhbFBhdGggJFJlZ2lzdHJ5UGF0aCBgCiAgICAgICAg
ICAgIC1OYW1lIFZpc2liaWxpdHkgYAogICAgICAgICAgICAtVmFsdWUgJFZhbHVlIGAKICAgICAg
ICAgICAgLUVycm9yQWN0aW9uIFN0b3AKICAgIH0KICAgIGZpbmFsbHkgewogICAgICAgIGlmICgk
YWNsQ2hhbmdlZCkgewogICAgICAgICAgICAkcmVzdG9yZUFjbCA9IE5ldy1PYmplY3QgU2VjdXJp
dHkuQWNjZXNzQ29udHJvbC5SZWdpc3RyeVNlY3VyaXR5CiAgICAgICAgICAgICRyZXN0b3JlQWNs
LlNldFNlY3VyaXR5RGVzY3JpcHRvclNkZGxGb3JtKAogICAgICAgICAgICAgICAgJG9yaWdpbmFs
U2RkbCwKICAgICAgICAgICAgICAgICRhY2Nlc3NTZWN0aW9ucwogICAgICAgICAgICApCiAgICAg
ICAgICAgIFNldC1OYXRpdmVSZWdpc3RyeVNlY3VyaXR5IGAKICAgICAgICAgICAgICAgIC1SZWdp
c3RyeVBhdGggJFJlZ2lzdHJ5UGF0aCBgCiAgICAgICAgICAgICAgICAtU2VjdXJpdHkgJHJlc3Rv
cmVBY2wgYAogICAgICAgICAgICAgICAgLVNlY3VyaXR5SW5mb3JtYXRpb24gMHgwMDAwMDAwNSBg
CiAgICAgICAgICAgICAgICAtRGVzaXJlZEFjY2VzcyAweDAwMEMwMDAwCgogICAgICAgICAgICAk
cmVzdG9yZWRBY2wgPSBHZXQtQWNsIC1QYXRoICRSZWdpc3RyeVBhdGgKICAgICAgICAgICAgJHJl
c3RvcmVkU2RkbCA9CiAgICAgICAgICAgICAgICAkcmVzdG9yZWRBY2wuR2V0U2VjdXJpdHlEZXNj
cmlwdG9yU2RkbEZvcm0oJGFjY2Vzc1NlY3Rpb25zKQogICAgICAgICAgICAkcmVzdG9yZWRTZGRs
IHwKICAgICAgICAgICAgICAgIE91dC1GaWxlIC1GaWxlUGF0aCAoJEFjbEJhY2t1cFBhdGggKyAn
LnJlc3RvcmVkLnR4dCcpIGAKICAgICAgICAgICAgICAgICAgICAtRW5jb2RpbmcgQVNDSUkKCiAg
ICAgICAgICAgICMgVHJlYXQgYSBEQUNMX0FVVE9fSU5IRVJJVEVEIG1hcmtlci1vbmx5IG5vcm1h
bGl6YXRpb24gYXMKICAgICAgICAgICAgIyBlcXVpdmFsZW50OyBhbnkgb3duZXIgb3IgQUNFIGRp
ZmZlcmVuY2Ugc3RpbGwgZmFpbHMuIFNjb3BlIHRoZQogICAgICAgICAgICAjIG5vcm1hbGl6YXRp
b24gdG8gdGhlIERBQ0wgZmxhZ3Mgc2VnbWVudCAoYmV0d2VlbiAiRDoiIGFuZCBpdHMKICAgICAg
ICAgICAgIyBmaXJzdCBBQ0UgIigiKSBzbyBhIGxpdGVyYWwgIkFJIiBlbHNld2hlcmUgaW4gdGhl
IGRlc2NyaXB0b3IKICAgICAgICAgICAgIyBjYW5ub3QgbWFzayBhIHJlYWwgZGlmZmVyZW5jZS4K
ICAgICAgICAgICAgJG9yaWdpbmFsQ29tcGFyYWJsZSA9IEdldC1Db21wYXJhYmxlU2RkbCAtU2Rk
bCAkb3JpZ2luYWxTZGRsCiAgICAgICAgICAgICRyZXN0b3JlZENvbXBhcmFibGUgPSBHZXQtQ29t
cGFyYWJsZVNkZGwgLVNkZGwgJHJlc3RvcmVkU2RkbAogICAgICAgICAgICBpZiAoJHJlc3RvcmVk
Q29tcGFyYWJsZSAtbmUgJG9yaWdpbmFsQ29tcGFyYWJsZSkgewogICAgICAgICAgICAgICAgdGhy
b3cgKAogICAgICAgICAgICAgICAgICAgICdPd25lci9EQUNMIHNlbWFudGljIHJlc3RvcmF0aW9u
IHZlcmlmaWNhdGlvbiBmYWlsZWQuIFJlc3RvcmUgZnJvbTogezB9JyAtZgogICAgICAgICAgICAg
ICAgICAgICRBY2xCYWNrdXBQYXRoCiAgICAgICAgICAgICAgICApCiAgICAgICAgICAgIH0KICAg
ICAgICB9CiAgICB9Cn0KCgojIC0tLS0gTEVWRUwgMTogcmVzdG9yZSB2aXNpYmlsaXR5IHdpdGgg
cHJvcGVyIFRydXN0ZWRJbnN0YWxsZXIgdGFrZW92ZXIgLS0tLQpXcml0ZS1Ib3N0ICdSZXN0b3Jp
bmcgdmlzaWJpbGl0eSBvZiBLQjMxMjU1NzQgcGFja2FnZXMgKFZpc2liaWxpdHk9MSkuLi4nCiRy
ZXN0b3JlZCA9IDA7ICRmYWlsZWQgPSAwCiRhY2xCYWNrdXBEaXIgPSBKb2luLVBhdGggJGVudjpU
RU1QICdrYjMxMjU1NzRfdW5pbnN0YWxsX2FjbCcKaWYgKC1ub3QgKFRlc3QtUGF0aCAkYWNsQmFj
a3VwRGlyKSkgeyBOZXctSXRlbSAtSXRlbVR5cGUgRGlyZWN0b3J5IC1QYXRoICRhY2xCYWNrdXBE
aXIgLUZvcmNlIHwgT3V0LU51bGwgfQpmb3JlYWNoICgkbiBpbiAkbnVtcykgewogICAgJGtleXMg
PSBHZXQtQ2hpbGRJdGVtIC1QYXRoICRjYnNSb290IC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRp
bnVlIHwKICAgICAgICAgICAgV2hlcmUtT2JqZWN0IHsgKFNwbGl0LVBhdGggJF8uTmFtZSAtTGVh
ZikgLW1hdGNoICgiXlBhY2thZ2VfezB9X2Zvcl9LQjMxMjU1NzR+IiAtZiAkbikgfQogICAgZm9y
ZWFjaCAoJGsgaW4gJGtleXMpIHsKICAgICAgICAkcmVnUGF0aCA9ICRrLlBTUGF0aAogICAgICAg
ICRsZWFmID0gU3BsaXQtUGF0aCAkay5OYW1lIC1MZWFmCiAgICAgICAgJGFjbEJhY2t1cCA9IEpv
aW4tUGF0aCAkYWNsQmFja3VwRGlyICgkbGVhZiArICcuc2RkbCcpCiAgICAgICAgdHJ5IHsKICAg
ICAgICAgICAgU2V0LUNic1Zpc2liaWxpdHlWYWx1ZSAtUmVnaXN0cnlQYXRoICRyZWdQYXRoIC1W
YWx1ZSAxIC1BY2xCYWNrdXBQYXRoICRhY2xCYWNrdXAgLUFsbG93VGVtcG9yYXJ5QWNjZXNzICR0
cnVlCiAgICAgICAgICAgICRyZXN0b3JlZCsrCiAgICAgICAgfQogICAgICAgIGNhdGNoIHsKICAg
ICAgICAgICAgJGZhaWxlZCsrCiAgICAgICAgICAgIFdyaXRlLVdhcm5pbmcgKCJbezB9XSByZXN0
b3JlIGZhaWxlZDogezF9IiAtZiAkbGVhZiwgJF8uRXhjZXB0aW9uLk1lc3NhZ2UpCiAgICAgICAg
fQogICAgfQp9CmlmICgkZmFpbGVkIC1lcSAwKSB7CiAgICBXcml0ZS1Ib3N0ICgiRG9uZS4gVmlz
aWJpbGl0eSByZXN0b3JlZCBvbiB7MH0gcGFja2FnZSBrZXkocyk7IHVwZGF0ZXMgYXJlIHZpc2li
bGUgYWdhaW4uIiAtZiAkcmVzdG9yZWQpIC1Gb3JlZ3JvdW5kQ29sb3IgR3JlZW4KfSBlbHNlIHsK
ICAgIFdyaXRlLUhvc3QgKCJSZXN0b3JlZCB7MH0sIGZhaWxlZCB7MX0uIFNlZSB3YXJuaW5ncyBh
Ym92ZS4iIC1mICRyZXN0b3JlZCwgJGZhaWxlZCkgLUZvcmVncm91bmRDb2xvciBZZWxsb3cKfQoK
IyAtLS0tIExFVkVMIDIgKE9QVElPTkFMLCBISUdIIFJJU0spOiBmdWxsIHBhY2thZ2UgcmVtb3Zh
bCAtLS0tCmlmICgkUmVtb3ZlUGFja2FnZXMpIHsKICAgIFdyaXRlLUhvc3QgJycKICAgIFdyaXRl
LUhvc3QgJ1dBUk5JTkc6IHJlbW92aW5nIHRoZXNlIHBhY2thZ2VzIHJvbGxzIHRlcm1pbmFsIGNv
bXBvbmVudHMgYmFjayB0byBvbGRlci9taXNzaW5nJyAtRm9yZWdyb3VuZENvbG9yIFllbGxvdwog
ICAgV3JpdGUtSG9zdCAndmVyc2lvbnMgYW5kIE1BWSBCUkVBSyB0aGUgc3lzdGVtIG9yIGxhdGVy
IHVwZGF0ZXMgdGhhdCBkZXBlbmQgb24gdGhlbS4nIC1Gb3JlZ3JvdW5kQ29sb3IgWWVsbG93CiAg
ICBpZiAoKFJlYWQtSG9zdCAnVHlwZSBSRU1PVkUgdG8gcHJvY2VlZCwgYW55dGhpbmcgZWxzZSB0
byBjYW5jZWwnKSAtbmUgJ1JFTU9WRScpIHsgV3JpdGUtSG9zdCAnQ2FuY2VsbGVkLic7IGV4aXQg
MCB9CiAgICBmb3JlYWNoICgkbiBpbiAkbnVtcykgewogICAgICAgICRrZXlzID0gR2V0LUNoaWxk
SXRlbSAtUGF0aCAkY2JzUm9vdCAtRXJyb3JBY3Rpb24gU2lsZW50bHlDb250aW51ZSB8CiAgICAg
ICAgICAgICAgICBXaGVyZS1PYmplY3QgeyAoU3BsaXQtUGF0aCAkXy5OYW1lIC1MZWFmKSAtbWF0
Y2ggKCJeUGFja2FnZV97MH1fZm9yX0tCMzEyNTU3NH4iIC1mICRuKSB9CiAgICAgICAgZm9yZWFj
aCAoJGsgaW4gJGtleXMpIHsKICAgICAgICAgICAgJG5hbWUgPSBTcGxpdC1QYXRoICRrLk5hbWUg
LUxlYWYKICAgICAgICAgICAgV3JpdGUtSG9zdCAoIlJlbW92aW5nIHswfSAuLi4iIC1mICRuYW1l
KQogICAgICAgICAgICAmIGRpc20gL29ubGluZSAvUmVtb3ZlLVBhY2thZ2UgL1BhY2thZ2VOYW1l
OiRuYW1lIC9Ob1Jlc3RhcnQgfCBPdXQtTnVsbAogICAgICAgIH0KICAgIH0KICAgIFdyaXRlLUhv
c3QgJ1BhY2thZ2UgcmVtb3ZhbCBzdWJtaXR0ZWQuIFJlYm9vdCB0byBjb21wbGV0ZS4nIC1Gb3Jl
Z3JvdW5kQ29sb3IgQ3lhbgp9Cg==
'@
    $readmeB64 = @'
S0IzMTI1NTc0LUxpdGUgIFVuaW5zdGFsbGVyICAtLSAgVXNhZ2UgLyDkvb/nlKjor7TmmI4KPT09
PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09
PT09PQoKW0VuZ2xpc2hdClRoaXMgdW5pbnN0YWxsZXIgcmV2ZXJ0cyB0aGUgS0IzMTI1NTc0LUxp
dGUgaW50ZWdyYXRpb24gb24gVEhJUyBydW5uaW5nIHN5c3RlbS4KQWx3YXlzIHJ1biBhcyBBZG1p
bmlzdHJhdG9yLgoKTEVWRUwgMSAoZGVmYXVsdCkgLS0gcmVzdG9yZSB2aXNpYmlsaXR5OgogICAg
UmlnaHQtY2xpY2sgIlVuaW5zdGFsbC1LQjMxMjU1NzQtTGl0ZS5jbWQiIC0+IFJ1biBhcyBhZG1p
bmlzdHJhdG9yCiAgVGhlIGhpZGRlbiBLQjMxMjU1NzQgdXBkYXRlcyBiZWNvbWUgdmlzaWJsZSBh
Z2FpbiBpbiBJbnN0YWxsZWQgVXBkYXRlcy4KICBOb3RoaW5nIGlzIHJlbW92ZWQuIFNhZmUgYW5k
IHJldmVyc2libGUuCgpMRVZFTCAyIChvcHRpb25hbCwgSElHSCBSSVNLKSAtLSByZW1vdmUgdGhl
IHBhY2thZ2VzOgogICAgT3BlbiBhbiBlbGV2YXRlZCBjb21tYW5kIHByb21wdCBpbiB0aGlzIGZv
bGRlciBhbmQgcnVuOgogICAgICAgIFVuaW5zdGFsbC1LQjMxMjU1NzQtTGl0ZS5jbWQgcmVtb3Zl
CiAgICBZb3Ugd2lsbCBiZSBhc2tlZCB0byB0eXBlIFJFTU9WRSB0byBjb25maXJtLgogIFRoaXMg
dW5pbnN0YWxscyB0aGUgcGFja2FnZXMgdmlhIERJU00gYW5kIG1heSByb2xsIHRlcm1pbmFsIGNv
bXBvbmVudHMgYmFjayBvcgogIGJyZWFrIGxhdGVyIHVwZGF0ZXMgdGhhdCBkZXBlbmQgb24gdGhl
bS4gUmVib290IGFmdGVyd2FyZHMuCgpOb3RlOiB0aGUgQ0JTIHBhY2thZ2Uga2V5cyBhcmUgb3du
ZWQgYnkgVHJ1c3RlZEluc3RhbGxlci4gVGhlIHNjcmlwdCB0ZW1wb3JhcmlseQp0YWtlcyBvd25l
cnNoaXAgdG8gY2hhbmdlIHRoZSB2aXNpYmlsaXR5IHZhbHVlLCB0aGVuIHJlc3RvcmVzIHRoZSBv
cmlnaW5hbCBvd25lcgphbmQgQUNMIGF1dG9tYXRpY2FsbHkuIFRoaXMgaXMgd2h5IGl0IG11c3Qg
cnVuIGVsZXZhdGVkLgoKLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
LS0tLS0tLS0tLS0tLS0tLS0tLS0tLQoKW+S4reaWh10K5pys5Y246L295Zmo55So5LqO5Zyo44CQ
5b2T5YmN6L+Q6KGM55qE57O757uf44CR5LiK5pKk6ZSAIEtCMzEyNTU3NC1MaXRlIOmbhuaIkOOA
guivt+WKoeW/heS7peeuoeeQhuWRmOi6q+S7vei/kOihjOOAggoK57qn5Yir5LiA77yI6buY6K6k
77yJ4oCU4oCUIOaBouWkjeWPr+ingeaAp++8mgogICAg5Y+z6ZSu4oCcVW5pbnN0YWxsLUtCMzEy
NTU3NC1MaXRlLmNtZOKAnSAtPiDku6XnrqHnkIblkZjouqvku73ov5DooYwKICDooqvpmpDol4/n
moQgS0IzMTI1NTc0IOabtOaWsOS8muWcqOKAnOW3suWuieijheabtOaWsOKAneS4remHjeaWsOWP
r+ingeOAggogIOS4jeWIoOmZpOS7u+S9leS4nOilv++8jOWuieWFqOS4lOWPr+mAhuOAggoK57qn
5Yir5LqM77yI5Y+v6YCJ77yM6auY6aOO6Zmp77yJ4oCU4oCUIOWNuOi9vXRoZXNl5YyF77yaCiAg
ICDlnKjmnKzmlofku7blpLnmiZPlvIDnrqHnkIblkZjlkb3ku6TooYzvvIzov5DooYzvvJoKICAg
ICAgICBVbmluc3RhbGwtS0IzMTI1NTc0LUxpdGUuY21kIHJlbW92ZQogICAg57O757uf5Lya6KaB
5rGC6ZSu5YWlIFJFTU9WRSDnoa7orqTjgIIKICDov5nkvJrpgJrov4cgRElTTSDljbjovb3ov5nk
upvljIXvvIzlj6/og73lm57pgIDmlq3ku6Pnu4Tku7bjgIHmiJbnoLTlnY/kvp3otZblroPku6zn
moTlkI7nu63mm7TmlrDjgILlrozmiJDlkI7pnIDph43lkK/jgIIKCuivtOaYju+8mkNCUyDljIXm
s6jlhozooajplK7lvZIgVHJ1c3RlZEluc3RhbGxlciDmiYDmnInjgILohJrmnKzkvJrkuLTml7bm
jqXnrqHmiYDmnInmnYPku6Xkv67mlLnlj6/op4HmgKflgLzvvIwK54S25ZCO6Ieq5Yqo6L+Y5Y6f
5Y6f5aeL5omA5pyJ6ICF5ZKMIEFDTOOAgui/meWwseaYr+W/hemhu+S7peeuoeeQhuWRmOi6q+S7
vei/kOihjOeahOWOn+WboOOAggo=
'@
    $ps1 = Join-Path $RootDir 'Uninstall-KB3125574-Lite.ps1'
    $cmd = Join-Path $RootDir 'Uninstall-KB3125574-Lite.cmd'
    $readme = Join-Path $RootDir 'Uninstall-README.txt'

    # decode body, substitute package numbers, write .ps1 (ASCII)
    $body = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($bodyB64 -replace '\s','')))
    $body = $body.Replace('__NUMS__', $numList)
    Set-Content -LiteralPath $ps1 -Value $body -Encoding ASCII

    # decode bilingual README, write as UTF-8 (contains Chinese)
    $readmeText = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(($readmeB64 -replace '\s','')))
    $utf8 = New-Object System.Text.UTF8Encoding($true)  # with BOM so Notepad shows Chinese
    [System.IO.File]::WriteAllText($readme, $readmeText, $utf8)

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
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, EntryPoint="RegSetValueExW")]
        static extern int RegSetValueEx(IntPtr key,string name,int res,int type,byte[] data,int len);

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
Add-Type -TypeDefinition $native -Language CSharp

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
$chg = 0; $already = 0; $failed = 0; $script:hiddenNums = @()
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

    $sec = [Security.AccessControl.AccessControlSections]::Owner -bor `
           [Security.AccessControl.AccessControlSections]::Access

    foreach ($leaf in $names) {
        $rel   = "$pkgRootRel\$leaf"      # relative to HKLM, for native calls
        $psKey = "HKLM:\$rel"             # provider path, only for Get-Acl (read)
        $origSddl = $null
        $tookOwnership = $false
        try {
            $origAcl  = Get-Acl -Path $psKey
            $origSddl = $origAcl.GetSecurityDescriptorSddlForm($sec)

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

            # write the value natively (no provider handle on the hive)
            [OfflineCbs.Native]::SetDword($rel, 'Visibility', $targetVis)
            $chg++
            if ($leaf -match '^Package_(\d+)_for_KB3125574~') { $script:hiddenNums += [int]$Matches[1] }
        }
        catch { $failed++; Write-Warning ("[{0}] {1}" -f $leaf, $_.Exception.Message) }
        finally {
            if ($tookOwnership -and $origSddl) {
                # restore original owner + DACL
                $rAcl = New-Object Security.AccessControl.RegistrySecurity
                $rAcl.SetSecurityDescriptorSddlForm($origSddl, $sec)
                [OfflineCbs.Native]::SetSecurity($rel, $rAcl.GetSecurityDescriptorBinaryForm(), 0x5, 0x000C0000) # WRITE_OWNER|WRITE_DAC
                # verify semantic restoration
                $back = (Get-Acl -Path $psKey).GetSecurityDescriptorSddlForm($sec)
                if ((Get-ComparableSddl $back) -ne (Get-ComparableSddl $origSddl)) {
                    Write-Warning ("[{0}] ACL restore verification differs" -f $leaf)
                }
            }
        }
    }
    Write-Host ("[hide] Done: changed {0}, failed {1} (of {2})" -f $chg, $failed, $names.Count)
    if ($script:hiddenNums.Count -gt 0 -and -not $NoUninstaller) {
        try { Write-UninstallScript -RootDir $Mount -Numbers ([int[]]$script:hiddenNums) }
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
                Write-Warning "reg unload still failing. Close this PowerShell window (frees handles), then: reg unload HKLM\$mn"
            }
        }
    }
}
