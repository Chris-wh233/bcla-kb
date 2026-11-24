import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.epoll.Epoll;
import io.netty.handler.ssl.OpenSsl;
import io.netty.handler.ssl.util.SelfSignedCertificate;
import org.apache.rocketmq.remoting.common.TlsMode;
import org.apache.rocketmq.remoting.netty.*;
import org.apache.rocketmq.remoting.protocol.RemotingCommand;

public class RemotingProbe {
    public static void main(String[] args) throws Exception {
        if (!Epoll.isAvailable()) throw new AssertionError("Native epoll unavailable", Epoll.unavailabilityCause());
        if (!OpenSsl.isAvailable()) throw new AssertionError("Native TLS unavailable", OpenSsl.unavailabilityCause());
        SelfSignedCertificate cert = new SelfSignedCertificate();
        TlsSystemConfig.tlsMode = TlsMode.ENFORCING;
        TlsSystemConfig.tlsTestModeEnable = false;
        TlsSystemConfig.tlsServerCertPath = cert.certificate().getAbsolutePath();
        TlsSystemConfig.tlsServerKeyPath = cert.privateKey().getAbsolutePath();
        TlsSystemConfig.tlsServerNeedClientAuth = "none";
        TlsSystemConfig.tlsServerAuthClient = false;
        TlsSystemConfig.tlsClientAuthServer = false;
        NettyServerConfig config = new NettyServerConfig();
        config.setListenPort(0);
        config.setUseEpollNativeSelector(true);
        config.setServerWorkerThreads(2);
        config.setServerSelectorThreads(1);
        NettyRemotingServer server = new NettyRemotingServer(config);
        NettyClientConfig clientConfig = new NettyClientConfig();
        clientConfig.setUseTLS(true);
        NettyRemotingClient client = new NettyRemotingClient(clientConfig);
        ExecutorService executor = Executors.newFixedThreadPool(1);
        server.registerProcessor(0, new NettyRequestProcessor() {
            public RemotingCommand processRequest(ChannelHandlerContext ctx, RemotingCommand request) {
                RemotingCommand response = RemotingCommand.createResponseCommand(0, "native audit echo");
                response.setBody(request.getBody());
                return response;
            }
            public boolean rejectRequest() { return false; }
        }, executor);
        try {
            server.start();
            client.start();
            Field loop = NettyRemotingServer.class.getDeclaredField("eventLoopGroupBoss");
            loop.setAccessible(true);
            Field ssl = NettyRemotingAbstract.class.getDeclaredField("sslContext");
            ssl.setAccessible(true);
            System.out.println("ROCKETMQ_SERVER_LOOP " + loop.get(server).getClass().getName());
            System.out.println("ROCKETMQ_SERVER_SSL " + ssl.get(server).getClass().getName());
            for (int i = 0; i < 10; i++) {
                byte[] body = ("loongarch-native-" + i).getBytes(StandardCharsets.UTF_8);
                RemotingCommand request = RemotingCommand.createRequestCommand(0, null);
                request.setBody(body);
                RemotingCommand response = client.invokeSync("127.0.0.1:" + server.localListenPort(), request, 10000);
                if (response.getCode() != 0 || !Arrays.equals(body, response.getBody())) throw new AssertionError("Echo mismatch");
            }
            System.out.println("ROCKETMQ_NATIVE_TLS_EPOLL_ROUNDTRIP PASS count=10");
        } finally {
            client.shutdown();
            server.shutdown();
            executor.shutdownNow();
            cert.delete();
        }
    }
}
