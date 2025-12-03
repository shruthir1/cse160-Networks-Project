#include "../../includes/channels.h"
#include "../../includes/socket.h"
#include "../../includes/packet.h"

configuration TransportC {
    provides interface Transport;         
}

implementation {
    components TransportP;
    Transport = TransportP.Transport;
    
    // components PacketHandlerC as PacketHandler;
    // TransportP.PacketHandler -> PacketHandler;

    components ActiveMessageC;
    TransportP.Packet -> ActiveMessageC;

    components new TimerMilliC() as TCPtimer;
    TransportP.TCPtimer -> TCPtimer;

    components new TimerMilliC() as timeWaitTimer;
    TransportP.timeWaitTimer -> timeWaitTimer;

    components new SimpleSendC(AM_PACK) as Sender;
    TransportP.Sender -> Sender;

    components new AMReceiverC(AM_PACK) as TransportReceive;
    TransportP.Receive -> TransportReceive;

    components new PoolC(message_t, 32) as packetPool;
    TransportP.packetPool -> packetPool;


    components new QueueC(message_t *, 32) as packetQueue;
    TransportP.packetQueue -> packetQueue;

    components new QueueC(socket_store_t *, 32) as socketQueue;
    TransportP.socketQueue -> socketQueue;

    components new QueueC(socket_store_t *, 32) as timeWaitQueue;
    TransportP.timeWaitQueue -> timeWaitQueue;

    components new QueueC(pack*, 32) as sendQueue;
    TransportP.sendQueue -> sendQueue;

    components new PoolC(pack, 32) as sendPool;
    TransportP.sendPool -> sendPool ;

    components new PoolC(socket_store_t, 32) as sockPool;
    TransportP.socketPool -> sockPool;


}


