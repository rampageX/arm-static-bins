#!/bin/sh
# Alpine/musl: native, aarch64-linux-musl and arm-linux-musleabi static nginx.
# Usage: sh nginx_http3_static_unified.sh [--arch native|aarch64|armv5te|all]
#        [--nginx latest|1.31.8] [--channel mainline|stable] [--force] [--print]
# Keep this script in the original /root/src directory with the addon folders.

set -eu

base_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
arch_choice=${ARCH:-native}
nginx_version=${NGINX_TAG:-latest}
channel=${NGINX_CHANNEL:-mainline}
force=${FORCE_REBUILD:-0}
print_only=0

# Versioned source archives. Override any of these with environment variables.
# nginx itself is discovered from the official directory index by default.
ZLIB_TAG=${ZLIB_TAG:-1.3.2}
OPENSSL_TAG=${OPENSSL_TAG:-3.5.9}  # supported OpenSSL 3.5 LTS / native QUIC
PCRE2_TAG=${PCRE2_TAG:-10.49}
LIBATOMIC_OPS_TAG=${LIBATOMIC_OPS_TAG:-7.10.0}
LZMA_TAG=${LZMA_TAG:-5.8.4}
LIBXML_TAG=${LIBXML_TAG:-2.15.4}
LIBXSLT_TAG=${LIBXSLT_TAG:-1.1.45}
PCRE_TAG=${PCRE_TAG:-8.45}       # optional legacy PCRE1 (NGINX uses PCRE2)
BUILD_PCRE1=${BUILD_PCRE1:-0}
JOBS=${JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)}

say() { printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

usage() {
    sed -n '2,5p' "$0"
    printf '\nDefaults: --arch native --nginx latest --channel mainline\n'
    printf 'Environment: JOBS, NGINX_TAG, *_TAG, BUILD_TRIPLET, BUILD_PCRE1=1, FORCE_REBUILD=1\n'
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --arch) [ "$#" -ge 2 ] || die '--arch needs a value'; arch_choice=$2; shift 2 ;;
        --nginx) [ "$#" -ge 2 ] || die '--nginx needs a value'; nginx_version=$2; shift 2 ;;
        --channel) [ "$#" -ge 2 ] || die '--channel needs a value'; channel=$2; shift 2 ;;
        --force) force=1; shift ;;
        --print) print_only=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done
case "$arch_choice" in native|aarch64|armv5te|all) ;; *) die "invalid architecture: $arch_choice" ;; esac
case "$channel" in mainline|stable) ;; *) die "invalid channel: $channel" ;; esac
case "$nginx_version" in latest|[0-9]*.[0-9]*.[0-9]*) ;; *) die "invalid nginx version: $nginx_version" ;; esac
case "$JOBS" in *[!0-9]*|'') die "JOBS must be a positive integer" ;; esac
[ "$JOBS" -gt 0 ] || die "JOBS must be positive"

# An existing proxy is authoritative. Otherwise use the user's mixed proxy:
# HTTP for curl/git HTTPS and SOCKS5H (remote DNS) for general fallback.
if [ -n "${http_proxy:-}${https_proxy:-}${all_proxy:-}${HTTP_PROXY:-}${HTTPS_PROXY:-}${ALL_PROXY:-}" ]; then
    proxy_mode=environment
else
    proxy_mode=192.168.2.8:7373
    http_proxy=http://192.168.2.8:7373
    https_proxy=http://192.168.2.8:7373
    all_proxy=socks5h://192.168.2.8:7373
    export http_proxy https_proxy all_proxy
fi

if [ "$print_only" -eq 1 ]; then
    printf 'base_dir=%s\narchitectures=%s\nnginx=%s\nchannel=%s\nproxy_mode=%s\n' \
        "$base_dir" "$arch_choice" "$nginx_version" "$channel" "$proxy_mode"
    exit 0
fi

