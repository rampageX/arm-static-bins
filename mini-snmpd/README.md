Source: [mini-snmpd](https://github.com/troglobit/mini-snmpd)

results:

	file ./mini-snmpd
	./mini-snmpd: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped


```
Usage: mini-snmpd [options]

  -a, --auth             Enable authentication, i.e. SNMP version 2c
  -c, --community STR    Community string, default: public
  -C, --contact STR      System contact, default: none
  -d, --disks PATH       Disks to monitor, default: /
  -D, --description STR  System description, default: none
  -h, --help             This help text
  -i, --interfaces IFACE Network interfaces to monitor, default: none
  -I, --listen IFACE     Network interface to listen, default: all
  -l, --loglevel LEVEL   Set log level: none, err, info, notice*, debug
  -L, --location STR     System location, default: none
  -n, --foreground       Run in foreground, do not detach from controlling terminal
  -p, --udp-port PORT    UDP port to bind to, default: 161
  -P, --tcp-port PORT    TCP port to bind to, default: 161
  -s, --syslog           Use syslog for logging, even if running in the foreground
  -t, --timeout SEC      Timeout for MIB updates, default: 1 second
  -u, --drop-privs USER  Drop privileges after opening sockets to USER, default: no
  -v, --version          Show program version and exit
  -V, --vendor OID       System vendor, default: none

Bug report address: https://github.com/troglobit/mini-snmpd/issues
Project homepage: https://troglobit.com/projects/mini-snmpd/
```