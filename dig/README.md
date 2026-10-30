# BIND 9.20.30 `dig` · ARMv5TE musl 静态编译

给 Tomato / Entware / BCM4708 的 `dig` 单文件构建方案（2026-10-30）。

## 下载内容

- `bind_dig_armv5te_static.sh` — Alpine 虚拟机上运行的完整 Bash 构建脚本。
- `dig_armv5te_static_9.20.30` — 本次构建的 32-bit ARMv5TE、静态链接、已 strip 的可执行文件。

## 在现有 Alpine 虚拟机运行

```sh
apk add bash curl tar xz bzip2 coreutils build-base perl autoconf automake libtool pkgconf binutils
cd /root/src
bash bind_dig_armv5te_static.sh --jobs 4
```

沿用原有交叉工具链 `/opt/cross/bin/arm-linux-musleabi-*`，并保留 `/root/src` 目录组织。输出：

```
/root/src/armv5te_result/dig_armv5te_static_9.20.30
```

构建缓存和中间目录位于 `/root/src/.downloads/bind-dig`、`/root/src/.build/armv5te/bind-dig`；全部静态依赖隔离在 `/root/src/armv5te_bind_dev`，不动已有 Nginx、Tor、kdig 的依赖库。

缺少可用代理环境变量时，自动使用 `http://192.168.2.8:7373` 下载；已有系统代理则原样沿用。下载包 SHA256 固定并核验，兼容 BusyBox `sha256sum`，重复运行会跳过已成功构建的依赖。

可选参数：

```sh
bash bind_dig_armv5te_static.sh --print       # 只显示配置，不改动系统
bash bind_dig_armv5te_static.sh --no-doh      # 裁去 DNS-over-HTTPS / nghttp2 依赖
bash bind_dig_armv5te_static.sh --rebuild     # 重新编译依赖库
```

## 为什么可以静态编译？

ISC 禁止**完整 BIND** 的 static build，原因涉及 `named` 动态模块与安全加固；此脚本只编译 `lib/` 与 `bin/dig/dig`，不会构建、安装或运行 `named`。脚本仅针对官方 `configure` 做三处限制范围明确的修改：

1. 绕过整个发行包的静态链接禁止检查；
2. 允许选用 `liburcu-mb`（较适合旧内核，而非默认 `membarrier`）；
3. 略过仅对服务端功能有意义的强制 Linux `libcap` 探测。

不修改 BIND C 源码，不静态构建 `named`，不建议将这个绕过用于服务器程序。保留 DNSSEC、DoT 和默认 DoH 查询功能；OpenSSL 以 `no-shared no-module no-dso` 构建。

## 静态依赖

| 组件 | 版本 | 用途 |
|---|---|---|
| BIND | 9.20.30 | `dig` 与必需库 |
| OpenSSL | 3.5.9 | TLS、DNSSEC 等 |
| libuv | 1.53.0 | 事件循环 |
| userspace-rcu | 0.15.7 | `liburcu-mb` |
| nghttp2 | 1.70.0 | HTTP/2 / DoH（可关闭） |
| GCC libatomic | 交叉工具链自带 | ARMv5TE 的 64 位原子操作 |

## 校验与路由器试运行

本次已用独立新建的目录**从头跑完整份脚本**（GCC 16.2 ARM musl 交叉工具链），成功输出 ELF 32-bit ARM EABI5 **statically linked**，ABI 标记 `v5TE`。QEMU `qemu-arm dig_armv5te_static_9.20.30 -v` 返回 `DiG 9.20.30`。

在路由器上执行：

```sh
chmod +x ./dig_armv5te_static_9.20.30
./dig_armv5te_static_9.20.30 -v
./dig_armv5te_static_9.20.30 @223.5.5.5 example.com A
./dig_armv5te_static_9.20.30 @223.5.5.5 example.com A +tls
./dig_armv5te_static_9.20.30 @223.5.5.5 example.com A +https
```

DoT/DoH 的证书验证应在提供可信 CA、相应 TLS 主机名的条件下单独测试；

**已在虚拟机 Alpine GCC 9.4 工具链及 Tomato 路由器上实际运行；真实 DNS/DoT/DoH 网络查询已在 ASUS RT-AC5300 路由器验证。** 


已编译成品 SHA256：

```
833768ded3c3a9064215cba700a6265a7c3f184feb2358ce07d207b149a6b206  dig_armv5te_static_9.20.30
```
<p align="right">Credit goes to knup@chatGPT</p>