for util in curl tar git cmake make sed awk grep pkg-config; do need "$util"; done
mkdir -p "$base_dir/.downloads" "$base_dir/.build"
say "Proxy: $proxy_mode (no credentials printed)"

fetch() {
    # Do not use a curl | tar pipeline: an HTTP error must abort the build.
    url=$1; destination=$2
    if [ -s "$destination" ]; then return 0; fi
    part="$destination.part.$$"
    if ! curl --fail --location --show-error --silent \
        --retry 4 --retry-delay 2 --connect-timeout 15 -o "$part" "$url"; then
        rm -f "$part"
        die "download failed: $url"
    fi
    [ -s "$part" ] || die "empty download: $url"
    mv -f "$part" "$destination"
}

resolve_nginx() {
    if [ "$nginx_version" != latest ]; then NGINX_TAG=$nginx_version; return; fi
    index="$base_dir/.downloads/nginx-index.$$"
    # Refresh the index every invocation; never silently build an old version.
    if ! curl --fail --location --show-error --silent --retry 3 \
        --connect-timeout 15 -o "$index" https://nginx.org/download/; then
        die 'cannot query nginx.org; set --nginx X.Y.Z for an offline build'
    fi
    NGINX_TAG=$(
        grep -oE 'nginx-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' "$index" |
        sed 's/^nginx-//;s/\.tar\.gz$//' |
        awk -F. -v ch="$channel" '
            (ch=="mainline" && $2%2==0) || (ch=="stable" && $2%2==1) {next}
            $1>major || ($1==major && ($2>minor || ($2==minor && $3>patch))) {
                major=$1; minor=$2; patch=$3; best=$0
            }
            END {print best}'
    )
    rm -f "$index"
    [ -n "$NGINX_TAG" ] || die "cannot determine latest $channel nginx"
}
resolve_nginx
say "NGINX version: $NGINX_TAG ($channel, requested: $nginx_version)"

ensure_source() {
    # All source/build trees are architecture-scoped, so a previous 32-bit
    # Configure/make cannot contaminate the next 64-bit build.
    name=$1; url=$2
    src="$source_root/$name"
    if [ -d "$src" ]; then return 0; fi
    archive="$base_dir/.downloads/$name.tar.${url##*.}"
    # Give downloads their real extension; tar auto-detects gz/xz.
    case "$url" in *.tar.gz) archive="$base_dir/.downloads/$name.tar.gz" ;;
                    *.tar.xz) archive="$base_dir/.downloads/$name.tar.xz" ;;
                    *) die "unsupported archive URL: $url" ;; esac
    fetch "$url" "$archive"
    stage=$(mktemp -d "$work_dir/unpack.XXXXXXXX")
    tar -xf "$archive" -C "$stage" || die "archive extraction failed: $archive"
    [ -d "$stage/$name" ] || die "archive does not contain expected folder: $name"
    mv "$stage/$name" "$src"
    rmdir "$stage"
}

stamp_ok() {
    [ "$force" != 1 ] && [ -f "$stamp_dir/$1" ] && [ -s "$lib_dir/$2" ]
}
stamp_done() { touch "$stamp_dir/$1"; }

build_autoconf() {
    name=$1; lib=$2; shift 2
    if stamp_ok "$name" "$lib"; then say "reuse $name"; return; fi
    say "compile $name [$arch]"
    ( cd "$source_root/$name"
      if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
      # Exporting a cross CC alone does not tell Autoconf that target binaries
      # cannot run on the Alpine build machine. Explicitly distinguish the
      # build and host triplets for EVERY Autoconf dependency (not just PCRE2).
      # Keep native builds unchanged; BUILD_TRIPLET can be overridden if the
      # Alpine machine's default gcc is not the native compiler.
      if [ -n "$host" ]; then
          build_triplet=${BUILD_TRIPLET:-$(gcc -dumpmachine)}
          [ -n "$build_triplet" ] || die 'cannot determine native build triplet; set BUILD_TRIPLET'
          set -- --build="$build_triplet" --host="$host" "$@"
      fi
      ./configure --prefix="$install_dir" --disable-shared --enable-static "$@"
      make -j"$JOBS"
      make install
    )
    [ -s "$lib_dir/$lib" ] || die "$name: $lib was not installed"
    stamp_done "$name"
}

