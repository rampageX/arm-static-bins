Source: [haproxy](https://www.haproxy.org/)

Results:

	file ./haproxy
	./haproxy: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped

Full version:

```
HA-Proxy version 2.2.5-34b2b10 2020/11/05 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2025.
Known bugs: http://www.haproxy.org/bugs/bugs-2.2.5.html
Running on: Linux 2.6.36.4brcmarm #7 SMP PREEMPT Tue Sep 22 17:36:38 CEST 2020 armv7l
Build options :
  TARGET  = linux-uclibc
  CPU     = native
  CC      = distcc arm-linux-gcc
  CFLAGS  = -O2 -march=native -g -Wall -Wextra -Wdeclaration-after-statement -fwrapv -Wno-address-of-packed-member -Wno-unused-label -Wno-sign-compare -Wno-unused-parameter -Wno-clobbered -Wno-missing-field-initializers -Wno-stringop-overflow -Wno-cast-function-type -Wtype-limits -Wshift-negative-value -Wshift-overflow=2 -Wduplicated-cond -Wnull-dereference
  OPTIONS = USE_PCRE=1 USE_PCRE_JIT=1 USE_LIBCRYPT= USE_CRYPT_H= USE_GETADDRINFO= USE_OPENSSL=1 USE_LUA=1 USE_ZLIB=1 USE_NS=

Feature list : -EPOLL -KQUEUE -NETFILTER +PCRE +PCRE_JIT -PCRE2 -PCRE2_JIT +POLL -PRIVATE_CACHE -THREAD -PTHREAD_PSHARED -BACKTRACE -STATIC_PCRE -STATIC_PCRE2 -TPROXY -LINUX_TPROXY -LINUX_SPLICE -LIBCRYPT -CRYPT_H -GETADDRINFO +OPENSSL +LUA -FUTEX -ACCEPT4 -CLOSEFROM +ZLIB -SLZ -CPU_AFFINITY -TFO -NS -DL -RT -DEVICEATLAS -51DEGREES -WURFL -SYSTEMD -OBSOLETE_LINKER -PRCTL -THREAD_DUMP -EVPORTS

Default settings :
  bufsize = 16384, maxrewrite = 1024, maxpollevents = 200

Built with OpenSSL version : OpenSSL 1.1.1h  22 Sep 2020
Running on OpenSSL version : OpenSSL 1.1.1h  22 Sep 2020
OpenSSL library supports TLS extensions : yes
OpenSSL library supports SNI : yes
OpenSSL library supports : TLSv1.0 TLSv1.1 TLSv1.2 TLSv1.3
Built with Lua version : Lua 5.3.5
Built with zlib version : 1.2.11
Running on zlib version : 1.2.11
Compression algorithms supported : identity("identity"), deflate("deflate"), raw-deflate("deflate"), gzip("gzip")
Built with transparent proxy support using: IP_TRANSPARENT IP_FREEBIND
Built without multi-threading support (USE_THREAD not set).
Built with PCRE version : 8.43 2019-02-23
Running on PCRE version : 8.43 2019-02-23
PCRE library supports JIT : yes
Encrypted password support via crypt(3): no
Built with gcc compiler version 9.2.0

Available polling systems :
       poll : pref=200,  test result OK
     select : pref=150,  test result OK
Total: 2 (2 usable), will use poll.

Available multiplexer protocols :
(protocols marked as <default> cannot be specified using 'proto' keyword)
            fcgi : mode=HTTP       side=BE        mux=FCGI
       <default> : mode=HTTP       side=FE|BE     mux=H1
              h2 : mode=HTTP       side=FE|BE     mux=H2
       <default> : mode=TCP        side=FE|BE     mux=PASS

Available services : none

Available filters :
	[SPOE] spoe
	[COMP] compression
	[TRACE] trace
	[CACHE] cache
	[FCGI] fcgi-app
```
Lite version:

```
HA-Proxy version 2.2.5-34b2b10 2020/11/05 - https://haproxy.org/
Status: long-term supported branch - will stop receiving fixes around Q2 2025.
Known bugs: http://www.haproxy.org/bugs/bugs-2.2.5.html
Running on: Linux 2.6.36.4brcmarm #7 SMP PREEMPT Tue Sep 22 17:36:38 CEST 2020 armv7l
Build options :
  TARGET  = linux-uclibc
  CPU     = generic
  CC      = distcc arm-linux-gcc
  CFLAGS  = -O2 -g -Wall -Wextra -Wdeclaration-after-statement -fwrapv -Wno-address-of-packed-member -Wno-unused-label -Wno-sign-compare -Wno-unused-parameter -Wno-clobbered -Wno-missing-field-initializers -Wno-stringop-overflow -Wno-cast-function-type -Wtype-limits -Wshift-negative-value -Wshift-overflow=2 -Wduplicated-cond -Wnull-dereference
  OPTIONS = USE_LIBCRYPT= USE_CRYPT_H= USE_NS=

Feature list : -EPOLL -KQUEUE -NETFILTER -PCRE -PCRE_JIT -PCRE2 -PCRE2_JIT +POLL -PRIVATE_CACHE -THREAD -PTHREAD_PSHARED -BACKTRACE -STATIC_PCRE -STATIC_PCRE2 -TPROXY -LINUX_TPROXY -LINUX_SPLICE -LIBCRYPT -CRYPT_H -GETADDRINFO -OPENSSL -LUA -FUTEX -ACCEPT4 -CLOSEFROM -ZLIB -SLZ -CPU_AFFINITY -TFO -NS -DL -RT -DEVICEATLAS -51DEGREES -WURFL -SYSTEMD -OBSOLETE_LINKER -PRCTL -THREAD_DUMP -EVPORTS

Default settings :
  bufsize = 16384, maxrewrite = 1024, maxpollevents = 200

Built without compression support (neither USE_ZLIB nor USE_SLZ are set).
Compression algorithms supported : identity("identity")
Built with transparent proxy support using: IP_TRANSPARENT IP_FREEBIND
Built without multi-threading support (USE_THREAD not set).
Built without PCRE or PCRE2 support (using libc's regex instead)
Encrypted password support via crypt(3): no
Built with gcc compiler version 9.2.0

Available polling systems :
       poll : pref=200,  test result OK
     select : pref=150,  test result OK
Total: 2 (2 usable), will use poll.

Available multiplexer protocols :
(protocols marked as <default> cannot be specified using 'proto' keyword)
            fcgi : mode=HTTP       side=BE        mux=FCGI
       <default> : mode=HTTP       side=FE|BE     mux=H1
              h2 : mode=HTTP       side=FE|BE     mux=H2
       <default> : mode=TCP        side=FE|BE     mux=PASS

Available services : none

Available filters :
	[SPOE] spoe
	[COMP] compression
	[TRACE] trace
	[CACHE] cache
	[FCGI] fcgi-app
```

Compile note:

```bash
#!/bin/sh

#USE_IPV6= to disable IPV6 support

mkdir -p done/lite
mkdir -p done/all

#1.9.x  USE_CRYPT_H= USE_LIBCRYPT=
make clean
make TARGET=linux-uclibc CPU=native USE_GETADDRINFO= USE_PCRE=1 USE_PCRE_JIT=1 USE_LUA=1 USE_ZLIB=1 USE_OPENSSL=1 USE_CRYPT_H= USE_LIBCRYPT= ADDLIB="-lpthread -lc -ldl -lz" LDFLAGS="-Wl,-static -static -static-libgcc -s" CC="distcc arm-linux-gcc" V=1 -j7
[ "$?" -eq 0 ] && mv ./haproxy done/all/ || echo "All version Build failed."

#1.9.x+ LITE
make clean
make TARGET=linux-uclibc USE_CRYPT_H= USE_LIBCRYPT= LDFLAGS="-Wl,-static -static -static-libgcc -s" CC="distcc arm-linux-gcc" V=1 -j7
[ "$?" -eq 0 ] && mv ./haproxy done/lite/ || echo "Lite version Build failed."

done/all/haproxy -vv
echo -e "\n\n"
done/lite/haproxy -vv
```

