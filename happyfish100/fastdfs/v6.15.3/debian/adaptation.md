# Accepted adaptations

FastDFS source remains exactly V6.15.3 (3aa443ce6b2a65b4f60986c6f3943b8b2bf25631); no FastDFS C source patch was used.

- The official docker/dockerfile_network/Dockerfile is retained byte for byte as Dockerfile.upstream. The accepted Dockerfile maps its generic CentOS build/runtime needs to a digest-pinned native Debian image and copies the separately retained native install tree. Original entrypoint, configuration volume and exposed ports remain.
- Nginx 1.22.1 is one of the official Dockerfile's recommended NGINX_VERSION choices and supports the available system PCRE2. Its FastDFS module is retained.
- patches/loongarch.patch is the exact accepted install-tree configuration diff: tracker thread_stack_size 64KB becomes 512KB. The measured PTHREAD_STACK_MIN was 131072 bytes. build-native.sh performs this adjustment after copying official configuration. Do not also patch it a second time. Storage already uses 512KB.
- libfastcommon V1.0.83 requires the approved upstream e009d750a5f2288fcdb6c1aba0a0a54a65f184f0 backport, captured in dependencies/libfastcommon-1.0.83/patches/loongarch.patch. This supplies free_queue_task_arg_offset, required by storage_dio.c. It is an upstream common-code dependency correction, not a LoongArch-only C implementation.
- The build wrapper checks generated make targets explicitly and asserts fdfs_storaged exists; upstream wrappers alone do not establish complete output.

Effective evidence: native compilation in exec-cb3a5b08276544c591d6e3e666d951a0; tracker adjustment and final image build in exec-0fb26dd817684c5399b9826fa45a87b2. The accepted build-native.sh consolidates these successful operations; its final hash is recorded by exec-5fdde064b334443f97598dae1b2fb932. Execution IDs identify local task evidence, not public URLs.
