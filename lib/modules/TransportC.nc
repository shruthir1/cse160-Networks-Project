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

    components new TimerMilliC() as TCPtimer;
    TransportP.TCPtimer -> TCPtimer;

    components new SimpleSendC(AM_PACK) as Sender;
    TransportP.Sender -> Sender;

    // components new AMReceiverC(AM_TRANSPORT) as TransportReceive;
    // TransportP.Receive -> TransportReceive;

    components new QueueC(pack, 32) as packetQueue;
    TransportP.packetQueue -> packetQueue;

    components new QueueC(socket_store_t *, 32) as socketQueue;
    TransportP.socketQueue -> socketQueue;

}


