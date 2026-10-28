#!/bin/sh
# Static Tor for Alpine: ARMv5TE soft-float and AArch64 musl, in one script.
# Put this script in /root/src, alongside the existing <arch>_dev/result dirs.
#
#   sh tor_static_unified.sh --arch armv5te --tor stable
#   sh tor_static_unified.sh --arch aarch64 --tor git
#   sh tor_static_unified.sh --arch all --tor stable --client-only
#   sh tor_static_unified.sh --arch armv5te --tor 0.4.9.14 --force
#   sh tor_static_unified.sh --print
#
# Default: latest numbered stable Tor tarball, with LZMA AND Zstd enabled.
# Override library versions through *_TAG environment variables if necessary.

set -eu

base_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
arch_choice=${ARCH:-armv5te}
tor_choice=${TOR_SOURCE:-stable}
git_branch=${TOR_GIT_BRANCH:-main}
force=${FORCE_REBUILD:-0}
client_only=${CLIENT_ONLY:-0}
print_only=0

# Verified stable library releases as of 2026-10-28.
LZMA_TAG=${LZMA_TAG:-5.8.4}
ZSTD_TAG=${ZSTD_TAG:-1.5.7}
ZLIB_TAG=${ZLIB_TAG:-1.3.2}
OPENSSL_TAG=${OPENSSL_TAG:-3.5.9}  # OpenSSL 3.5 LTS; threads required by Tor.
LIBEVENT_TAG=${LIBEVENT_TAG:-2.1.13}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}

say() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf '\nERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

usage() {
    sed -n '2,10p' "$0"
    printf '\nOptions:\n'
    printf '  --arch armv5te|aarch64|all  Target(s), default armv5te\n'
    printf '  --tor stable|git|X.Y.Z.N  Latest stable, Git main, or explicit release\n'
    printf '  --branch NAME              Git branch, default main\n'
    printf '  --client-only              Omit relay/authority (compression stays enabled)\n'
    printf '  --force                    Rebuild versioned libraries and Tor\n'
    printf '  --print                    Display settings, no network/build actions\n'
    printf '  --help                     This help\n'
    printf 'Env: JOBS, *_TAG, TOR_GIT_BRANCH, FORCE_REBUILD, CLIENT_ONLY\n'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --arch) [ "$#" -ge 2 ] || die '--arch needs a value'; arch_choice=$2; shift 2 ;;
        --tor) [ "$#" -ge 2 ] || die '--tor needs a value'; tor_choice=$2; shift 2 ;;
        --branch) [ "$#" -ge 2 ] || die '--branch needs a value'; git_branch=$2; shift 2 ;;
        --client-only) client_only=1; shift ;;
        --force) force=1; shift ;;
        --print) print_only=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

case "$arch_choice" in armv5te|aarch64|all) ;; *) die "bad arch: $arch_choice" ;; esac
case "$tor_choice" in
    stable|git) ;;
    *[!0-9.]*|'') die 'Tor must be stable, git, or version X.Y.Z.N' ;;
    *) printf '%s\n' "$tor_choice" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' ||
       die 'Tor version must be X.Y.Z.N' ;;
esac
case "$git_branch" in ''|*[!a-zA-Z0-9_.-]*) die 'unsafe Git branch name' ;; esac
case "$JOBS" in ''|*[!0-9]*) die 'JOBS must be numeric' ;; esac
[ "$JOBS" -gt 0 ] || die 'JOBS must be positive'
case "$force:$client_only" in 0:0|0:1|1:0|1:1) ;; *) die 'FORCE_REBUILD and CLIENT_ONLY must be 0 or 1' ;; esac

