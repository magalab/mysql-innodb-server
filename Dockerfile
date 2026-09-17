# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG MYSQL_VERSION=8.4.11
ARG MYSQL_SOURCE_URL=https://cdn.mysql.com/Downloads/MySQL-8.4/mysql-8.4.11.tar.gz
# SHA-256 of the MySQL 8.4.11 generic source archive.
ARG MYSQL_SOURCE_SHA256=eb3051164d625dd346a8203f76e0d5d5d9aec51dbe9d51788e39ec6b3f1394c2
ARG CMAKE_BUILD_PARALLEL_LEVEL=2

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  bison \
  build-essential \
  ca-certificates \
  cmake \
  curl \
  git \
  libaio-dev \
  libncurses-dev \
  libssl-dev \
  libtirpc-dev \
  pkg-config \
  perl \
  xz-utils \
  zstd \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/src /opt/mysql-runtime \
  && curl --fail --location --silent --show-error \
  --continue-at - \
  --retry 10 --retry-all-errors --retry-delay 5 --retry-max-time 3600 \
  "${MYSQL_SOURCE_URL}" --output /tmp/mysql-source.tar.gz \
  && echo "${MYSQL_SOURCE_SHA256}  /tmp/mysql-source.tar.gz" | sha256sum --check --strict \
  && tar --extract --gzip --file /tmp/mysql-source.tar.gz --directory /opt/src \
  && test -f "/opt/src/mysql-${MYSQL_VERSION}/CMakeLists.txt" \
  && rm -f /tmp/mysql-source.tar.gz

WORKDIR /opt/src/mysql-${MYSQL_VERSION}

COPY patches /opt/mysql-innodb-server/patches
COPY scripts/apply-patches.sh scripts/prune-source.sh scripts/verify.sh /opt/mysql-innodb-server/scripts/

