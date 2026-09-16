# MySQL InnoDB Server

| 中文 | [English](README.en.md) |
| --- | --- |

这是一个面向 MySQL 8.4.11 的小型补丁仓库。它不保存 MySQL 完整源码，而是保存补丁、源码裁剪脚本、Dockerfile 和验证说明，用于构建一个“用户表仅使用 InnoDB 持久化存储”的 MySQL Server。

## 当前状态

当前实现已经完成用户可见存储引擎清理：

- InnoDB 是唯一保留的用户表持久化存储引擎；
- MyISAM、MRG_MYISAM、CSV、Archive、Blackhole、Federated、NDB 等不再作为可用用户表引擎；
- `PERFORMANCE_SCHEMA` 和 `MEMORY` 仍保留，它们分别用于性能监控和内存/临时表路径；
- `SHOW ENGINES` 仍会显示 `PERFORMANCE_SCHEMA`、`InnoDB` 和 `MEMORY`，这是当前“正常可运行 Server”目标的预期结果；
- Docker 镜像包含启动所需的动态组件、ICU 数据、时区数据、TLS、初始化脚本和健康检查。

本项目目标已完成：在保留 MySQL 正常运行所需的 `MEMORY`、`TempTable` 和 `PERFORMANCE_SCHEMA` 能力的前提下，用户表的持久化存储引擎仅为 InnoDB。它们是服务运行路径中的内部依赖，不属于用户表的持久化引擎。

## 快速开始

### 构建镜像

构建上下文只需要本仓库。Docker builder 会从 MySQL 官方地址下载源码，校验 SHA-256，应用补丁并删除列出的源码目录。

```bash
cd /path/to/mysql-innodb-server
docker build --progress=plain \
  --build-arg CMAKE_BUILD_PARALLEL_LEVEL=4 \
  -t mysql-innodb-server:8.4.11 .
```

### 启动服务

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  mysql-innodb-server:8.4.11
```

默认会创建 `root@'%'`，因此 GUI 和其他容器可以通过 TCP 连接。初始化完成后可使用：

```text
Host: 127.0.0.1
Port: 3306
User: root
Password: change-me
```

### 开发环境空密码

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  mysql-innodb-server:8.4.11
```

`MYSQL_ALLOW_EMPTY_PASSWORD=yes` 与默认远程 root 账户组合时，使用者需要自行承担网络暴露风险。

## 初始化环境变量

以下变量只在 `/var/lib/mysql` 尚未初始化时生效：

| 变量 | 作用 |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` / `MYSQL_ROOT_PASSWORD_FILE` | 设置 root 密码；与空密码、随机密码三选一 |
| `MYSQL_ROOT_HOST` / `MYSQL_ROOT_HOST_FILE` | root 账户 Host，默认 `%`，可设置为 `192.168.215.%` 等 IP 模式 |
| `MYSQL_DATABASE` | 自动创建数据库 |
| `MYSQL_USER` | 创建普通用户，Host 为 `%` |
| `MYSQL_PASSWORD` / `MYSQL_PASSWORD_FILE` | 普通用户密码 |
| `MYSQL_ALLOW_EMPTY_PASSWORD=yes` | 允许 root 使用空密码 |
| `MYSQL_RANDOM_ROOT_PASSWORD=yes` | 随机生成 root 密码并写入日志 |
| `MYSQL_ONETIME_PASSWORD=yes` | 初始化后让 root 密码过期 |
| `MYSQL_INITDB_SKIP_TZINFO=yes` | 跳过时区表导入 |

密码、Host、数据库和普通用户变量支持 Docker secrets 风格的 `_FILE` 形式。`MYSQL_USER` 建议与 `MYSQL_PASSWORD`、`MYSQL_DATABASE` 一起使用。

## 初始化文件

把文件挂载到 `/docker-entrypoint-initdb.d`，只在首次初始化时按文件名字典序处理：

- `.sh`
- `.sql`
- `.sql.bz2`
- `.sql.gz`
- `.sql.xz`
- `.sql.zst`

示例：

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  -v "$(pwd)/initdb:/docker-entrypoint-initdb.d:ro" \
  mysql-innodb-server:8.4.11
```

## 补丁序列

补丁按文件名字典序应用，并且每个补丁都基于干净的 MySQL 8.4.11 源码：

1. `0001-remove-ndbinfo-server-integration.patch`：移除 NDB information schema 的 Server 集成；
2. `0002-remove-myisam-core-and-key-cache.patch`：移除 MyISAM 核心状态和 key cache 路径；
3. `0003-remove-myisam-only-sql-surfaces.patch`：移除 MyISAM/MRG_MYISAM 的 SQL parser 和头文件残留；
4. `0004-remove-myisam-fulltext-state.patch`：移除 MyISAM 专属全文检索状态和变量；
5. `0005-guard-innodb-pfs-during-help.patch`：修复 `--help`/配置预检阶段的 InnoDB PFS 初始化路径；
6. `0006-use-innodb-for-system-log-tables.patch`：将 general/slow log 系统表改为 InnoDB。

源码目录删除不放进 patch，而由 `scripts/prune-source.sh` 执行，以避免把大段被删除源码重复存储到 Git。

## 从源码构建

建议保留一个永不修改的 pristine 源码副本，再使用工作副本回放补丁：

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

Docker 和可运行的源码构建使用 `optional`、`user` 两个裁剪级别。脚本仍保留 `strict` 级别用于实验性裁剪；它会删除 HEAP、TempTable 和 Performance Schema，不属于当前可运行 Server 构建路径。

## Docker 设计

- Ubuntu 24.04 多阶段构建；
- builder 只输出 `mysqld`、`mysql`、`mysqladmin`、`mysql_tzinfo_to_sql` 和启动所需的 `component_reference_cache.so`；
- runtime 不包含源码、CMake 构建目录、测试组件和 Docker builder；
- runtime 安装 `tzdata`，并打包 ICU 正则表达式数据；
- 默认只暴露经典 MySQL 协议端口 `3306`，MySQL X Plugin 已关闭；
- 支持 `/etc/mysql/conf.d`、`/etc/mysql/mysql.conf.d` 和 `mysqld` 命令行参数。

## 验证

基础检查：

```bash
bash -n docker/*.sh scripts/*.sh
git diff --check
```

运行后重点确认：

```sql
SHOW ENGINES;
SHOW DATABASES;
CREATE TABLE t_innodb (id INT) ENGINE=InnoDB;
```

`InnoDB` 建表应成功，MyISAM/CSV/MRG_MYISAM 等用户表建表应失败。全新容器还应能完成时区表初始化并通过 healthcheck。

## 源码版本

当前源码版本为 MySQL 8.4.11。源码归档 SHA-256 保存在 [SOURCE.sha256](SOURCE.sha256) 中；版本变更时应同步更新源码 URL、校验值、补丁和文档。
