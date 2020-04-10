Source: [shadowsocksr-libev](https://github.com/shadowsocksrr/shadowsocksr-libev)

Results:

	file ./ss-local
	./ss-local: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
shadowsocksr-libev 2.5.6 with mbed TLS 2.16.0

  maintained by Max Lv <max.c.lv@gmail.com> and Linus Yang <laokongzi@gmail.com>

  usage:

    ss-local

       -s <server_host>           Host name or IP address of your remote server.
       -p <server_port>           Port number of your remote server.
       -l <local_port>            Port number of your local server.
       -k <password>              Password of your remote server.
       -m <encrypt_method>        Encrypt method: table, rc4, rc4-md5,
                                  aes-128-cfb, aes-192-cfb, aes-256-cfb,
                                  aes-128-ctr, aes-192-ctr, aes-256-ctr,
                                  bf-cfb, camellia-128-cfb, camellia-192-cfb,
                                  camellia-256-cfb, cast5-cfb, des-cfb,
                                  idea-cfb, rc2-cfb, seed-cfb, salsa20,
                                  chacha20 and chacha20-ietf.
                                  The default cipher is rc4-md5.

       [-a <user>]                Run as another user.
       [-f <pid_file>]            The file path to store pid.
       [-t <timeout>]             Socket timeout in seconds.
       [-c <config_file>]         The path to config file.
       [-n <number>]              Max number of open files.
       [-i <interface>]           Network interface to bind.
       [-b <local_address>]       Local address to bind.

       [-u]                       Enable UDP relay.
       [-U]                       Enable UDP relay and disable TCP relay.

       [--fast-open]              Enable TCP fast open.
                                  with Linux kernel > 3.7.0.
       [--acl <acl_file>]         Path to ACL (Access Control List).
       [--mtu <MTU>]              MTU of your network interface.
       [--mptcp]                  Enable Multipath TCP on MPTCP Kernel.

       [-v]                       Verbose mode.
       [-h, --help]               Print this message.
```

Compile note:

```bash
echo "Compiling MbedTLS Version..."
make clean
CONFIGURE="./configure --prefix=/opt --disable-documentation --disable-assert --disable-ssp"
$CONFIGURE --with-crypto-library=mbedtls --with-mbedtls=/mmc/lib --with-mbedtls-include=/mmc/include
#then edit src/Makefile , find the LDFLAGS variable, and set it to "-all-static"
sed -i 's/^LDFLAGS = /LDFLAGS = -all-static -s /g' src/Makefile
make -j2
```

