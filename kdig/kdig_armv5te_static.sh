#!/usr/bin/env bash
# Knot DNS kdig only; static ARMv5TE/soft-float/musl, for Tomato/Entware.
# This file intentionally does NOT modify /root/src/armv5te_dev used by Tor/nginx.
set -Eeuo pipefail

ROOT="${ROOT:-/root/src}"
ARCH=armv5te
KNOT_VERSION="${KNOT_VERSION:-3.6.2}"
KNOT_SOURCE=stable
DOH=1
DOQ=1
JOBS="${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 2)}"
REBUILD=0
DRY_RUN=0
PROXY_FALLBACK="${PROXY_FALLBACK:-http://192.168.2.8:7373}"

# Pinned source releases verified 2026-10-29. SHA256 prevents unnoticed bad downloads.
GMP_VERSION=6.3.0
NETTLE_VERSION=4.0
GNUTLS_VERSION=3.8.13
NCURSES_VERSION=6.6
LIBEDIT_VERSION=20260512-3.1
NGHTTP2_VERSION=1.70.0

usage() {
  cat <<'EOF'
Usage: bash kdig_armv5te_static.sh [options]

  --source stable|git       Knot DNS official stable (default) or Git master
  --version N.N.N           Override Knot stable release (default: 3.6.2)
  --no-doh                  Skip DNS-over-HTTPS (default: enabled)
  --no-doq                  Skip DNS-over-QUIC (default: enabled, bundled ngtcp2)
  --jobs N                  Parallel make jobs
  --rebuild                 Rebuild dependencies even when previously installed
  --print                   Print environment/plan without downloads
  -h, --help                This help

Environment overrides:
  ROOT=/root/src
  CROSS_PREFIX=arm-linux-musleabi-   (override for other musl cross compilers)
  CROSS_BIN_DIR=/opt/cross/bin       (optional, appended before system PATH)
  PROXY_FALLBACK=http://192.168.2.8:7373
  JOBS=4

Output: /root/src/armv5te_result/kdig_armv5te_static_<version>
Install prefix: /root/src/armv5te_kdig_dev (isolated from existing Tor/nginx).
EOF
}

while (($#)); do
  case "$1" in
    --source) KNOT_SOURCE="${2:?missing source}"; shift 2 ;;
    --version) KNOT_VERSION="${2:?missing version}"; shift 2 ;;
    --no-doh) DOH=0; shift ;;
    --no-doq) DOQ=0; shift ;;
    --jobs) JOBS="${2:?missing jobs}"; shift 2 ;;
    --rebuild) REBUILD=1; shift ;;
    --print|--dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$KNOT_SOURCE" == stable || "$KNOT_SOURCE" == git ]] || { echo 'Invalid --source' >&2; exit 2; }
