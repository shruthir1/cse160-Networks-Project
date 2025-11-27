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

    // components new Receive() as Rcv;
    // TransportP.Receive -> Rcv;

    components new QueueC(pack, 32) as packetQueue;
    TransportP.packetQueue -> packetQueue;

    components new ListC(socket_store_t, 32) as SocketList;
    TransportP.SocketList -> SocketList;
}


