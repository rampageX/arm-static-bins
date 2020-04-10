Source: [microsocks](https://github.com/rofl0r/microsocks)

results:

	file ./microsocks
	./microsocks: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./microsocks -h

MicroSocks SOCKS5 Server Poll() version
------------------------
usage: microsocks -1 -i listenip -p port -u user -P password -b bindaddr
all arguments are optional.
by default listenip is 0.0.0.0 and port 1080.

option -b specifies which ip outgoing connections are bound to
option -1 activates auth_once mode: once a specific ip address
authed successfully with user/pass, it is added to a whitelist
and may use the proxy without auth.
this is handy for programs like firefox that don't support
user/pass auth. for it to work you'd basically make one connection
with another program that supports it, and then you can use firefox too.
```