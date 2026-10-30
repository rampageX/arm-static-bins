#!/usr/bin/env bash
# Build ISC BIND 9 dig ONLY, fully static for ARMv5TE soft-float + musl.
# Tested against BIND 9.20.30 with GCC 16.2.0; intended for the user's
# /opt/cross/bin/arm-linux-musleabi-* toolchain (GCC 9.4) on Alpine.
# Do not use the static-link bypass below to build/deploy named or loadable plugins.
set -Eeuo pipefail

ROOT="${ROOT:-/root/src}"
ARCH=armv5te
BIND_VERSION="${BIND_VERSION:-9.20.30}"
OPENSSL_VERSION=3.5.9
LIBUV_VERSION=1.53.0
URCU_VERSION=0.15.7
NGHTTP2_VERSION=1.70.0
DOH=1
REBUILD=0
DRY_RUN=0
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 4)}"
PROXY_FALLBACK="${PROXY_FALLBACK:-http://192.168.2.8:7373}"

# SHA256 checksums from the exact upstream source archives (2026-10-29).
# A different BIND release is accepted only with an explicit SHA256 override.
BIND_SHA256_DEFAULT=9e1443a40a72a30272cbc3196d020a6b2e26937111c83e59e101e82e1e3b4fef
OPENSSL_SHA256=603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a
LIBUV_SHA256=cb0d6dd2128d5a95bd242c6cc982a24fe608fa93da57b6b4ec763b0018c53e64
URCU_SHA256=2556b83adc0f9b3ac8024e613e17d014d04c4c49110604ce55fcb14eae32edd3
NGHTTP2_SHA256=e05cb1388eaca3830aded4ccf20044b6e1ac1a61411dcca11b0437c4285c8bc2

usage() {
  printf '%s\n' \
    'Usage: bash bind_dig_armv5te_static.sh [--jobs N] [--no-doh] [--rebuild] [--print]' \
    '       [--version 9.20.x] (also set BIND_SHA256 for other releases)' \
    '' \
    'Purpose: Build only BIND 9 dig as ARMv5TE soft-float, fully static.' \
    'BIND 9.20.30 includes DNSSEC, DoT and (default) DoH; no named or plugins.' \
    'Required build tools: bash curl tar sha256sum make gcc perl autoconf automake' \
    '                      libtoolize pkg-config sed grep awk file readelf.' \
    'Alpine: apk add bash curl tar xz bzip2 coreutils build-base perl autoconf automake libtool pkgconf binutils' \
    'Cross toolchain: /opt/cross/bin/arm-linux-musleabi-gcc et al.' \
    '' \
    'Optional environment: ROOT=/root/src CROSS_PREFIX=arm-linux-musleabi-' \
    '                      CROSS_BIN_DIR=/opt/cross/bin JOBS=4' \
    '                      PROXY_FALLBACK=http://192.168.2.8:7373' \
    '                      BIND_SHA256=<64 hex chars> for --version override' \
    'Output: /root/src/armv5te_result/dig_armv5te_static_9.20.30' \
    'Deps:   /root/src/armv5te_bind_dev (isolated from nginx/tor/kdig).'
}

while (($#)); do
  case "$1" in
    --jobs) JOBS="${2:?--jobs requires N}"; shift 2 ;;
    --version) BIND_VERSION="${2:?--version requires version}"; shift 2 ;;
    --no-doh) DOH=0; shift ;;
    --rebuild) REBUILD=1; shift ;;
    --print|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid jobs count' >&2; exit 2; }
[[ "$BIND_VERSION" =~ ^9\.20\.[0-9]+$ ]] || { echo 'Only the BIND 9.20 stable branch is supported' >&2; exit 2; }
if [[ "$BIND_VERSION" == 9.20.30 ]]; then
  BIND_SHA256="${BIND_SHA256:-$BIND_SHA256_DEFAULT}"
else
  BIND_SHA256="${BIND_SHA256:-}"
  [[ -n "$BIND_SHA256" ]] || { echo '--version override requires BIND_SHA256' >&2; exit 2; }
