# RocketMQ Alpine 适配

官方容器模板：apache/rocketmq-docker@56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16 的 image-build/Dockerfile-alpine；原文件 SHA-256 为 b3d7904720234eea5e856a35cd6ac1afc5f41d2661e6e132b65b65b3bdfee939。

接受的 Dockerfile-alpine 保留上游两阶段结构、用户、启动脚本、端口和安装目录。两个 FROM 指向已验证使用 JDK 8 Server VM 的基础镜像别名；builder 从构建上下文读取经 SHA-512 校验的 RocketMQ 4.8.0 ZIP、发布签名及 Apache KEYS，并保留 GPG 验证。

所有构建适配均在单独保存的 Dockerfile 内；RocketMQ 源码和上游运行脚本没有适配改动，因此不另外生成重复的源码补丁。base-evidence 只保存基础镜像补充构建的准确文件，不作为 RocketMQ 构建的主要流程。

复用时确保基础镜像使用 JDK Server VM；否则先构建符合要求的基础镜像。
