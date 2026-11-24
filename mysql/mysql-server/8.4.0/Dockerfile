# Derived from docker-library/mysql c05422492215b3f0602409288c868ee4fd606ac3,
# 8.4/Dockerfile.oracle. Uses forky DEBs in place of Oracle RPMs.
ARG MYSQL_BASE_IMAGE=lcr.loongnix.cn/library/debian:forky@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b
FROM ${MYSQL_BASE_IMAGE}

RUN set -eux; \
    groupadd --system --gid 999 mysql; \
    useradd --system --uid 999 --gid 999 --home-dir /var/lib/mysql --no-create-home mysql

ENV MYSQL_MAJOR=8.4 MYSQL_VERSION=8.4.0-1debian14

COPY debs/ /tmp/mysql-debs/
COPY runtime-deps/ /tmp/runtime-debs/
RUN set -eux; \
    printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; \
    chmod +x /usr/sbin/policy-rc.d; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends /tmp/mysql-debs/*.deb /tmp/runtime-debs/*.deb; \
    rm /usr/sbin/policy-rc.d; \
    find /etc/mysql -type f -name '*.cnf' -exec sed -ri 's/^[[:space:]]*(bind-address|mysqlx-bind-address|log[_-]error)[[:space:]]*=/#&/' '{}' +; \
    rm -rf /var/lib/mysql; \
    mkdir -p /var/lib/mysql /var/run/mysqld /docker-entrypoint-initdb.d; \
    chown mysql:mysql /var/lib/mysql /var/run/mysqld; \
    chmod 1777 /var/lib/mysql /var/run/mysqld; \
    gosu --version; \
    gosu nobody true; \
    mysqld --version; \
    mysql --version; \
    test "$(dpkg-query -W -f='${Version}' mysql-community-server-core)" = "$MYSQL_VERSION"; \
    rm -rf /tmp/mysql-debs /tmp/runtime-debs /var/lib/apt/lists/*

LABEL org.opencontainers.image.version="8.4.0" \
      org.opencontainers.image.source="https://github.com/mysql/mysql-server" \
      org.opencontainers.image.vendor="BCLA local build" \
      org.opencontainers.image.description="MySQL Server and standard clients, built as native LoongArch64 DEBs on Debian forky"

VOLUME /var/lib/mysql
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
EXPOSE 3306 33060
CMD ["mysqld"]
