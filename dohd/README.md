Source: [dohd](https://github.com/dyne/dohd)

results:

	file ./dohd
	./dohd: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./dohd -h
./dohd, DNSoverHTTPS minimalist daemon.
License: AGPL
Usage: ./dohd -c cert -k key [-p port] [-d dnsserver] [-F] [-u user] [-V] [-v] [-h]
	'cert' and 'key': certificate and its private key.
	'user' : login name (when running as root) to switch to (dropping permissions)
	Default values: port=8053 dnsserver="::1"
	Use '-h' for help
	Use '-V' to show version
	Use '-v' for verbose mode
	Use '-F' for foreground mode
```