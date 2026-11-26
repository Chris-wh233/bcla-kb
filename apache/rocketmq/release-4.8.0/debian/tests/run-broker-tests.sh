#!/bin/sh
set -eu
root=$PWD
image=apache/rocketmq:4.8.0-debian
network=rocketmq-verify-smoke
nameserver=rocketmq-verify-namesrv
broker=rocketmq-verify-broker
cleanup() {
    for container in "$broker" "$nameserver"; do
        docker logs "$container" > "$root/verification/$container.log" 2>&1 || true
        docker rm -f "$container" >/dev/null 2>&1 || true
    done
    docker network rm "$network" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker network create "$network"
docker run -d --name "$nameserver" --network "$network" -v "$root/smoke:/smoke:ro" -e HEAP_OPTS='-Xms128m -Xmx128m -Xmn64m' "$image" nameserver -c /smoke/namesrv.properties
docker run -d --name "$broker" --network "$network" -v "$root/smoke:/smoke:ro" -e HEAP_OPTS='-Xms256m -Xmx256m -Xmn128m -XX:MaxDirectMemorySize=128m' "$image" broker -n "$nameserver:9876" -c /smoke/broker.properties
ready=false
for attempt in $(seq 1 60); do
    if docker logs "$broker" 2>&1 | grep -q 'boot success' && docker logs "$nameserver" 2>&1 | grep -q 'boot success'; then
        ready=true
        break
    fi
    test "$(docker inspect -f '{{.State.Running}}' "$broker")" = true
    test "$(docker inspect -f '{{.State.Running}}' "$nameserver")" = true
    sleep 1
done
test "$ready" = true
docker run --rm --network "$network" -v "$root/smoke:/smoke:ro" "$image" sh -c 'set -eu; mkdir -p /tmp/smoke; javac -cp "$ROCKETMQ_HOME/lib/*" -d /tmp/smoke /smoke/MessageSmoke.java; timeout 60 java -Xmx128m -cp "/tmp/smoke:$ROCKETMQ_HOME/lib/*" MessageSmoke rocketmq-verify-namesrv:9876; test "$(id -u)" = 3000; test -z "$(env | grep -i proxy || true)"' > verification/message-final-image.log 2>&1
grep 'sendStatus=SEND_OK' verification/message-final-image.log
grep 'MESSAGE_ROUNDTRIP_OK' verification/message-final-image.log
docker exec "$broker" sh -c './mqadmin clusterList -n rocketmq-verify-namesrv:9876' > verification/cluster-final-image.log 2>&1
grep 'V4_8_0' verification/cluster-final-image.log
docker cp "$broker:/home/rocketmq/logs/rocketmqlogs" verification/broker-runtime-logs
grep 'mlock .*ret = 0' verification/broker-runtime-logs/store.log
grep 'madvise .*ret = 0' verification/broker-runtime-logs/store.log
for container in "$broker" "$nameserver"; do
    docker exec "$container" sh -c 'test "$(id -u)" = 3000; test -z "$(env | grep -i proxy || true)"; java -XshowSettings:properties -version 2>&1 | grep -F "java.vm.name = OpenJDK 64-Bit Server VM"'
done
echo FINAL_IMAGE_BROKER_TESTS_PASS
