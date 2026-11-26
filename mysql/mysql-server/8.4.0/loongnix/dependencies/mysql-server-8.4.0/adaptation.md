# MySQL 8.4.0 原生 RPM 适配

原始官方 SPEC 保存在 upstream/mysql.spec，精确差异为 patches/rpm-spec.patch，最终接受文件为 mysql.spec。Source100/101/102 与 Patch100/101 的最终字节均保存在 SOURCES/，并与适配后源码 RPM 中的文件逐项验证一致。

- CYCLE：为 LoongArch64 增加 rdtime.d 稳定计数器及 routine31，使用上游频率校准；允许连续读取相同但不允许倒退，并要求计数前进。Debug 五项计时测试和最终服务器 Performance Schema WAIT 计时均通过。
- CSR：NodeCertificate 的 PKCS#10 version 改为经过返回值检查的0，适配 OpenSSL3；源补丁与计时补丁合并保存在 patches/loongarch.patch，同时保留 SPEC 实际使用的两个独立补丁。
- GNU config.guess/config.sub：将接受的相同文件复制到捆绑 libtirpc 和 ICU。此任务实际选用系统 libtirpc。
- 工具链：使用发行版 cmake、GCC12；关闭 maintainer mode，禁用发行版自动 LTO，其他原生编译加固保留。
- 使用系统 FIDO/MeCab/curl，保留认证和 MeCab 插件；删除捆绑 FIDO/MeCab 的不适用清单项，并让系统 libfido2 SONAME 进入真实 RPM Requires。
- LoongArch 的上游 RPM 布局实际生成 /usr/lib/mysql 与 /usr/lib/mysqlrouter。仅让 SPEC 私有应用目录匹配该布局，保持 ELF64 和系统库目录不变；mysqlclient.pc 放入发行版 /usr/lib64/pkgconfig。
- 构建前安装 patchelf。MySQL 已有的 CMake 安装清理钩子依赖它；未更换 MySQL 版本。Source102 进一步删除空项/构建目录 RPATH，去重并将 $ORIGIN 排在绝对路径之前，保留所需私有库路径。真实 RPM 严格 check-rpaths 已通过；没有放宽 QA_RPATHS。参考上游同类构建依赖问题 https://bugs.mysql.com/bug.php?id=118796 。

最终 SPEC 中 repack_only/reuse_staging 是本次复用已验证编译及安装产物的显式开关；新构建保持未定义。实际缓存封包的完整命令和包装器退出状态解释见 build-commands.json。正常 RPM clean/rmbuild 会删除 BUILD/BUILDROOT，不应在它们删除后断言文件仍存在。已生成的源包含全部最终适配，不依赖该错误断言脚本。