[[ "$KNOT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Invalid --version' >&2; exit 2; }
[[ "$JOBS" =~ ^[1-9][0-9]*$ ]] || { echo 'Invalid --jobs' >&2; exit 2; }

WORK="$ROOT/.build/$ARCH/kdig"
DOWNLOADS="$ROOT/.downloads/kdig"
SOURCE_DIR="$WORK/src"
PREFIX="$ROOT/${ARCH}_kdig_dev"
RESULT_DIR="$ROOT/${ARCH}_result"
MARK_DIR="$WORK/marks"
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

if ((DRY_RUN)); then
  printf 'Knot DNS: %s (%s)\n' "$KNOT_VERSION" "$KNOT_SOURCE"
  printf 'Host: %s | CC: %s\n' "$HOST" "$CC"
  printf 'DoT: yes | DoH: %s | DoQ: %s\n' "$DOH" "$DOQ"
  printf 'Dependencies: GMP %s, Nettle %s, GnuTLS %s, ncurses %s, libedit %s' \
    "$GMP_VERSION" "$NETTLE_VERSION" "$GNUTLS_VERSION" "$NCURSES_VERSION" "$LIBEDIT_VERSION"
  ((DOH)) && printf ', nghttp2 %s' "$NGHTTP2_VERSION"
  printf '\nPrefix: %s\nOutput: %s\nProxy: %s\n' "$PREFIX" "$RESULT_DIR" "$PROXY_MODE"
  exit 0
fi

for program in git curl tar sha256sum make pkg-config file readelf awk sed; do
  command -v "$program" >/dev/null 2>&1 || die "Missing host tool: $program (apk add $program)"
done
for program in "$CC" "$AR" "$RANLIB" "$STRIP" "$READELF"; do
  command -v "$program" >/dev/null 2>&1 || die "Missing cross tool: $program"
done
BUILD="$(gcc -dumpmachine 2>/dev/null || cc -dumpmachine 2>/dev/null || printf x86_64-alpine-linux-musl)"

mkdir -p "$WORK" "$DOWNLOADS" "$SOURCE_DIR" "$PREFIX" "$RESULT_DIR" "$MARK_DIR" \
  "$PREFIX/lib/pkgconfig" "$PREFIX/include"
export CC AR RANLIB STRIP
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig"
export PKG_CONFIG_PATH="$PKG_CONFIG_LIBDIR"
unset PKG_CONFIG_SYSROOT_DIR || true

# Autotools normally invokes pkg-config without --static, omitting Libs.private.
# This private wrapper solves the entire static dependency graph without hacks.
HOST_PKG_CONFIG="$(command -v pkg-config)"
printf '#!/bin/sh\nexec "%s" --static "$@"\n' "$HOST_PKG_CONFIG" > "$PKG_WRAPPER"
chmod 755 "$PKG_WRAPPER"
export PKG_CONFIG="$PKG_WRAPPER"

# GCC 15+ defaults to GNU C23, which breaks GMP 6.3's old-style configure
# probes; GNU C11 is supported by both the user's GCC 9.4 and modern compilers.
BASE_CFLAGS="${BASE_CFLAGS:--O2 -std=gnu11 -march=armv5te -mfloat-abi=soft -fPIC}"
# ncurses installs headers under include/ncurses unless built with overwrite.
# libedit uses <ncurses.h>, so both include paths are necessary.
BASE_CPPFLAGS="-I$PREFIX/include -I$PREFIX/include/ncurses"
BASE_LDFLAGS="-L$PREFIX/lib"
ATOMIC_LIBS=
ATOMIC_ARCHIVE="$($CC -print-file-name=libatomic.a)"
if [[ "$ATOMIC_ARCHIVE" != libatomic.a && -f "$ATOMIC_ARCHIVE" ]]; then
  ATOMIC_LIBS='-latomic'
else
  die "$CC does not expose libatomic.a (required by 64-bit atomics on ARMv5TE)"
fi

export CFLAGS="$BASE_CFLAGS" CPPFLAGS="$BASE_CPPFLAGS" LDFLAGS="$BASE_LDFLAGS"
log "Toolchain: $($CC -dumpmachine); $($CC -dumpversion) | proxy: $PROXY_MODE"

on_error() {
  local code=$?
  printf '\nBUILD FAILED at line %s (exit %s).\n' "$1" "$code" >&2
  printf 'Inspect config.log and output under %s; rerun resumes completed libraries.\n' "$WORK" >&2
  exit "$code"
}
trap 'on_error "$LINENO"' ERR

verify_file() {
  local file="$1" digest="$2"
  # GNU coreutils provides --status, BusyBox sha256sum only supports -s.
  # The common denominator is plain -c with its output redirected away.
  printf '%s  %s\n' "$digest" "$file" | sha256sum -c >/dev/null 2>&1
}

fetch() {
  local name="$1" digest="$2" url="$3" file
  file="$DOWNLOADS/$name"
  if [[ -f "$file" ]] && verify_file "$file" "$digest"; then
    log "cached $name"
  else
    log "download $name"
    # Do not erase corrupt user files; retain a recoverable copy if present.
    [[ ! -f "$file" ]] || mv "$file" "$file.invalid.$(date +%s)"
    curl -fLSs --retry 4 --retry-delay 2 --connect-timeout 20 --max-time 240 \
      -o "$file.part" "$url"
    verify_file "$file.part" "$digest" || die "SHA256 mismatch: $name"
    mv "$file.part" "$file"
  fi
}

extract() {
  local name="$1" dir="$2"
  if [[ ! -d "$SOURCE_DIR/$dir" ]]; then
    log "extract $name"
    # BusyBox tar may not recognize GNU tar's --no-same-* switches.
    local tar_opts=()
    local tar_help
    tar_help="$(tar --help 2>&1 || true)"
    [[ "$tar_help" != *'--no-same-owner'* ]] || tar_opts+=(--no-same-owner)
    [[ "$tar_help" != *'--no-same-permissions'* ]] || tar_opts+=(--no-same-permissions)
    tar "${tar_opts[@]}" -xf "$DOWNLOADS/$name" -C "$SOURCE_DIR"
  fi
  [[ -f "$SOURCE_DIR/$dir/configure" ]] || die "Missing configure in $dir"
}

mark_exists() { (( ! REBUILD )) && [[ -f "$MARK_DIR/$1" ]] && [[ -f "$PREFIX/lib/$2" ]]; }
mark_done() { touch "$MARK_DIR/$1"; }

configure_autotools() {
  local dir="$1"; shift
  ( cd "$SOURCE_DIR/$dir" && ./configure --build="$BUILD" --host="$HOST" \
    --prefix="$PREFIX" "$@" )
}

make_install() {
  local dir="$1"; shift
  make -C "$SOURCE_DIR/$dir" -j "$JOBS" "$@"
  make -C "$SOURCE_DIR/$dir" install
}

# 1. Terminal library: only libedit needs it; no target-side tic execution.
if ! mark_exists "ncurses-$NCURSES_VERSION" libtinfo.a; then
  fetch "ncurses-$NCURSES_VERSION.tar.gz" \
    355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11 \
    "https://invisible-island.net/archives/ncurses/ncurses-$NCURSES_VERSION.tar.gz"
  extract "ncurses-$NCURSES_VERSION.tar.gz" "ncurses-$NCURSES_VERSION"
  log 'configure ncurses (static terminfo)'
  configure_autotools "ncurses-$NCURSES_VERSION" --without-shared --with-normal \
    --with-termlib --without-debug --without-progs --without-tests \
    --without-cxx --without-cxx-binding --without-ada --without-manpages \
    --disable-widec --with-pkg-config="$HOST_PKG_CONFIG" \
    --with-pkg-config-libdir="$PREFIX/lib/pkgconfig"
  # Full 'make install' also runs misc/install.data, which invokes tic to
  # compile target terminfo entries. With --without-progs (and cross-build),
  # tic is intentionally absent and run_tic.sh fails with '-V: not found'.
  # ncurses' INSTALL explicitly supports install.libs: libs + headers only.
  make -C "$SOURCE_DIR/ncurses-$NCURSES_VERSION" -j "$JOBS"
  make -C "$SOURCE_DIR/ncurses-$NCURSES_VERSION" install.libs
  [[ -f "$PREFIX/lib/libtinfo.a" ]] || die 'ncurses did not install libtinfo.a'
  mark_done "ncurses-$NCURSES_VERSION"
fi

# 2. libedit is still a mandatory configure-time check even for kdig-only.
if ! mark_exists "libedit-$LIBEDIT_VERSION" libedit.a; then
  fetch "libedit-$LIBEDIT_VERSION.tar.gz" \
    432d5e7ea8b0116dd39f2eca7bc11d0eed77faa6b77ea526ace89907c23ea4a0 \
    "https://www.thrysoee.dk/editline/libedit-$LIBEDIT_VERSION.tar.gz"
  extract "libedit-$LIBEDIT_VERSION.tar.gz" "libedit-$LIBEDIT_VERSION"
  log 'configure libedit'
  configure_autotools "libedit-$LIBEDIT_VERSION" --disable-shared --enable-static
  make_install "libedit-$LIBEDIT_VERSION"
  [[ -f "$PREFIX/lib/libedit.a" ]] || die 'libedit did not install libedit.a'
  mark_done "libedit-$LIBEDIT_VERSION"
fi

# 3. GMP: portable generic C, no newer ARM instructions.
if ! mark_exists "gmp-$GMP_VERSION" libgmp.a; then
  fetch "gmp-$GMP_VERSION.tar.xz" \
    a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898 \
    "https://ftp.gnu.org/gnu/gmp/gmp-$GMP_VERSION.tar.xz"
  extract "gmp-$GMP_VERSION.tar.xz" "gmp-$GMP_VERSION"
  log 'configure GMP (generic C, no asm)'
  configure_autotools "gmp-$GMP_VERSION" --disable-shared --enable-static --disable-assembly
  make_install "gmp-$GMP_VERSION"
  mark_done "gmp-$GMP_VERSION"
fi

# 4. Nettle 4.0 (GnuTLS 3.8.13 explicitly supports Nettle 4.0).
if ! mark_exists "nettle-$NETTLE_VERSION" libhogweed.a; then
  fetch "nettle-$NETTLE_VERSION.tar.gz" \
    3addbc00da01846b232fb3bc453538ea5468da43033f21bb345cb1e9073f5094 \
    "https://ftp.gnu.org/gnu/nettle/nettle-$NETTLE_VERSION.tar.gz"
  extract "nettle-$NETTLE_VERSION.tar.gz" "nettle-$NETTLE_VERSION"
  log 'configure Nettle (no asm, no fat lib)'
  configure_autotools "nettle-$NETTLE_VERSION" --disable-shared --disable-assembler \
    --disable-fat --disable-documentation
  make_install "nettle-$NETTLE_VERSION"
  [[ -f "$PREFIX/lib/libnettle.a" ]] || die 'Nettle did not install libnettle.a'
  mark_done "nettle-$NETTLE_VERSION"
fi

# 5. GnuTLS: included ASN.1/Unistring; no PKCS11/systemd/extra shared deps.
if ! mark_exists "gnutls-$GNUTLS_VERSION" libgnutls.a; then
  fetch "gnutls-$GNUTLS_VERSION.tar.xz" \
    ffed8ec1bf09c2426d4f14aae377de4753b53e537d685e604e99a8b16ca9c97e \
    "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-$GNUTLS_VERSION.tar.xz"
  extract "gnutls-$GNUTLS_VERSION.tar.xz" "gnutls-$GNUTLS_VERSION"
  log 'configure GnuTLS (static, no PKCS#11)'
  ( export LIBS="$ATOMIC_LIBS -lm"
    configure_autotools "gnutls-$GNUTLS_VERSION" --disable-shared --enable-static \
      --disable-tools --disable-tests --disable-doc --disable-cxx --disable-nls \
      --disable-libdane --disable-hardware-acceleration --without-p11-kit \
      --without-idn --with-included-libtasn1 --with-included-unistring \
      --with-zlib=no --with-zstd=no --with-brotli=no \
      --with-default-trust-store-file=/opt/etc/ssl/certs/ca-certificates.crt
  )
  make_install "gnutls-$GNUTLS_VERSION"
  mark_done "gnutls-$GNUTLS_VERSION"
fi

# 6. libnghttp2 adds DNS-over-HTTPS without pulling in an entire HTTP client.
if ((DOH)) && ! mark_exists "nghttp2-$NGHTTP2_VERSION" libnghttp2.a; then
  fetch "nghttp2-$NGHTTP2_VERSION.tar.xz" \
    e05cb1388eaca3830aded4ccf20044b6e1ac1a61411dcca11b0437c4285c8bc2 \
    "https://github.com/nghttp2/nghttp2/releases/download/v$NGHTTP2_VERSION/nghttp2-$NGHTTP2_VERSION.tar.xz"
  extract "nghttp2-$NGHTTP2_VERSION.tar.xz" "nghttp2-$NGHTTP2_VERSION"
  log 'configure nghttp2 (library only)'
  configure_autotools "nghttp2-$NGHTTP2_VERSION" --disable-shared --enable-static \
    --enable-lib-only
  make_install "nghttp2-$NGHTTP2_VERSION"
  mark_done "nghttp2-$NGHTTP2_VERSION"
fi

if [[ "$KNOT_SOURCE" == stable ]]; then
  KNOT_DIR="knot-$KNOT_VERSION"
  KNOT_TARBALL="$KNOT_DIR.tar.xz"
  if [[ "$KNOT_VERSION" == 3.6.2 ]]; then
    KNOT_SHA=2916ac117ac77d1f2341a6562e47d797493521b791b414960a382cb5bc113e21
  else
    # Newer official releases provide an adjacent .sha256 file.
    KNOT_SHA="$(curl -fLSs "https://knot-dns.nic.cz/release/$KNOT_TARBALL.sha256" | awk 'NR==1 {print $1}')"
    [[ "$KNOT_SHA" =~ ^[0-9a-fA-F]{64}$ ]] || die 'Cannot read upstream SHA256'
  fi
  fetch "$KNOT_TARBALL" "$KNOT_SHA" \
    "https://knot-dns.nic.cz/release/$KNOT_TARBALL"
  extract "$KNOT_TARBALL" "$KNOT_DIR"
  KNOT_LABEL="$KNOT_VERSION"
else
  KNOT_DIR=knot-git
  if [[ ! -d "$SOURCE_DIR/$KNOT_DIR/.git" ]]; then
    log 'clone Knot DNS git master'
    git clone --depth=1 --branch master https://github.com/CZ-NIC/knot.git \
      "$SOURCE_DIR/$KNOT_DIR"
  else
    log 'update Knot DNS git master'
    git -C "$SOURCE_DIR/$KNOT_DIR" fetch --depth=1 origin master
    # This is our disposable source clone; refresh our namespacing patch too.
    git -C "$SOURCE_DIR/$KNOT_DIR" checkout --detach -f FETCH_HEAD
  fi
  (cd "$SOURCE_DIR/$KNOT_DIR" && autoreconf -fi)
  KNOT_LABEL="git-$(git -C "$SOURCE_DIR/$KNOT_DIR" rev-parse --short=12 HEAD)"
fi

# Knot's utility hex_decode() collides with a global symbol in modern static
# libgnutls.a. Fix the source-level namespace instead of -Wl,-z,muldefs.
# Only these three kdig-specific source files are touched (idempotently).
log 'namespace Knot utility hex_decode() to avoid static GnuTLS collision'
for rel in utils/common/hex.c utils/common/hex.h utils/kdig/kdig_params.c; do
  target="$SOURCE_DIR/$KNOT_DIR/src/$rel"
  [[ -f "$target" ]] || die "Cannot find kdig hex source: $target"
  if grep -Eq '(^|[^[:alnum:]_])hex_decode\(' "$target"; then
    sed -i 's/hex_decode(/kdig_hex_decode(/g' "$target"
  fi
  grep -q 'kdig_hex_decode(' "$target" || die "Unexpected hex_decode API change: $target"
done

log "configure Knot DNS kdig $KNOT_LABEL (DoT + DoH=$DOH + DoQ=$DOQ)"
KNOT_ARGS=(
  --disable-shared --enable-static --disable-daemon --disable-modules
  --disable-documentation --disable-fastparser --disable-kdig-validation
  --disable-dnstap --enable-pkcs11=no --enable-xdp=no --enable-redis=no
  --enable-systemd=no --enable-dbus=no --with-lmdb=embedded --with-libidn=no
)
if ((DOH)); then KNOT_ARGS+=(--with-libnghttp2=yes); else KNOT_ARGS+=(--with-libnghttp2=no); fi
if ((DOQ)); then KNOT_ARGS+=(--enable-quic=embedded); else KNOT_ARGS+=(--enable-quic=no); fi

( export LIBS="$ATOMIC_LIBS -lm -pthread"
  export LDFLAGS="$BASE_LDFLAGS -static -no-pie"
  # Even with --disable-daemon, libknotus signal.h includes knot_lmdb.h.
  # Upstream's libknotus CPPFLAGS omits lmdb_CFLAGS; add the embedded path.
  export CPPFLAGS="$BASE_CPPFLAGS -I$SOURCE_DIR/$KNOT_DIR/src/contrib/lmdb"
  configure_autotools "$KNOT_DIR" "${KNOT_ARGS[@]}"
)

KNOT_CONFIG="$SOURCE_DIR/$KNOT_DIR/src/config.h"
if ((DOH)); then
  grep -Eq '^#define LIBNGHTTP2 1$' "$KNOT_CONFIG" || die 'DoH silently disabled!'
fi
if ((DOQ)); then
  grep -Eq '^#define ENABLE_QUIC 1$' "$KNOT_CONFIG" || die 'DoQ silently disabled!'
fi

log 'compile only kdig (not knotd and other utilities)'
# Knot uses libtool: -static alone does NOT force a static executable.
# -all-static is libtool's link flag, injected at make time (not configure).
BIN="$SOURCE_DIR/$KNOT_DIR/src/kdig"
# Force a fresh final link when a previous invocation produced a dynamic ELF.
[[ ! -f "$BIN" ]] || rm -f "$BIN"
make -C "$SOURCE_DIR/$KNOT_DIR/src" -j "$JOBS" \
  LDFLAGS="$BASE_LDFLAGS -all-static -no-pie" kdig
[[ -s "$BIN" ]] || die 'No kdig executable produced'

OUT="$RESULT_DIR/kdig_${ARCH}_static_${KNOT_LABEL}"
cp "$BIN" "$OUT"
"$STRIP" --strip-all "$OUT"

"$READELF" -h "$OUT" | grep -q 'Machine:.*ARM' || die 'Wrong ELF architecture'
if "$READELF" -l "$OUT" | grep -Eq 'INTERP|DYNAMIC'; then
  die 'ELF is not fully static (PT_INTERP or PT_DYNAMIC found)'
fi
file "$OUT"
log "DONE: $OUT"
log "Try on Tomato: $OUT -V; $OUT @1.1.1.1 example.com +tls"
