#!/bin/bash
# 关闭「自动弹窗」模式，改回手动切换
#
# 用途：如果你之前装过自动弹窗（LaunchAgent），想改回手动双击模式，
#       双击本文件即可（或 `bash 关闭自动弹窗.command`）。
#
# 保留：~/bin/huawei-switch、~/bin/huawei-usb-prompt.command、Touch ID 设置
# 移除：LaunchAgent、守卫脚本、状态文件
#
# 不需要 root —— LaunchAgent 是用户级的。

export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

LABEL="local.huawei-usb"

echo "════════════════════════════════════════"
echo "  关闭自动弹窗，改回手动模式"
echo "════════════════════════════════════════"
echo

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    echo "发现正在运行的自动弹窗服务，正在关闭..."
else
    echo "未发现自动弹窗服务（可能已经关过了）"
fi
echo

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null \
    && echo "  ✅ 已卸载 LaunchAgent ($LABEL)" \
    || echo "  ·  LaunchAgent 未在运行"
launchctl bootout "gui/$(id -u)/com.yao.huawei-usb" 2>/dev/null

for f in "$HOME/Library/LaunchAgents/$LABEL.plist" \
         "$HOME/Library/LaunchAgents/com.yao.huawei-usb.plist" \
         "$HOME/bin/huawei-autoswitch.sh" \
         "/tmp/.huawei-autoswitch.state"; do
    if [ -e "$f" ]; then
        rm -f "$f" && echo "  ✅ 已删除 $f"
    fi
done

echo
if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    echo "⚠️  服务似乎仍在运行。请到「系统设置 → 通用 → 登录项」里检查。"
else
    echo "✅ 自动弹窗已关闭 —— 以后插上设备不会再自动弹窗。"
fi
echo
echo "以后手动切换："
echo "  双击  ~/bin/huawei-usb-prompt.command"
echo "  （建议把它拖进 Dock，一次点击即可）"
echo
printf "按回车键关闭窗口..."
read -r _ || true
exit 0
