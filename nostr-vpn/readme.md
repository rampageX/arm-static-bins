Source: [nostr-vpn](https://github.com/mmalmi/nostr-vpn)

```
cross build --release --target=armv7-unknown-linux-musleabi
```

Result:
```
file ./nvpn
./nvpn: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped
```

./nvpn -h
```
FIPS private mesh VPN

Usage: nvpn <COMMAND>

Commands:
  init                Initialize a local config file (keys are generated automatically)
  version             Show the running CLI version
  update              Update this `nvpn` binary from the latest published release
  install-cli         Install `nvpn` into a platform-appropriate default PATH location
  uninstall-cli       Remove an `nvpn` binary previously installed into PATH
  service             Manage the persistent system daemon service
  start               Start a session (foreground by default, or daemonized with --daemon)
  stop                Stop a background daemon started by `nvpn start --daemon`
  repair-network      Repair local network state left behind by a stopped or crashed VPN session
  reload              Ask the running daemon to reload config and peer set
  pause               Pause VPN networking while keeping daemon running
  resume              Resume VPN networking on a running daemon
  connect             Run a FIPS private mesh session from config
  status              Show local and discovered peer status
  set                 Update persisted node/network settings
  create-invite       Emit a full `nvpn://invite/...` code for the active network
  import-invite       Import a full `nvpn://invite/...` code into the active network config
  invite-broadcast    Broadcast the active network's invite over LAN multicast so nearby devices running `nvpn discover` can pair without copy/pasting a code. Runs in the foreground; Ctrl-C stops broadcasting
  discover            Listen for nearby LAN invite broadcasts and print what's found. With `--accept`, import the first valid invite seen (queues a join request to the broadcaster, same as `nvpn import-invite`)
  add-participant     Add one or more participants to the active network roster
  remove-participant  Remove one or more participants from the active network roster
  add-admin           Add one or more admins to the active network roster
  remove-admin        Remove one or more admins from the active network roster
  ping                Ping a peer by node ID or tunnel IP
  doctor              Diagnose runtime/network issues and optionally write a support bundle
  ip                  Show local or peer tunnel IPs
  whois               Resolve a node/tunnel IP to peer metadata
  wg-upstream-test    Probe a WireGuard upstream config (Mullvad/Proton-style) by running the userspace WG state machine against it and reporting whether the handshake completes. Without --replace-default or --scoped-host, this does not create a tun device and does not modify routes
  help                Print this message or the help of the given subcommand(s)

Options:
  -h, --help  Print help
```
