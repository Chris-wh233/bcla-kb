# Derived from happyfish100/fastdfs V6.15.3 docker/dockerfile_network/Dockerfile.
# build-native.sh produces the retained installation tree, including nginx's FastDFS module.
# This verified native base already supplies glibc, PCRE2, zlib and libcrypt.
FROM lcr.loongnix.cn/library/debian@sha256:f5ef929388a56fb070c8c86cd572e70b0241f13a227c624c36260ef067f43d2b
COPY artifacts/rootfs/ /
RUN ldconfig && mkdir -p /home/dfs
VOLUME /etc/fdfs
EXPOSE 22122 23000 8888 80
ENTRYPOINT ["/home/fastdfs.sh"]
