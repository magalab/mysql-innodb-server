# MySQL InnoDB Server implementation

| 中文 | [English](../README.en.md) |
| --- | --- |

## Project status

本项目目标已完成：在保留 MySQL 正常运行所需内部能力的前提下，用户表的持久化存储引擎仅为 InnoDB。

`MEMORY`、`TempTable` 和 `PERFORMANCE_SCHEMA` 仍然保留。它们分别服务于内存表/临时表路径和性能监控，不是用户表的持久化存储引擎。因而 `SHOW ENGINES` 显示这些组件是正常运行 Server 的预期结果。

## Implemented changes

- Git 仓库只保存补丁、源码裁剪脚本、Dockerfile 和验证文档，不保存完整 MySQL 源码；
- 移除 NDB、Archive、Blackhole、Federated、Example 和 mock engine 等不需要的源码目录；
- 移除 CSV、MyISAM、MRG_MYISAM 及其 Server 核心依赖、SQL 残留和专属全文检索状态；
- 将默认用户表引擎设置为 InnoDB，并保留正常启动所需的 HEAP、TempTable 和 Performance Schema 路径；
- 将 general/slow log 系统表从 CSV 改为 InnoDB，支持全新 datadir 初始化；
- 保留 InnoDB、TLS、ICU 正则表达式数据、时区表导入和 Docker 健康检查等正常服务能力。

## Patch and source layout

补丁按文件名的字典序应用。每个补丁都基于干净的 MySQL 8.4.11 源码：

1. `0001-remove-ndbinfo-server-integration.patch`
2. `0002-remove-myisam-core-and-key-cache.patch`
3. `0003-remove-myisam-only-sql-surfaces.patch`
4. `0004-remove-myisam-fulltext-state.patch`
5. `0005-guard-innodb-pfs-during-help.patch`
6. `0006-use-innodb-for-system-log-tables.patch`

目录删除不放进 diff 补丁，而由 `scripts/prune-source.sh` 执行，以避免把被删除源码内容重复存储在 Git 中。Docker 和可运行的源码构建使用 `optional`、`user` 两个裁剪级别；脚本保留的 `strict` 级别仅用于实验性裁剪，不属于当前可运行 Server 构建路径。

## Docker packaging

`../Dockerfile` 使用 Ubuntu 24.04 多阶段构建：builder 下载并校验 MySQL 8.4.11 源码，回放本仓库补丁并执行源码裁剪；runtime 只复制 `mysqld`、初始化需要的客户端、运行时库、字符集/错误消息资源和 Docker 入口文件。

镜像复用了官方镜像的初始化变量和 `/docker-entrypoint-initdb.d` 约定，同时保持 Ubuntu 风格的 `/etc/mysql/my.cnf` 与 `conf.d` 配置目录。默认创建 `root@'%'`，便于 GUI 和其他容器通过 TCP 连接；使用空密码时应避免将端口暴露到不可信网络。

## Validation

已验证以下行为：

- 应用 `0001`—`0006`、执行 `optional` 和 `user` 裁剪后，CMake 配置和 `mysqld` 目标构建成功；
- builtin plugin list 不包含 MyISAM、CSV、MRG_MYISAM 或 NDB；
- 全新容器可以初始化 datadir、导入时区表、通过 healthcheck 并正常启动；
- `SHOW ENGINES` 显示 InnoDB、MEMORY 和 PERFORMANCE_SCHEMA；
- InnoDB 用户表可以完成 DDL/DML，MyISAM、CSV、MRG_MYISAM 用户表创建会被拒绝；
- 其他容器可以通过 TCP 连接到 `root@%`。

## Source version

当前源码版本为 MySQL 8.4.11。源码归档 SHA-256 保存在 [SOURCE.sha256](../SOURCE.sha256) 中；版本变更时应同步更新源码 URL、校验值、补丁和文档。
