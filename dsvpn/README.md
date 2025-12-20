Source: [dsvpn](https://github.com/jedisct1/dsvpn)

results:

	file ./dsvpn
	./crappydns: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
dsvpn -h
DSVPN 0.1.5 usage:

dsvpn	"server"
	<key file>
	<vpn server ip or name>|"auto"
	<vpn server port>|"auto"
	<tun interface>|"auto"
	<local tun ip>|"auto"
	<remote tun ip>|"auto"
	<external ip>|"auto"

dsvpn	"client"
	<key file>
	<vpn server ip or name>
	<vpn server port>|"auto"
	<tun interface>|"auto"
	<local tun ip>|"auto"
	<remote tun ip>|"auto"
	<gateway ip>|"auto"

Example:

[server]
	dd if=/dev/urandom of=vpn.key count=1 bs=32	# create key
	base64 < vpn.key		# copy key as a string
	sudo ./dsvpn server vpn.key	# listen on 443

[client]
	echo ohKD...W4= | base64 --decode > vpn.key	# paste key
	sudo ./dsvpn client vpn.key 34.216.127.34
```

Compile note:

```bash
add `-static -s` to CFLAGS 
```

