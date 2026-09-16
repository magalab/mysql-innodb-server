# Patch order

补丁按文件名的字典序应用。每个补丁都应基于干净的 MySQL 8.4.11 源码，并在应用后执行一次 CMake 配置验证。

目录删除不放进 diff 补丁，以免把被删除源码内容重复存储在 Git 中；目录删除由 `scripts/prune-source.sh` 按阶段执行。
