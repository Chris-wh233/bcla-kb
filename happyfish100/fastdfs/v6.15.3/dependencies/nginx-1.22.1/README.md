# nginx 1.22.1

Source: https://nginx.org/download/nginx-1.22.1.tar.gz
Resolved content identity: archive-sha256:9ebb333a9e82b952acd3e2b4aeb1d4ff6406f72491bab6cd9fe69f0dea737f31
Produced native output: `usr/local/nginx/sbin/nginx`, SHA256 `2b76f3ef7b941569f82a777753d4923f27d54d91f0e7fa70f5ad105da32df026`.
Consumers: FastDFS image HTTP80 and HTTP8888.

Follow the parent ../../README.md input preparation and ordered build; ROOTFS is `$WORKSPACE/artifacts/rootfs`. Build commands are extracted from the accepted build-native.sh, executed by exec-cb3a5b08276544c591d6e3e666d951a0. The original output was tested in its real FastDFS image consumer by exec-9f6bc1e1341c41a3ac569be64cb0a74e. These IDs are local evidence references. Native ABI: ELF64 LoongArch LP64D with Debian glibc2.43. There is no separate image or standalone test-only replacement artifact.

