# MySQL 8.4.11 InnoDB-only patch repository

这个仓库只保存把 MySQL 8.4.11 源码裁剪成 InnoDB-only Server 所需的补丁、脚本和验证说明，不保存完整 MySQL 源码。

## 当前状态

当前已包含 M1 和 M2 补丁：移除 NDB information schema 在 Server 核心中的无条件集成，并清理 CSV、MyISAM、MRG_MYISAM 的 Server 核心依赖。它还不会让最终 Server 变成严格意义上的 InnoDB-only：HEAP、TempTable 和 Performance Schema 仍是内部路径的一部分。

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
"$PATCH_REPO/scripts/build.sh" "$SOURCE_DIR" "$BUILD_DIR"
"$PATCH_REPO/scripts/verify.sh" "$SOURCE_DIR" "$BUILD_DIR"
```

`prune-source.sh` 只删除脚本中列出的明确目录。当前 M2 回放后可以执行 `optional` 和 `user`；`strict` 阶段在对应补丁完成前禁止执行。

## 源码版本

构建前应记录 MySQL 8.4.11 源码压缩包的 SHA-256：

```bash
shasum -a 256 mysql-8.4.11.tar.gz > SOURCE.sha256
```

`SOURCE.sha256` 应随版本变更提交到本仓库。
