Source: [golang](https://golang.org/dl/)

[Note](https://www.quakemachinex.com/blog/235.html)

results:

	tar --numeric-owner -czf /mnt/data/go1.15.linux-armv7.tar.gz -C /mmc/usr go

Compile note:

```bash
rm -fr /mmc/usr/go
tar -xzf /mnt/data/go1.15.linux-armv7.tar.gz -C /mmc/usr
export PATH=/mmc/usr/go/bin:$PATH
go version
```

