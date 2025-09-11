#include "../../includes/packet.h"

interface NeighborDiscovery(int channel){
   provides interface NeighborDiscovery
}

implementation{
    components new NeighhoborDiscoveryP();
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;
    
    componetns new TimerMiliC() as nieghborTimer;
    NeighhoborDiscoveryP.neighborTimer -> neighborTimer;

    components RandomC as Random;
    NeighborDiscoveryP.Random -> Random;

}


