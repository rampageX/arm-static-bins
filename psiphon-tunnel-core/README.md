Console app for <a href="https://github.com/Psiphon-Labs/psiphon-tunnel-core/tree/master/ConsoleClient" target="_blank">Psiphon</a>

```bash
psiphon-tunnel-core -v
Psiphon Console Client
  Build Date: 2024-07-18T21:32:36+08:00
  Built With: go1.22.1
  Repository: https://github.com/Psiphon-Labs/psiphon-tunnel-core.git
  Revision: e029252
```


```bash
file `which psiphon-tunnel-core`
/opt/sbin/psiphon-tunnel-core: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, Go BuildID=JhVYM7xs8xlGbHMGqQBd/xniZPBLHl9jiV9lpdfL3/gZhvQJeCOxSxsioHC6_d/m1hhUX-T9vuYhnmDGa5z, stripped
```



Add armv5 compile to psiphon-tunnel-core/ConsoleClientmake.bash:

```bash
build_for_armv5 () {
  prepare_build arm

  echo "...Building linux-arm"
  # TODO: is "CFLAGS=-m32" required?
  GOOS=linux GOARCH=arm GOARM=5 go build -v -x -ldflags "$LDFLAGS" -tags "${BUILD_TAGS}" -o bin/armv5/${EXE_BASENAME}-armv5
  RETVAL=$?
  if [ $RETVAL != 0 ]; then
    echo ".....gox failed, exiting"
    exit $RETVAL
  fi
  unset RETVAL

  echo "....STRIP packaging output"
  /opt/tomatoware/arm-musl-mmc/bin/arm-linux-strip bin/armv5/${EXE_BASENAME}-armv5
  RETVAL=$?
  if [ $RETVAL != 0 ]; then
    echo ".....STRIP failed, exiting"
    exit $RETVAL
  fi
  unset RETVAL
}
```
