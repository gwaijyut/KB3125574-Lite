# KB3125574 terminal sub-package prerequisite classification

Scope: the proven 104-package optimum for none + zh-CN + en-US terminal
payloads.

## Classification

| Class | External prerequisite | Packages | Coverage role |
|---|---|---:|---:|
| Inbox parent | none | 90 | 1079 payloads |
| RSAT | KB958830 | 10 | part of the 47-payload Features delta |
| Windows Virtual PC | KB958559 | 1 | one payload |
| Platform Update | KB2670838 | 3 | final 12 payloads |

The sets are disjoint and total 104 packages.

## No external feature KB: 90 packages

These packages have at least one exact parent in state 96 or 112 in the
Microsoft original Windows 7 SP1 x64 zh-CN Ultimate SOFTWARE hive. They need no
RSAT, Virtual PC, Platform Update, WMF or DirectX add-on parent.

Manifest:

`manifests/v3/by-prerequisite/inbox-original-90.txt`

This category means "no external feature KB on the validated original image."
It does not yet prove identical applicability on every desktop SKU. Some parent
families are optional or edition-specific; Package_848, for example, detects
`Microsoft-Windows-Security-SPP-Component-SKU-Ultimate-Package`.

Starter, Home Basic, Home Premium, Professional and Enterprise must be checked
against their own SOFTWARE hives before the label can be promoted to
"all Windows 7 desktop editions."

## KB958830: RSAT, 10 packages

Packages:

`366, 374, 382, 798, 799, 808, 816, 818, 834, 1101`

The KB958830 CAB contains the exact
`Microsoft-Windows-RemoteServerAdministrationTools-Package`
6.1.7601.17514 parent identities. All ten packages succeeded after NTLite
integrated Features.

Packages 366, 374 and 382 also list DirectoryServices ADAM Client identities,
but they require exact version 6.1.7601.17514. KB975541 supplies
6.1.7600.16521 instead.

CBS explicitly reported the KB975541 ADAM identity as `not real parent` during
the successful Features run, then selected the KB958830 RSAT identity. No exact
ADAM 6.1.7601.17514 MUM exists in the available Features CABs or local update
archive. KB975541 is therefore rejected as an alternative prerequisite.

Manifest:

`manifests/v3/by-prerequisite/kb958830-rsat-10.txt`

## KB958559: Windows Virtual PC, one package

Package_859 detects:

`Microsoft-Windows-VirtualPC-Package~31bf3856ad364e35~amd64~~7.1.7601.17514`

KB958559 supplies that exact parent. Package_859 succeeded in the Features
test.

Manifest:

`manifests/v3/by-prerequisite/kb958559-virtualpc-1.txt`

## KB2670838: Platform Update, three packages

| Child package | Exact parent family |
|---:|---|
| 965 | Win8IP Printing |
| 2627 | Win8IP Multimedia |
| 3152 | Win8IP Graphics |

KB2670838 supplies all three 7.1.7601.16492 parents. The three child packages
succeeded 3/3 and add the final 12 target payloads.

Manifest:

`manifests/v3/by-prerequisite/kb2670838-platform-update-3.txt`

## Components that do not gate the selected 104

No selected package requires WMF 5.1, KB970985, the other miscellaneous
Features CABs, or DirectX June 2010 as its CBS parent.

These components may still be part of the desired final image, but they do not
change the prerequisite classification of the 104-package terminal set.

## Servicing prerequisites are a separate axis

KB4490628, KB4474419 and KB4019990 remain installer-level servicing
prerequisites in the current deployment script. They are not parent
dependencies of individual KB3125574 sub-packages and therefore are not mixed
into the four classes above.
