# RocketMQ 4.8.0 Debian / LoongArch64

最终目标为 `apache/rocketmq:4.8.0-debian`。复用 RocketMQ 4.8.0 上游二进制发行包，在本地完成三个原生依赖 JAR 的替换并重新打包，然后用官方容器模板派生的 Dockerfile 构建镜像。RocketMQ 本体无需源码编译。

项目版本为 `release-4.8.0`，源码 commit 为 `39bb9386f10d5d8dfe81183c172a3a86f6d313bd`。容器模板为 [apache/rocketmq-docker](https://github.com/apache/rocketmq-docker/tree/56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16/image-build)，commit `56bebfc4a6a3555e4fb1bdab9d8979eaa4d39c16` 的 `Dockerfile-ubuntu`；最终文件为本目录的 `Dockerfile-debian`。官方三个启动脚本按原字节保存在 `scripts/`。

两个构建阶段均使用 `lcr.loongnix.cn/library/eclipse-temurin:8-jdk-forky`。验证时摘要为 `sha256:70edd7f83966f2d9bc188f1f3239993efb4a1703fc453ee6da37f94db55244a8`，提供 Debian forky/sid、glibc、JDK 8u492 和 OpenJDK 64-Bit Server VM。基础镜像需提供 JDK 8 Server VM，本次直接使用该已验证镜像。

**准备二进制 ZIP。** 在有 LoongArch64 Docker daemon 访问权限的辅助环境中执行。将本经验目录复制到工作区，设置变量；工作区在宿主机和辅助容器中的绝对路径应一致。

```sh
export WORK_DIR=/absolute/path/to/rocketmq-work
export RECIPE_DIR="$WORK_DIR/recipe"
export ARTIFACT_DIR="$WORK_DIR/rocketmq-docker/image-build/artifacts"
export BUILD_CONTEXT="$WORK_DIR/build-context"
mkdir -p "$ARTIFACT_DIR/native"
cp "$RECIPE_DIR/native-provenance.json" "$ARTIFACT_DIR/native/provenance.json"
```

从 [Apache 归档](https://archive.apache.org/dist/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip)或本次实际使用的 [华为云镜像](https://repo.huaweicloud.com/apache/rocketmq/4.8.0/rocketmq-all-4.8.0-bin-release.zip)取得原包，保存为 `$ARTIFACT_DIR/rocketmq.zip`。其 SHA256 为 `56bce195af3843a234f77e4248657d0f72d5da0f7f44923bd820762e7d35c548`。

从 Loongnix Maven 仓库取得以下三个 JAR，按下载文件原名放到 `$ARTIFACT_DIR/native/`。表内哈希用于识别本次已验证的准备输入。

| Maven 坐标 | 获取地址 | SHA256 |
| --- | --- | --- |
| `io.netty:netty-all:4.0.56.Final` | [下载 JAR](https://maven.loongnix.cn/loongarch/maven/io/netty/netty-all/4.0.56.Final/netty-all-4.0.56.Final.jar) | `5b0778b89f3e48837ac17ae7bca6dc69a63f30a172473fa007db097fb6509536` |
| `io.netty:netty-tcnative-boringssl-static:2.0.7.Final` | [下载 JAR](https://maven.loongnix.cn/loongarch/maven/io/netty/netty-tcnative-boringssl-static/2.0.7.Final/netty-tcnative-boringssl-static-2.0.7.Final.jar) | `ca9ac670d92b699792f5498562b0ade1cded5a629cd8f7cc069ef5b3d2e0188c` |
| `net.java.dev.jna:jna:4.2.2` | [下载 JAR](https://maven.loongnix.cn/loongarch/maven/net/java/dev/jna/jna/4.2.2/jna-4.2.2.jar) | `d41e251fff61b2bcd23e59abef30e13517c931e17587ea9b7865abaa32266218` |

Netty 与 tcnative 使用上述已验证的配对。JNA 版本保持 4.2.2，使用其中包含 LoongArch 原生库的构建。执行记录中实际采用的重打包算法已提取为 `prepare-zip.py`；该脚本保留 ZIP 目录结构、文件权限和时间戳，并检查其余文件内容。

```sh
cd "$WORK_DIR"
docker run --rm --network none -i -v "$PWD:$PWD" -w "$PWD" \
  --entrypoint python3 lcr.loongnix.cn/library/python:3.12-slim \
  - < "$RECIPE_DIR/prepare-zip.py"
```

输出为 `$ARTIFACT_DIR/rocketmq-all-4.8.0-bin-release-loongarch64.zip`，是镜像构建必需的独立二进制产物。它包含 34 个 JAR，恰好三个替换，另 87 个普通文件及条目权限、时间戳保持一致；ZIP 共 100 个条目，CRC 检查通过。本次文件大小为 12,204,062 字节，SHA256 为 `4850543dd1e378fbb061d88d3a8bbdda42b5fa7ff84b350eea6e0ae1a956d00e`。完整来源和替换映射见 `prepared-artifact.json`。

知识库保存准备方法和产物身份，ZIP 二进制另行提供。已有这一预处理 ZIP 时，可直接将它作为制作镜像或扁平项目的输入。

**构建最终镜像。** 构建上下文由预处理 ZIP、最终 Dockerfile 和官方启动脚本组成。以下流程与成功构建采用的最小上下文一致。

```sh
mkdir -p "$BUILD_CONTEXT/artifacts"
cp "$RECIPE_DIR/Dockerfile-debian" "$BUILD_CONTEXT/Dockerfile-debian"
cp -a "$RECIPE_DIR/scripts" "$BUILD_CONTEXT/"
cp "$ARTIFACT_DIR/rocketmq-all-4.8.0-bin-release-loongarch64.zip" "$BUILD_CONTEXT/artifacts/"
cd "$BUILD_CONTEXT"
docker build --pull=false --network=host --platform=linux/loong64 \
  --build-arg version=4.8.0 -f Dockerfile-debian \
  -t apache/rocketmq:4.8.0-debian .
```

Dockerfile 的 builder 阶段安装 unzip，COPY 本地 ZIP 并解压；运行阶段沿用官方用户 UID 3000、端口和启动脚本。依赖准备已在 ZIP 产物阶段完成。最终 Dockerfile 按任务约定只消费该 ZIP，不执行哈希或签名校验。

**验证最终镜像。** `tests/` 保存最终通过的原生库、TLS、消息收发检查及配置。测试脚本的目录和容器名称已归一化；测试逻辑与成功执行记录一致。

```sh
mkdir -p "$WORK_DIR/smoke" "$WORK_DIR/verification"
cp "$RECIPE_DIR/tests/"*.java "$WORK_DIR/smoke/"
cp "$RECIPE_DIR/tests/"*.properties "$WORK_DIR/smoke/"
cp "$RECIPE_DIR/tests/native-image-tests.sh" "$WORK_DIR/smoke/"
cp "$RECIPE_DIR/tests/run-broker-tests.sh" "$WORK_DIR/verification/"
cd "$WORK_DIR"
docker run --rm --network none \
  --hostname rocketmq-native --add-host rocketmq-native:127.0.0.1 \
  -v "$PWD/smoke:/smoke:ro" \
  -v "$ARTIFACT_DIR/rocketmq.zip:/original.zip:ro" \
  apache/rocketmq:4.8.0-debian sh /smoke/native-image-tests.sh
sh verification/run-broker-tests.sh
```

最终已验证的镜像 ID 为 `sha256:31374b062fc36961b2b9d34e0a8e3bed29b9d2e6794a1aa976cbd88deaf756db`，平台 `linux/loong64`。验证结果包括：

- 34 个 JAR 的文件集合和内容身份正确，31 个保持上游原样；三个原生组件均包含 LoongArch ELF。
- 默认用户 UID 3000 下，JNA 的 mlock、madvise、munlock 返回 0，原生 epoll 成功绑定端口，BoringSSL 可用。
- RocketMQ 使用 EpollEventLoopGroup 和 OpenSslServerContext，连续 10 次 TLS 请求往返通过。
- 官方 NameServer、Broker 启动成功，集群版本 V4_8_0，生产者 SEND_OK，消费者读回完全相同的消息。
- 开启文件预热、临时存储池后，commitlog 的 mlock、madvise 返回 0；JDK 的 G1/CMS 可用，基础镜像层继承关系正确。

本次未进行完整回归、长时间压力测试或镜像发布，没有功能省略。执行 ID 仅标识本地任务证据；可复用命令和输入地址均已在此给出。