toolchain() {
    arch=$1
    case "$arch" in
        native)
            host=; CC=${NATIVE_CC:-gcc}; CXX=${NATIVE_CXX:-g++}
            AR=ar; RANLIB=ranlib; STRIP=strip
            CROSS_ARG=; SSL_TARGET=; CMAKE_CPU=$(uname -m)
            CFLAGS="${NATIVE_CFLAGS:--O2 -march=native -mtune=native}"
            prefix=/usr/local; conf=/usr/local/nginx/conf/nginx.conf
            pid=/run/nginx.pid; lock=/run/nginx.lock
            brotli_dir="$base_dir/ngx_brotli"
            ;;
        aarch64)
            host=aarch64-linux-musl; CC=$host-gcc; CXX=$host-g++
            AR=$host-ar; RANLIB=$host-ranlib; STRIP=$host-strip
            CROSS_ARG=Linux::aarch64; SSL_TARGET=linux-aarch64; CMAKE_CPU=aarch64
            CFLAGS='-O2 -march=armv8-a -mtune=generic'
            prefix=/usr/local; conf=/usr/local/nginx/conf/nginx.conf
            pid=/run/nginx.pid; lock=/run/nginx.lock
            brotli_dir="$base_dir/ngx_brotli_aarch64"
            ;;
        armv5te)
            host=arm-linux-musleabi; CC=$host-gcc; CXX=$host-g++
            AR=$host-ar; RANLIB=$host-ranlib; STRIP=$host-strip
            CROSS_ARG=Linux::arm; SSL_TARGET=linux-armv4; CMAKE_CPU=arm
            # BCM4708/Cortex-A9 has ARMv7 instructions but no usable VFP;
            # generate conservative ARMv5TE, soft-float EABI binaries.
            CFLAGS='-O2 -march=armv5te -mfloat-abi=soft'
            prefix=/opt/etc/nginx; conf=/opt/etc/nginx/nginx.conf
            pid=/var/run/nginx.pid; lock=/var/run/nginx.lock
            brotli_dir="$base_dir/ngx_brotli_armv5te"
            ;;
    esac
    for tool in "$CC" "$CXX" "$AR" "$RANLIB" "$STRIP"; do need "$tool"; done
    export CC CXX AR RANLIB STRIP CFLAGS
}

