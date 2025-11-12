#include "../../includes/channels.h"

configuration TransportC {
    provides interface Transport;         
    uses interface SimpleSend as WaySend; 
    uses interface Receive as WayReceive; 
}

implementation {
    components TransportP;

    Transport = TransportP;
    WaySend = TransportP.WaySend;
    WayReceive = TransportP.WayReceive;
}