# Respect any proxy configured in Alpine. Otherwise use the user's mixed
# HTTP/SOCKS5H proxy; SOCKS5H resolves hostnames at the proxy endpoint.
if [ -n "${https_proxy:-}${http_proxy:-}${all_proxy:-}${HTTPS_PROXY:-}${HTTP_PROXY:-}${ALL_PROXY:-}" ]; then
    proxy_mode=environment
    proxy_value=${https_proxy:-${HTTPS_PROXY:-${http_proxy:-${HTTP_PROXY:-${all_proxy:-${ALL_PROXY:-}}}}}}
    : "${https_proxy:=$proxy_value}" "${http_proxy:=$proxy_value}" "${all_proxy:=$proxy_value}"
else
    proxy_mode=192.168.2.8:7373
    https_proxy=http://192.168.2.8:7373
    http_proxy=http://192.168.2.8:7373
    all_proxy=socks5h://192.168.2.8:7373
fi
export https_proxy http_proxy all_proxy

if [ "$print_only" -eq 1 ]; then
    printf 'base_dir=%s\narch=%s\ntor=%s\ngit_branch=%s\nclient_only=%s\n' \
        "$base_dir" "$arch_choice" "$tor_choice" "$git_branch" "$client_only"
    printf 'xz=%s  zstd=%s  zlib=%s  openssl=%s  libevent=%s\n' \
        "$LZMA_TAG" "$ZSTD_TAG" "$ZLIB_TAG" "$OPENSSL_TAG" "$LIBEVENT_TAG"
    printf 'proxy=%s\n' "$proxy_mode"
    exit 0
fi

for util in curl tar git make sed awk grep pkg-config sha256sum file; do need "$util"; done
PKG_CONFIG=${PKG_CONFIG:-pkg-config}
need "$PKG_CONFIG"
mkdir -p "$base_dir/.downloads" "$base_dir/.build"
say "proxy: $proxy_mode (credentials not shown)"

fetch() {
    fetch_url=$1; fetch_dest=$2
    [ -s "$fetch_dest" ] && return 0
    fetch_part="$fetch_dest.part.$$"
    if ! curl --fail --location --silent --show-error --retry 4 --retry-delay 2 \
        --connect-timeout 15 -o "$fetch_part" "$fetch_url"; then
        rm -f "$fetch_part"
        die "download failed: $fetch_url"
    fi
    [ -s "$fetch_part" ] || die "empty download: $fetch_url"
    mv -f "$fetch_part" "$fetch_dest"
}

resolve_tor() {
    case "$tor_choice" in
        git) TOR_TAG=git; return ;;
        stable)
            say 'query Tor official stable tarball index'
            index="$base_dir/.downloads/tor-index.$$"
            if ! curl --fail --location --silent --show-error --retry 3 \
                --connect-timeout 15 -o "$index" https://dist.torproject.org/; then
                die 'cannot get Tor index; use --tor X.Y.Z.N to pin a release'
            fi
            TOR_TAG=$(
                grep -oE 'tor-[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' "$index" |
                sed 's/^tor-//;s/\.tar\.gz$//' |
                awk -F. 'BEGIN {a=-1;b=-1;c=-1;d=-1}
                  ($1>a)||($1==a&&$2>b)||($1==a&&$2==b&&$3>c)||($1==a&&$2==b&&$3==c&&$4>d) \
                  {a=$1;b=$2;c=$3;d=$4;best=$0} END {print best}'
            )
            rm -f "$index"
            [ -n "$TOR_TAG" ] || die 'cannot parse latest stable Tor version'
            ;;
        *) TOR_TAG=$tor_choice ;;
    esac
}
resolve_tor
say "Tor source: $TOR_TAG"

