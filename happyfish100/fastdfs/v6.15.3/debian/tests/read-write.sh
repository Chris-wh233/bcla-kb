#!/bin/sh
set -eu
printf 'FastDFS 6.15.3 LoongArch64 upstream-backport smoke test\n' > /tmp/payload.txt
file_id=$(fdfs_upload_file /etc/fdfs/client.conf /tmp/payload.txt)
printf '%s\n' "$file_id" > /tmp/uploaded-file-id
printf 'uploaded: %s\n' "$file_id"
fdfs_download_file /etc/fdfs/client.conf "$file_id" /tmp/downloaded.txt
cmp /tmp/payload.txt /tmp/downloaded.txt
sha256sum /tmp/payload.txt /tmp/downloaded.txt
fdfs_file_info /etc/fdfs/client.conf "$file_id"
