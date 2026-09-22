# bcla-kb

LoongArch64 BCLA 构建经验知识库

## 用途

本仓库保存已经实际构建并通过基础验证的 LoongArch64 容器镜像经验。每一项经验都是一个可复用的 Build Recipe，用来帮助后续任务减少源码分析、依赖检索和构建路径推导。

知识库只保存最终有效方案，不保存失败尝试、被撤销的补丁、无效命令或没有参与最终构建的临时资源。知识库是加速构建的参考，不能替代当前任务中的实际检查，也不能覆盖用户当前的版本、目标镜像、基础镜像和功能要求。

经验由 BCLA 任务成功后，在用户明确调用 `gen-experience` 时生成。默认写入本地知识库 `main` 分支，不会在构建成功后自动生成或自动推送。

## 目录结构

项目按代码托管来源、组织、仓库和版本组织。GitHub 项目通常使用以下形式：

```text
bcla-kb/
├── index.json
└── <owner>/
    └── <repository>/
        ├── index.json
        └── <version>/
            ├── experience.json
            ├── README.md
            ├── Dockerfile[.<target>]
            ├── adaptation.md
            ├── patches/
            │   └── loongarch.patch
            └── dependencies/
                └── <dependency>-<version>/
                    ├── experience.json
                    ├── README.md
                    ├── Dockerfile[.<target>]
                    └── patches/
```

例如，EMQX 6.3.0 的经验位于：

```text
emqx/emqx/6.3.0/
```

这里的目录名来自规范化后的仓库身份和请求版本，不代表所有项目都使用相同的文件集合。没有源码适配时，不应创建空的 `adaptation.md` 或补丁文件；没有源码构建依赖时，也不应创建 `dependencies/`。

对于非 GitHub 来源，目录需要包含主机名以避免不同代码托管服务发生同名冲突，例如：

```text
<host>/<owner>/<repository>/<version>/
```

不要为每个构建任务创建独立 Git 分支，也不要同时保存一份按主机名开头、另一份按组织开头的重复经验。不同项目和版本通过目录区分，统一提交到知识库 `main` 分支。

## 根目录索引

`index.json` 是由经验目录生成的快速检索索引。它通常记录经验对应的项目目录和仓库地址，例如：

```json
{
  "schema_version": 2,
  "projects": [
    {
      "path": "emqx/emqx",
      "repository": "https://github.com/emqx/emqx"
    }
  ]
}
```

索引不是唯一可信来源。索引可能过期、缺少条目或与目录暂时不一致；读取经验时应以实际目录中的 `experience.json` 为准。索引可以使用 BCLA 提供的 `kb_index.py` 重建或检查。

## 项目索引

每个项目目录可以有自己的 `index.json`，用于快速列出该项目可用的版本和目标。例如：

```json
{
  "schema_version": 2,
  "project": "emqx",
  "repository": "https://github.com/emqx/emqx",
  "experiences": [
    {
      "version": "6.3.0",
      "path": "6.3.0",
      "status": "verified",
      "targets": ["debian-14-slim"]
    }
  ]
}
```

项目索引同样只是检索辅助。版本目录缺失、索引过期或索引内容不完整时，应扫描版本目录并检查其中的 `experience.json`。

## 版本经验目录

### `experience.json`

这是一项经验的机器可读 Source of Truth。它描述：

- 项目仓库、请求版本和实际解析到的提交；
- 构建目标和验证状态；
- 实际使用的构建命令、环境、构建参数和执行证据；
- 最终镜像 ID、架构、Dockerfile 以及基础镜像来源；
- 参与构建的第三方依赖及其来源、版本、架构和消费者；
- 适用条件、必需文件、构建入口和运行时约束；
- 最终测试、接受文件和来源信息。

以 EMQX 6.3.0 为例，`experience.json` 会记录 `linux/loong64`、Debian 14 slim、最终镜像 ID、官方 Dockerfile 提交，以及 LoongArch64 EMQX 发行包的来源和校验信息。它还会记录最终构建实际传入的 `BUILD_FROM` 和 `RUN_FROM`，因此不能只根据 Dockerfile 的默认参数判断经验使用的基础镜像。

经验中的命令和补丁只代表历史上经过验证的方案。复用时仍需检查当前项目版本、文件、镜像架构、ABI、基础镜像和目标需求。

### `README.md`

这是面向模型和人工审阅的构建说明，解释机器字段难以表达的使用方式。通常包括：

1. 必须准备的关键产物、版本、服务对象和获取方式；
2. 项目自身二进制或发行包的实际构建流程；
3. 最终容器镜像构建流程；
4. 必要的环境变量、构建参数、执行目录和验证命令；
5. 最终镜像的架构、运行方式、测试结果和已知限制。

