#
# NOTE: THIS DOCKERFILE IS GENERATED VIA "apply-templates.sh"
#
# PLEASE DO NOT EDIT IT DIRECTLY.
#

ARG MYSQL_BASE_IMAGE=lcr.loongnix.cn/loongnix-server/loongnix-server:23.3@sha256:54c61a0ca717f1688fa5a6252a7e36a6e55f429c4d4bf00b4c9a97964b0b8e4e
FROM ${MYSQL_BASE_IMAGE}

RUN set -eux; \
	groupadd --system --gid 27 mysql; \
	useradd --system --uid 27 --gid 27 --home-dir /var/lib/mysql --no-create-home mysql

# Native static gosu reused from the prior verified BCLA MySQL8.4.0 image.
ENV GOSU_VERSION 1.19
COPY gosu /usr/local/bin/gosu
RUN set -eux; \
    chmod +x /usr/local/bin/gosu; \
    gosu --version; \
    gosu nobody true

RUN set -eux; \
	dnf install -y \
		bzip2 \
		gzip \
		openssl \
		xz \
		zstd \
# Oracle Linux 8+ is very slim :)
		findutils \
		tzdata \
	; \
	dnf clean all

ENV MYSQL_MAJOR 8.4
ENV MYSQL_VERSION 8.4.0-1.lns23

# Locally built native MySQL8.4.0 RPMs replace Oracle's foreign-architecture RPM repository.
COPY rpms/ /tmp/mysql-rpms/
RUN set -eux; \
    dnf install -y --setopt=install_weak_deps=False /tmp/mysql-rpms/*.rpm; \
    test "$(rpm -q --qf '%{VERSION}-%{RELEASE}' mysql-community-server)" = "$MYSQL_VERSION"; \
    dnf clean all; \
    rm -rf /tmp/mysql-rpms; \
# the "socket" value in the Oracle packages is set to "/var/lib/mysql" which isn't a great place for the socket (we want it in "/var/run/mysqld" instead)
# https://github.com/docker-library/mysql/pull/680#issuecomment-636121520
	grep -F 'socket=/var/lib/mysql/mysql.sock' /etc/my.cnf; \
	sed -i 's!^socket=.*!socket=/var/run/mysqld/mysqld.sock!' /etc/my.cnf; \
	grep -F 'socket=/var/run/mysqld/mysqld.sock' /etc/my.cnf; \
    sed -ri 's/^[[:space:]]*log[-_]error[[:space:]]*=/#&/' /etc/my.cnf; \
	{ echo '[client]'; echo 'socket=/var/run/mysqld/mysqld.sock'; } >> /etc/my.cnf; \
	\
# make sure users dumping files in "/etc/mysql/conf.d" still works
	! grep -F '!includedir' /etc/my.cnf; \
	{ echo; echo '!includedir /etc/mysql/conf.d/'; } >> /etc/my.cnf; \
	mkdir -p /etc/mysql/conf.d; \
# ensure these directories exist and have useful permissions
# the rpm package has different opinions on the mode of `/var/run/mysqld`, so this needs to be after install
	mkdir -p /var/lib/mysql /var/run/mysqld; \
	chown mysql:mysql /var/lib/mysql /var/run/mysqld; \
# ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	chmod 1777 /var/lib/mysql /var/run/mysqld; \
	\
	mkdir /docker-entrypoint-initdb.d; \
	\
	mysqld --version; \
	mysql --version

# MySQL Shell is a separate project and is not included in this server build.

VOLUME /var/lib/mysql

COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]

EXPOSE 3306 33060
CMD ["mysqld"]
