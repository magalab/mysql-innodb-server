# MySQL 8.4.11 InnoDB-only patch repository

这个仓库只保存把 MySQL 8.4.11 源码裁剪成 InnoDB-only Server 所需的补丁、脚本和验证说明，不保存完整 MySQL 源码。

## 当前状态

当前已包含 M1 和 M2 补丁：移除 NDB information schema 在 Server 核心中的无条件集成，并清理 CSV、MyISAM、MRG_MYISAM 的 Server 核心依赖。补丁还修正了 InnoDB 作为默认引擎后的启动早期初始化、help/validate 预检路径，以及无 CSV 时 general/slow log 系统表的初始化。M2 已在 Apple Silicon 环境成功构建 `mysqld` 目标，并通过内置插件清单检查。它还不会让最终 Server 变成严格意义上的 InnoDB-only：HEAP、TempTable 和 Performance Schema 仍是内部路径的一部分。

后续补丁按以下顺序增加：

1. 删除可选引擎和组件：NDB、Archive、Blackhole、Federated 等；
2. 删除 CSV；
3. 删除 MyISAM 和 MRG_MYISAM，并把启动默认引擎改为 InnoDB；（已完成）
4. 视最终兼容性要求，重构并删除 HEAP、TempTable、Performance Schema；
5. 清理工具、安装包和测试。

## 使用方式

`SOURCE_DIR` 必须是干净的 MySQL 8.4.11 源码副本。建议保留一个永不修改的 pristine 副本，再使用另一个 work 副本。

```bash
PATCH_REPO=/path/to/innodb-only-patches
SOURCE_DIR=/path/to/mysql-8.4.11-work
BUILD_DIR=/private/tmp/mysql-8.4.11-innodb-build

"$PATCH_REPO/scripts/apply-patches.sh" "$SOURCE_DIR"
CONFIRM_PRUNE=yes "$PATCH_REPO/scripts/prune-source.sh" optional "$SOURCE_DIR"
CONFIRM_PRUNE=yes "$PATCH_REPO/scripts/prune-source.sh" user "$SOURCE_DIR"
"$PATCH_REPO/scripts/build.sh" "$SOURCE_DIR" "$BUILD_DIR"
"$PATCH_REPO/scripts/verify.sh" "$SOURCE_DIR" "$BUILD_DIR"
```

`prune-source.sh` 只删除脚本中列出的明确目录。当前 M2 回放后可以执行 `optional` 和 `user`；`strict` 阶段在对应补丁完成前禁止执行。

## Docker 镜像

`Dockerfile` 位于本仓库中，Docker build context 只需要这个补丁仓库。builder 阶段从 MySQL 官方源码下载地址取得 `mysql-8.4.11.tar.gz`，校验 SHA-256 后应用补丁、删除可选引擎和用户层 MyISAM/CSV/MRG_MYISAM 源码，再编译 `mysqld`、`mysql`、`mysqladmin` 和 `mysql_tzinfo_to_sql`。runtime 阶段只复制这些程序、运行时库、字符集/错误消息资源、入口脚本和配置，不复制源码、编译目录、测试组件或 Docker builder。

```bash
cd /path/to/innodb-only-patches
docker build --progress=plain \
  --build-arg CMAKE_BUILD_PARALLEL_LEVEL=2 \
  -t mysql-innodb-only:8.4.11 .

docker run -d --name mysql-innodb-only \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -p 3306:3306 \
  -v mysql-innodb-only-data:/var/lib/mysql \
  mysql-innodb-only:8.4.11
```

入口脚本兼容官方镜像常用的 `MYSQL_ROOT_PASSWORD[_FILE]`、`MYSQL_DATABASE`、`MYSQL_USER`、`MYSQL_PASSWORD[_FILE]`、`MYSQL_ALLOW_EMPTY_PASSWORD`、`MYSQL_RANDOM_ROOT_PASSWORD` 和 `/docker-entrypoint-initdb.d` 初始化文件约定；支持 `.sh`、`.sql`、`.sql.bz2`、`.sql.gz`、`.sql.xz`、`.sql.zst`。MySQL X Plugin 被关闭，因此镜像只暴露经典协议端口 `3306`。

当前 Dockerfile 对应 M2 状态：用户可创建表的持久化存储引擎目标是 InnoDB，但 HEAP、TempTable 和 Performance Schema 仍是 Server 内部路径，尚未达到“`SHOW ENGINES` 只剩 InnoDB”的严格 M3 目标。构建产物不能在严格目标完成前宣称为完全严格的 InnoDB-only Server。

## 源码版本

构建前应记录 MySQL 8.4.11 源码压缩包的 SHA-256：

```bash
shasum -a 256 mysql-8.4.11.tar.gz > SOURCE.sha256
```

`SOURCE.sha256` 应随版本变更提交到本仓库。
