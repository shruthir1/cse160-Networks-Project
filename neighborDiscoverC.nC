#include "../../includes/am_types.h"

generic configuration NeighborDiscovery(int channel){
    provides interface NeighborDiscovery;
}

implementation{

    components new NeighborDiscoverP(); //creating a linkage to P file
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    //connecting private timer in P file to timer
    components new TimerMilliC() as neighborTimer;
    NeighborDiscoveryP.neighborTimer -> neighborTimer; 

    components RandomC as Random
    NeighborDiscoveryP.Random -> Random;
}