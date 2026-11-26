# RocketMQ 4.8.0 LoongArch 适配

应用范围为 RocketMQ `release-4.8.0` 的 Debian 容器镜像。项目源码基线为 `39bb9386f10d5d8dfe81183c172a3a86f6d313bd`；容器模板来自 `apache/rocketmq-docker` 的 `56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16`，路径为 `image-build/Dockerfile-ubuntu`。

上游二进制 ZIP 可以复用。镜像构建前，将其中 JNA、Netty 和 tcnative 的 JAR 替换为已验证的 Loongnix Maven 产物，再生成独立的 LoongArch ZIP。替换映射、获取地址、内容身份及完整性检查见 `prepared-artifact.json`；实际采用的重打包算法见 `prepare-zip.py`。

两个镜像阶段均使用 `lcr.loongnix.cn/library/eclipse-temurin:8-jdk-forky`。构建阶段安装 unzip，复制并解压预处理 ZIP；运行阶段沿用官方用户、启动脚本、端口和目录布局。Dockerfile 不进行依赖准备或 ZIP 校验。Dockerfile 本身就是保留的适配文件，原始模板单独存放于 `upstream/Dockerfile-ubuntu`。

Netty `4.0.56.Final` 与 tcnative `2.0.7.Final` 成对使用；JNA 保持 `4.2.2` 并使用 LoongArch 构建。三个原生库均有 LoongArch ELF，并已在最终镜像的默认用户 UID 3000 下通过原生调用和实际业务验证。没有 RocketMQ 源码改动，也没有源码构建的依赖。