build_libraries() {
    ensure_source "zlib-$ZLIB_TAG" "https://zlib.net/zlib-$ZLIB_TAG.tar.gz"
    if ! stamp_ok "zlib-$ZLIB_TAG" libz.a; then
        say "compile zlib-$ZLIB_TAG [$arch]"
        (cd "$source_root/zlib-$ZLIB_TAG"
         if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
         CC="$CC" ./configure --prefix="$install_dir" --static
         make -j"$JOBS"; make install)
        [ -s "$lib_dir/libz.a" ] || die 'zlib did not install libz.a'
        stamp_done "zlib-$ZLIB_TAG"
    fi

    ensure_source "pcre2-$PCRE2_TAG" \
        "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$PCRE2_TAG/pcre2-$PCRE2_TAG.tar.gz"
    build_autoconf "pcre2-$PCRE2_TAG" libpcre2-8.a \
        --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 --enable-jit

    # PCRE1 is obsolete and is not used by current nginx, but can be retained
    # for any of the user's other legacy consumers with BUILD_PCRE1=1.
    if [ "$BUILD_PCRE1" = 1 ]; then
        ensure_source "pcre-$PCRE_TAG" \
            "https://downloads.sourceforge.net/project/pcre/pcre/$PCRE_TAG/pcre-$PCRE_TAG.tar.gz"
        build_autoconf "pcre-$PCRE_TAG" libpcre.a
    fi

    ensure_source "libatomic_ops-$LIBATOMIC_OPS_TAG" \
        "https://github.com/bdwgc/libatomic_ops/releases/download/v$LIBATOMIC_OPS_TAG/libatomic_ops-$LIBATOMIC_OPS_TAG.tar.gz"
    build_autoconf "libatomic_ops-$LIBATOMIC_OPS_TAG" libatomic_ops.a

    ensure_source "xz-$LZMA_TAG" \
        "https://github.com/tukaani-project/xz/releases/download/v$LZMA_TAG/xz-$LZMA_TAG.tar.gz"
    build_autoconf "xz-$LZMA_TAG" liblzma.a

    ensure_source "libxml2-$LIBXML_TAG" \
        "https://download.gnome.org/sources/libxml2/${LIBXML_TAG%.*}/libxml2-$LIBXML_TAG.tar.xz"
    build_autoconf "libxml2-$LIBXML_TAG" libxml2.a --without-python

    # libxslt's configure can otherwise pick up /usr/bin/xml2-config from
    # the Alpine BUILD host instead of the selected target architecture.
    XML2_CONFIG="$install_dir/bin/xml2-config"
    export XML2_CONFIG
    [ -f "$XML2_CONFIG" ] || die "target xml2-config missing: $XML2_CONFIG"
    ensure_source "libxslt-$LIBXSLT_TAG" \
        "https://download.gnome.org/sources/libxslt/${LIBXSLT_TAG%.*}/libxslt-$LIBXSLT_TAG.tar.xz"
    build_autoconf "libxslt-$LIBXSLT_TAG" libxslt.a --without-python

    ensure_source "openssl-$OPENSSL_TAG" \
        "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_TAG/openssl-$OPENSSL_TAG.tar.gz"
    if ! stamp_ok "openssl-$OPENSSL_TAG" libssl.a || [ ! -s "$lib_dir/libcrypto.a" ]; then
        say "compile openssl-$OPENSSL_TAG [$arch]"
        ( cd "$source_root/openssl-$OPENSSL_TAG"
          if [ -f Makefile ]; then make distclean >/dev/null 2>&1 || true; fi
          if [ -n "$SSL_TARGET" ]; then
              # CC/AR/RANLIB are already fully prefixed by toolchain().
              # OpenSSL's Makefile combines CROSS_COMPILE + CC, so supplying
              # --cross-compile-prefix here would produce e.g.
              # arm-linux-musleabi-arm-linux-musleabi-gcc (and fail).
              CROSS_COMPILE= ./Configure "$SSL_TARGET" \
                  --prefix="$install_dir" --libdir=lib \
                  no-shared no-dso no-tests no-comp
          else
              ./config --prefix="$install_dir" --libdir=lib \
                  no-shared no-dso no-tests no-comp
          fi
          make -j"$JOBS"; make install_sw
        )
        [ -s "$lib_dir/libssl.a" ] && [ -s "$lib_dir/libcrypto.a" ] ||
            die 'OpenSSL static archives are missing'
        stamp_done "openssl-$OPENSSL_TAG"
    fi
}

