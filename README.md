# 华为随身WiFi 在 Mac 上用 USB 共享网络

让华为 HiLink 随身WiFi（E5577 等）通过 USB 给 Mac 共享网络。
**不需要安装任何华为驱动** —— 用 macOS 自带的 CDC-ECM 驱动即可。

> 实测环境：Apple Silicon（M 系列）+ macOS 26（Tahoe）。
> 已在 E5577Bs-937 上验证通过。

---

## 问题现象

把随身WiFi 插到 Mac 上：

- 桌面只出现一个 8.4 MB 的光盘（`MobileWiFi`），里面是华为的驱动
- 双击里面的驱动装不上，报 AppleScript 错误
- **系统设置 → 网络**里不会出现任何新网卡，USB 共享网络无从谈起

## 根因（三层，一层套一层）

### 第一层：设备根本没在网卡模式

插上后设备处于华为的**「零CD / 仅存储」模式**（USB ID `12d1:1f01`）。
把 IORegistry 去重后可以确认，它**只暴露一个接口**：

```
bInterfaceNumber   = 0
bInterfaceClass    = 8    (Mass Storage)
bInterfaceSubClass = 6
bInterfaceProtocol = 80
```

**整台设备只有这一个存储接口，没有网卡。** 所以 macOS 上不会出现任何新网络接口 ——
不是缺驱动，是设备压根没把网卡功能拿出来。

### 第二层：光盘里的 Mac 驱动是死路

`MobileWiFi` 光盘里的 Mac 驱动包，解包后要装的是 `MBBDataCardECMDriver_10_9.kext`：

- **只有 x86_64 架构**（Xcode 4.6.3 / macOS 10.8 SDK 构建）—— Apple Silicon 的
  arm64 内核根本无法加载
- 它的 `postinstall` 脚本用 `sw_vers | awk -F. '{print $2}'` 取次版本号，
  判断 `-eq 10` 才安装 kext。macOS 26.6.2 取到的是 `6`，**脚本自己就跳过了**
- 安装脚本还会 `chmod a+w /usr`、`mkdir /usr/local` —— 在 macOS 11+ 的只读系统卷上必然失败
- 装完还要靠 `/Library/StartupItems` 自启 —— 该机制自 macOS 10.15 起已废弃

> ⚠️ **不要尝试强行运行那个安装脚本。** 它会改 `/usr` 权限、动 `/private/etc/sudoers`
> 权限、往 `/Library/Extensions` 塞 kext。在 Apple Silicon 上要么失败，要么把系统搞坏。

### 第三层：切换模式需要 root，而且执行上下文很挑

要让设备切到网络模式，得给它发一条 SCSI 命令，而这需要先摘下大容量存储驱动、抢占 USB 接口 —— 都要 root。

但**在错误的上下文里以 root 执行会失败**：

| 执行方式 | 结果 |
|---|---|
| `osascript -e 'do shell script ... with administrator privileges'` | ❌ `libusb_claim_interface` 报 `IOCreatePlugInInterfaceForService: out of resources`（`kIOReturnNoResources` / `e00002be`） |
| 终端里 `sudo`（GUI 会话） | ✅ 正常 |

