# KB3125574-Lite

[English](README.md) | **中文**

**对外发布版本 v1.0.2**
来源基线：`3.0.0 / 20260709.milestone-final-104`

从 Windows 7 x64 便利更新卷（**KB3125574**）中，只安装仍然属于断代荷载的子包。脚本直接使用你自己解包得到的 KB3125574 源目录。

本发布包只提供清单和安装脚本，不分发任何微软更新包。

## 已验证结果

目标口径：Windows 7 SP1 x64，neutral + zh-CN + en-US 荷载，总计 `1138/1138`。

| 层级 | 清单 | 外部前置条件 | 本层包数 | 累计包数 | 累计覆盖 | 实测状态 | 使用场景 |
|---|---|---|---:|---:|---:|---|---|
| 原版 WIM 基线 | `manifests/v3/base-original-observed-90.txt` | 微软原版 Win7 SP1 x64 zh-CN Ultimate + 必需服务栈前置 | 90 | 90 | 1079/1138 | 90/90 成功 | 基础已验证配置 |
| Features 增量 | `manifests/v3/features-addon-observed-11.txt` | 所需 Windows 可选功能 | +11 | 101 | 1126/1138 | 来自 Features 配置实测成功包 | 叠加在 90 包基线之上 |
| Features 配置 | `manifests/v3/features-observed-101.txt` | 原版 WIM 基线 + 所需 Windows 可选功能 | 101 | 101 | 1126/1138 | 59 个适用条件包成功；KB2670838 前的 3 个 Win8IP 包按预期返回 0x800f081e | 已预置 Features、未集成 KB2670838 时使用 |
| KB2670838 增量 | `manifests/v3/platform-update-kb2670838-addon-3.txt` | KB2670838 Platform Update | +3 | 104 | 1138/1138 | 集成 KB2670838 后 3/3 成功 | 叠加在 Features 配置之上 |
| 完整目标配置 | `manifests/v3/full-feature-target-104-driver-last.txt` | 所需 Windows 可选功能 + KB2670838 | 104 | 104 | 1138/1138 | 一次性实测 104/104 成功 | 推荐的完整目标清单 |
| 全语言归档产物 | `manifests/v3/all-terminal-152.txt` | 全补丁样本 Installed 候选全集 | 152 | 152 | 1228/1228 全语言归档全集 | 优化审计产物，不是推荐默认安装清单 | 仅供审计/参考 |

完整目标清单 SHA-256：

```text
8FEA0CA9EEAC748D8A33BECF16442FE0315BF9CEAAD9D7B2F7B93251922FE210
```

## 最终 104 包前置条件拆分

已验证的 104 包被拆成四个互斥组：

| 类别 | 前置组件 | 清单 | 子包数 |
|---|---|---|---:|
| 原版 inbox 可直接集成 | 无外部功能 KB | `manifests/v3/by-prerequisite/inbox-original-90.txt` | 90 |
| RSAT | KB958830 | `manifests/v3/by-prerequisite/kb958830-rsat-10.txt` | 10 |
| Windows Virtual PC | KB958559 | `manifests/v3/by-prerequisite/kb958559-virtualpc-1.txt` | 1 |
| Platform Update | KB2670838 | `manifests/v3/by-prerequisite/kb2670838-platform-update-3.txt` | 3 |

具体依赖：

- KB958830：`366`、`374`、`382`、`798`、`799`、`808`、`816`、`818`、`834`、`1101`
- KB958559：`859`
- KB2670838：`965`、`2627`、`3152`

详见 `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md`。

## 必需服务栈前置

安装脚本会先检查以下补丁：

1. KB4490628
2. KB4474419
3. KB4019990

如果要使用 104 包完整目标清单，还需要预先准备：

- 所需 Windows 可选功能；
- KB2670838 Platform Update。

如果父组件不存在，DISM 会返回 `0x800f081e`。这表示“不适用”，不等于包损坏。

## 快速使用

先挂载镜像并集成服务栈前置补丁：

```cmd
dism /Mount-Image /ImageFile:"install.wim" /Index:1 /MountDir:D:\Mount
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4490628.msu"
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4474419.msu"
dism /Image:D:\Mount /Add-Package /PackagePath:"X:\Updates\KB4019990.msu"
```

然后在管理员命令提示符中执行一份清单：

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\base-original-observed-90.txt
```

如果镜像已经具备 Features + KB2670838，则使用完整目标 104 包清单：

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\full-feature-target-104-driver-last.txt
```

最后提交镜像：

```cmd
dism /Unmount-Image /MountDir:D:\Mount /Commit
```

如果省略 `-List`，安装器默认使用 `manifests/v3/base-original-observed-90.txt`。

## 隐藏“已安装更新”条目与卸载脚本

集成过程干净完成后，`Install-KB3125574Lite.ps1` 会把本次集成的 KB3125574 子包从离线镜像的 CBS “已安装更新”视图中隐藏：具体做法是将对应 CBS package key 的 `Visibility` 值设为 `2`。

需要明确：

- 包仍然处于已安装状态；隐藏只影响“已安装更新”可见性。
- 安装器只隐藏本次清单实际匹配到的包号。
- 只接受已经存在且类型为 DWORD、数值为 `1` 或 `2` 的 `Visibility`；脚本不会创建缺失值。
- 每次写入后都会重新读取并验证。
- CBS package key 归 TrustedInstaller 所有，脚本会临时接管 ACL，写入后再恢复原 owner 和 ACL；写入、ACL 恢复或离线 hive 卸载失败都会中止流程。
- 如果不想隐藏，传入 `-NoHide`。

示例：

```cmd
scripts\Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\base-original-observed-90.txt -NoHide
```

至少有一个值从可见改为隐藏时，安装器才会在离线镜像根目录写入以下文件；部署后它们位于 `C:\`：

- `Uninstall-KB3125574-Lite.ps1`
- `Uninstall-KB3125574-Lite.cmd`
- `Uninstall-README.txt`

默认卸载动作：

```cmd
Uninstall-KB3125574-Lite.cmd
```

这个动作只恢复可见性（`Visibility=1`），不会删除包。

高风险删除包动作：

```cmd
Uninstall-KB3125574-Lite.cmd remove
```

这个动作会对生成清单中的包调用 `dism /online /Remove-Package`，并要求手动输入 `REMOVE` 才会继续。仅在你明确要回滚这些集成包时使用；删除断代组件可能破坏后续更新或组件状态。

随包也提供独立维护脚本 `scripts\Hide-OfflineKB3125574.ps1`。如果不传 `-Numbers`，它会处理离线镜像中所有 KB3125574 子包 key；主安装器调用它时会显式传入包号范围。可使用 `-WhatIf` 预览当前值和目标值，不修改注册表值或 ACL：

```powershell
.\scripts\Hide-OfflineKB3125574.ps1 -Mount D:\Mount -Numbers 366,374,382 -WhatIf
```

## 适用范围与限制

- 已验证环境是微软原版 Windows 7 SP1 x64 zh-CN Ultimate。
- 目标荷载口径为 neutral + zh-CN + en-US。
- 其他 SKU、语言、Server 2008 R2、Enterprise、自封装 sysprep 镜像都需要单独验证。
- 不要在 CBS 操作未落地的 Audit Mode 中集成。建议进入 Audit Mode 前集成；或者启用功能后完整重启一次，再集成。

## 文档

- `docs/BASELINE-v3.0.0.md`
- `docs/PACKAGE-PREREQUISITE-CLASSIFICATION.md`
- `RELEASE_NOTES.md`
- `CHANGELOG.md`

## 许可

MIT (c) 2026 gwaijyut。见 LICENSE。