get_addons() {
    # Never mutate a pre-existing checkout with git pull/reset. A new checkout
    # uses system proxy environment (or the automatically selected fallback).
    for record in \
        'nginx-dav-ext-module|https://github.com/arut/nginx-dav-ext-module.git' \
        'headers-more-nginx-module|https://github.com/openresty/headers-more-nginx-module.git' \
        'ngx-fancyindex|https://github.com/aperezdc/ngx-fancyindex.git'; do
        dir=${record%%|*}; url=${record#*|}
        if [ ! -d "$base_dir/$dir" ]; then
            say "clone $dir"
            git clone --depth=1 "$url" "$base_dir/$dir"
        fi
        [ -f "$base_dir/$dir/config" ] || die "addon $dir has no config"
    done
    if [ ! -d "$brotli_dir" ]; then
        say "clone $(basename "$brotli_dir")"
        git clone --recurse-submodules https://github.com/google/ngx_brotli.git "$brotli_dir"
    fi
    ( cd "$brotli_dir"; git submodule update --init --recursive )
    [ -f "$brotli_dir/config" ] || die 'ngx_brotli config missing'
}

build_brotli() {
    say "compile ngx_brotli [$arch]"
    brotli_source="$brotli_dir/deps/brotli"
    [ -f "$brotli_source/CMakeLists.txt" ] || die 'Brotli submodule missing'
    # Old user builds may have cached BUILD_SHARED_LIBS=ON in `out` and
    # generated .so files there. Keep that folder intact. Build from an
    # independent STATIC cache, then put only the required .a archives into
    # the legacy `out` location used by ngx_brotli/filter/config.
    static_out="$brotli_source/out-nginx-static"
    if [ "$arch" = native ]; then
        cmake -S "$brotli_source" -B "$static_out" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS:BOOL=OFF -DBROTLI_BUILD_FOR_PACKAGE:BOOL=OFF \
            -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS"
    else
        cmake -S "$brotli_source" -B "$static_out" \
            -DCMAKE_BUILD_TYPE=Release \
            -DBUILD_SHARED_LIBS:BOOL=OFF -DBROTLI_BUILD_FOR_PACKAGE:BOOL=OFF \
            -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR="$CMAKE_CPU" \
            -DCMAKE_C_COMPILER="$CC" -DCMAKE_C_FLAGS="$CFLAGS"
    fi
    cmake --build "$static_out" --parallel "$JOBS" --target brotlienc
    [ -s "$static_out/libbrotlienc.a" ] || die 'Brotli did not produce static libbrotlienc.a'
    [ -s "$static_out/libbrotlicommon.a" ] || die 'Brotli did not produce static libbrotlicommon.a'
    mkdir -p "$brotli_source/out"
    cp -f "$static_out/libbrotlienc.a" "$static_out/libbrotlicommon.a" "$brotli_source/out/"
}

prepare_dav_config() {
    # The dav-ext module's LIBXSLT token prompts nginx to search HOST libs.
    # Instead, let nginx auto/module append the TARGET static libs to its own
    # generated link rule (replaces the obsolete hard-coded final-step hack).
    dav_work="$work_dir/nginx-dav-ext-module"
    if [ ! -d "$dav_work" ]; then cp -R "$base_dir/nginx-dav-ext-module" "$dav_work"; fi
    [ -f "$dav_work/config" ] || die 'dav-ext config missing'
    # The old scripts permanently commented this line in the original addon.
    # Restore it in our private copy as an ACTIVE nginx module dependency.
    if grep -Eq '^[[:space:]]*#*[[:space:]]*ngx_module_libs=LIBXSLT' "$dav_work/config"; then
        sed -i "s|^[[:space:]]*#*[[:space:]]*ngx_module_libs=LIBXSLT.*|ngx_module_libs=\"-lxslt -lxml2 -llzma -lz -lm\"|" "$dav_work/config"
    fi
    # Validate the expected patch; silently disabling XML would be dangerous.
    grep -Eq '^ngx_module_libs=.*-lxslt -lxml2' "$dav_work/config" ||
        die 'dav-ext config has changed; cannot ensure static XML/XSLT linkage'
}

patch_nginx_cross() {
    # Upstream nginx (including 1.31.x) does not fully support Linux cross
    # compilation: --crossbuild still executes target autotest binaries and
    # hardcodes NGX_MACHINE=i386. Patch only our private per-arch source tree.
    [ -n "$CROSS_ARG" ] || return
    ngx_root="$source_root/nginx-$NGINX_TAG"
    cross_stamp="$ngx_root/.nginx-cross-autotests-v1"
    [ ! -f "$cross_stamp" ] || return

    # Both selected musl toolchains are little-endian. Validate this with the
    # target compiler rather than inferring it from the Alpine build host.
    target_byte_order=$(printf '' | "$CC" -dM -E -x c - |
        awk '$2 == "__BYTE_ORDER__" {print $3}')
    [ "$target_byte_order" = __ORDER_LITTLE_ENDIAN__ ] ||
        die "$CC has unexpected byte order: $target_byte_order"

    grep -q '^    NGX_MACHINE=i386$' "$ngx_root/configure" ||
        die 'nginx configure: unexpected crossbuild machine detection'
    grep -q '^if \[ -x \$NGX_AUTOTEST \]; then$' "$ngx_root/auto/feature" ||
        die 'nginx auto/feature layout changed; crossbuild patch needs review'
    grep -q '^if \[ -x \$NGX_AUTOTEST \]; then$' "$ngx_root/auto/types/sizeof" ||
        die 'nginx auto/types/sizeof layout changed; crossbuild patch needs review'
    grep -q '^if \[ -x \$NGX_AUTOTEST \]; then$' "$ngx_root/auto/endianness" ||
        die 'nginx auto/endianness layout changed; crossbuild patch needs review'

    # Restore the original build tree if a future nginx version changes its
    # probing rules; all backups live INSIDE the architecture-scoped tree.
    cp "$ngx_root/configure" "$ngx_root/configure.pre-cross"
    cp "$ngx_root/auto/feature" "$ngx_root/auto/feature.pre-cross"
    cp "$ngx_root/auto/types/sizeof" "$ngx_root/auto/types/sizeof.pre-cross"
    cp "$ngx_root/auto/endianness" "$ngx_root/auto/endianness.pre-cross"

    sed -i "s/^    NGX_MACHINE=i386\$/    NGX_MACHINE=$CMAKE_CPU/" "$ngx_root/configure"

    # The normal nginx feature test treats execution as proof of a working
    # compiler. Cross programs cannot run here, so use successful compile +
    # link as the criterion, preserving the existing feature selections.
    # A numeric result cannot be inferred from a successful link: leave such
    # optional features unavailable instead of executing a foreign binary.
    sed -i '/^if \[ -x \$NGX_AUTOTEST \]; then$/a\
    if [ "${NGX_CROSS_MODE:-no}" = yes ]; then\
        case "$ngx_feature_run" in\
            yes) ngx_feature_run=no ;;\
            value) echo " not available (cross-compiled)"; rm -f $NGX_AUTOTEST*; return ;;\
        esac\
    fi
' "$ngx_root/auto/feature"

    # Nginx sources these scripts with '.', so an early return skips only the
    # runtime probe. We never pretend that sizeof(time_t) == sizeof(void *):
    # ARMv5TE musl may use 64-bit time_t with 32-bit pointers.
    sed -i '1i\
if [ "${NGX_CROSS_MODE:-no}" = yes ]; then\
    . auto/types/sizeof-cross\
    return\
fi\
' "$ngx_root/auto/types/sizeof"
    sed -i '1i\
if [ "${NGX_CROSS_MODE:-no}" = yes ]; then\
    echo "checking for system byte ordering ... little endian (target compiler)"\
    have=NGX_HAVE_LITTLE_ENDIAN . auto/have\
    return\
fi\
' "$ngx_root/auto/endianness"

    # Discover exact target sizeof() values by compiling a negative-sized
    # array test. No QEMU or extra runtime packages are required.
    cat > "$ngx_root/auto/types/sizeof-cross" <<'NGX_CROSS_SIZEOF'
# Cross-compile-safe replacement for nginx auto/types/sizeof (sourced by nginx).
echo $ngx_n "checking for $ngx_type size ...$ngx_c"
ngx_size=
for ngx_candidate in 4 8; do
    cat << END > $NGX_AUTOTEST.c
#include <sys/types.h>
#include <sys/time.h>
$NGX_INCLUDE_UNISTD_H
#include <signal.h>
#include <stdio.h>
#include <sys/resource.h>
$NGX_INCLUDE_INTTYPES_H
$NGX_INCLUDE_AUTO_CONFIG_H
typedef char ngx_target_size_check[(sizeof($ngx_type) == $ngx_candidate) ? 1 : -1];
END
    ngx_test="$CC $CC_TEST_FLAGS $CC_AUX_FLAGS -c -o $NGX_AUTOTEST.o $NGX_AUTOTEST.c"
    if eval "$ngx_test >> $NGX_AUTOCONF_ERR 2>&1"; then
        ngx_size=$ngx_candidate
        break
    fi
done
rm -f $NGX_AUTOTEST*
case $ngx_size in
    4)
        ngx_max_value=2147483647
        ngx_max_len='(sizeof("-2147483648") - 1)'
    ;;
    8)
        ngx_max_value=9223372036854775807LL
        ngx_max_len='(sizeof("-9223372036854775808") - 1)'
    ;;
    *)
        echo "nginx crossbuild: cannot determine target sizeof($ngx_type)" >&2
        exit 1
    ;;
