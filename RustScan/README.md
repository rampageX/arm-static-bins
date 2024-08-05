Source: [RustScan](https://github.com/RustScan/RustScan/)

The Modern Port Scanner. Find ports quickly (3 seconds at its fastest). Run scripts through our scripting engine (Python, Lua, Shell supported).

✨ Features
* Scans all 65k ports in 3 seconds.
* Full scripting engine support. Automatically pipe results into Nmap, or use our scripts (or write your own) to do whatever you want.
* Adaptive learning. RustScan improves the more you use it. No bloated machine learning here, just basic maths.
* The usuals you would expect. IPv6, CIDR, file input and more.
* Automatically pipes ports into Nmap.

results:

```bash
file ./rustscan
./rustscan: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, stripped
```

Compile note:

`RUSTFLAGS="-C linker=arm-linux-musleabi-gcc" cargo build --release --target armv5te-unknown-linux-musleabi` will fail, so use <a href="https://github.com/cross-rs/cross" target="_blank">cross</a>:

```bash
cargo install cross
rustup target add armv5te-unknown-linux-musleabi
cross build --target=armv5te-unknown-linux-musleabi
```
