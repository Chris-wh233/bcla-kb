#!/bin/sh
set -eu
WORKSPACE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$WORKSPACE"
mkdir -p artifacts/rootfs
ROOTFS="$WORKSPACE/artifacts/rootfs"
for project in deps/libfastcommon deps/libserverframe source; do
  (cd "$project" && ./make.sh && ./make.sh install && DESTDIR="$ROOTFS" ./make.sh install)
done
for target in deps/libfastcommon/src deps/libserverframe/src source/tracker source/storage source/client; do make -C "$target"; done
test -x "$ROOTFS/usr/bin/fdfs_storaged"
ldconfig
(cd deps/nginx-1.22.1 && ./configure --add-module="$WORKSPACE/deps/fastdfs-nginx-module/src" && make -j4 && make install && make DESTDIR="$ROOTFS" install)
mkdir -p "$ROOTFS/etc/init.d" "$ROOTFS/home/dfs" "$ROOTFS/etc/fdfs"
cp source/init.d/fdfs_trackerd source/init.d/fdfs_storaged "$ROOTFS/etc/init.d/"
cp source/docker/dockerfile_network/conf/* "$ROOTFS/etc/fdfs/"
sed -i "s/^thread_stack_size[[:space:]]*=.*/thread_stack_size=512KB/" "$ROOTFS/etc/fdfs/tracker.conf"
cp source/docker/dockerfile_network/fastdfs.sh "$ROOTFS/home/fastdfs.sh"
chmod +x "$ROOTFS/home/fastdfs.sh" "$ROOTFS/etc/init.d/"fdfs_*
file "$ROOTFS/usr/bin/"fdfs_* "$ROOTFS/usr/local/nginx/sbin/nginx"
/usr/bin/fdfs_trackerd -V
/usr/local/nginx/sbin/nginx -V
find artifacts/rootfs -type f -exec sha256sum {} + > artifacts/SHA256SUMS
