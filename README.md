# arm-static-bins
Some static bins for arm5/7l device, native build with [Tomatoware](https://github.com/lancethepants/tomatoware) or Alpine cross-musl.

```
Architecture:           armv7l
Byte Order:             Little Endian
CPU(s):                 2
On-line CPU(s) list:    0,1
Vendor ID:              ARM
Model name:             Cortex-A9
Model:                  0
Thread(s) per core:     1
Core(s) per socket:     1
Socket(s):              2
Stepping:               r3p0
BogoMIPS:               2798.38
Flags:                  swp half thumb fastmult edsp
```
soft float and no VFP SoC.

#### Support: 

`Asus RT-AC68U`, `Netgear R7000` etc.. `BCM4708/9` based router. 

#### Tested worked on：

 `Asus`, `Asuswrt-Merlin` and `Tomato`, `DD-WRT` firmware. 

#### Note：

No special instructions, compiled based on the latest GIT code.

`packed` means bins compressed by `upx --lzma`.

> 为什么说 armv7 (非 hf) 更合理？
> 
> 指令集完美匹配：BCM4708 拥有双核 Cortex-A9 核心，它在芯片指令集设计上是标准的 ARMv7-A。如果你强行用 armv5te，编译器会为了兼容二十年前的老芯片，把很多高效的 ARMv7 原生汇编指令（比如更高效的内存屏障、分支预测优化等）全部替换成老旧、低效的替代方案。
> 
> 硬件原生支持 64 位原子操作：Cortex-A9 核心在硬件上是有 DMB（数据内存屏障）等指令来支撑 64 位原子操作的。Rust 的 armv7 标准库会直接开放 AtomicU64。
> 
> 软浮点（Soft-float）避坑：BCM4708 最坑人的地方在于它在出厂时，路由器厂商（为了省成本或授权费）把 ARMv7 标配的 VFP/NEON（浮点计算单元）给阉割掉或者关闭了。而 armv7-unknown-linux-musleabi（没有 hf）刚好就是“用 ARMv7 的指令集，但遇到浮点运算时用内核软件模拟”，这正好戳中了 BCM4708 的软肋。