这是 launchd 特权助手域的限制（[Apple 开发者论坛有相同案例](https://developer.apple.com/forums/thread/774331)）。
**推论：不能做成 LaunchDaemon**，只能走用户会话的 LaunchAgent。

## 原理

给设备发一条 31 字节的 SCSI CBW，把它从存储模式切换到 HiLink 网络模式：

```
12d1:1f01 (仅存储)  ──[31 字节 SCSI 命令]──▶  12d1:14db (标准 CDC-ECM)
                                                      │
                                    macOS 自带 usb.cdc.ecm 驱动直接识别
                                    Hardware Port: HUAWEI_MOBILE
```

切换消息取自 [usb-modeswitch-data](https://github.com/Distrotech/usb-modeswitch-data)：

```
55534243123456780000000000000a11062000000000000100000000000000
```

切换后设备暴露标准 CDC-ECM，**macOS 原生支持，零驱动**。实测：

```
Hardware Port: HUAWEI_MOBILE, Device: en11
inet 192.168.8.133, 默认路由 → en11, 外网 ping 通
```

切换后 DHCP 自动分配 `192.168.8.x`，设备管理界面仍在 `http://192.168.8.1`。

## 用法

### 一键安装

把 `安装华为USB网络.command` 拷到 Mac 上，**双击运行**（或右键 → 打开）。

> 若提示"来自身份不明的开发者"，先清除隔离属性：
> `xattr -cr ~/Downloads/安装华为USB网络.command`
> 或直接在终端运行：`bash ~/Downloads/安装华为USB网络.command`

安装程序会：

1. 释放 `~/bin/huawei-switch`（静态链接，无外部依赖）
2. 安装自动检测脚本和切换窗口脚本
3. 用本机实际路径生成并加载 LaunchAgent
4. 询问是否启用 Touch ID for sudo（可跳过）

### 日常使用

**插上设备 → 几秒内自动弹出终端窗口 → 按一下指纹（或输密码）→ 完事。**

| 时刻 | 现象 |
|---|---|
| 插上后约 1 秒 | 桌面出现 `MobileWiFi` 光盘图标 |
| 随后几秒内 | 自动弹出终端窗口，提示 `Touch ID for sudo:` |
| 按指纹后 | 显示 `✅ 完成，USB 网络已就绪` |
| 6 秒后 | 窗口自动关闭，USB 网络可用 |

> 光盘图标一闪而过是**正常的**，说明切换成功了。

### 手动使用

不用自动弹窗的话，直接跑：

```bash
sudo ~/bin/huawei-switch
```

## 注意事项

⚠️ **模式切换是临时的。** 拔插或重启设备后会回到存储模式，需要重新切换 ——
这也是装 LaunchAgent 的原因。

⚠️ **WiFi 与 USB 会同时在 `192.168.8.x` 网段。** macOS 通常优先走 USB，能用；
但更干净的做法是**用 USB 时把 WiFi 关掉**，避免路由/ARP 打架。

⚠️ **每次都需要 root。** 因为要摘下内核存储驱动。授权方式二选一：
按指纹（推荐，需启用 Touch ID for sudo）或输密码。

## 已知限制

- **仅验证过 Apple Silicon + macOS 26。** 老版本 macOS 上那个 `out of resources`
  的问题可能不存在（理论上更简单），但未实测。
- **Intel Mac 未验证。** 安装包内置的是 arm64 二进制；非 arm64 会回退到从源码编译，
  需要 Xcode Command Line Tools + `brew install libusb`。
- **launchd 自动弹窗这条链未充分验证** —— 核心切换功能已实测通过，
  但"LaunchAgent 自动拉起 Terminal"这一环在不同 macOS 版本上行为可能不同。
- 设备 Web 界面（`192.168.8.1`）**没有** USB 模式开关。

## 卸载

```bash
launchctl bootout gui/$(id -u)/local.huawei-usb
rm -f ~/Library/LaunchAgents/local.huawei-usb.plist
rm -f ~/bin/huawei-switch ~/bin/huawei-switch.c \
      ~/bin/huawei-usb-prompt.command ~/bin/huawei-autoswitch.sh

# 若想关闭 Touch ID for sudo
sudo rm -f /etc/pam.d/sudo_local
```

## 仓库内容

| 文件 | 说明 |
|---|---|
| `tryswitch.c` | 切换程序源码（核心，可自行审查/编译） |
| `安装华为USB网络.command` | 一键安装包（内嵌静态链接的 arm64 二进制） |
| `切换USB网络.command` | 单独的手动切换脚本 |
| `12d1:1f01` | usb_modeswitch 设备配置（参考） |

自行编译：

```bash
brew install libusb
clang -o huawei-switch tryswitch.c \
  -I$(brew --prefix)/include/libusb-1.0 $(brew --prefix)/lib/libusb-1.0.a \
  -framework IOKit -framework CoreFoundation -framework Security
```

## 致谢与许可

- 模式切换消息来自 [usb-modeswitch-data](https://github.com/Distrotech/usb-modeswitch-data)（GPL-2.0）
- 静态链接了 [libusb](https://libusb.info/)（LGPL-2.1）
- 本仓库**不包含**华为的专有驱动软件，请自行从设备上获取
