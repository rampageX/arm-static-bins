Source: [rrredir](https://github.com/rofl0r/rrredir)

results:

	file ./rrredir
	./rrredir: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
./rrredir -h
RR Redir - a round-robin port redirector
----------------------------------------
usage: rrredir [-i listenip -p port -t timeout -b bindaddr] ip1:port1 ip2:port2 ...
all arguments are optional.
by default listenip is 0.0.0.0 and port 1080.

option -b specifies the default ip outgoing connections are bound to
it can be overruled per-target by appending @bindip to the target addr
e.g. ip1:port1@bindip1
the -t timeout is specified in seconds, default: 0
if timeout is set to 0, block until the OS cancels conn. attempt

all incoming connections will be redirected to ip1:port1, followed
by ip2:port2 if the former host is unreachable, etc.
```



note: `timeout float` version can set timeout < 1, say 0.1-0.9 etc.

We can use that do a DNS server balancer:

```
rrredir -t 1 -p 6666 1.1.1.1:53 9.9.9.9:9953 208.67.222.222:553 208.67.220.220:443
rrredir -t 0.3 -p 6666 dns.pub:443 dns.alidns.com:443 dns.twnic.tw:443
rrredir -t 0.3 -p 6666 1.1.1.1:853 1.0.0.1:853 9.9.9.11:853 233.5.5.5:853
```

then:

```
dig @127.0.0.1 -p 6666 +tcp taobao.com
kdig -4 +https -d taobao.com @127.0.0.1:6666
kdig -4 +tls -d taobao.com @127.0.0.1:6666
```

