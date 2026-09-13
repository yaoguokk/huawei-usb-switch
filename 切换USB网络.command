#!/bin/bash
# 双击运行：把华为随身WiFi 从「零CD存储模式」切到「USB 网卡模式」
#
# 为什么必须由终端执行：
#   osascript 的 `do shell script ... with administrator privileges` 走的是 launchd
#   特权助手域，libusb 的 claim_interface 在那里必然报
#   IOCreatePlugInInterfaceForService: out of resources (e00002be)。
#   终端（GUI 会话）里 sudo 则正常。所以这个脚本故意只在本窗口里 sudo。

echo "正在切换华为随身WiFi 到 USB 网卡模式..."
echo

sudo "$HOME/bin/huawei-switch"
rc=$?

echo
if [ $rc -eq 0 ]; then
    echo "=== 等待设备重新枚举 ==="
    sleep 5
    if ifconfig en11 2>/dev/null | grep -q "inet "; then
        echo "✅ USB 网络已就绪："
        ifconfig en11 | grep -E "inet |status"
        echo
        echo "提示：WiFi(en0) 和 USB(en11) 现在同在 192.168.8.x 网段，"
        echo "      建议用 USB 时把 WiFi 关掉，避免路由/ARP 打架。"
    else
        echo "⚠️  切换命令已发送，但 en11 还没拿到 IP。"
        echo "    稍等片刻再看，或在「系统设置 → 网络」里检查 HUAWEI_MOBILE 服务。"
    fi
else
    echo "❌ 切换失败（退出码 $rc）。"
    echo "    若显示 claim 失败，请确认是在终端里运行的、且密码输入正确。"
fi

echo
echo "按回车键关闭此窗口..."
read