fi
[[ "$BIND_SHA256" =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'Invalid BIND_SHA256' >&2; exit 2; }

WORK="$ROOT/.build/$ARCH/bind-dig"
DOWNLOADS="$ROOT/.downloads/bind-dig"
SOURCE_DIR="$WORK/src"
PREFIX="$ROOT/${ARCH}_bind_dev"
RESULT_DIR="$ROOT/${ARCH}_result"
MARK_DIR="$WORK/marks"
BIND_DIR="bind-$BIND_VERSION"
PKG_WRAPPER="$WORK/pkg-config-static"

if [[ -z "${http_proxy:-}${https_proxy:-}${all_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]]; then
  export http_proxy="$PROXY_FALLBACK" https_proxy="$PROXY_FALLBACK"
  export HTTP_PROXY="$PROXY_FALLBACK" HTTPS_PROXY="$PROXY_FALLBACK"
  export all_proxy="$PROXY_FALLBACK" ALL_PROXY="$PROXY_FALLBACK"
  PROXY_MODE="fallback $PROXY_FALLBACK"
else
  PROXY_MODE='existing environment'
fi

CROSS_PREFIX="${CROSS_PREFIX:-arm-linux-musleabi-}"
if [[ -n "${CROSS_BIN_DIR:-}" ]]; then
  export PATH="$CROSS_BIN_DIR:$PATH"
elif [[ -d /opt/cross/bin ]]; then
  export PATH="/opt/cross/bin:$PATH"
fi
HOST="${CROSS_PREFIX%-}"
CC="${CROSS_PREFIX}gcc"
AR="${CROSS_PREFIX}ar"
RANLIB="${CROSS_PREFIX}ranlib"
STRIP="${CROSS_PREFIX}strip"
READELF="${CROSS_PREFIX}readelf"

log() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

if (( DRY_RUN )); then
  printf 'BIND: %s; DoH: %s; jobs: %s\n' "$BIND_VERSION" "$DOH" "$JOBS"
  printf 'CC: %s; ROOT: %s; Proxy: %s\n' "$CC" "$ROOT" "$PROXY_MODE"
  printf 'Output: %s/dig_%s_static_%s\n' "$RESULT_DIR" "$ARCH" "$BIND_VERSION"
  exit 0
fi

for tool in curl tar sha256sum make gcc perl autoconf automake libtoolize \
            pkg-config sed grep awk file; do
  command -v "$tool" >/dev/null 2>&1 || die "Missing build tool: $tool (see --help)"
done
for tool in "$CC" "$AR" "$RANLIB" "$STRIP" "$READELF"; do
  command -v "$tool" >/dev/null 2>&1 || die "Missing cross tool: $tool"
done
BUILD="$(gcc -dumpmachine)"
ATOMIC_ARCHIVE="$($CC -print-file-name=libatomic.a)"
[[ "$ATOMIC_ARCHIVE" != libatomic.a && -f "$ATOMIC_ARCHIVE" ]] || \
  die 'ARM libatomic.a missing (needed for OpenSSL/BIND 64-bit atomics)'

mkdir -p "$WORK" "$DOWNLOADS" "$SOURCE_DIR" "$PREFIX" "$RESULT_DIR" \
  "$MARK_DIR" "$PREFIX/include" "$PREFIX/lib/pkgconfig"

HOST_PKG_CONFIG="$(command -v pkg-config)"
printf '#!/bin/sh\nexec "%s" --static "$@"\n' "$HOST_PKG_CONFIG" > "$PKG_WRAPPER"
chmod 755 "$PKG_WRAPPER"
export PKG_CONFIG="$PKG_WRAPPER"
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
unset PKG_CONFIG_SYSROOT_DIR || true

BASE_CFLAGS="${BASE_CFLAGS:--O2 -std=gnu11 -march=armv5te -mfloat-abi=soft -fPIC}"
BASE_CPPFLAGS="-I$PREFIX/include"
BASE_LDFLAGS="-L$PREFIX/lib"
export CC AR RANLIB STRIP
export CFLAGS="$BASE_CFLAGS" CPPFLAGS="$BASE_CPPFLAGS" LDFLAGS="$BASE_LDFLAGS"
log "Toolchain $($CC -dumpmachine): $($CC -dumpversion); proxy: $PROXY_MODE"

on_error() {
  local status=$?
  printf '\nFAILED at script line %s (exit %s).\n' "$1" "$status" >&2
  printf 'See config.log and build artifacts under %s\n' "$WORK" >&2
  exit "$status"
}
trap 'on_error "$LINENO"' ERR

verify_file() {
  local path="$1" hash="$2"
  # GNU and BusyBox sha256sum both support -c; neither's --status is universal.
  printf '%s  %s\n' "$hash" "$path" | sha256sum -c >/dev/null 2>&1
}
fetch() {
  local name="$1" sha="$2" url="$3" path="$DOWNLOADS/$1"
  if [[ -f "$path" ]] && verify_file "$path" "$sha"; then
    log "cached $name"
    return
  fi
  log "download $name"
  [[ ! -f "$path" ]] || mv "$path" "$path.invalid.$(date +%s)"
  curl -fLSs --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 360 \
    -o "$path.part" "$url"
  verify_file "$path.part" "$sha" || die "SHA256 mismatch: $name"
  mv "$path.part" "$path"
}
extract() {
  local archive="$1" dirname="$2" opts=() tar_help
  if [[ -d "$SOURCE_DIR/$dirname" ]]; then return; fi
  log "extract $archive"
  tar_help="$(tar --help 2>&1 || true)"
  [[ "$tar_help" != *'--no-same-owner'* ]] || opts+=(--no-same-owner)
  [[ "$tar_help" != *'--no-same-permissions'* ]] || opts+=(--no-same-permissions)
  tar "${opts[@]}" -xf "$DOWNLOADS/$archive" -C "$SOURCE_DIR"
  [[ -d "$SOURCE_DIR/$dirname" ]] || die "Source directory missing: $dirname"
}
done_before() {
  (( ! REBUILD )) && [[ -f "$MARK_DIR/$1" && -f "$PREFIX/lib/$2" ]]
}
mark_done() { touch "$MARK_DIR/$1"; }
autoconf_cross() {
  local dirname="$1"; shift
  ( cd "$SOURCE_DIR/$dirname"
    ./configure --build="$BUILD" --host="$HOST" --prefix="$PREFIX" "$@" )
}
make_install() {
  local dirname="$1"
  make -C "$SOURCE_DIR/$dirname" -j "$JOBS"
  make -C "$SOURCE_DIR/$dirname" install
}

# 1. OpenSSL 3.5.x static (no externally loaded provider/engine or tests).
# Important: do NOT set CC to the prefixed compiler inside OpenSSL Configure;
# it would turn into arm-linux-musleabi-arm-linux-musleabi-gcc.
if ! done_before "openssl-$OPENSSL_VERSION" libcrypto.a; then
  fetch "openssl-$OPENSSL_VERSION.tar.gz" "$OPENSSL_SHA256" \
    "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
  extract "openssl-$OPENSSL_VERSION.tar.gz" "openssl-$OPENSSL_VERSION"
  log 'configure static OpenSSL (ARMv5, no modules)'
  ( cd "$SOURCE_DIR/openssl-$OPENSSL_VERSION"
    unset CC AR RANLIB
    ./Configure linux-armv4 --cross-compile-prefix="$CROSS_PREFIX" \
      --prefix="$PREFIX" --openssldir=/opt/etc/ssl \
      no-shared no-module no-tests no-dso no-asm no-engine
    make -j "$JOBS" build_libs
    make install_dev )
  [[ -f "$PREFIX/lib/libssl.a" ]] || die 'OpenSSL libssl.a missing'
  mark_done "openssl-$OPENSSL_VERSION"
fi

# 2. Userspace RCU. BIND's default membarrier flavor requires new kernels.
# liburcu-mb instead uses portable memory barriers for old Tomato kernels.
if ! done_before "userspace-rcu-$URCU_VERSION" liburcu-mb.a; then
  fetch "userspace-rcu-$URCU_VERSION.tar.bz2" "$URCU_SHA256" \
    "https://lttng.org/files/urcu/userspace-rcu-$URCU_VERSION.tar.bz2"
  extract "userspace-rcu-$URCU_VERSION.tar.bz2" "userspace-rcu-$URCU_VERSION"
  # Some older ARM musl toolchains (including the user's GCC 9.4) define
  # __NR_futex_time64 but ship Linux UAPI headers without linux/time_types.h.
  # The time64 futex syscall must not be disabled: 32-bit musl may use a
  # 64-bit time_t. Supply only the missing UAPI struct, preserving its ABI.
  URCU_FUTEX_H="$SOURCE_DIR/userspace-rcu-$URCU_VERSION/include/urcu/futex.h"
  if ! printf '#include <linux/time_types.h>\n' | \
      "$CC" -I"$PREFIX/include" -x c -E -o /dev/null - 2>/dev/null; then
    log 'old ARM kernel headers: supply __kernel_timespec fallback for futex_time64'
    if ! grep -Fq '/* ARMv5 old-UAPI time64 compatibility */' "$URCU_FUTEX_H"; then
      grep -Fq '# include <linux/time_types.h>' "$URCU_FUTEX_H" || \
        die 'Unexpected Userspace RCU futex.h layout; cannot apply old-UAPI fix'
      perl -0pi -e 's@# include <linux/time_types\.h>@/* ARMv5 old-UAPI time64 compatibility */\nstruct __kernel_timespec { int64_t tv_sec; long long tv_nsec; };@' "$URCU_FUTEX_H"
    fi
  fi
  log 'configure Userspace RCU (static, mb flavor)'
  autoconf_cross "userspace-rcu-$URCU_VERSION" --disable-shared --enable-static
  make_install "userspace-rcu-$URCU_VERSION"
  [[ -f "$PREFIX/lib/liburcu-cds.a" ]] || die 'Userspace RCU liburcu-cds.a missing'
  mark_done "userspace-rcu-$URCU_VERSION"
fi

# 3. libuv upstream release tarballs require autogen.sh before configure.
if ! done_before "libuv-$LIBUV_VERSION" libuv.a; then
  fetch "libuv-v$LIBUV_VERSION.tar.gz" "$LIBUV_SHA256" \
    "https://dist.libuv.org/dist/v$LIBUV_VERSION/libuv-v$LIBUV_VERSION.tar.gz"
  extract "libuv-v$LIBUV_VERSION.tar.gz" "libuv-v$LIBUV_VERSION"
  log 'configure libuv (static)'
  ( cd "$SOURCE_DIR/libuv-v$LIBUV_VERSION"
    [[ -f configure ]] || ./autogen.sh )
  autoconf_cross "libuv-v$LIBUV_VERSION" --disable-shared --enable-static
  make_install "libuv-v$LIBUV_VERSION"
  mark_done "libuv-$LIBUV_VERSION"
fi

# 4. Optional DoH; nghttp2 library alone, without nghttpx and its dependencies.
if (( DOH )) && ! done_before "nghttp2-$NGHTTP2_VERSION" libnghttp2.a; then
  fetch "nghttp2-$NGHTTP2_VERSION.tar.xz" "$NGHTTP2_SHA256" \
    "https://github.com/nghttp2/nghttp2/releases/download/v$NGHTTP2_VERSION/nghttp2-$NGHTTP2_VERSION.tar.xz"
  extract "nghttp2-$NGHTTP2_VERSION.tar.xz" "nghttp2-$NGHTTP2_VERSION"
  log 'configure static nghttp2 (library only)'
  autoconf_cross "nghttp2-$NGHTTP2_VERSION" --disable-shared --enable-static --enable-lib-only
  make_install "nghttp2-$NGHTTP2_VERSION"
  mark_done "nghttp2-$NGHTTP2_VERSION"
fi

# 5. Patch the *generated configure* narrowly; do not touch the BIND C source.
# ISC deliberately forbids static linking of the complete BIND suite (named,
# dlopen plugins, hardening constraints). This script NEVER builds those parts.
# BIND 9.20 also insists on libcap on Linux even for a dig-only build.
# Both full-BIND checks are inapplicable to the stand-alone dig binary.
fetch "bind-$BIND_VERSION.tar.xz" "$BIND_SHA256" \
  "https://downloads.isc.org/isc/bind9/$BIND_VERSION/bind-$BIND_VERSION.tar.xz"
extract "bind-$BIND_VERSION.tar.xz" "$BIND_DIR"
CONF="$SOURCE_DIR/$BIND_DIR/configure"
log 'apply dig-only configure bypass (static, no kernel libcap)'
grep -Fq 'Static linking is not supported as it disables dlopen()' "$CONF" || \
  die 'BIND configure changed: cannot find upstream static linking check'
grep -Fq 'Changing Userspace-RCU variant is allowed only in developer mode' "$CONF" || \
  die 'BIND configure changed: cannot find RCU variant check'
sed -i 's/if test "$enable_static" != "no" \&\& test "$enable_developer" != "yes"/if false # dig-only static build/' "$CONF"
sed -i 's/if test "$with_liburcu" != "membarrier" \&\& test "$enable_developer" != "yes"/if false # portable RCU mb for old kernels/' "$CONF"
# Replace exactly the Linux case arm adjacent to libcap pkg-config probe.
# This leaves every unrelated OS feature detection intact.
perl -0777 -i -pe 's/(case \$host in #\(\n)  \*-linux\*\) :\n\n(pkg_failed=no\n)/${1}  *-linux-skip-libcap-for-dig-only*) :\n\n${2}/g' "$CONF"
grep -Fq '*-linux-skip-libcap-for-dig-only*) :' "$CONF" || \
  die 'BIND configure changed: cannot suppress libcap (named-only dependency)'

# 6. Do not enable developer mode just to bypass the static guard: developer
# mode also changes compiler defaults. The two checks above are scoped hacks.
log "configure BIND $BIND_VERSION: dig only, static, DoH=$DOH"
BIND_ARGS=(
  --disable-shared --enable-static --with-liburcu=mb
  --without-gssapi --with-lmdb=no --with-libxml2=no --with-json-c=no
  --with-zlib=no --with-readline=no --without-libidn2 --with-cmocka=no
  --with-jemalloc=no --with-maxminddb=no --disable-geoip --disable-dnstap
)
(( DOH )) || BIND_ARGS+=(--disable-doh)
(
  export LIBS='-latomic -pthread -ldl'
  export LDFLAGS="-static -no-pie $BASE_LDFLAGS"
  autoconf_cross "$BIND_DIR" "${BIND_ARGS[@]}"
)

# Compile BIND libraries required by dig, not the full BIND utilities/server.
log 'compile BIND libraries'
make -C "$SOURCE_DIR/$BIND_DIR/lib" -j "$JOBS"
log 'link dig with libtool -all-static'
DIG="$SOURCE_DIR/$BIND_DIR/bin/dig/dig"
[[ ! -f "$DIG" ]] || rm -f "$DIG"  # force re-link even on resume
make -C "$SOURCE_DIR/$BIND_DIR/bin/dig" -j "$JOBS" \
  LDFLAGS="$BASE_LDFLAGS -all-static -no-pie" dig
[[ -s "$DIG" ]] || die 'BIND dig binary not built'

OUT="$RESULT_DIR/dig_${ARCH}_static_${BIND_VERSION}"
cp "$DIG" "$OUT"
"$STRIP" --strip-all "$OUT"
"$READELF" -h "$OUT" | grep -q 'Machine:.*ARM' || die 'Not an ARM ELF'
if "$READELF" -l "$OUT" | grep -Eq 'INTERP|DYNAMIC'; then
  die 'The resulting dig ELF has a dynamic interpreter or dynamic segment'
fi
"$READELF" -A "$OUT" | grep -q 'Tag_CPU_arch: v5TE' || \
  die 'ELF attributes do not advertise ARMv5TE'
file "$OUT"
log "SUCCESS: $OUT"
log 'Try on Tomato: dig_armv5te_static_9.20.30 -v'
log 'For DoT: dig @223.5.5.5 example.com +tls'
log 'For DoH: dig @223.5.5.5 example.com +https'
