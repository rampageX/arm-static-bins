Source: [kdig](https://github.com/CZ-NIC/knot)

results:

	file ./kdig
	./kdig: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
kdig -V
kdig (Knot DNS), version 2.80
```

Compile note:

```bash
./configure --prefix=/opt --disable-daemon --disable-modules --disable-documentation --disable-fastparser --without-libidn

make V=99 LDFLAGS="-zmuldefs -all-static"

cd ./src

gcc  -g -O2 -Wall -Werror=format-security -Werror=implicit -Wstrict-prototypes -zmuldefs -static -o kdig utils/kdig/kdig-kdig_exec.o utils/kdig/kdig-kdig_main.o utils/kdig/kdig-kdig_params.o  ./.libs/libknotus.a /mnt/data/compile/knot-dns/src/.libs/libknot.a -L/mmc/lib /mnt/data/compile/knot-dns/src/.libs/libdnssec.a -Wl,--whole-archive /mmc/lib/libedit.a -lncurses /mmc/lib/libgnutls.a -lnettle -lhogweed /mmc/lib/libgmp.a /mmc/lib/libintl.a /mmc/lib/libiconv.a -lc -Wl,--no-whole-archive
```