setup_arch() {
    arch=$1
    case "$arch" in
        armv5te)
            host=arm-linux-musleabi
            SSL_TARGET=linux-armv4
            ARCH_FLAGS='-O2 -march=armv5te -mfloat-abi=soft -fPIC'
            # OpenSSL 3.5's RCU/thread code uses 64-bit __atomic_* helpers.
            # GCC 9.4 on ARMv5TE provides them through libatomic.a.
            TOR_EXTRA_LIBS=-latomic
            ;;
        aarch64)
            host=aarch64-linux-musl
            SSL_TARGET=linux-aarch64
            ARCH_FLAGS='-O2 -march=armv8-a -fPIC'
            TOR_EXTRA_LIBS=
            ;;
    esac
    CC=$host-gcc
    CXX=$host-g++
    AR=$host-ar
    RANLIB=$host-ranlib
    STRIP=$host-strip
    for util in "$CC" "$CXX" "$AR" "$RANLIB" "$STRIP"; do need "$util"; done
    if [ "$arch" = armv5te ] &&
       [ "$("$CC" -print-file-name=libatomic.a)" = libatomic.a ]; then
        die "$CC: libatomic.a is missing from the ARM cross-toolchain"
    fi
    install_dir="$base_dir/${arch}_dev"
    lib_dir="$install_dir/lib"
    include_dir="$install_dir/include"
    pc_dir="$lib_dir/pkgconfig"
    result_dir="$base_dir/${arch}_result"
    work_dir="$base_dir/.build/$arch"
    source_root="$work_dir/src"
    stamp_dir="$work_dir/stamps"
    mkdir -p "$lib_dir" "$include_dir" "$pc_dir" "$result_dir" \
        "$source_root" "$stamp_dir"
    # Never read host /usr/lib/pkgconfig for a cross-architecture package.
    PKG_CONFIG_LIBDIR="$pc_dir:$install_dir/share/pkgconfig"
    # Keep this non-empty: Tor's configure.ac otherwise overwrites it with
    # $prefix/lib/pkgconfig, which here is the *result* dir, not the dev dir.
    PKG_CONFIG_PATH="$pc_dir:$install_dir/share/pkgconfig"
    PKG_CONFIG_SYSROOT_DIR=
    export PKG_CONFIG_LIBDIR PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR
    CFLAGS="$ARCH_FLAGS -pthread"
    CPPFLAGS="-I$include_dir"
    LDFLAGS="-static -no-pie -L$lib_dir -Wl,--no-as-needed -pthread"
    # Use explicit --build for Autoconf: target executables cannot run on Alpine.
    BUILD_TRIPLET=${BUILD_TRIPLET:-$(gcc -dumpmachine)}
    [ -n "$BUILD_TRIPLET" ] || die 'could not determine native GCC triplet'
}

stamp_ok() {
    [ "$force" = 0 ] && [ -s "$stamp_dir/$1" ] && [ -s "$lib_dir/$2" ] &&
        [ "$(sed -n '1p' "$stamp_dir/$1")" = "$CC $CFLAGS" ]
}
stamp_done() { printf '%s\n' "$CC $CFLAGS" > "$stamp_dir/$1"; }

ensure_source() {
    src_name=$1; src_url=$2
    [ -d "$source_root/$src_name" ] && return 0
    case "$src_url" in
        *.tar.gz) suffix=tar.gz ;;
        *.tar.xz) suffix=tar.xz ;;
        *) die "unsupported source archive: $src_url" ;;
    esac
    archive="$base_dir/.downloads/$src_name.$suffix"
    fetch "$src_url" "$archive"
    stage=$(mktemp -d "$work_dir/unpack.XXXXXXXX")
    tar -xf "$archive" -C "$stage" || die "invalid archive: $archive"
    [ -d "$stage/$src_name" ] || die "unexpected source directory in $archive"
    mv "$stage/$src_name" "$source_root/$src_name"
    rmdir "$stage"
}

check_static_lib() {
    [ -s "$lib_dir/$1" ] || die "$arch: missing static archive $lib_dir/$1"
}

autoconf_lib() {
    name=$1; lib=$2; shift 2
    if stamp_ok "$name" "$lib"; then say "reuse $name [$arch]"; return; fi
    say "compile $name [$arch]"
    (
        cd "$source_root/$name"
        if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
        CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS" \
        LDFLAGS="-L$lib_dir" \
        ./configure --build="$BUILD_TRIPLET" --host="$host" \
            --prefix="$install_dir" --libdir="$lib_dir" \
            --disable-shared --enable-static "$@"
        make -j"$JOBS"
        make install
    )
    check_static_lib "$lib"
    stamp_done "$name"
}

