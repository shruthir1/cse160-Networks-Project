#include <Timer.h> 
#include "includes/packet.h"

generic configuration FloodingC {
    provides interface Flooding;
    uses interface SimpleSend;
}
implementation {
    components FloodingP;

    Flooding = FloodingP.Flooding;
    components new TimerMilliC() as fTimer;
    FloodingP.fTimer -> fTimer;

   
    components RandomC as Random;
    FloodingP.Random -> Random;

    components ActiveMessageC as AM; 
    FloodingP.AMControl -> AM
    FloodingP.Receive -> AM.Receive

    Receive = FloodingP.Receive;
    SimpleSend = FloodingP.SimpleSend;


  }