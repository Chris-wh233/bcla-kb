#!/usr/bin/env bash
set -euo pipefail
set -x

runtime_version=${runtime_version:-0.0.0}


debug_args=${debug_args:-}
ENABLE_FIPS=${ENABLE_FIPS:-"false"}
OPENSSL_CONF_PATH=${OPENSSL_CONF_PATH:-$PWD/conf/openssl3/openssl.cnf}


OR_PREFIX=${OR_PREFIX:="/usr/local/openresty"}
OPENSSL_PREFIX=${OPENSSL_PREFIX:=$OR_PREFIX/openssl3}
zlib_prefix=${OR_PREFIX}/zlib
pcre_prefix=${OR_PREFIX}/pcre

cc_opt=${cc_opt:-"-DNGX_LUA_ABORT_AT_PANIC -I$zlib_prefix/include -I$pcre_prefix/include -I$OPENSSL_PREFIX/include"}
ld_opt=${ld_opt:-"-L$zlib_prefix/lib -L$pcre_prefix/lib -L$OPENSSL_PREFIX/lib -Wl,-rpath,$zlib_prefix/lib:$pcre_prefix/lib:$OPENSSL_PREFIX/lib"}


# dependencies for building openresty
OPENSSL_VERSION=${OPENSSL_VERSION:-"3.2.0"}
OPENRESTY_VERSION="1.27.1.1"
ngx_multi_upstream_module_ver="1.3.1"
mod_dubbo_ver="1.0.2"
apisix_nginx_module_ver="1.18.0"
wasm_nginx_module_ver="0.7.0"
lua_var_nginx_module_ver="v0.5.3"
lua_resty_events_ver="0.2.0"


install_openssl_3(){
    local fips=""
    if [ "$ENABLE_FIPS" == "true" ]; then
        fips="enable-fips"
    fi
    # required for openssl 3.x config
    if ! perl -MIPC::Cmd -e 1 >/dev/null 2>&1; then
        cpanm IPC/Cmd.pm
    fi
    wget --no-check-certificate https://github.com/openssl/openssl/releases/download/openssl-3.2.0/openssl-${OPENSSL_VERSION}.tar.gz
    tar xvf openssl-${OPENSSL_VERSION}.tar.gz
    cd openssl-${OPENSSL_VERSION}/
    export LDFLAGS="-Wl,-rpath,$zlib_prefix/lib:$OPENSSL_PREFIX/lib"
    ./config $fips \
      shared \
      zlib \
	  enable-camellia enable-seed enable-rfc3779 \
	  enable-cms enable-md2 enable-rc5 \
	  enable-weak-ssl-ciphers \
      --prefix=$OPENSSL_PREFIX \
      --libdir=lib               \
      --with-zlib-lib=$zlib_prefix/lib \
      --with-zlib-include=$zlib_prefix/include
    make -j $(nproc) LD_LIBRARY_PATH= CC="gcc"
    make install
    if [ -f "$OPENSSL_CONF_PATH" ]; then
        cp "$OPENSSL_CONF_PATH" "$OPENSSL_PREFIX"/ssl/openssl.cnf
    fi
    if [ "$ENABLE_FIPS" == "true" ]; then
        $OPENSSL_PREFIX/bin/openssl fipsinstall -out $OPENSSL_PREFIX/ssl/fipsmodule.cnf -module $OPENSSL_PREFIX/lib/ossl-modules/fips.so
        sed -i 's@# .include fipsmodule.cnf@.include '"$OPENSSL_PREFIX"'/ssl/fipsmodule.cnf@g; s/# \(fips = fips_sect\)/\1\nbase = base_sect\n\n[base_sect]\nactivate=1\n/g' $OPENSSL_PREFIX/ssl/openssl.cnf
    fi
    cd ..
}


