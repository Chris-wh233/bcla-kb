# Loongnix 运行镜像适配

Dockerfile 是来源任务接受的精确文件，未从对话重建。原始 docker-library/mysql 文件在 upstream/Dockerfile.oracle，差异在 patches/dockerfile.patch；官方入口脚本保持相同字节。

最终 FROM 为 runtime-base.json 中的 Loongnix Server23.3 固定摘要。以本次原生构建的六个 RPM 替换 Oracle 外架构仓库安装，使用原生 DNF 及发行版运行库。静态 gosu 是已验证现成资源，未复用任何旧 Debian MySQL 二进制。

基础镜像的 UID/GID999 已被占用，因此使用空闲 mysql UID/GID27。保留上游 socket、conf.d、数据目录权限、初始化、入口脚本和端口逻辑；注释 RPM 的 log-error 文件默认配置，使容器日志走 stderr。MySQL Shell 为独立项目，不包含；Router 不进入最终镜像。

源码与 RPM 适配完整保存在 dependencies/mysql-server-8.4.0/，其 patches/loongarch.patch 只包含源码变化；Dockerfile 差异和 SPEC 差异独立保存。
