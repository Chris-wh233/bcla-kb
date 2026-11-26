#!/bin/sh
set -eu
mkdir -p /tmp/native-tests
javac -cp "$ROCKETMQ_HOME/lib/*" -d /tmp/native-tests /smoke/NativeInventory.java /smoke/NativeProbe.java /smoke/RemotingProbe.java
java -cp "/tmp/native-tests:$ROCKETMQ_HOME/lib/*" NativeInventory "$ROCKETMQ_HOME/lib" /original.zip
java -cp "/tmp/native-tests:$ROCKETMQ_HOME/lib/*" NativeProbe > /tmp/native-probe.log 2>&1
cat /tmp/native-probe.log
grep -F 'JNA_LIBC mlock=0 madvise=0 munlock=0' /tmp/native-probe.log
grep -F 'EPOLL_AVAILABLE true' /tmp/native-probe.log
grep -F 'EPOLL_BIND ' /tmp/native-probe.log
grep -F 'OPENSSL_AVAILABLE true' /tmp/native-probe.log
grep -F 'OPENSSL_VERSION BoringSSL' /tmp/native-probe.log
timeout 45 java -cp "/tmp/native-tests:$ROCKETMQ_HOME/lib/*" RemotingProbe > /tmp/remoting-probe.log 2>&1
cat /tmp/remoting-probe.log
grep -F 'ROCKETMQ_SERVER_LOOP io.netty.channel.epoll.EpollEventLoopGroup' /tmp/remoting-probe.log
grep -F 'ROCKETMQ_SERVER_SSL io.netty.handler.ssl.OpenSslServerContext' /tmp/remoting-probe.log
grep -F 'ROCKETMQ_NATIVE_TLS_EPOLL_ROUNDTRIP PASS count=10' /tmp/remoting-probe.log
test "$(id -u)" = 3000
test -z "$(env | grep -i proxy || true)"
echo FINAL_IMAGE_NATIVE_TESTS_PASS
