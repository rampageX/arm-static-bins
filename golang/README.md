Source: [golang](https://golang.org/dl/)

Note: [Tomatoware ARM 下建立 Go 编译环境](https://www.quakemachinex.com/blog/235.html)

Packed:

	tar --numeric-owner -czf /mnt/data/go1.15.linux-armv7.tar.gz -C /mmc/usr go

Usage:

```bash
rm -fr /mmc/usr/go
tar -xzf /mnt/data/go1.15.linux-armv7.tar.gz -C /mmc/usr
export PATH=/mmc/usr/go/bin:$PATH
go version
```

