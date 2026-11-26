# MySQL 8.4.0 RPM 构建经验

本依赖提供最终 Loongnix 镜像实际安装的六个 RPM。版本必须为8.4.0-1.lns23、架构 loongarch64，内容摘要见 mysql-packages.json；未消费的测试、调试和 Router RPM 不作为本镜像输入。

## 环境和来源

使用原生 LoongArch64 Linux helper，基础镜像：

```text
lcr.loongnix.cn/loongnix-server/loongnix-server:23.3@sha256:54c61a0ca717f1688fa5a6252a7e36a6e55f429c4d4bf00b4c9a97964b0b8e4e
```

已验证工具版本在 toolchain.json。已有 Debian forky MySQL 二进制不适用于此 glibc2.38/RPM 路线。官方原始 source RPM 的 SHA256 为 `1145e598121b2e96a81359c35d5cb7feab083971eb39d6c66b7c5dcf95456796`，官方2023密钥签名和摘要已验证。来源任务还保留了适配后 source RPM，摘要见 source-rpms.json；其 SPEC 和五个适配输入与本目录逐项一致。

## 干净的项目产物构建流程

以下为基于最终接受 SPEC 整理的新工作区流程；本次执行证据采用已完成的 Debug/release 编译、patchelf 重配置确认和缓存安装根目录封包，并没有额外执行一次此完整干净流程。实际成功的有效命令、执行 ID、预条件及包装器状态见 build-commands.json。

变量：DEP 是本依赖目录；WORKSPACE 是 helper 内可写绝对路径，rpmbuild 位于其下。先将经验目录作为输入挂载到 helper。安装发行版构建依赖：

```sh
dnf install -y --setopt=install_weak_deps=False \
  gcc gcc-c++ make cmake bison elfutils rpm-build cpio patch diffutils \
  python3 curl ca-certificates tar xz perl perl-JSON perl-Memoize \
  perl-Time-HiRes perl-English \
  'perl(File::Copy)' 'perl(Sys::Hostname)' 'perl(Time::localtime)' \
  time libaio-devel libtirpc-devel rpcgen krb5-devel ncurses-devel \
  numactl-devel openssl-devel zlib-devel systemd-devel cyrus-sasl-devel cyrus-sasl-gssapi \
  openldap-devel libcurl-devel libfido2-devel mecab-devel patchelf
mkdir -p "$WORKSPACE/downloads" "$WORKSPACE/rpmbuild"
cd "$WORKSPACE"
curl -fL 'https://cdn.mysql.com/archives/mysql-8.4/mysql-community-8.4.0-1.el8.src.rpm' -o downloads/mysql-community-8.4.0-1.el8.src.rpm
printf '%s  %s\n' '1145e598121b2e96a81359c35d5cb7feab083971eb39d6c66b7c5dcf95456796' downloads/mysql-community-8.4.0-1.el8.src.rpm | sha256sum -c -
curl -fL https://repo.mysql.com/RPM-GPG-KEY-mysql-2023 -o downloads/RPM-GPG-KEY-mysql-2023
rpm --import downloads/RPM-GPG-KEY-mysql-2023
rpm -Kv downloads/mysql-community-8.4.0-1.el8.src.rpm
rpm -ivh --define "_topdir $WORKSPACE/rpmbuild" downloads/mysql-community-8.4.0-1.el8.src.rpm
cp "$DEP/mysql.spec" rpmbuild/SPECS/mysql.spec
cp "$DEP"/SOURCES/* rpmbuild/SOURCES/
rpmbuild --define "_topdir $WORKSPACE/rpmbuild" --define '_smp_mflags -j64' --define '_lto_cflags %{nil}' --define 'with_mecab system' --define 'with_unittests 1' --define 'with_debuginfo 1' -ba "$WORKSPACE/rpmbuild/SPECS/mysql.spec"
```

这里先安装 source RPM 保留其全部上游 Source 文件，再覆盖精确接受的 SPEC 和五个适配文件。不要仅下载一个 tarball 就假定 SPEC 所需输入齐全。不要对新工作区设置 repack_only/reuse_staging 或跳过 RPM post 检查。

上游 SPEC 编译 Debug 与 RelWithDebInfo 两个配置；最终安装、debug 符号拆分、严格 RPATH 检查和文件清单由 SPEC 处理。封包后的原生产物位于 `$WORKSPACE/rpmbuild/RPMS/loongarch64/` 和 `SRPMS/`。只有 mysql-packages.json 中六项复制到镜像 rpms/。正常打包会清理构建树，源码单元测试应在清理之前安排，不能假称打包后又运行了已删除的 gunit 二进制。

## 实际证据与消费者

`exec-902489b44f74481d99a03d9b5614c24d` 确认 patchelf 重配置未改变两个已编译配置头，且两个配置 all-target 构建成功。最终有效 rpmbuild -ba 子进程返回0并完成 clean/rmbuild；外层包装器之后错误断言被清理的文件仍存在，所以该包装执行记录为FAILED。这不是将失败命令改写为成功：有效子命令与包装器结果分别记录。

后续 `exec-e8c6698088a247a692d465cb10a572c4` 独立验证完整 RPM 的版本、架构、摘要、实际 native server ELF，并核对源 RPM 内部适配字节；`exec-54acd36da1864ff5b6c1039af1bff35f` 验证保留副本的 SHA256。最终镜像安装这些 RPM 后，通过 DNF 依赖检查和真实 SQL/TLS/重启测试。因此本经验验证状态来自产物及真实消费者，而非包装器退出码。

本机本次经验生成没有重新编译或重跑数据库测试。哈希分布质量断言和完整 CTest 的边界见变体根目录 unit-results.json。

重建产生的 RPM 可能因构建时间、工具包补丁级别等改变字节。原 mysql-packages.json 中的 SHA256 只用于识别和复用本次已验收产物，不承诺每次源码重建均逐字节可重现。对于新产物，应重新验证版本、架构、依赖及真实镜像消费者并记录新的内容身份，不能为了通过旧清单而跳过校验。
