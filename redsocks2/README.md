Source: [redsocks](https://github.com/semigodking/redsocks/tree/master)

results:
```
file /opt/sbin/redsocks2
/opt/sbin/redsocks2: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped
```

```
redsocks2 -v
redsocks release-0.72 
mbedTLS
Features: DISABLE_SHADOWSOCKS STATIC_COMPILE
Built with libevent-2.1.12-stable
Runs  with libevent-2.1.12-stable
```

Compile:

```bash
#!/bin/sh

[ -n "$1" ] && ssVersion=$1 || ssVersion="git"

mkdir -p done/${ssVersion}/OpenSSL/packed
mkdir -p done/${ssVersion}/MBEDTLS/packed
mkdir -p done/${ssVersion}/Lite/packed

echo "Compiling OpenSSL Version..."
make distclean
make -j6 CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1 ENABLE_STATIC=true DISABLE_SHADOWSOCKS=true ENABLE_HTTPS_PROXY=true
mv -f ./redsocks2 done/${ssVersion}/OpenSSL/


echo "Compiling MBEDTLS Version..."
make distclean
make -j6 CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1 ENABLE_STATIC=true DISABLE_SHADOWSOCKS=true USE_CRYPTO_MBEDTLS=true ENABLE_HTTPS_PROXY=true

mv -f ./redsocks2 done/${ssVersion}/MBEDTLS/

echo "Compiling Lite Version..."
make distclean
make -j6 CC="distcc arm-linux-gcc" CXX="distcc arm-linux-g++" V=1 ENABLE_STATIC=true DISABLE_SHADOWSOCKS=true

mv -f ./redsocks2 done/${ssVersion}/Lite/

#UPX all
cp -f done/${ssVersion}/OpenSSL/redsocks2 done/${ssVersion}/OpenSSL/packed/
upx -9 done/${ssVersion}/OpenSSL/packed/*

cp -f done/${ssVersion}/MBEDTLS/redsocks2 done/${ssVersion}/MBEDTLS/packed/
upx -9 done/${ssVersion}/MBEDTLS/packed/*

cp -f done/${ssVersion}/Lite/redsocks2 done/${ssVersion}/Lite/packed/
upx -9 done/${ssVersion}/Lite/packed/*

file done/${ssVersion}/MBEDTLS/packed/redsocks2
done/${ssVersion}/MBEDTLS/packed/redsocks2 -v

file done/${ssVersion}/OpenSSL/packed/redsocks2
done/${ssVersion}/OpenSSL/packed/redsocks2 -v

file done/${ssVersion}/Lite/packed/redsocks2
done/${ssVersion}/Lite/packed/redsocks2 -v
```
