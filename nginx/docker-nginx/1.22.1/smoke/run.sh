#!/bin/sh
set -eu
image=${IMAGE:-lcr.loongnix.cn/library/nginx:1.22.1-alpine}
prefix=${SMOKE_PREFIX:-nginx-1221}
docker image inspect "$image" > smoke/image-inspect.json
docker run --rm --network none "$image" sh -ec '
cat /etc/alpine-release
uname -m
nginx -V
nginx -t
njs -v
apk --no-network info -v | sort
test ! -e /usr/bin/gcc
test ! -e /tmp/nginx-build
test ! -e /build
test -z "$(env | grep -i proxy || true)"
envsubst --version
' > smoke/runtime-check.log 2>&1
docker run -d --name "$prefix-default-smoke" "$image" > smoke/default.cid
docker exec "$prefix-default-smoke" curl --retry 10 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1/ > smoke/default.html
grep -q 'Welcome to nginx' smoke/default.html
docker run -d --name "$prefix-modules-smoke" -v "$PWD/smoke/modules.conf:/etc/nginx/modules-test.conf:ro" -v "$PWD/smoke/test.js:/etc/nginx/test.js:ro" "$image" nginx -c /etc/nginx/modules-test.conf -g 'daemon off;' > smoke/modules.cid
docker exec "$prefix-modules-smoke" curl --retry 10 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1:8080/njs > smoke/njs-response.txt
test "$(cat smoke/njs-response.txt)" = nginx-1.22.1-njs-0.7.7
docker exec "$prefix-modules-smoke" curl -fsS http://127.0.0.1:8080/status > smoke/status.txt
grep -q 'Active connections' smoke/status.txt
docker run -d --name "$prefix-template-smoke" -e TEST_MESSAGE=template-substitution-ok -v "$PWD/smoke/default.conf.template:/etc/nginx/templates/default.conf.template:ro" "$image" > smoke/template.cid
docker exec "$prefix-template-smoke" curl --retry 10 --retry-connrefused --retry-delay 1 -fsS http://127.0.0.1/ > smoke/template-response.txt
test "$(cat smoke/template-response.txt)" = template-substitution-ok
for kind in default modules template; do
  docker logs "$prefix-$kind-smoke" > "smoke/$kind-container.log" 2>&1
  docker stop -t 15 "$prefix-$kind-smoke"
  test "$(docker inspect -f '{{.State.ExitCode}}' "$prefix-$kind-smoke")" = 0
done
printf '%s\n' 'PASS: version/platform, default HTTP, six dynamic modules, njs HTTP handler, stub_status, templates, graceful SIGQUIT shutdown.'
