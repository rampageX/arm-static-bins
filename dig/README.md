Source: [dig](https://www.isc.org/bind/)

results:

	file ./dig
	./kdig: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
dig -v
DiG 9.16.10
```

Compile note:

```bash
./configure --prefix=/mmc --with-openssl=/mmc --without-libxml2 --with-libxml2=no --with-lmdb=no --enable-full-report --without-python

cd lib
make -j7
cd bin/dig
make -j7 LDFLAGS="-static -s" BUILD_LDFLAGS="-static -s"
```