esac
echo " $ngx_size bytes (cross-compiled)"
NGX_CROSS_SIZEOF
    touch "$cross_stamp"
    say "nginx crossbuild autotests patched [$arch, $CMAKE_CPU, little endian]"
}

build_nginx() {
    ensure_source "nginx-$NGINX_TAG" \
        "https://nginx.org/download/nginx-$NGINX_TAG.tar.gz"
    prepare_dav_config
    patch_nginx_cross
    say "configure nginx-$NGINX_TAG [$arch]"

    # Avoid --with-openssl=source: it re-configures OpenSSL with the *host*
    # settings on some nginx/cross-build combinations. Use the already built
    # target libssl.a/libcrypto.a instead. Never link host Alpine .so files.
    cc_opt="$CFLAGS -I$include_dir -I$include_dir/libxml2"
    ld_opt="-static -L$lib_dir -Wl,--no-as-needed"
    ( cd "$source_root/nginx-$NGINX_TAG"
      if [ -f objs/Makefile ]; then make clean >/dev/null 2>&1 || true; fi
      set -- \
          --prefix="$prefix" --conf-path="$conf" \
          --error-log-path=/var/log/nginx_error.log \
          --http-log-path=/var/log/nginx_access.log \
          --pid-path="$pid" --lock-path="$lock" \
          --with-cc="$CC" --with-cpp="$CC -E" \
          --with-cc-opt="$cc_opt" --with-ld-opt="$ld_opt" \
          --with-mail --with-mail_ssl_module \
          --with-stream --with-stream_ssl_module \
          --with-stream_realip_module --with-stream_ssl_preread_module \
          --with-http_ssl_module --with-http_v2_module --with-http_v3_module \
          --with-http_realip_module --with-http_addition_module \
          --with-http_sub_module --with-http_dav_module \
          --with-http_flv_module --with-http_mp4_module \
          --with-http_gunzip_module --with-http_gzip_static_module \
          --with-http_auth_request_module --with-http_random_index_module \
          --with-http_secure_link_module --with-http_degradation_module \
          --with-http_slice_module --with-http_stub_status_module \
          --with-pcre-jit --with-libatomic --with-compat \
          --with-file-aio --with-threads --with-poll_module \
          --with-select_module \
          --add-module="$brotli_dir" \
          --add-module="$dav_work" \
          --add-module="$base_dir/headers-more-nginx-module" \
          --add-module="$base_dir/ngx-fancyindex"
      if [ -n "$CROSS_ARG" ]; then set -- --crossbuild="$CROSS_ARG" "$@"; fi
      if [ -n "$CROSS_ARG" ]; then
          NGX_CROSS_MODE=yes ./configure "$@"
      else
          ./configure "$@"
      fi
      [ -s objs/Makefile ] || die 'nginx did not generate objs/Makefile'
      grep -q -- '-lxslt' objs/Makefile || die 'dav-ext XSLT library absent from generated linker command'
      grep -q -- '-lxml2' objs/Makefile || die 'dav-ext XML2 library absent from generated linker command'
      for addon in ngx_http_brotli_filter_module ngx_http_brotli_static_module \
          ngx_http_dav_ext_module ngx_http_headers_more_filter_module \
          ngx_http_fancyindex_module; do
          grep -q "$addon" objs/ngx_modules.c || die "missing static module: $addon"
      done

      # The patched cross-build probes must measure target types exactly.
      # Fail on a mismatch instead of overwriting sizeof-related headers:
      # on 32-bit musl, sizeof(time_t) may be 8 while sizeof(void *) is 4.
      ptr_size=$(
          printf '\n' | "$CC" -dM -E -x c - |
          awk '$2=="__SIZEOF_POINTER__" {print $3}'
      )
      case "$ptr_size" in 4|8) ;; *) die 'could not query target pointer size' ;; esac
      conf_ptr=$(awk '$1=="#define" && $2=="NGX_PTR_SIZE" {print $3}' objs/ngx_auto_config.h)
      [ "$conf_ptr" = "$ptr_size" ] ||
          die "nginx target pointer size mismatch: compiler=$ptr_size config=$conf_ptr"
      # All referenced .o files are derived from this version's Makefile.
      make -j"$JOBS"
      [ -s objs/nginx ] || die 'nginx link step did not produce objs/nginx'
    )
}

