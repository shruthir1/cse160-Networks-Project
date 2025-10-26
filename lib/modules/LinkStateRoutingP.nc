#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#define TIMEOUT_MAX 15

module IPForwardingP{
    uses interface Timer<TMili> as PeriodicTimer; 
    uses interface SimpleSend as Sender; 
    uses interface Receive as Receive;
    uses interface NeighborDiscovery;

    provides interface IPForwarding;
}

implementation{
    
}