build_libs() {
    ensure_source "zlib-$ZLIB_TAG" "https://zlib.net/zlib-$ZLIB_TAG.tar.gz"
    if ! stamp_ok "zlib-$ZLIB_TAG" libz.a; then
        say "compile zlib-$ZLIB_TAG [$arch]"
        (
            cd "$source_root/zlib-$ZLIB_TAG"
            if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
            CC="$CC" CFLAGS="$CFLAGS" ./configure --prefix="$install_dir" --static
            make -j"$JOBS"; make install
        )
        check_static_lib libz.a
        stamp_done "zlib-$ZLIB_TAG"
    fi

    ensure_source "xz-$LZMA_TAG" "https://tukaani.org/xz/xz-$LZMA_TAG.tar.gz"
    autoconf_lib "xz-$LZMA_TAG" liblzma.a \
        --disable-xz --disable-xzdec --disable-lzmadec \
        --disable-lzmainfo --disable-scripts --disable-doc --disable-nls

    ensure_source "zstd-$ZSTD_TAG" \
        "https://github.com/facebook/zstd/releases/download/v$ZSTD_TAG/zstd-$ZSTD_TAG.tar.gz"
    if ! stamp_ok "zstd-$ZSTD_TAG" libzstd.a || [ ! -s "$pc_dir/libzstd.pc" ]; then
        say "compile STATIC libzstd-$ZSTD_TAG [$arch]"
        (
            cd "$source_root/zstd-$ZSTD_TAG"
            # Only library targets: root 'make install' also builds CLI and .so,
            # and can accidentally switch back to the native gcc on install.
            # 1.5.7's Makefile variable is ZSTD_NO_ASM (not ZSTD_DISABLE_ASM).
            make -C lib -j"$JOBS" libzstd.a-release \
                CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
                CFLAGS="$CFLAGS" ZSTD_NO_ASM=1 PREFIX="$install_dir"
            make -C lib install-static install-pc install-includes \
                CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
                CFLAGS="$CFLAGS" ZSTD_NO_ASM=1 PREFIX="$install_dir"
        )
        check_static_lib libzstd.a
        [ -s "$pc_dir/libzstd.pc" ] || die 'zstd did not install libzstd.pc'
        stamp_done "zstd-$ZSTD_TAG"
    fi

    ensure_source "libevent-$LIBEVENT_TAG-stable" \
        "https://github.com/libevent/libevent/releases/download/release-$LIBEVENT_TAG-stable/libevent-$LIBEVENT_TAG-stable.tar.gz"
    autoconf_lib "libevent-$LIBEVENT_TAG-stable" libevent.a \
        --with-pic --disable-samples --disable-libevent-regress \
        --disable-openssl

    ensure_source "openssl-$OPENSSL_TAG" \
        "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_TAG/openssl-$OPENSSL_TAG.tar.gz"
    if ! stamp_ok "openssl-$OPENSSL_TAG" libssl.a || [ ! -s "$lib_dir/libcrypto.a" ]; then
        say "compile openssl-$OPENSSL_TAG [$arch]"
        need perl
        (
            cd "$source_root/openssl-$OPENSSL_TAG"
            if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
            # CC already has the target prefix; never ALSO pass
            # --cross-compile-prefix=$host- (it doubles the compiler prefix).
            CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" CROSS_COMPILE= \
            ./Configure "$SSL_TARGET" --prefix="$install_dir" --libdir=lib \
                threads no-shared no-dso no-tests no-comp
            make -j"$JOBS"
            make install_sw
        )
        check_static_lib libssl.a
        check_static_lib libcrypto.a
        stamp_done "openssl-$OPENSSL_TAG"
    fi

    for lib in libz.a liblzma.a libzstd.a libevent.a libssl.a libcrypto.a; do
        check_static_lib "$lib"
    done
    for pkg in liblzma libzstd; do
        if ! "$PKG_CONFIG" --exists "$pkg"; then
            die "$arch: target pkg-config cannot see $pkg under $pc_dir"
        fi
        say "$arch: $pkg $("$PKG_CONFIG" --modversion "$pkg")"
    done
    [ "$("$PKG_CONFIG" --modversion liblzma)" = "$LZMA_TAG" ] ||
        die 'liblzma .pc has an unexpected version; --force might be needed'
    [ "$("$PKG_CONFIG" --modversion libzstd)" = "$ZSTD_TAG" ] ||
        die 'libzstd .pc has an unexpected version; --force might be needed'
    # Tor requires OPENSSL_THREADS, not merely an OpenSSL 3 header shim.
    if ! printf '#include <openssl/opensslconf.h>\n#ifndef OPENSSL_THREADS\n#error OpenSSL must be built with threads\n#endif\n' |
        "$CC" $CFLAGS "$CPPFLAGS" -x c -fsyntax-only - >/dev/null 2>&1; then
        die "$arch: OpenSSL headers do not advertise thread support"
    fi
}

