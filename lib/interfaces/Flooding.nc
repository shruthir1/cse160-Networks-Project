#include "../../includes/packet.h"
#include "../../includes/am_types.h"


generic configuration Flooding(int channel) {
    provides interface Flooding
    provides interface Receive;     
    uses interface SimpleSend;  
}

implementation {
    // Main flooding logic
    components new FloodingP();

    // Expose FloodingP's interfaces upward
    Receive = FloodingP.Receive;
    SimpleSend = FloodingP.SimpleSend;

    // Radio & control
    components ActiveMessageC;
    FloodingP.AMControl -> ActiveMessageC;

    // Timer for resending / retries
    components new TimerMilliC() as floodTimer;
    FloodingP.floodTimer -> floodTimer;

    // Random for jitter (avoid collisions)
    components RandomC as Random;
    FloodingP.Random -> Random;

    // AMSender & AMReceiver for the radio channel
    components new AMSenderC(channel) as AMSendC;
    components new AMReceiverC(channel) as AMRecvC;

    FloodingP.AMSend   -> AMSendC;
    FloodingP.AMPacket -> AMSendC;
    FloodingP.Packet   -> AMSendC;

    FloodingP.Receive  -> AMRecvC;
}