RUN chmod +x /opt/mysql-innodb-server/scripts/*.sh \
  && /opt/mysql-innodb-server/scripts/apply-patches.sh . \
  && CONFIRM_PRUNE=yes /opt/mysql-innodb-server/scripts/prune-source.sh optional . \
  && CONFIRM_PRUNE=yes /opt/mysql-innodb-server/scripts/prune-source.sh user .

RUN cmake -S . -B /opt/mysql-build \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local/mysql \
  -DINSTALL_LAYOUT=STANDALONE \
  -DWITH_SSL=system \
  -DWITH_EDITLINE=bundled \
  -DWITH_UNIT_TESTS=OFF \
  -DWITH_ROUTER=OFF \
  -DWITH_SYSTEMD=OFF \
  -DWITH_NUMA=OFF \
  -DWITH_NDB=OFF \
  -DWITH_MYSQLX=OFF \
  -DWITH_NGRAM_PARSER=OFF \
  -DWITH_FIDO=none \
  -DWITH_CURL=none

# Build only the server, required startup component, and client-side programs
# needed by the entrypoint. The source tree still has the complete
# test/developer toolset, but it never enters the runtime stage.
RUN cmake --build /opt/mysql-build \
  --target mysqld mysql mysqladmin mysql_tzinfo_to_sql component_reference_cache \
  --parallel "${CMAKE_BUILD_PARALLEL_LEVEL}"

RUN /opt/mysql-innodb-server/scripts/verify.sh . /opt/mysql-build \
  && install -d /opt/mysql-runtime/bin /opt/mysql-runtime/lib \
  && install -D -m 0755 /opt/mysql-build/runtime_output_directory/mysqld /opt/mysql-runtime/bin/mysqld \
  && install -D -m 0755 /opt/mysql-build/runtime_output_directory/mysql /opt/mysql-runtime/bin/mysql \
  && install -D -m 0755 /opt/mysql-build/runtime_output_directory/mysqladmin /opt/mysql-runtime/bin/mysqladmin \
  && install -D -m 0755 /opt/mysql-build/runtime_output_directory/mysql_tzinfo_to_sql /opt/mysql-runtime/bin/mysql_tzinfo_to_sql \
  && cp -a /opt/mysql-build/share /opt/mysql-runtime/ \
  && find /opt/mysql-runtime/share -type d -name CMakeFiles -prune -exec rm -rf {} + \
  && find /opt/mysql-build/library_output_directory -maxdepth 1 \( -type f -o -type l \) -name 'lib*.so*' -exec cp -a {} /opt/mysql-runtime/lib/ \; \
  && install -d /opt/mysql-runtime/lib/plugin /opt/mysql-runtime/lib/private \
  && find /opt/mysql-build/plugin_output_directory -maxdepth 1 \( -type f -o -type l \) -exec cp -a {} /opt/mysql-runtime/lib/plugin/ \; \
  && if test -d /opt/mysql-build/library_output_directory/private; then cp -a /opt/mysql-build/library_output_directory/private/. /opt/mysql-runtime/lib/private/; fi \
  && icu_data_dir=icudt77l \
  && if test "$(uname -m)" = s390x; then icu_data_dir=icudt77b; fi \
  && cp -a "/opt/src/mysql-${MYSQL_VERSION}/extra/icu/${icu_data_dir}" /opt/mysql-runtime/lib/private/ \
  && test -x /opt/mysql-runtime/bin/mysqld \
  && test -x /opt/mysql-runtime/bin/mysql \
  && test -x /opt/mysql-runtime/bin/mysqladmin \
  && test -f /opt/mysql-runtime/share/english/errmsg.sys

# The official-style entrypoint probes this command before initialization. Keep
# it as a build-time smoke test so startup-only plugin regressions fail here.
RUN LD_LIBRARY_PATH=/opt/mysql-runtime/lib \
  /opt/mysql-runtime/bin/mysqld --verbose --help \
  --log-bin-index=/tmp/mysql-build-binlog.index >/dev/null

FROM ubuntu:${UBUNTU_VERSION} AS runtime

ARG MYSQL_VERSION=8.4.11

ENV DEBIAN_FRONTEND=noninteractive \
  MYSQL_HOME=/usr/local/mysql \
  MYSQL_DATADIR=/var/lib/mysql \
  MYSQL_UNIX_PORT=/var/lib/mysql/mysql.sock \
  LD_LIBRARY_PATH=/usr/local/mysql/lib \
  PATH=/usr/local/mysql/bin:/usr/local/mysql/sbin:${PATH}

LABEL org.opencontainers.image.title="MySQL InnoDB Server" \
  org.opencontainers.image.description="MySQL Server with InnoDB as the only user-table persistent storage engine" \
  org.opencontainers.image.version="${MYSQL_VERSION}"

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  bzip2 \
  ca-certificates \
  libaio1t64 \
  libncurses6 \
  libssl3t64 \
  libtirpc3t64 \
  libtinfo6 \
  tzdata \
  xz-utils \
  zstd \
  && rm -rf /var/lib/apt/lists/* \
  && groupadd --system mysql \
  && useradd --system --gid mysql --home-dir /nonexistent --no-create-home mysql \
  && install -d -o mysql -g mysql -m 0750 \
  /var/lib/mysql \
  /var/lib/mysql-files \
  /var/run/mysqld \
  /docker-entrypoint-initdb.d \
  && install -d -o root -g root -m 0755 /etc/mysql/conf.d /etc/mysql/mysql.conf.d

COPY --from=builder /opt/mysql-runtime/ /usr/local/mysql/
COPY docker/my.cnf /etc/mysql/my.cnf
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/healthcheck.sh /usr/local/bin/docker-healthcheck.sh

RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/docker-healthcheck.sh \
  && ln -sf /usr/local/mysql/bin/mysqld /usr/local/bin/mysqld \
  && ln -sf /usr/local/mysql/bin/mysql /usr/local/bin/mysql \
  && ln -sf /usr/local/mysql/bin/mysqladmin /usr/local/bin/mysqladmin \
  && ln -sf /usr/local/mysql/bin/mysql_tzinfo_to_sql /usr/local/bin/mysql_tzinfo_to_sql \
  && printf '%s\n' "MySQL ${MYSQL_VERSION} InnoDB Server image" > /usr/local/mysql/IMAGE_INFO

VOLUME ["/var/lib/mysql"]
EXPOSE 3306
STOPSIGNAL SIGTERM

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=10 \
  CMD ["/usr/local/bin/docker-healthcheck.sh"]

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["mysqld"]
