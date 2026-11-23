# RocketMQ 4.8.0 Alpine / LoongArch64

本配方复用 apache/rocketmq-docker 官方 Alpine 模板，构建 apache/rocketmq:4.8.0-alpine。RocketMQ release-4.8.0 对应提交 39bb9386f10d5d8dfe81183c172a3a86f6d313bd；容器模板固定为 https://github.com/apache/rocketmq-docker 提交 56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16 的 image-build/Dockerfile-alpine。

## 基础镜像前提

**必须确保 eclipse-temurin:8-jdk-alpine 基础镜像使用 JDK 8 Server VM；若仓库镜像使用 Zero VM，则需要先构建符合要求的基础镜像，再构建 RocketMQ。** 使用时先验证 java.vm.name、javac，以及 G1/CMS 支持。此次实际使用的基础镜像别名为 eclipse-temurin:8-jdk-alpine-loongarch64-server，两个 FROM 阶段均引用此别名。补充构建仅用于纠正仓库镜像的 VM 类型；原样文件和镜像身份保存在 base-evidence 及 experience.json 中供追溯。

## 准备构建上下文

在原生 LoongArch64 Docker 主机上运行，需要 Git、curl、SHA-512 工具，以及可访问 Alpine APK 仓库的构建网络。将 RECIPE_DIR 设置为本配方绝对路径，WORKSPACE 设置为可写的工作目录，BASE_IMAGE 设置为已经验证符合上述前提的基础镜像引用。

    docker run --rm "$BASE_IMAGE" sh -ec 'java -XshowSettings:properties -version 2>&1 | grep -F "java.vm.name = OpenJDK 64-Bit Server VM"; javac -version; java -XX:+UseG1GC -version; java -XX:+UseConcMarkSweepGC -version'
    docker tag "$BASE_IMAGE" eclipse-temurin:8-jdk-alpine-loongarch64-server
    git clone https://github.com/apache/rocketmq-docker.git "$WORKSPACE/rocketmq-docker"
    cd "$WORKSPACE/rocketmq-docker"
    git checkout --detach 56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16
    cp "$RECIPE_DIR/Dockerfile-alpine" image-build/Dockerfile-alpine
    mkdir -p image-build/artifacts
    cd image-build/artifacts
    curl -fSL https://repo.huaweicloud.com/apache/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip -o rocketmq.zip
    curl -fsSL https://archive.apache.org/dist/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip.sha512 -o rocketmq.zip.sha512
    curl -fsSL https://archive.apache.org/dist/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip.asc -o rocketmq.zip.asc
    curl -fsSL https://www.apache.org/dist/rocketmq/KEYS -o KEYS
    expected=$(sed 's/^[^:]*://' rocketmq.zip.sha512 | tr -d ' \r\n' | tr A-F a-f)
    test "${#expected}" -eq 128
    printf '%s  %s\n' "$expected" rocketmq.zip | sha512sum -c

RocketMQ 发布包为 Apache 官方 4.8.0 二进制分发 ZIP，镜像站提供相同字节；也可从 https://archive.apache.org/dist/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip 下载。它由 builder 阶段解包，随后复制到最终镜像，无需额外编译 RocketMQ。ZIP 的 SHA-256 为 56bce195af3843a234f77e4248657d0f72d5da0f7f44923bd820762e7d35c548。构建阶段继续使用 Apache KEYS 验证发布签名，此次验证的签名指纹为 EC9F268B4C20590138B11FE701420E4292296EAE。

image-build/scripts/ 保持来自固定提交的上游脚本。ZIP、签名和 KEYS 是 builder 的必要输入；无需将整个 RocketMQ 源码放入构建上下文。

## 构建最终镜像

工作目录为容器模板仓库的 image-build/：

    cd "$WORKSPACE/rocketmq-docker/image-build"
    docker build --pull=false --network=host --platform=linux/loong64 --build-arg version=4.8.0 -f Dockerfile-alpine -t apache/rocketmq:4.8.0-alpine .

命令保留成功构建的版本、上下文、平台和网络模式；执行环境临时代理参数未写入配方。最终镜像使用上游 rocketmq 用户、启动入口、9876/10909/10911/10912 端口和运行脚本。builder 只是内部构建阶段。

## 运行与验证

测试使用独立网络、NameServer 和 Broker，并通过 HEAP_OPTS 缩小测试内存；不修改镜像默认内存配置：

    docker network create rocketmq-smoke
    docker run -d --name rocketmq-namesrv --network rocketmq-smoke -e HEAP_OPTS='-Xms128m -Xmx128m -Xmn64m' apache/rocketmq:4.8.0-alpine nameserver
    docker run -d --name rocketmq-broker --network rocketmq-smoke -e HEAP_OPTS='-Xms256m -Xmx256m -Xmn128m -XX:MaxDirectMemorySize=128m' apache/rocketmq:4.8.0-alpine broker -n rocketmq-namesrv:9876 autoCreateTopicEnable=true

等待两个容器日志出现 boot success 后，使用配方中的原始测试客户端验证实际收发：

    mkdir -p "$WORKSPACE/smoke"
    cp "$RECIPE_DIR/MessageSmoke.java" "$WORKSPACE/smoke/"
    docker run --rm --network rocketmq-smoke -v "$WORKSPACE/smoke:/smoke:ro" apache/rocketmq:4.8.0-alpine sh -ec 'mkdir -p /tmp/smoke; javac -cp "$ROCKETMQ_HOME/lib/*" -d /tmp/smoke /smoke/MessageSmoke.java; java -Xms64m -Xmx128m -cp "/tmp/smoke:$ROCKETMQ_HOME/lib/*" MessageSmoke rocketmq-namesrv:9876'
    docker exec rocketmq-broker sh -c './mqadmin clusterList -n rocketmq-namesrv:9876'

任务已验证 NameServer/Broker 启动、SEND_OK、发送内容读取一致、集群版本 V4_8_0。基础镜像和最终镜像均为 linux/loong64、使用 OpenJDK 8u472 Server VM，且无代理环境变量；最终镜像继承基础镜像层也已校验。最终镜像 ID 为 sha256:6c105fa50d60b56acc9100666e99eb65ac7e64c7ca01374249fbce2c294acc35。测试容器和网络已移除，镜像仅保存在本地，未推送。只构建并验证 Alpine 变体。

来源任务：bcla-602a4b92a1bc4c169b538429d2a68d61，证据修订号 5。
