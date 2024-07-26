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