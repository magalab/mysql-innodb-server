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
