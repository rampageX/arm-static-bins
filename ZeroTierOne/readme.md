Source: [ZeroTierOne](https://github.com/zerotier/ZeroTierOne)


mod make-linux.mk:
```
# ARM32 hell -- use conservative CFLAGS
ifeq ($(ZT_ARCHITECTURE),3)
	ifeq ($(shell if [ -e /usr/bin/dpkg ]; then dpkg --print-architecture; fi),armel)
		override CFLAGS+=-march=armv5t -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
		override CXXFLAGS+=-march=armv5t -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
		ZT_USE_ARM32_NEON_ASM_CRYPTO=0
	else
		override CFLAGS+=-march=armv5t -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
		override CXXFLAGS+=-march=armv5t -mfloat-abi=soft -msoft-float -mno-unaligned-access -marm
		ZT_USE_ARM32_NEON_ASM_CRYPTO=0
	endif
endif
```

native ARM compile on tomatoware:

`ZT_STATIC=1 make -j5`

cross compile mipsel version on alpine:

`CC=mipsel-linux-muslsf-gcc CXX=mipsel-linux-muslsf-g++ ZT_STATIC=1 make -j8`

results:

ARM:
```
file ./zerotier-one
./zerotier-one: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped
```
MIPSEL:

```
file ./zerotier-one
./zerotier-one: ELF 32-bit LSB pie executable, MIPS, MIPS-I version 1 (SYSV), static-pie linked, stripped
```

./zerotier-one -h
```
ZeroTier One version 1.10.6
Copyright (c) 2020 ZeroTier, Inc.
Licensed under the ZeroTier BSL 1.1 (see LICENSE.txt)
Usage: zerotier-one [-switches] [home directory]

Available switches:
  -h                - Display this help
  -v                - Show version
  -U                - Skip privilege check and do not attempt to drop privileges
  -p<port>          - Port for UDP and TCP/HTTP (default: 9993, 0 for random)
  -d                - Fork and run as daemon (Unix-ish OSes)
  -i                - Generate and manage identities (zerotier-idtool)
  -q                - Query API (zerotier-cli)
```

Usage:

Copy `zerotier-one` to /opt/bin/, then:

```
ln -sf /opt/bin/zerotier-one zerotier-cli
ln -sf /opt/bin/zerotier-one zerotier-idtool
```