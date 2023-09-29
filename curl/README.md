Source: [curl](https://curl.se/)

Full functions curl static build with mbedTLS/WolfSSL/OpenSSL and a tiny version. 8.3.0+ support HTTP3.

```
curl 8.3.0 (armv5t-pc-linux-gnu) libcurl/8.3.0 OpenSSL/3.1.2 zlib/1.3 brotli/1.1.0 zstd/1.5.5 libidn2/2.3.4 libssh2/1.11.0 nghttp2/1.56.0 ngtcp2/0.19.1 nghttp3/0.15.0
Release-Date: 2023-09-13
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS brotli HSTS HTTP2 HTTP3 HTTPS-proxy IDN IPv6 Largefile libz NTLM NTLM_WB SSL threadsafe TLS-SRP TrackMemory UnixSockets zstd
```

results:

	file ./curl
	./curl: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
curlm -V;curlo -V;curlw -V;curlt -V

#wolfSSL Version
curl 7.79.0 (armv7l-unknown-linux-uclibceabi) libcurl/7.79.0 wolfSSL/4.8.1 zlib/1.2.11 brotli/1.0.9 zstd/1.5.0 c-ares/1.17.2 libidn2/2.3.2 libpsl/0.21.1 (+libidn2/2.3.2) libssh2/1.10.0 nghttp2/1.45.0
Release-Date: 2021-09-15
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp scp sftp smtp smtps telnet tftp
Features: alt-svc AsynchDNS brotli HSTS HTTP2 IDN IPv6 Largefile libz PSL SSL UnixSockets zstd

#OpenSSL Version
curl 7.79.0 (armv7l-unknown-linux-uclibceabi) libcurl/7.79.0 OpenSSL/1.1.1l zlib/1.2.11 brotli/1.0.9 zstd/1.5.0 c-ares/1.17.2 libidn2/2.3.2 libpsl/0.21.1 (+libidn2/2.3.2) libssh2/1.10.0 nghttp2/1.45.0
Release-Date: 2021-09-15
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS brotli HSTS HTTP2 HTTPS-proxy IDN IPv6 Largefile libz NTLM NTLM_WB PSL SSL TLS-SRP UnixSockets zstd

#mbedTLS Version
curl 7.79.0 (armv7l-unknown-linux-uclibceabi) libcurl/7.79.0 mbedTLS/3.0.0 zlib/1.2.11 brotli/1.0.9 zstd/1.5.0 c-ares/1.17.2 libidn2/2.3.2 libpsl/0.21.1 (+libidn2/2.3.2) libssh2/1.10.0 nghttp2/1.45.0
Release-Date: 2021-09-15
Protocols: dict file ftp ftps gopher gophers http https imap imaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp
Features: alt-svc AsynchDNS brotli HSTS HTTP2 IDN IPv6 Largefile libz NTLM NTLM_WB PSL SSL UnixSockets zstd

#Tiny Version
curl 7.79.0 (armv7l-unknown-linux-uclibceabi) libcurl/7.79.0 wolfSSL/4.8.1
Release-Date: 2021-09-15
Protocols: http https
Features: AsynchDNS SSL
```

Compile note:

8.3.0+ use this script: [static-curl-http3](https://github.com/rampageX/static-curl)

Old:

```bash
#!/bin/sh

#[ ! -e ./curl.pem ] && wget -qO curl.pem https://curl.haxx.se/ca/cacert.pem

#build_openssl=true
#build_wolfssl=true
#build_mbedtls=true
build_tiny=true
#build_mmc=true
proxy="192.168.2.20:7575"

[ -n "$1" ] && ssVersion=$1 || ssVersion="git"

[ $build_wolfssl ] && mkdir -p done/${ssVersion}/WolfSSL
[ $build_openssl ] && mkdir -p done/${ssVersion}/OpenSSL
[ $build_mbedtls ] && mkdir -p done/${ssVersion}/MbedTLS
[ $build_tiny ] && mkdir -p done/${ssVersion}/Tiny

[ $build_tiny ] && {
echo "Compiling TinyCurl Static Version..."
make clean
./configure --prefix=/opt --with-ca-bundle=/etc/ssl/cert.pem --with-wolfssl=/mmc --without-ssl --without-brotli --without-libpsl --disable-ldap --disable-shared --disable-verbose --disable-ipv6 --disable-libcurl-option --disable-rtsp --disable-zlib --disable-dict --disable-file --disable-ftp --disable-ftps --disable-gopher --disable-imap --disable-imaps --disable-pop3 --disable-pop3s --disable-smtp --disable-smtps --disable-telnet --disable-tftp --without-libidn2 --without-zlib --without-nghttp2 --disable-unix-sockets --without-zstd --disable-mqtt
sed -i '/gen.pl mainpage/d' docs/cmdline-opts/Makefile
make -j8 LDFLAGS="-all-static -s" LIBS="-ldl" CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1
[ $? -eq 0 ] || { echo "Compiling Curl failed."; exit 1; }
cp -f curl-config done/${ssVersion}/Tiny/
mv -f src/curl done/${ssVersion}/Tiny/curlt
}

[ $build_wolfssl ] && {
echo "Compiling WolfSSL Static Version..."
make clean
./configure --prefix=/opt --with-ca-bundle=/etc/ssl/cert.pem --with-wolfssl --without-ssl --with-nghttp2 --with-libssh2 --enable-ares --disable-ldap --disable-shared --disable-manual --without-krb4
sed -i '/gen.pl mainpage/d' docs/cmdline-opts/Makefile
make -j8 LDFLAGS="-all-static -s" LIBS="-ldl" CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1
[ $? -eq 0 ] || { echo "Compiling Curl failed."; exit 1; }
cp -f curl-config done/${ssVersion}/WolfSSL/
mv -f src/curl done/${ssVersion}/WolfSSL/curlw
}

[ $build_mbedtls ] && {
echo "Compiling MbedTLS Static Version..."
make clean
./configure --prefix=/opt --with-ca-bundle=/etc/ssl/cert.pem --with-mbedtls --without-ssl --with-nghttp2 --with-libssh2 --enable-ares --disable-ldap --disable-shared --disable-manual --without-krb4
sed -i '/gen.pl mainpage/d' docs/cmdline-opts/Makefile
make -j8 LDFLAGS="-all-static -s" LIBS="-ldl" CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1
[ $? -eq 0 ] || { echo "Compiling Curl failed."; exit 1; }
cp -f curl-config done/${ssVersion}/MbedTLS/
mv -f src/curl done/${ssVersion}/MbedTLS/curlm
}

[ $build_openssl ] && {
echo "Compiling OpenSSL Install Version..."

make clean
#My config （debian）
./configure --prefix=/opt --with-ca-bundle=/etc/ssl/cert.pem --with-ca-fallback --with-ssl=/mmc --with-nghttp2 --with-libssh2 --enable-ares --disable-ldap --disable-shared --disable-manual --without-krb4

#tomatoware default add https suport
#./configure --prefix=/opt --with-ca-bundle=/etc/ssl/cert.pem --with-ca-fallback --with-ssl=/mmc --with-nghttp2 --enable-threaded-resolver --disable-ldap --disable-shared --without-libpsl --disable-ldap --disable-ldaps --without-libssh2 --without-libidn --without-libidn2 -disable-nls --disable-manual --without-krb4

sed -i '/gen.pl mainpage/d' docs/cmdline-opts/Makefile
make -j8 LDFLAGS="-all-static -s" LIBS="-ldl" CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1
[ $? -eq 0 ] || { echo "Compiling Curl failed."; exit 1; }
cp -f curl-config done/${ssVersion}/OpenSSL/
mv -f src/curl done/${ssVersion}/OpenSSL/curlo
}

[ $build_mmc ] && {
echo "Compiling WolfSSL MMC Version..."
make clean
./configure --prefix=/mmc --with-ca-bundle=/etc/ssl/cert.pem --with-wolfssl --without-ssl --with-nghttp2 --with-libssh2 --enable-ares --disable-ldap --disable-shared --disable-manual --without-krb4
make -j8 V=1
[ $? -eq 0 ] || { echo "Compiling Curl failed."; exit 1; }
make install
}

if [ $build_openssl ] || [ $build_wolfssl ] || [ $build_mbedtls ] || [ $build_tiny ]; then echo -e "Compile Result:\n"; fi

[ $build_wolfssl ] && file done/${ssVersion}/WolfSSL/curlw
[ $build_openssl ] && file done/${ssVersion}/OpenSSL/curlo
[ $build_mbedtls ] && file done/${ssVersion}/MbedTLS/curlm
[ $build_tiny ] && file done/${ssVersion}/Tiny/curlt

echo ""

[ $build_wolfssl ] && done/${ssVersion}/WolfSSL/curlw -V
#[ $build_wolfssl ] && done/${ssVersion}/WolfSSL/curl -I -v -m 5 --socks5-hostname $proxy https://twitter.com
[ $build_openssl ] && done/${ssVersion}/OpenSSL/curlo -V
#[ $build_openssl ] && done/${ssVersion}/OpenSSL/curl -I -v -m 5 --socks5-hostname $proxy https://twitter.com
[ $build_mbedtls ] && done/${ssVersion}/MbedTLS/curlm -V
#[ $build_mbedtls ] && done/${ssVersion}/MbedTLS/curl -I -v -m 5 --socks5-hostname $proxy https://twitter.com
[ $build_tiny ] && done/${ssVersion}/Tiny/curlt -V

[ $build_mmc ] && {
	ldd src/curl
	echo ""
	src/curl -V
	src/curl -I -v -m 5 --socks5-hostname $proxy https://twitter.com
}

```

