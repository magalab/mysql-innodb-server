# MySQL InnoDB Server

| [简体中文](README.md) | English |
| --- | --- |

This repository maintains isolated build targets for MySQL upstream series. Each target contains its own pinned source version and SHA-256, patch series, pruning/build/verification scripts, Docker configuration, and documentation. The full MySQL source tree is not stored here.

## Build targets

| Upstream series | Pinned source | Status | Target |
| --- | --- | --- | --- |
| MySQL 8.4 LTS | 8.4.11 | Implemented | [targets/mysql-8.4](targets/mysql-8.4/README.en.md) |

Each target makes InnoDB the only persistent storage engine for user tables while retaining internal capabilities required for normal MySQL operation. Patches are specific to their upstream series and should not be reused across series without rework.

## Build the 8.4 image

```bash
docker build --progress=plain \
  --file targets/mysql-8.4/Dockerfile \
  --build-arg CMAKE_BUILD_PARALLEL_LEVEL=2 \
  -t ghcr.io/magalab/mysql-innodb-server:8.4.11 \
  targets/mysql-8.4
```

The publishing workflow selects a target from the major/minor parts of the Git tag, checks the tag against that target's source pin, then builds `linux/amd64` and `linux/arm64` images. See the target documentation for build, startup, and patch details.

## Run the 8.4 image

Common startup patterns. The complete environment-variable reference, initialization-file semantics, and patch series live in [targets/mysql-8.4](targets/mysql-8.4/README.en.md).

### Set the root password

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

The default root account is `root@'%'`, so GUI clients and other containers can connect over TCP. Client configuration: `127.0.0.1:3306`, user `root`, password as set above.

### Empty password (development only)

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

> ⚠️ Combined with the default remote root account, the operator is responsible for the resulting network exposure. Use a fixed password or restrict network access in any non-dev setting.

### Random root password

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

A random password is generated and printed to the container log (`docker logs mysql-innodb-server`).

### Create a database and a normal user at the same time

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -e MYSQL_DATABASE=appdb \
  -e MYSQL_USER=appuser \
  -e MYSQL_PASSWORD='app-pass' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

Pick exactly one of `MYSQL_ROOT_PASSWORD`, `MYSQL_ALLOW_EMPTY_PASSWORD=yes`, or `MYSQL_RANDOM_ROOT_PASSWORD=yes`. Setting none of them causes the first startup to fail.

## Common environment variables

| Variable | Description |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` | Set the root password (pick one of password, empty, or random) |
| `MYSQL_ALLOW_EMPTY_PASSWORD=yes` | Allow an empty root password |
| `MYSQL_RANDOM_ROOT_PASSWORD=yes` | Generate a random root password and print it to the log |
| `MYSQL_DATABASE` | Create a database automatically during initialization |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Create a normal user during initialization (Host `%`) |
| `MYSQL_ROOT_HOST` | Host pattern for the remote root account; defaults to `%` |

Each variable also accepts a Docker-secrets-style `*_FILE` companion (for example `MYSQL_ROOT_PASSWORD_FILE`), suitable for injecting credentials via mounted files. See the target documentation for the full list.

## Healthcheck

The image ships with a built-in healthcheck. Inspect a container's status with:

```bash
docker inspect --format '{{.State.Health.Status}}' mysql-innodb-server
```

A status of `healthy` means mysqld is ready to accept connections.
