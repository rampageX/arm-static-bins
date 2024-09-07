Source: [supervisord](https://github.com/ochinchina/supervisord)


results:

	file supervisord
	supervisord: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, Go BuildID=DWZZNLvyOaDQxG-DdeGi/UrGCISTQKQh_hqbterzT/OFPRrWIRpcSUoC9MMeSV/tI-W0bJ7fj8p8UNbd03B, stripped


```
./supervisord -h
Usage:
  supervisord [OPTIONS] [command]

Application Options:
  -c, --configuration= the configuration file
  -d, --daemon         run as daemon
      --env-file=      the environment file

Help Options:
  -h, --help           Show this help message

Available commands:
  ctl      Control a running daemon
  init     initialize a template
  service  install/uninstall/start/stop service
  version  show the version of supervisor
```