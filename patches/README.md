# Patch order

| 中文 | [English](../README.en.md) |
| --- | --- |

补丁按文件名的字典序应用。每个补丁都应基于干净的 MySQL 8.4.11 源码，并在应用后执行一次 CMake 配置验证。

当前补丁序列按语义组织为：

1. `0001-remove-ndbinfo-server-integration.patch`
2. `0002-remove-myisam-core-and-key-cache.patch`
3. `0003-remove-myisam-only-sql-surfaces.patch`
4. `0004-remove-myisam-fulltext-state.patch`
5. `0005-guard-innodb-pfs-during-help.patch`
6. `0006-use-innodb-for-system-log-tables.patch`

目录删除不放进 diff 补丁，以免把被删除源码内容重复存储在 Git 中；目录删除由 `scripts/prune-source.sh` 按裁剪级别执行。

## 升级源码版本

补丁不是跨 MySQL 版本自动兼容的。升级版本时，应先准备新的干净源码副本，更新根目录的 `SOURCE.sha256`，然后使用 `scripts/apply-patches.sh` 逐个检查并应用现有补丁。无法应用或语义发生变化的补丁需要基于新源码重新整理，并重新完成 CMake、构建、`scripts/verify.sh` 和运行时验证。

GitHub Actions 会要求推送的版本 tag（可带 `v` 前缀）与 `SOURCE.sha256` 中的源码版本一致；如果只创建新 tag 而没有更新源码校验或补丁，发布会在构建前失败。
