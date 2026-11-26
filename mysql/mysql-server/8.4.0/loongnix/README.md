# MySQL 8.4.0 / Loongnix Server23.3 / LoongArch64

来源任务 `bcla-d1d59653e8aa4eb38b95667bda3b28d6`，接受证据 revision16。此 schema3 变体仅覆盖 `mysql:8.4.0-loongnix23.3`；已有 Debian 变体保持独立。

## 关键准备产物

- 原生 RPM：mysql-packages.json 中六项，版本8.4.0-1.lns23；从来源任务保留的 artifacts/rpms 包取得，或按照 dependencies/mysql-server-8.4.0/ 的原生 source-RPM 流程重建。源包 URL、签名、内容摘要、最终 SPEC 和适配文件均已保存。二进制 RPM 不存入 Git。
- gosu：gosu.json 指定的静态 LoongArch1.19文件，SHA256 `02a0431eaa5ca337ee728e0d1c32652484365bcf076b03cb39608e0e107ae383`。来自既有已验证镜像的 /usr/sbin/gosu，使用 docker create/docker cp 提取；或由持有该文件的产物包提供。必须校验摘要，并在目标基础镜像执行 gosu nobody true。不要将此路径理解为通用发行版动态二进制可跨 glibc 复用。
- 运行基础镜像：runtime-base.json 所记录的精确23.3摘要。需要 Docker daemon 可访问它或已有同摘要缓存。
- Dockerfile、docker-entrypoint.sh：本目录为接受的精确最终字节；源仓库、提交及官方原始文件在 source-provenance.json 和 upstream/。

## 项目构建与镜像构建

MySQL 的 source-RPM 项目构建在 dependencies/mysql-server-8.4.0/README.md，不能省略这个先生成原生 RPM 的步骤。也可直接复用摘要匹配的已验收 RPM，无需重建。干净重建流程与实际分阶段成功证据的区别在该文档中明确列出。

变量：RECIPE 为此变体目录，WORKSPACE 为 helper 的可写绝对工作区，ARTIFACTS 为包含 rpms/ 的已验收产物目录，PREPARED_GOSU 为所需静态 gosu 文件路径。以下准备只选择消费清单，不能把全部调试/开发/Router 包放入镜像：

```sh
mkdir -p "$WORKSPACE/image/rpms"
cp "$RECIPE/Dockerfile" "$RECIPE/docker-entrypoint.sh" "$WORKSPACE/image/"
cp "$PREPARED_GOSU" "$WORKSPACE/image/gosu"
python3 - "$RECIPE/mysql-packages.json" "$ARTIFACTS/rpms" "$WORKSPACE/image/rpms" <<'COPY_RPMS'
import json,hashlib,shutil,sys
from pathlib import Path
for x in json.load(open(sys.argv[1])):
    p=Path(sys.argv[2])/x['file']
    assert hashlib.sha256(p.read_bytes()).hexdigest()==x['sha256']
    shutil.copy2(p,Path(sys.argv[3])/p.name)
COPY_RPMS
chmod 755 "$WORKSPACE/image/docker-entrypoint.sh" "$WORKSPACE/image/gosu"
cd "$WORKSPACE"
printf '%s  %s\n' '02a0431eaa5ca337ee728e0d1c32652484365bcf076b03cb39608e0e107ae383' image/gosu | sha256sum -c -
docker build -t mysql:8.4.0-loongnix23.3 image
```

实际成功镜像构建记录 `exec-bff993abf06a4f45a32767ba85bad7b3`。Dockerfile 使用 COPY 安装六个本地产物，DNF 从基础镜像原生发行版仓库补充运行依赖，不需要 MySQL 外架构仓库。静态 gosu 的独立提取示例（临时容器名可自行选择）：

```sh
docker create --name mysql-gosu-source sha256:0d1f4915989e3ec4b55a4d81cb0442e63d044be767062b7606cd63baeff6ef79
docker cp mysql-gosu-source:/usr/sbin/gosu "$PREPARED_GOSU"
docker rm mysql-gosu-source
```

这里源镜像用于已有静态资源提取；不是源码构建依赖，也不复用其 Debian MySQL 二进制。该来源镜像须由现有镜像/归档提供；不存在虚构的公网下载地址。也可以从已验收的本变体最终镜像 /usr/local/bin/gosu 恢复相同字节。

## 验证结果与边界

最终镜像 `sha256:c9effc8c871fa926e696cad8ada2132cf296bb2d91bd90e16edc0a922b460382`，Linux/loong64。其 mysqld 与实际原生 RPM 的 ELF/摘要一致，入口脚本字节与官方提交一致，运行库依赖完整，无代理环境变量；见 verification.json 和 runtime-audit.json。

实际独立 bridge 网络客户端通过 TCP/TLS 连接；初始化脚本、账户、事务与回滚、中文/JSON、索引和 join、InnoDB 磁盘临时表及强制落盘分组、时区/CET、mysqldump/恢复、mysql用户PID1、重启持久化与只初始化一次、正常退出0全部通过。InnoDB/mysqlx ACTIVE，group_replication 插件加载ACTIVE；没有声称完成多节点组复制/NDB集群验收。

CYCLE频率99621890Hz、分辨率1，SLEEP(0.2) 的等待计时为0.200818641996秒，日志没有缺失 CYCLE 告警。下面 SQL 是已验证的检查，可在启动后的服务器中使用带正确客户端配置的 mysql 执行；完整成功执行记录 `exec-2625bb8b7d1845e7b3325f72c71448a3`：

```sql
SELECT VERSION();
SELECT TIMER_NAME,TIMER_FREQUENCY,TIMER_RESOLUTION
FROM performance_schema.performance_timers WHERE TIMER_NAME='CYCLE';
SELECT @@innodb_adaptive_hash_index;
```

完整原始 CTest 247/305组通过，未全通过：56个Router组（不进入最终镜像），临时文件名形式断言，以及最初被300s上限中断的InnoDB组。延长InnoDB重跑后898通过、32跳过、仅hash_uint64_pair_distribution统计质量断言失败。相关源码检查未发现正确性/可用性故障；特定负载性能未评估，算法及断言保留，AHI在实测镜像默认OFF。不能将这些记录改写为“所有测试通过”。最终实际镜像的落盘临时表等功能通过，但没有声称本次打包清理后又执行了gunit tmpfs复查。

MySQL Shell 是独立项目，未包含；Router未进入本镜像。NUMA策略权限告警保留，未增加容器特权。来源任务的首次初始化等待受远端环境影响；用户随后在宿主机复制启动测试正常，已明确结束该问题，不作为镜像缺陷或后续排查事项。此宿主机结果是用户反馈，不冒充远端执行证据。

镜像归档名和摘要在 image-archive.json。经验仅保存文本、元数据、构建适配和必要内容身份，二进制 RPM/gosu/镜像归档仍需单独准备。执行ID用于定位来源任务本地证据，不是公共可访问链接。

若从源码重新构建而非复用已验收 RPM，输出摘要可能不同。上面的消费校验针对本次原始六个 RPM；新构建须完成同类产物和镜像验收并生成新的消费清单，不能把旧 SHA256 当作所有未来构建的固定输出值。
