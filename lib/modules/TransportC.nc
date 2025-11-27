#include "../../includes/channels.h"

configuration TransportC {
    provides interface Transport;         
    // uses interface SimpleSend as Sender; 
    // uses interface Receive; 
}

implementation {
    components TransportP as transport;

    Transport = transport;
  
}

