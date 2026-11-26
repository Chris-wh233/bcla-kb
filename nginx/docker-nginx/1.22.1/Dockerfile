FROM lcr.loongnix.cn/library/alpine:3.24.4

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION 1.22.1
ENV NJS_VERSION   0.7.7
ENV PKG_RELEASE   1

COPY abuild-compat.conf njs-webcrypto.patch /tmp/

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${PKG_RELEASE} \
    " \
# use the verified Alpine mirror during the build
    && cp /etc/apk/repositories /tmp/apk-repositories \
    && sed -i 's|https://dl-cdn.alpinelinux.org/alpine|https://mirrors.tuna.tsinghua.edu.cn/alpine|g' /etc/apk/repositories \
# we're on an architecture upstream doesn't officially build for
# let's build binaries from the published packaging sources
    && tempDir="$(mktemp -d)" \
    && chown nobody:nobody $tempDir \
    && apk add --no-cache --virtual .build-deps \
        gcc \
        libc-dev \
        make \
        openssl \
        openssl-dev \
        pcre2-dev \
        zlib-dev \
        linux-headers \
        libxslt-dev \
        gd-dev \
        geoip-dev \
        perl-dev \
        libedit-dev \
        bash \
        alpine-sdk \
        findutils \
        curl \
        ca-certificates \
        patch \
    && su nobody -s /bin/sh -c " \
        set -e \
        && export HOME=${tempDir} \
        && cd ${tempDir} \
        && curl -f -L --retry 3 https://codeload.github.com/nginx/pkg-oss/tar.gz/873a91379b6884c29e9cd00dc6a35a7c93102891 -o pkg-oss.tar.gz \
        && mkdir pkg-oss \
        && tar xzvf pkg-oss.tar.gz --strip-components=1 -C pkg-oss \
        && cd pkg-oss \
        && mkdir -p contrib/tarballs njs-src \
        && curl -f -L --retry 3 https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz -o contrib/tarballs/nginx-${NGINX_VERSION}.tar.gz \
        && curl -f -L --retry 3 https://codeload.github.com/nginx/njs/tar.gz/refs/tags/${NJS_VERSION} -o njs.tar.gz \
        && tar xzvf njs.tar.gz -C njs-src \
        && patch --force --fuzz=0 -d njs-src/njs-${NJS_VERSION} -p1 < /tmp/njs-webcrypto.patch \
        && tar czf contrib/tarballs/njs-${NJS_VERSION}.tar.gz -C njs-src njs-${NJS_VERSION} \
        && cd contrib/tarballs \
        && sha512sum njs-${NJS_VERSION}.tar.gz > ../src/njs/SHA512SUMS \
        && cd ../../alpine \
        && make ${tempDir}/.abuild/abuild.conf \
        && cat /tmp/abuild-compat.conf >> ${tempDir}/.abuild/abuild.conf \
        && make all \
        && apk --keys-dir ${tempDir}/.abuild index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
        && abuild-sign -k ${tempDir}/.abuild/abuild-key.rsa ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz \
        " \
    && cp ${tempDir}/.abuild/abuild-key.rsa.pub /etc/apk/keys/ \
    && apk del --no-network .build-deps \
    && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
# if we have leftovers from building, let's purge them
    && rm -rf "$tempDir" /tmp/abuild-compat.conf /tmp/njs-webcrypto.patch \
    && rm -f /etc/apk/keys/abuild-key.rsa.pub \
# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk --no-network info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del --no-network .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
# Bring in tzdata so users could set the timezones through the environment
# variables
    && apk add --no-cache tzdata \
# Bring in curl and ca-certificates to make registering on DNS SD easier
    && apk add --no-cache curl ca-certificates \
    && mv /tmp/apk-repositories /etc/apk/repositories \
# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
# create a docker-entrypoint.d directory
    && mkdir /docker-entrypoint.d

COPY docker-entrypoint.sh /
COPY 10-listen-on-ipv6-by-default.sh /docker-entrypoint.d
COPY 20-envsubst-on-templates.sh /docker-entrypoint.d
COPY 30-tune-worker-processes.sh /docker-entrypoint.d
ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