verify_result() {
    source_binary="$source_root/nginx-$NGINX_TAG/objs/nginx"
    result_dir="$base_dir/${arch}_result"
    mkdir -p "$result_dir"
    if command -v readelf >/dev/null 2>&1; then
        if readelf -l "$source_binary" | grep -q 'INTERP'; then
            die "$arch nginx has a dynamic ELF interpreter; not fully static"
        fi
        case "$arch" in
            armv5te)
                readelf -h "$source_binary" | grep -Eq 'Machine:[[:space:]]+ARM([[:space:]]|$)' ||
                    die 'armv5te output is not an ARM ELF binary'
                ;;
            aarch64)
                readelf -h "$source_binary" | grep -Eq 'Machine:[[:space:]]+AArch64([[:space:]]|$)' ||
                    die 'aarch64 output is not an AArch64 ELF binary'
                ;;
        esac
    fi
    "$STRIP" "$source_binary"
    if [ "$arch" = native ]; then
        binary="$result_dir/nginx_static_$NGINX_TAG"
    else
        binary="$result_dir/nginx_${arch}_static_$NGINX_TAG"
    fi
    cp -f "$source_binary" "$binary"
    file "$binary" 2>/dev/null || true
    say "DONE: $binary"
    if [ "$arch" = native ]; then
        "$binary" -V 2>&1 || die 'native nginx -V failed'
    fi
}

build_target() {
    toolchain "$1"
    unset XML2_CONFIG
    work_dir="$base_dir/.build/$arch"
    source_root="$work_dir/src"
    install_dir="$base_dir/${arch}_dev"
    include_dir="$install_dir/include"
    lib_dir="$install_dir/lib"
    stamp_dir="$install_dir/.static-build-stamps"
    mkdir -p "$source_root" "$include_dir" "$lib_dir" "$stamp_dir"
    export CPPFLAGS="-I$include_dir -I$include_dir/libxml2"
    export LDFLAGS="-static -L$lib_dir"
    export PKG_CONFIG_PATH="$lib_dir/pkgconfig:$install_dir/share/pkgconfig"
    export PKG_CONFIG_LIBDIR="$PKG_CONFIG_PATH"
    say "========== $arch ($CC) =========="
    build_libraries
    get_addons
    build_brotli
    build_nginx
    verify_result
}

if [ "$arch_choice" = all ]; then
    for selected_arch in native aarch64 armv5te; do build_target "$selected_arch"; done
else
    build_target "$arch_choice"
fi
