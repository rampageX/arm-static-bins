Source: [haproxy](https://www.haproxy.org/)

Results:

	file ./haproxy
	./haproxy: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped

Full version:

```
HA-Proxy version 1.8.26 2020/08/03
Copyright 2000-2020 Willy Tarreau <willy@haproxy.org>

Build options :
  TARGET  = linux2628
  CPU     = native
  CC      = distcc arm-linux-gcc
  CFLAGS  = -O2 -march=native -g -fno-strict-aliasing -Wdeclaration-after-statement -fwrapv -Wno-address-of-packed-member -Wno-null-dereference -Wno-unused-label -Wno-stringop-overflow
  OPTIONS = USE_ZLIB=1 USE_OPENSSL=1 USE_LUA=1 USE_PCRE=1 USE_PCRE_JIT=1

Default settings :
  maxconn = 2000, bufsize = 16384, maxrewrite = 1024, maxpollevents = 200

Built with OpenSSL version : OpenSSL 1.1.1g  21 Apr 2020
Running on OpenSSL version : OpenSSL 1.1.1g  21 Apr 2020
OpenSSL library supports TLS extensions : yes
OpenSSL library supports SNI : yes
OpenSSL library supports : TLSv1.0 TLSv1.1 TLSv1.2 TLSv1.3
Built with Lua version : Lua 5.3.5
Built with transparent proxy support using: IP_TRANSPARENT IPV6_TRANSPARENT IP_FREEBIND
Encrypted password support via crypt(3): yes
Built with multi-threading support.
Built with PCRE version : 8.43 2019-02-23
Running on PCRE version : 8.43 2019-02-23
PCRE library supports JIT : yes
Built with zlib version : 1.2.11
Running on zlib version : 1.2.11
Compression algorithms supported : identity("identity"), deflate("deflate"), raw-deflate("deflate"), gzip("gzip")
Built with network namespace support.

Available polling systems :
      epoll : pref=300,  test result OK
       poll : pref=200,  test result OK
     select : pref=150,  test result OK
Total: 3 (3 usable), will use epoll.

Available filters :
	[SPOE] spoe
	[COMP] compression
	[TRACE] trace

```
Lite version:

```
HA-Proxy version 1.8.26 2020/08/03
Copyright 2000-2020 Willy Tarreau <willy@haproxy.org>

Build options :
  TARGET  = linux2628
  CPU     = generic
  CC      = distcc arm-linux-gcc
  CFLAGS  = -O2 -g -fno-strict-aliasing -Wdeclaration-after-statement -fwrapv -Wno-address-of-packed-member -Wno-null-dereference -Wno-unused-label -Wno-stringop-overflow
  OPTIONS =

Default settings :
  maxconn = 2000, bufsize = 16384, maxrewrite = 1024, maxpollevents = 200

Built with transparent proxy support using: IP_TRANSPARENT IPV6_TRANSPARENT IP_FREEBIND
Encrypted password support via crypt(3): yes
Built with multi-threading support.
Built without PCRE or PCRE2 support (using libc's regex instead)
Built without compression support (neither USE_ZLIB nor USE_SLZ are set).
Compression algorithms supported : identity("identity")
Built with network namespace support.

Available polling systems :
      epoll : pref=300,  test result OK
       poll : pref=200,  test result OK
     select : pref=150,  test result OK
Total: 3 (3 usable), will use epoll.

Available filters :
	[SPOE] spoe
	[COMP] compression
	[TRACE] trace

```

Compile note:

```bash
#!/bin/sh

#USE_IPV6= to disable IPV6 support

mkdir -p done/lite
mkdir -p done/all

#1.9.x  USE_CRYPT_H= USE_LIBCRYPT=
make clean
make TARGET=linux2628 CPU=native USE_GETADDRINFO= USE_PCRE=1 USE_PCRE_JIT=1 USE_LUA=1 USE_ZLIB=1 USE_OPENSSL=1 USE_CRYPT_H= USE_LIBCRYPT= ADDLIB="-lpthread -lc -ldl -lz" LDFLAGS="-Wl,-static -static -static-libgcc -s" CC="distcc arm-linux-gcc" V=1 -j7
[ "$?" -eq 0 ] && mv ./haproxy done/all/ || echo "All version Build failed."

#1.9.x+ LITE
make clean
make TARGET=linux2628 USE_CRYPT_H= USE_LIBCRYPT= LDFLAGS="-Wl,-static -static -static-libgcc -s" CC="distcc arm-linux-gcc" V=1 -j7
[ "$?" -eq 0 ] && mv ./haproxy done/lite/ || echo "Lite version Build failed."

done/all/haproxy -vv
echo -e "\n\n"
done/lite/haproxy -vv
```

