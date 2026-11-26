import com.sun.jna.Memory;
import com.sun.jna.Native;
import com.sun.jna.NativeLong;
import com.sun.jna.NativeLibrary;
import com.sun.jna.Platform;
import com.sun.jna.Pointer;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.epoll.Epoll;
import io.netty.channel.epoll.EpollEventLoopGroup;
import io.netty.channel.epoll.EpollServerSocketChannel;
import io.netty.handler.ssl.OpenSsl;
import io.netty.handler.ssl.SslContext;
import org.apache.rocketmq.remoting.netty.TlsHelper;
import org.apache.rocketmq.store.util.LibC;

public class NativeProbe {
    public static void main(String[] args) {
        System.out.println("RUNTIME " + System.getProperty("java.vm.name") + " " + System.getProperty("os.arch"));
        try {
            System.out.println("JNA " + Native.VERSION + " prefix=" + Platform.RESOURCE_PREFIX + " pointer=" + Native.POINTER_SIZE);
            int pageSize = NativeLibrary.getInstance("c").getFunction("getpagesize").invokeInt(new Object[0]);
            System.out.println("PAGE_SIZE " + pageSize);
            Memory memory = new Memory(2L * pageSize);
            memory.clear();
            long mask = pageSize - 1L;
            Pointer aligned = memory.share((pageSize - (Pointer.nativeValue(memory) & mask)) & mask);
            int lock = LibC.INSTANCE.mlock(aligned, new NativeLong(pageSize));
            int advise = LibC.INSTANCE.madvise(aligned, new NativeLong(pageSize), LibC.MADV_WILLNEED);
            int unlock = LibC.INSTANCE.munlock(aligned, new NativeLong(pageSize));
            System.out.println("JNA_LIBC mlock=" + lock + " madvise=" + advise + " munlock=" + unlock);
        } catch (Throwable error) {
            System.out.println("JNA_FAIL " + error);
            error.printStackTrace(System.out);
        }
        try {
            System.out.println("EPOLL_AVAILABLE " + Epoll.isAvailable());
            if (!Epoll.isAvailable()) throw Epoll.unavailabilityCause();
            EpollEventLoopGroup group = new EpollEventLoopGroup(1);
            try {
                Channel channel = new ServerBootstrap().group(group).channel(EpollServerSocketChannel.class)
                    .childHandler(new ChannelInitializer<Channel>() { protected void initChannel(Channel ch) {} })
                    .bind("127.0.0.1", 0).sync().channel();
                System.out.println("EPOLL_BIND " + channel.localAddress());
                channel.close().sync();
            } finally {
                group.shutdownGracefully().sync();
            }
        } catch (Throwable error) {
            System.out.println("EPOLL_FAIL " + error);
            error.printStackTrace(System.out);
        }
        try {
            System.out.println("OPENSSL_AVAILABLE " + OpenSsl.isAvailable());
            if (!OpenSsl.isAvailable()) throw OpenSsl.unavailabilityCause();
            System.out.println("OPENSSL_VERSION " + OpenSsl.versionString());
            SslContext context = TlsHelper.buildSslContext(false);
            System.out.println("ROCKETMQ_TLS_CONTEXT " + context.getClass().getName());
        } catch (Throwable error) {
            System.out.println("OPENSSL_FAIL " + error);
            error.printStackTrace(System.out);
        }
    }
}
