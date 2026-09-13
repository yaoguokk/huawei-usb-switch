#!/bin/bash
# 华为随身WiFi -> USB 网卡模式
#
# 用法：插上设备后双击本文件（建议拖到 Dock 里，一次点击即可）。
#
# ⚠️ 为什么必须在【终端】里 sudo：
#    osascript 的 `do shell script ... with administrator privileges` 走的是
#    launchd 特权助手域，libusb 的 claim_interface 在那里必然报
#    IOCreatePlugInInterfaceForService: out of resources (e00002be)。
#    终端（GUI 会话）里 sudo 则正常。所以这里刻意只用 sudo。
#
# 授权：已启用 Touch ID for sudo 时按指纹，否则输入密码。

export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

echo "════════════════════════════════════════"
echo "  华为随身WiFi -> USB 网卡模式"
echo "════════════════════════════════════════"
echo
echo "下面提示时请按指纹（或输入密码）"
echo

sudo "$HOME/bin/huawei-switch"
rc=$?

echo
if [ $rc -ne 0 ]; then
    echo "❌ 切换失败（退出码 $rc）"
    echo
    echo "按回车键关闭此窗口..."
    read
    exit 1
fi

echo "命令已发送，等待设备重新枚举..."
sleep 5

# 自动找 HUAWEI_MOBILE 对应的网卡名
# （不要写死 en11 —— 接口编号会随插入顺序变化）
IFACE=$(networksetup -listallhardwareports 2>/dev/null \
        | awk '/Hardware Port: HUAWEI_MOBILE/{getline; print $2}')

if [ -n "$IFACE" ] && ifconfig "$IFACE" 2>/dev/null | grep -q "inet "; then
    echo "✅ 完成，USB 网络已就绪："
    echo
    ifconfig "$IFACE" | grep -E "inet |status" | sed 's/^/    /'
    echo
    echo "提示：WiFi 与 USB 现在同在 192.168.8.x 网段，"
    echo "      建议用 USB 时把 WiFi 关掉，避免路由打架。"
    echo
    echo "本窗口 6 秒后自动关闭..."
    sleep 6
    exit 0
fi

echo "⚠️  切换命令已发送，但还没看到拿到 IP 的网卡。"
echo "    再等几秒；若始终没有，请到「系统设置 -> 网络」查看 HUAWEI_MOBILE。"
echo
echo "按回车键关闭此窗口..."
read
