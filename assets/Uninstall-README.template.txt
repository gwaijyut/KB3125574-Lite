KB3125574-Lite  Uninstaller  --  Usage / 使用说明
================================================================

[English]
This uninstaller reverts the KB3125574-Lite integration on THIS running system.
Always run as Administrator.

LEVEL 1 (default) -- restore visibility:
    Right-click "Uninstall-KB3125574-Lite.cmd" -> Run as administrator
  The hidden KB3125574 updates become visible again in Installed Updates.
  Nothing is removed. Safe and reversible.

LEVEL 2 (optional, HIGH RISK) -- remove the packages:
    Open an elevated command prompt in this folder and run:
        Uninstall-KB3125574-Lite.cmd remove
    You will be asked to type REMOVE to confirm.
  This uninstalls the packages via DISM and may roll terminal components back or
  break later updates that depend on them. Reboot afterwards.

Note: the CBS package keys are owned by TrustedInstaller. The script temporarily
takes ownership to change the visibility value, then restores the original owner
and ACL automatically. This is why it must run elevated.

----------------------------------------------------------------

[中文]
本卸载器用于在【当前运行的系统】上撤销 KB3125574-Lite 集成。请务必以管理员身份运行。

级别一（默认）—— 恢复可见性：
    右键“Uninstall-KB3125574-Lite.cmd” -> 以管理员身份运行
  被隐藏的 KB3125574 更新会在“已安装更新”中重新可见。
  不删除任何东西，安全且可逆。

级别二（可选，高风险）—— 卸载these包：
    在本文件夹打开管理员命令行，运行：
        Uninstall-KB3125574-Lite.cmd remove
    系统会要求键入 REMOVE 确认。
  这会通过 DISM 卸载这些包，可能回退断代组件、或破坏依赖它们的后续更新。完成后需重启。

说明：CBS 包注册表键归 TrustedInstaller 所有。脚本会临时接管所有权以修改可见性值，
然后自动还原原始所有者和 ACL。这就是必须以管理员身份运行的原因。
