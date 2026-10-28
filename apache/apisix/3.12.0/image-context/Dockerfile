# Stage 2: assemble APISIX from the required independently built runtime image.
FROM apache/apisix-runtime-deb:3.12.0

ENV PATH="/usr/local/openresty/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/luajit/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LD_LIBRARY_PATH="/usr/local/openresty/openssl3/lib:/usr/local/openresty/wasmtime-c-api/lib:/usr/local/openresty/pcre/lib:/usr/local/openresty/luajit/lib:/usr/local/openresty/zlib/lib" \
    LUA_PATH="/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/local/apisix/deps/share/lua/5.1/?.lua;/usr/local/apisix/deps/share/lua/5.1/?/init.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/openresty/lualib/?.lua;/usr/local/openresty/lualib/?/init.lua;;" \
    LUA_CPATH="/usr/lib/loongarch64-linux-gnu/lua/5.1/?.so;/usr/local/apisix/deps/lib/lua/5.1/?.so;/usr/local/openresty/lualib/?.so;;" \
    APISIX_PREFIX="/usr/local/apisix"

COPY apisix-rootfs/ /
COPY docker-entrypoint.sh /docker-entrypoint.sh

RUN cp /usr/lib/loongarch64-linux-gnu/lua/5.1/ssl.so /usr/local/apisix/deps/lib/lua/5.1/ssl.so \
    && sed -i 's/require("ngx.re").opt("jit_stack_size", 200 \* 1024)/if require("jit").arch ~= "loongarch64" then require("ngx.re").opt("jit_stack_size", 200 * 1024) end/' /usr/local/share/lua/5.1/apisix/init.lua \
    && chmod 0755 /docker-entrypoint.sh \
    && groupadd --system --gid 636 apisix \
    && useradd --system --gid apisix --no-create-home --shell /usr/sbin/nologin --uid 636 apisix \
    && mkdir -p /usr/local/apisix/logs /usr/local/openresty/nginx/logs \
    && chown -R apisix:0 /usr/local/openresty/nginx/logs \
    && chmod -R g=u /usr/local/openresty/nginx/logs \
    && ln -sf /dev/stdout /usr/local/apisix/logs/access.log \
    && ln -sf /dev/stderr /usr/local/apisix/logs/error.log \
    && chown -R apisix:0 /usr/local/apisix \
    && chmod -R g=u /usr/local/apisix

WORKDIR /usr/local/apisix
USER apisix
EXPOSE 9080 9180 9443
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["docker-start"]
STOPSIGNAL SIGQUIT