prepare_tor() {
    if [ "$tor_choice" = git ]; then
        tor_src="$source_root/tor-git"
        need autoreconf
        if [ ! -d "$tor_src/.git" ]; then
            say "clone Tor Git branch $git_branch [$arch]"
            git_temp=$(mktemp -d "$work_dir/tor-clone.XXXXXXXX")
            if ! git clone --depth=1 --branch "$git_branch" \
                https://gitlab.torproject.org/tpo/core/tor.git "$git_temp/tor-primary"; then
                say 'Tor primary GitLab unavailable; trying its public GitLab mirror'
                git clone --depth=1 --branch "$git_branch" \
                    https://gitlab.com/torproject/tor.git "$git_temp/tor-mirror" ||
                    die 'Tor Git clone failed on both sources'
                mv "$git_temp/tor-mirror" "$tor_src"
            else
                mv "$git_temp/tor-primary" "$tor_src"
            fi
            rmdir "$git_temp" 2>/dev/null || true
        else
            say "update Tor Git [$arch]"
            git -C "$tor_src" fetch --depth=1 origin "$git_branch" ||
                die 'Git fetch failed (working tree untouched)'
            git -C "$tor_src" checkout --detach FETCH_HEAD ||
                die 'Git checkout refused because the source was modified'
        fi
        tor_revision=$(git -C "$tor_src" rev-parse --short=12 HEAD)
        [ -f "$tor_src/configure.ac" ] || die 'Tor checkout missing configure.ac'
        (cd "$tor_src"; ./autogen.sh)
        tor_version="git-$tor_revision"
    else
        name="tor-$TOR_TAG"
        tor_archive="$base_dir/.downloads/$name.tar.gz"
        # Verify the archive BEFORE unpacking any untrusted bytes.
        fetch "https://dist.torproject.org/$name.tar.gz" "$tor_archive"
        # Tor upstream publishes a SHA-256 file next to each stable tarball.
        hash_file="$base_dir/.downloads/$name.tar.gz.sha256sum"
        fetch "https://dist.torproject.org/$name.tar.gz.sha256sum" "$hash_file"
        expected_hash=$(awk 'NR==1 {print $1}' "$hash_file")
        actual_hash=$(sha256sum "$tor_archive" | awk '{print $1}')
        [ "$expected_hash" = "$actual_hash" ] ||
            die "Tor source checksum mismatch: $tor_archive"
        ensure_source "$name" "https://dist.torproject.org/$name.tar.gz"
        tor_src="$source_root/$name"
        tor_version=$TOR_TAG
    fi
}

