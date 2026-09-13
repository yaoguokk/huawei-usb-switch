/* 给华为 E5577 (12d1:1f01) 发送 USB 模式切换命令
 * 目的：从"零CD存储模式"切到 HiLink 网络模式 (12d1:14db)
 * 命令来源：usb-modeswitch-data/usb_modeswitch.d/12d1:1f01
 *
 * 注意：必须在 GUI 会话的终端里用 sudo 运行。
 * 经 launchd 特权助手(do shell script with administrator privileges)运行会因
 * IOCreatePlugInInterfaceForService 返回 e00002be(kIOReturnNoResources) 而 claim 失败。
 */
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <libusb.h>

static int hex2bin(const char *hex, unsigned char *out) {
    int n = 0;
    while (hex[0] && hex[1]) {
        unsigned int b;
        if (sscanf(hex, "%2x", &b) != 1) break;
        out[n++] = (unsigned char)b;
        hex += 2;
    }
    return n;
}

int main(void) {
    const char *hex = "55534243123456780000000000000a11062000000000000100000000000000";
    unsigned char msg[64];
    int msglen, r, transferred = 0, attempt;

    libusb_context *ctx = NULL;
    libusb_device_handle *h = NULL;

    msglen = hex2bin(hex, msg);
    printf("命令长度 = %d 字节\n", msglen);

    libusb_init(&ctx);

    h = libusb_open_device_with_vid_pid(ctx, 0x12d1, 0x1f01);
    if (!h) {
        printf("[X] 打开设备失败 —— 设备可能已经不在 12d1:1f01 模式了\n");
        libusb_exit(ctx);
        return 1;
    }
    printf("[OK] 设备已打开\n");

    r = libusb_kernel_driver_active(h, 0);
    printf("[?] kernel_driver_active(iface 0) = %d\n", r);
    if (r == 1) {
        r = libusb_detach_kernel_driver(h, 0);
        printf("[?] detach_kernel_driver(iface 0) = %d %s\n", r, r == 0 ? "(成功)" : "(失败)");
    }
    libusb_set_auto_detach_kernel_driver(h, 1);

    /* macOS 的 IOCreatePlugInInterfaceForService 不稳定，官方建议重试 */
    for (attempt = 1; attempt <= 8; attempt++) {
        r = libusb_claim_interface(h, 0);
        printf("[?] 第 %d 次 claim_interface(iface 0) = %d\n", attempt, r);
        if (r == 0) break;
        sleep(1);
    }
    if (r != 0) {
        printf("\n[X] 8 次重试后仍抢不到接口，退出\n");
        libusb_close(h);
        libusb_exit(ctx);
        return 1;
    }

    printf("\n[OK] 接口已抢到！\n");
    r = libusb_bulk_transfer(h, 0x01, msg, msglen, &transferred, 3000);
    printf("[%s] bulk_transfer(EP 0x01) = %d, 已发送 %d 字节\n",
           (r == 0 && transferred == msglen) ? "OK" : "X", r, transferred);

    if (r == 0 && transferred == msglen) {
        printf("\n>>> 切换命令已成功发出！设备应会重新枚举为 12d1:14db <<<\n");
    }

    libusb_release_interface(h, 0);
    libusb_close(h);
    libusb_exit(ctx);
    return 0;
}
