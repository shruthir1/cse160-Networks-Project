#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module IPForwardingP{
    provides interface SimpleSend as IPSender;
    provies interface Receive as IPReceive;

    uses interface SimpleSend as Sender;
    uses interface Receive as InternalReceiver; 

    uses interface LinkRouting;
}

implementation{
    
}