Source: [https_dns_proxy](https://github.com/aarond10/https_dns_proxy)

Results:

	file ./https_dns_proxy
	./https_dns_proxy: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped
	
	Version 2021.07.30-750c4db
	Built Aug 20 2021 21:38:46.
	System c-ares: 1.15.0
	System libcurl: libcurl/7.78.0 wolfSSL/4.8.1 zlib/1.2.11 zstd/1.5.0 c-ares/1.15.0 nghttp2/1.41.0
	


```
Usage: https_dns_proxy [-a <listen_addr>] [-p <listen_port>]
        [-d] [-u <user>] [-g <group>] [-b <dns_servers>]
        [-r <resolver_url>] [-e <subnet_addr>]
        [-t <proxy_server>] [-l <logfile>] [-x] [-v]+

  -a listen_addr         Local IPv4/v6 address to bind to. (127.0.0.1)
  -p listen_port         Local port to bind to. (5053)
  -d                     Daemonize.
  -u user                Optional user to drop to if launched as root.
  -g group               Optional group to drop to if launched as root.
  -b dns_servers         Comma-separated IPv4/v6 addresses and ports (addr:port)
                         of DNS servers to resolve resolver host (e.g. dns.google).
                         When specifying a port for IPv6, enclose the address in [].
                         (8.8.8.8,1.1.1.1,8.8.4.4,1.0.0.1,145.100.185.15,145.100.185.16,185.49.141.37)
  -4                     Force IPv4 hostnames for DNS resolvers non IPv6 networks.
  -r resolver_url        The HTTPS path to the resolver URL. default: https://dns.google/dns-query
  -t proxy_server        Optional HTTP proxy. e.g. socks5://127.0.0.1:1080
                         Remote name resolution will be used if the protocol
                         supports it (http, https, socks4a, socks5h), otherwise
                         initial DNS resolution will still be done via the
                         bootstrap DNS servers.
  -l logfile             Path to file to log to. ("-")
  -x                     Use HTTP/1.1 instead of HTTP/2. Useful with broken
                         or limited builds of libcurl. (false)
  -v                     Increase logging verbosity. (INFO)
```

Compile note:

```bash
cp -f ./CMakeLists.txt ./CMakeLists_.txt

cat << EOF >> ./CMakeLists.txt
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -s -static")
EOF

[ -d "./b" ] && rm -rf b/
mkdir b
cd b
cmake ..
sed -i "s~-lcurl~$(curl-config --static-libs)~g" CMakeFiles/https_dns_proxy.dir/link.txt
#wolfssl
sed -i "s~-lcurl~$(/mmc/dev/bin/curl-config --static-libs)~g" CMakeFiles/https_dns_proxy.dir/link.txt
make && {
    cp -f ../CMakeLists_.txt ../CMakeLists.txt
    file ./https_dns_proxy
    } || echo "Build failed!"
```

