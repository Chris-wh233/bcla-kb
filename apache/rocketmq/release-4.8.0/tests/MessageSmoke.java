import java.nio.charset.StandardCharsets;
import org.apache.rocketmq.client.producer.DefaultMQProducer;
import org.apache.rocketmq.client.producer.SendResult;
import org.apache.rocketmq.client.consumer.DefaultMQPullConsumer;
import org.apache.rocketmq.client.consumer.PullResult;
import org.apache.rocketmq.client.consumer.PullStatus;
import org.apache.rocketmq.common.message.Message;
import org.apache.rocketmq.common.message.MessageExt;
public class MessageSmoke {
 public static void main(String[] args) throws Exception {
  String endpoint=args[0], token="loongarch-rocketmq-4.8.0-"+System.currentTimeMillis();
  DefaultMQProducer producer=new DefaultMQProducer("bcla_smoke_producer");
  DefaultMQPullConsumer consumer=new DefaultMQPullConsumer("bcla_smoke_consumer");
  producer.setNamesrvAddr(endpoint); consumer.setNamesrvAddr(endpoint);
  producer.setVipChannelEnabled(false);
  try {
   producer.start(); consumer.start();
   SendResult sent=producer.send(new Message("BCLA_SMOKE",token.getBytes(StandardCharsets.UTF_8)),20000);
   System.out.println("SEND="+sent);
   boolean found=false;
   for(int i=0;i<30 && !found;i++) {
    PullResult pulled=consumer.pull(sent.getMessageQueue(),"*",sent.getQueueOffset(),1);
    if(pulled.getPullStatus()==PullStatus.FOUND) for(MessageExt m:pulled.getMsgFoundList()) {
     if(token.equals(new String(m.getBody(),StandardCharsets.UTF_8))) found=true;
    }
    if(!found) Thread.sleep(1000);
   }
   if(!found) throw new IllegalStateException("Sent message was not read back");
   System.out.println("MESSAGE_ROUNDTRIP_OK "+token);
  } finally { consumer.shutdown(); producer.shutdown(); }
 }
}
