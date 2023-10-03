Source: [tor](https://github.com/torproject/tor)

results:

	file ./tor/src/app/tor
	./tor/src/app/tor: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
Usage: ./tor version
Oct 23 20:42:38.023 [notice] Tor 0.4.5.0-alpha-dev (git-0d420918e71f94be) running on Linux with Libevent 2.1.8-stable, OpenSSL 1.0.2u, Zlib 1.2.11, Liblzma 5.2.4, Libzstd 1.4.4 and Glibc 1.0.32 as libc.

#Alpine musl
Tor version 0.4.9.0-alpha-dev (git-34b53ed8df1c315a).
Tor is running on Linux with Libevent 2.1.12-stable, OpenSSL 1.1.1l, Zlib 1.2.11, Liblzma 5.2.5, Libzstd 1.5.5 and Unknown N/A as libc.
Tor compiled with GCC version 9.4.0
```



Build:

```bash
#!/bin/sh

#Build Static Tor Binary

[ -n "$1" -a "$1" = "prepare" ] && {
    #Prerequirements
    apt-get update
    apt-get install -y build-essential curl

    #lzma, zstd
    apt install -y liblzma-dev
    apt install -y libzstd-dev

    #Dependecies
    
    #zLib
    curl -fsSL "https://zlib.net/zlib-1.2.11.tar.gz" | tar zxvf -
    cd zlib-1.2.11
    ./configure --prefix=$PWD/install
    make -j$(nproc)
    make install
    cd ..


    #libevent
    curl -fsSL "https://github.com/libevent/libevent/releases/download/release-2.1.8-stable/libevent-2.1.8-stable.tar.gz" | tar zxvf -
    cd libevent-2.1.8-stable
    ./configure --prefix=$PWD/install \
               --disable-shared \
               --enable-static \
               --with-pic
    make -j$(nproc)
    make install
    cd ..


    #libssl (openssl 1.1.x will cause compile failed,so use 1.0.x whatever.)
    curl -fsSL "https://www.openssl.org/source/openssl-1.0.2u.tar.gz" | tar zxvf -
    cd openssl-1.0.2u
    ./config --prefix=$PWD/install no-shared no-dso
    make -j$(nproc)
    make install
    cd ..

}

#Tor
[ -e tor ] && git clone https://github.com/torproject/tor.git
cd tor
git pull
make distclean
./autogen.sh
./configure --enable-static-tor --enable-static-libevent \
			--enable-static-openssl --enable-static-zlib \
			--enable-zstd --enable-lzma --disable-manpage \
			--disable-html-manual --disable-asciidoc \
			--disable-unittests --disable-seccomp \
			--disable-libscrypt \
			--with-libevent-dir=$PWD/../libevent-2.1.8-stable/install \
			--with-openssl-dir=$PWD/../openssl-1.0.2u/install \
			--with-zlib-dir=$PWD/../zlib-1.2.11/install
make -j$(nproc)
strip src/app/tor
file src/app/tor
src/app/tor --version


#Alpine musl cross compile
PKG_CONFIG_PATH="${lib_dir}/pkgconfig" \
./configure --prefix=${result_dir} --host=${host} --disable-tool-name-check \
            --enable-static-tor --enable-static-libevent --enable-static-openssl --enable-static-zlib \
            --enable-zstd --enable-lzma --enable-pic \
            --disable-manpage --disable-html-manual --disable-asciidoc --disable-unittests \
            --disable-seccomp --disable-libscrypt \
            --with-libevent-dir=${install_dir} \
            --with-openssl-dir=${install_dir} \
            --with-zlib-dir=${install_dir} \
            CC=${host}-gcc CXX=${host}-g++ #ZSTD_LIBS=${install_dir}
            #CPPFLAGS="${CPPFLAGS}" LDFLAGS="${LDFLAGS}"
sed -i 's/-pie//g' Makefile
```

