#!/bin/sh
set -eu

context_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
runtime_image=${RUNTIME_IMAGE:-apache/apisix-runtime-deb:3.12.0}
apisix_image=${APISIX_IMAGE:-apache/apisix:3.12.0}

printf '%s\n' "Stage 1/2: build required runtime image ${runtime_image}"
docker build -f "$context_dir/Dockerfile.runtime" -t "$runtime_image" "$context_dir"
docker image inspect "$runtime_image" --format 'runtime={{.Id}} {{.Os}}/{{.Architecture}}'

printf '%s\n' "Stage 2/2: build APISIX image ${apisix_image} FROM ${runtime_image}"
docker build -f "$context_dir/Dockerfile" -t "$apisix_image" "$context_dir"
docker image inspect "$apisix_image" --format 'apisix={{.Id}} {{.Os}}/{{.Architecture}} size={{.Size}}'
