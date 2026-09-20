# MySQL InnoDB Server

| 中文 | [English](README.en.md) |
| --- | --- |

本仓库按 MySQL 上游版本系列维护独立构建目标。每个目标分别保存源码版本和 SHA-256、补丁序列、裁剪/构建/验证脚本、Docker 配置及对应说明，不在仓库中保存完整 MySQL 源码。

## 构建目标

| 上游系列 | 固定源码版本 | 状态 | 目标目录 |
| --- | --- | --- | --- |
| MySQL 8.4 LTS | 8.4.11 | 已实现 | [targets/mysql-8.4](targets/mysql-8.4/README.md) |

各目标都以 InnoDB 作为用户表唯一的持久化存储引擎，同时保留 MySQL 正常运行所需的内部能力。补丁不能跨版本系列直接复用。

## 构建 8.4 镜像

```bash
docker build --progress=plain \
  --file targets/mysql-8.4/Dockerfile \
  --build-arg CMAKE_BUILD_PARALLEL_LEVEL=2 \
  -t ghcr.io/magalab/mysql-innodb-server:8.4.11 \
  targets/mysql-8.4
```

Git tag 的主次版本用于选择目标目录；发布工作流会校验 tag 与该目标中的源码版本一致，再构建 `linux/amd64` 和 `linux/arm64` 镜像。具体构建、启动和补丁信息见对应目标文档。
