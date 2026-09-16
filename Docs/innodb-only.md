# InnoDB-only implementation plan

## Current target

最终目标是一个只允许 InnoDB 作为用户表存储引擎的 MySQL Server。严格意义上，如果 `SHOW ENGINES` 也必须只显示 InnoDB，还需要继续重构内部临时表和 Performance Schema 路径。

## Milestones

### M1: small patch repository and optional cleanup（已完成）

- Git 不保存 MySQL 完整源码；
- 移除 NDB、Archive、Blackhole、Federated、Example 和 mock engine 源码；
- 保留 InnoDB、MyISAM、CSV、HEAP、TempTable、Performance Schema；
- 完成干净 CMake 配置和构建。

### M2: user-facing engine cleanup（已完成并验证 `mysqld` 目标）

- 删除 CSV、MyISAM、MRG_MYISAM；
- 修改启动阶段的默认 handlerton 初始化；
- 移除 `mi_log`、MyISAM key cache 和 MyISAM 专属系统变量；
- 将仍被 SQL 层使用的字节序和检查标志移到通用头文件；
- 移除 MyISAM 专属全文检索全局变量和启动校验；InnoDB FTS 保留其自身配置路径；
- 工具、man page 和安装清单仍待下一轮清理；当前先保证 Server 核心能够脱离这三个引擎源码构建。

验证结果：应用 `0001`—`0006`、执行 `optional` 和 `user` 裁剪后，CMake 配置成功，`mysqld` 目标成功链接；生成的 builtin plugin list 不包含 MyISAM、CSV、MRG_MYISAM 或 NDB。

### M3: strict engine cleanup

- 重构临时表执行器，移除 HEAP/TempTable plugin 依赖；
- 评估移除 Performance Schema 的影响；
- 只保留 InnoDB handlerton；
- 只支持全新的 8.4.11 datadir，放弃旧 MyISAM 系统表升级兼容性。

## Acceptance tests

```sql
CREATE TABLE t_innodb (id INT) ENGINE=InnoDB;
CREATE TABLE t_myisam (id INT) ENGINE=MyISAM;
CREATE TABLE t_memory (id INT) ENGINE=MEMORY;
CREATE TABLE t_csv (id INT) ENGINE=CSV;
```

最终只有第一条应成功。还需要验证全新 datadir 初始化、启动、InnoDB DDL/DML、崩溃恢复和安装包内容。
