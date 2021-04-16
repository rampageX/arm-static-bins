Source: [stunnel](https://www.stunnel.org/)

results:

	file ./stunnel
	./stunnel: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./stunnel -version
stunnel 5.56 on armv7l-unknown-linux-uclibceabi platform
Compiled/running with OpenSSL 1.1.1d  10 Sep 2019
Threading:PTHREAD Sockets:POLL,IPv6 TLS:ENGINE,FIPS,OCSP,PSK,SNI

Global options:
RNDbytes               = 1024
RNDfile                = /dev/urandom
RNDoverwrite           = yes

Service-level options:
ciphers                = FIPS (with "fips = yes")
ciphers                = HIGH:!aNULL:!SSLv2:!DH:!kDHEPSK (with "fips = no")
ciphersuites           = TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256 (with TLSv1.3)
curves                 = X25519:P-256:X448:P-521:P-384
debug                  = daemon.notice
logId                  = sequential
options                = NO_SSLv2
options                = NO_SSLv3
sessionCacheSize       = 1000
sessionCacheTimeout    = 300 seconds
stack                  = 65536 bytes
TIMEOUTbusy            = 300 seconds
TIMEOUTclose           = 60 seconds
TIMEOUTconnect         = 10 seconds
TIMEOUTidle            = 43200 seconds
verify                 = none
```

Compile note:

```bash
./configure --prefix=/opt --disable-systemd --with-threads=pthread --with-ssl=/mmc
make LDFLAGS="-Wl,-static -static -static-libgcc -s" LIBS="-ldl -lz"
```

