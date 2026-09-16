# MySQL InnoDB Server

| [简体中文](README.md) | English |
| --- | --- |

This repository contains a small patch series for MySQL 8.4.11. It does not vendor the full MySQL source tree. Instead, it stores the patches, source-pruning scripts, Dockerfile, and validation notes needed to build a MySQL Server whose only user-table persistent storage engine is InnoDB.

## Current status

The current implementation completes the user-facing storage-engine cleanup:

- InnoDB is the only persistent storage engine available for user tables;
- MyISAM, MRG_MYISAM, CSV, Archive, Blackhole, Federated, NDB, and the other removed engines are no longer usable for user tables;
- `PERFORMANCE_SCHEMA` and `MEMORY` remain for monitoring and memory/temporary-table paths;
- `SHOW ENGINES` is expected to show `PERFORMANCE_SCHEMA`, `InnoDB`, and `MEMORY`;
- the Docker image includes the startup component, ICU data, timezone data, TLS support, initialization scripts, and a healthcheck.

This is therefore the “InnoDB-only user tables” baseline, not a strict build where `SHOW ENGINES` contains only InnoDB. That stricter M3 target would require further changes to temporary tables, monitoring, and compatibility behavior.

## Quick start

### Build the image

The build context only needs this repository. The Docker builder downloads the official MySQL source archive, verifies its SHA-256, applies the patches, and removes the source directories listed by the pruning script.

```bash
cd /path/to/mysql-innodb-server
docker build --progress=plain \
  --build-arg CMAKE_BUILD_PARALLEL_LEVEL=4 \
  -t mysql-innodb-server:8.4.11 .
```

### Start the server

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  mysql-innodb-server:8.4.11
```

The default root account is `root@'%'`, so GUI clients and other containers can connect over TCP:

```text
Host: 127.0.0.1
Port: 3306
User: root
Password: change-me
```

### Empty password for development

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  mysql-innodb-server:8.4.11
```

When this is combined with the default remote root account, the user is responsible for the resulting network exposure.

## Initialization environment variables

The following variables only take effect when `/var/lib/mysql` has not been initialized:

| Variable | Purpose |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` / `MYSQL_ROOT_PASSWORD_FILE` | Set the root password; choose this, empty-password mode, or random-password mode |
| `MYSQL_ROOT_HOST` / `MYSQL_ROOT_HOST_FILE` | Root account Host value; defaults to `%`, and may be set to an IP pattern such as `192.168.215.%` |
| `MYSQL_DATABASE` | Create a database automatically |
| `MYSQL_USER` | Create a normal user with Host `%` |
| `MYSQL_PASSWORD` / `MYSQL_PASSWORD_FILE` | Password for the normal user |
| `MYSQL_ALLOW_EMPTY_PASSWORD=yes` | Allow an empty root password |
| `MYSQL_RANDOM_ROOT_PASSWORD=yes` | Generate a random root password and print it to the log |
| `MYSQL_ONETIME_PASSWORD=yes` | Expire the root password after initialization |
| `MYSQL_INITDB_SKIP_TZINFO=yes` | Skip timezone-table loading |

Password, Host, database, and normal-user variables support Docker-secrets-style `_FILE` forms. Use `MYSQL_USER` together with `MYSQL_PASSWORD` and `MYSQL_DATABASE`.

## Initialization files

Files mounted at `/docker-entrypoint-initdb.d` are processed in lexical filename order on the first initialization only. Supported extensions are:

- `.sh`
- `.sql`
- `.sql.bz2`
- `.sql.gz`
- `.sql.xz`
- `.sql.zst`

Example:

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  -v "$(pwd)/initdb:/docker-entrypoint-initdb.d:ro" \
  mysql-innodb-server:8.4.11
```

## Patch series

Patches are applied in lexical filename order, and every patch is based on a clean MySQL 8.4.11 source tree:

1. `0001-remove-ndbinfo-server-integration.patch`: remove NDB information-schema integration from the Server;
2. `0002-remove-myisam-core-and-key-cache.patch`: remove MyISAM core state and key-cache paths;
3. `0003-remove-myisam-only-sql-surfaces.patch`: remove MyISAM/MRG_MYISAM parser and header leftovers;
4. `0004-remove-myisam-fulltext-state.patch`: remove MyISAM-specific full-text state and variables;
5. `0005-guard-innodb-pfs-during-help.patch`: fix the InnoDB PFS initialization path during `--help` and config validation;
6. `0006-use-innodb-for-system-log-tables.patch`: use InnoDB for the general and slow log system tables.

Source-directory deletion is handled by `scripts/prune-source.sh` instead of patches, avoiding duplicate storage of large removed source trees in Git.

## Build from source

Keep a pristine source copy and apply the patches to a separate work copy:

```bash
PATCH_REPO=/path/to/mysql-innodb-server
SOURCE_DIR=/path/to/mysql-8.4.11-work
BUILD_DIR=/private/tmp/mysql-8.4.11-innodb-build

"$PATCH_REPO/scripts/apply-patches.sh" "$SOURCE_DIR"
CONFIRM_PRUNE=yes "$PATCH_REPO/scripts/prune-source.sh" optional "$SOURCE_DIR"
CONFIRM_PRUNE=yes "$PATCH_REPO/scripts/prune-source.sh" user "$SOURCE_DIR"
"$PATCH_REPO/scripts/build.sh" "$SOURCE_DIR" "$BUILD_DIR"
"$PATCH_REPO/scripts/verify.sh" "$SOURCE_DIR" "$BUILD_DIR"
```

The `strict` pruning phase removes HEAP, TempTable, and Performance Schema. Do not run it until the M3 refactoring is complete.

## Docker design

- Ubuntu 24.04 multi-stage build;
- the builder emits only `mysqld`, `mysql`, `mysqladmin`, `mysql_tzinfo_to_sql`, and the startup-required `component_reference_cache.so`;
- the runtime stage contains no source tree, CMake build tree, test components, or Docker builder;
- `tzdata` and ICU regular-expression data are included;
- only the classic MySQL protocol on port `3306` is exposed; MySQL X Plugin is disabled;
- `/etc/mysql/conf.d`, `/etc/mysql/mysql.conf.d`, and `mysqld` command-line options remain available.

## Validation

Basic checks:

```bash
bash -n docker/*.sh scripts/*.sh
git diff --check
```

After startup, verify:

```sql
SHOW ENGINES;
SHOW DATABASES;
CREATE TABLE t_innodb (id INT) ENGINE=InnoDB;
```

InnoDB table creation should succeed. User-table creation with MyISAM, CSV, or MRG_MYISAM should fail. A fresh container should also load timezone tables and pass the healthcheck.

## Source version

The current source version is MySQL 8.4.11. Its archive SHA-256 is stored in [SOURCE.sha256](SOURCE.sha256). When changing versions, update the source URL, checksum, patches, and documentation together.