例如，EMQX 经验会说明应先取得 LoongArch64 发行包，再将它交给官方 Dockerfile 的 `tgz` 路径，并明确写出实际构建时使用的 LCR Debian 14 镜像参数。README 中的命令必须来自最终成功方案，不应包含已经失败或被替换的尝试。

### `Dockerfile` 文件

版本目录中的 Dockerfile 是最终成功构建所使用的精确文件。一个任务包含多个目标时，可以分别保存为：

```text
Dockerfile.hub
Dockerfile.agent
```

文件名应在 `experience.json` 中明确关联到目标镜像。Dockerfile 可以是官方 Dockerfile 的 LoongArch64 适配版本，但必须能追溯到官方或用户提供的源文件。知识库不应保存模型凭空推测的 Dockerfile。

### `adaptation.md`

当项目源代码或项目构建逻辑需要 LoongArch64 适配时，使用这个文件说明保留下来的适配内容、原因和影响。它适合记录架构识别、平台映射、构建脚本或可选组件调整等人工判断。

如果只替换了外部发行包、基础镜像或辅助依赖，项目本身无需修改，则不创建这个文件。

### `patches/loongarch.patch`

这里保存最终成功方案中保留的 upstream tracked file 修改，便于在同一源码版本上复现。内容可以覆盖源代码、构建文件、脚本、架构映射和项目 Dockerfile 的修改；构建生成目录、缓存、日志以及无关的 lockfile 变化不应加入。

EMQX 6.3.0 的补丁只记录 Dockerfile 为 LoongArch64 增加静态 curl 选择和相关处理的修改。若任务没有保留的源码或构建逻辑修改，就不创建补丁目录或补丁文件。

Dockerfile 可以单独保存为版本目录文件，不要求把 Dockerfile 的内容重复放进补丁说明。

## 第三方依赖经验

当主项目依赖必须从源码构建的第三方组件时，在 `dependencies/` 下为该组件建立独立经验目录：

```text
dependencies/
├── dependency-a-1.2.3/
├── dependency-b-4.5.6/
└── dependency-c-7.8.9/
```

依赖目录采用平级结构，不把一个依赖嵌套到另一个依赖目录中。依赖之间的关系写在各自的 `experience.json` 中。

只有实际参与最终成功构建的源码依赖才应生成依赖经验。直接从已有 LoongArch 资源获取、没有单独源码构建过程的普通包，不需要生成一份虚假的源码经验。

依赖经验可以拥有与主项目相同的 `experience.json`、`README.md`、Dockerfile、`adaptation.md` 和 `patches/`。主项目的 `experience.json` 应记录它实际消费了哪个依赖版本、来源和产物。

## 经验状态与可信范围

`status: "verified"` 表示该经验在生成时完成了记录中的实际构建和基础测试。它不表示：

- 当前时间仍然可以从网络获得所有未固定版本的依赖；
- 当前 LCR 标签或上游 Release 永远不会变化；
- 经验适用于其它版本、架构、libc、基础镜像或功能组合；
- 经验中的第三方资源可以跳过实际消费者验证。

复用经验时，优先匹配同一仓库和版本，然后检查目标、基础镜像、工具链、必要文件、Dockerfile 入口和依赖兼容性。经验不可用或不适用时，应回到正常源码分析和资源获取，不应因为知识库条目损坏而阻断构建。

## 文件来源和证据

经验只能记录最终成功状态中的事实：

- 构建命令必须实际执行成功；
- Dockerfile、补丁和报告应保存精确内容及 SHA-256；
- 依赖来源、版本、架构、ABI 和消费者应有实际检查证据；
- 镜像应验证 Linux LoongArch64 架构、不可变镜像 ID 或 digest，以及目标要求的启动或 smoke test；
- 临时参与成功构建的配置和补丁，即使之后恢复，也应在恢复前保存复现所需内容。

失败尝试可以保留在 BCLA 任务日志中用于诊断，但不应写入最终经验的干净构建流程。

## 维护方式

通常的生命周期是：

```text
BCLA 任务成功
    ↓
用户显式调用 gen-experience
    ↓
从任务最终结果和执行证据生成版本目录
    ↓
检查 JSON、文件哈希和索引
    ↓
在 main 分支本地提交
    ↓
按用户授权推送
```

生成新经验前，应比较相同项目和版本是否已有条目。相同事实不重复写入；目标互补且不冲突时可以合并；命令、提交、补丁或产物冲突时应保留冲突信息，不应静默覆盖已验证经验。