if ([ $# -gt 0 ] && [ "$1" == "latest" ]) || [ "$runtime_version" == "0.0.0" ]; then
    debug_args="--with-debug"
fi

prev_workdir="$PWD"
repo=$(basename "$prev_workdir")
workdir=$(mktemp -d)
cd "$workdir" || exit 1


if LD_LIBRARY_PATH="$OPENSSL_PREFIX/lib:$zlib_prefix/lib" "$OPENSSL_PREFIX/bin/openssl" version 2>/dev/null | grep -q "^OpenSSL ${OPENSSL_VERSION} "; then
    echo "Using verified OpenSSL ${OPENSSL_VERSION} already installed at $OPENSSL_PREFIX"
else
    install_openssl_3
fi

wget --no-check-certificate https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz
tar -zxvpf openresty-${OPENRESTY_VERSION}.tar.gz > /dev/null

if [ "$repo" == lua-resty-events ]; then
    cp -r "$prev_workdir" ./lua-resty-events-${lua_resty_events_ver}
else
    git clone --depth=1 -b $lua_resty_events_ver \
        https://github.com/Kong/lua-resty-events.git \
        lua-resty-events-${lua_resty_events_ver}
fi

if [ "$repo" == ngx_multi_upstream_module ]; then
    cp -r "$prev_workdir" ./ngx_multi_upstream_module-${ngx_multi_upstream_module_ver}
else
    git clone --depth=1 -b $ngx_multi_upstream_module_ver \
        https://github.com/api7/ngx_multi_upstream_module.git \
        ngx_multi_upstream_module-${ngx_multi_upstream_module_ver}
fi

if [ "$repo" == mod_dubbo ]; then
    cp -r "$prev_workdir" ./mod_dubbo-${mod_dubbo_ver}
else
    git clone --depth=1 -b $mod_dubbo_ver \
        https://github.com/api7/mod_dubbo.git \
        mod_dubbo-${mod_dubbo_ver}
fi

if [ "$repo" == apisix-nginx-module ]; then
    cp -r "$prev_workdir" ./apisix-nginx-module-${apisix_nginx_module_ver}
else
    git clone --depth=1 -b $apisix_nginx_module_ver \
        https://github.com/api7/apisix-nginx-module.git \
        apisix-nginx-module-${apisix_nginx_module_ver}
fi

if [ "$repo" == wasm-nginx-module ]; then
    cp -r "$prev_workdir" ./wasm-nginx-module-${wasm_nginx_module_ver}
else
    git clone --depth=1 -b $wasm_nginx_module_ver \
        https://github.com/api7/wasm-nginx-module.git \
        wasm-nginx-module-${wasm_nginx_module_ver}
fi

if [ "$repo" == lua-var-nginx-module ]; then
    cp -r "$prev_workdir" ./lua-var-nginx-module-${lua_var_nginx_module_ver}
else
    git clone --depth=1 -b $lua_var_nginx_module_ver \
        https://github.com/api7/lua-var-nginx-module \
        lua-var-nginx-module-${lua_var_nginx_module_ver}
fi

cd ngx_multi_upstream_module-${ngx_multi_upstream_module_ver} || exit 1
./patch.sh ../openresty-${OPENRESTY_VERSION}
cd ..

cd apisix-nginx-module-${apisix_nginx_module_ver}/patch || exit 1
./patch.sh ../../openresty-${OPENRESTY_VERSION}
cd ../..

cd wasm-nginx-module-${wasm_nginx_module_ver} || exit 1
test -s "$prev_workdir/../../../runtime-stage/wasmtime-c-api/lib/libwasmtime.so"
rm -rf "$OR_PREFIX/wasmtime-c-api"
install -d "$OR_PREFIX/wasmtime-c-api"
cp -a "$prev_workdir/../../../runtime-stage/wasmtime-c-api/." "$OR_PREFIX/wasmtime-c-api/"
rm -rf "$PWD/wasmtime-c-api"
cp -a "$OR_PREFIX/wasmtime-c-api" "$PWD/wasmtime-c-api"
cd ..


luajit_xcflags=${luajit_xcflags:="-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT"}
no_pool_patch=${no_pool_patch:-}

luajit_source_dir="$prev_workdir/../luajit2-loongarch64"
if [ ! -d "$luajit_source_dir/.git" ]; then
    git clone --depth=1 --branch v2.1-agentzh-loongarch64 \
        https://github.com/loongson/luajit2.git "$luajit_source_dir"
fi
make -C "$luajit_source_dir" clean
make -C "$luajit_source_dir" -j"$(nproc)" XCFLAGS="$luajit_xcflags"
rm -rf "$OR_PREFIX/luajit"
make -C "$luajit_source_dir" install PREFIX="$OR_PREFIX/luajit"
luajit_arch=$(LD_LIBRARY_PATH="$OR_PREFIX/luajit/lib:${LD_LIBRARY_PATH:-}" \
    "$OR_PREFIX/luajit/bin/luajit" -e 'io.write(jit.arch)')
test "$luajit_arch" = loongarch64

cd openresty-${OPENRESTY_VERSION} || exit 1

or_limit_ver=0.09
if [ ! -d "bundle/lua-resty-limit-traffic-$or_limit_ver" ]; then
    echo "ERROR: the official repository of lua-resty-limit-traffic has been updated, please sync to API7's repository." >&2
    exit 1
else
    rm -rf bundle/lua-resty-limit-traffic-$or_limit_ver
    limit_ver=1.0.0
    wget "https://github.com/api7/lua-resty-limit-traffic/archive/refs/tags/v$limit_ver.tar.gz" -O "lua-resty-limit-traffic-$limit_ver.tar.gz"
    tar -xzf lua-resty-limit-traffic-$limit_ver.tar.gz
    mv lua-resty-limit-traffic-$limit_ver bundle/lua-resty-limit-traffic-$or_limit_ver
fi


./configure --with-luajit="$OR_PREFIX/luajit" --prefix="$OR_PREFIX" \
    --with-cc-opt="-DAPISIX_RUNTIME_VER=$runtime_version $cc_opt" \
    --with-ld-opt="-Wl,-rpath,$OR_PREFIX/wasmtime-c-api/lib $ld_opt" \
    $debug_args \
    --add-module=../mod_dubbo-${mod_dubbo_ver} \
    --add-module=../ngx_multi_upstream_module-${ngx_multi_upstream_module_ver} \
    --add-module=../apisix-nginx-module-${apisix_nginx_module_ver} \
    --add-module=../apisix-nginx-module-${apisix_nginx_module_ver}/src/stream \
    --add-module=../apisix-nginx-module-${apisix_nginx_module_ver}/src/meta \
    --add-module=../wasm-nginx-module-${wasm_nginx_module_ver} \
    --add-module=../lua-var-nginx-module-${lua_var_nginx_module_ver} \
    --add-module=../lua-resty-events-${lua_resty_events_ver} \
    --with-poll_module \
    --without-http_rds_json_module \
    --without-http_rds_csv_module \
    --without-lua_rds_parser \
    --with-stream \
    --with-stream_ssl_module \
    --with-stream_ssl_preread_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_addition_module \
    --with-http_auth_request_module \
    --with-http_secure_link_module \
    --with-http_random_index_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-http_dav_module \
    --with-http_flv_module \
    --with-http_mp4_module \
    --with-http_gunzip_module \
    --with-threads \
    --with-compat \
    --with-luajit-xcflags="$luajit_xcflags" \
    $no_pool_patch \
    -j`nproc`

make -j`nproc`
make install
cd ..

cd lua-resty-events-${lua_resty_events_ver} || exit 1
install -d "$OR_PREFIX"/lualib/resty/events/
install -m 664 lualib/resty/events/*.lua "$OR_PREFIX"/lualib/resty/events/
install -d "$OR_PREFIX"/lualib/resty/events/compat/
install -m 644 lualib/resty/events/compat/*.lua "$OR_PREFIX"/lualib/resty/events/compat/
cd ..

cd apisix-nginx-module-${apisix_nginx_module_ver} || exit 1
OPENRESTY_PREFIX="$OR_PREFIX" make install
cd ..

cd wasm-nginx-module-${wasm_nginx_module_ver} || exit 1
OPENRESTY_PREFIX="$OR_PREFIX" make install
cd ..

# etcdctl is not shipped in the official APISIX Debian image.