build_tor() {
    prepare_tor
    say "configure Tor $tor_version [$arch] (Zstd+LZMA REQUIRED)"
    (
        cd "$tor_src"
        if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
        # Force concrete target static archives instead of generic -lzstd and
        # -llzma. This also lets Tor's PKG_CHECK_MODULES see target headers.
        # Its --enable-* checks are otherwise WARNING-only (not fatal).
        LZMA_CFLAGS="-I$include_dir" \
        LZMA_LIBS="$lib_dir/liblzma.a" \
        ZSTD_CFLAGS="-I$include_dir" \
        ZSTD_LIBS="$lib_dir/libzstd.a" \
        CC="$CC" CXX="$CXX" AR="$AR" RANLIB="$RANLIB" \
        CFLAGS="$CFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" \
        LIBS="$TOR_EXTRA_LIBS" \
        PKG_CONFIG="$PKG_CONFIG" tor_cv_ldflags__pie=no \
        ./configure --build="$BUILD_TRIPLET" --host="$host" \
            --prefix="$result_dir" --disable-tool-name-check --enable-static-tor \
            --enable-static-libevent --enable-static-openssl --enable-static-zlib \
            --enable-zstd --enable-lzma --disable-manpage \
            --disable-html-manual --disable-asciidoc --disable-unittests \
            --disable-seccomp --disable-libscrypt \
            --with-libevent-dir="$install_dir" \
            --with-openssl-dir="$install_dir" \
            --with-zlib-dir="$install_dir" \
            $(if [ "$client_only" = 1 ]; then printf '%s' '--disable-module-relay --disable-module-dirauth'; fi)

        # Critical: --enable-zstd/--enable-lzma do NOT fail when pkg-config
        # misses them! Require both config defines before compiling anything.
        grep -Eq '^#define HAVE_ZSTD 1$' orconfig.h ||
            die "Tor $arch silently disabled ZSTD; see config.log"
        grep -Eq '^#define HAVE_LZMA 1$' orconfig.h ||
            die "Tor $arch silently disabled LZMA; see config.log"
        # Some Tor builds auto-append -pie despite --enable-static-tor. The
        # AC_CACHE_CHECK override above preserves GCC hardening without PIE.
        if grep -E '^LDFLAGS[[:space:]]*=' Makefile | grep -Eq -- '(^|[[:space:]])-pie([[:space:]]|$)'; then
            die 'Tor configure re-added -pie to a static executable'
        fi
        say "$arch: configure confirms HAVE_ZSTD=1 and HAVE_LZMA=1"
        make -j"$JOBS"
        make install
    )

    binary="$result_dir/bin/tor"
    [ -s "$binary" ] || die "Tor did not install: $binary"
    "$STRIP" --strip-unneeded "$binary"
    elf_description=$(file -b "$binary")
    case "$elf_description" in
        *'statically linked'*|*'static-pie linked'*) ;;
        *) die "Tor is not a static ELF: $elf_description" ;;
    esac
    elf_reader=readelf
    if ! command -v "$elf_reader" >/dev/null 2>&1; then
        elf_reader=$host-readelf
    fi
    if command -v "$elf_reader" >/dev/null 2>&1; then
        if "$elf_reader" -l "$binary" | grep -q INTERP; then
            die 'Tor contains a dynamic interpreter: NOT fully static'
        fi
        if "$elf_reader" -d "$binary" 2>/dev/null | grep -q '(NEEDED)'; then
            die 'Tor unexpectedly has dynamically-linked libraries'
        fi
    fi
    file "$binary"
    tagged_binary="$result_dir/tor_${arch}_static_${tor_version}"
    cp "$binary" "$tagged_binary"
    chmod 755 "$tagged_binary"
    say "DONE: $tagged_binary ($tor_version, $arch, static zstd+lzma)"
}

run_arch() {
    setup_arch "$1"
    say "=== $arch: $CC / $SSL_TARGET ==="
    build_libs
    build_tor
}

if [ "$arch_choice" = all ]; then
    run_arch armv5te
    run_arch aarch64
else
    run_arch "$arch_choice"
fi

