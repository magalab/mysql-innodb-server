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

## 运行 8.4 镜像

常见启动方式。完整的环境变量清单、初始化脚本语义和补丁序列见 [targets/mysql-8.4](targets/mysql-8.4/README.md)。

### 指定 root 密码

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ROOT_PASSWORD='change-me' \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

默认会创建 `root@'%'`，因此 GUI 客户端和其他容器可直接通过 TCP 连接。客户端配置：`127.0.0.1:3306`，用户 `root`，密码即所设值。

### 空密码（仅限开发环境）

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

> ⚠️ 与默认的远程 root 账户组合时，使用者需要自行承担网络暴露风险。生产环境请改用指定密码或限制网络访问。

### 随机 root 密码

```bash
docker run -d --name mysql-innodb-server \
  -p 3306:3306 \
  -e MYSQL_RANDOM_ROOT_PASSWORD=yes \
  -v mysql-innodb-server-data:/var/lib/mysql \
  ghcr.io/magalab/mysql-innodb-server:8.4.11
```

密码由容器随机生成并写入容器日志（`docker logs mysql-innodb-server`）。

### 同时创建数据库和普通用户

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

`MYSQL_ROOT_PASSWORD` / `MYSQL_ALLOW_EMPTY_PASSWORD=yes` / `MYSQL_RANDOM_ROOT_PASSWORD=yes` 三者必须且只能选一个，未设置任何一个会导致首次启动失败。

## 常用环境变量速查

| 变量 | 说明 |
| --- | --- |
| `MYSQL_ROOT_PASSWORD` | 设置 root 密码（与空密码、随机密码三选一） |
| `MYSQL_ALLOW_EMPTY_PASSWORD=yes` | 允许 root 使用空密码 |
| `MYSQL_RANDOM_ROOT_PASSWORD=yes` | 随机生成 root 密码并写入容器日志 |
| `MYSQL_DATABASE` | 初始化时自动创建数据库 |
| `MYSQL_USER` / `MYSQL_PASSWORD` | 初始化时创建普通用户（Host 为 `%`） |
| `MYSQL_ROOT_HOST` | root 远程登录 Host 模式，默认 `%` |

所有这些变量都支持 Docker secrets 风格的 `*_FILE` 后缀形式（如 `MYSQL_ROOT_PASSWORD_FILE`），适合通过挂载文件注入凭据，详见目标文档。

## 健康检查

镜像内置 healthcheck，可用以下命令查看容器健康状态：

```bash
docker inspect --format '{{.State.Health.Status}}' mysql-innodb-server
```

状态为 `healthy` 时表示 mysqld 已准备好接受连接。
