Source: [Trojan](https://github.com/trojan-gfw/trojan)


Use trojan_static_CMakeLists.txt, then:

`cmake -DENABLE_MYSQL=OFF -DENABLE_REUSE_PORT=OFF -DENABLE_STATIC=ON ..`

results:

	file ./trojan
	./trojan: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./trojan -v

Welcome to trojan 1.15.1
Boost 1_71, OpenSSL 1.1.1e  17 Mar 2020
[Disabled] MySQL Support
[Enabled] TCP_FASTOPEN Support
[Disabled] TCP_FASTOPEN_CONNECT Support
[Enabled] SSL KeyLog Support
[Enabled] NAT Support
[Enabled] TLS1.3 Ciphersuites Support
[Disabled] TCP Port Reuse Support
OpenSSL Information
Build Flags: compiler: distcc arm-linux-gcc -fPIC -pthread -Wa,--noexecstack -Wall -O3 -march=armv7-a -mtune=cortex-a9 -DOPENSSL_USE_NODELETE -DOPENSSL_PIC -DOPENSSL_CPUID_OBJ -DOPENSSL_BN_ASM_MONT -DOPENSSL_BN_ASM_GF2m -DSHA1_ASM -DSHA256_ASM -DSHA512_ASM -DKECCAK1600_ASM -DAES_ASM -DBSAES_ASM -DGHASH_ASM -DECP_NISTZ256_ASM -DPOLY1305_ASM -DZLIB -DNDEBUG -I/mmc/include -DOPENSSL_PREFER_CHACHA_OVER_GCM
```