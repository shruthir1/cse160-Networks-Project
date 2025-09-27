#include "../../includes/am_types.h"

generic configuration NeighborDiscovery(int channel){
    provides interface NeighborDiscovery;
}

implementation{
    components new NeighborDiscoverP();
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    components new TimerMilliC() as neighborTimer;
    NeighborDiscoveryP.neighborTimer -> neighborTimer;

    components RandomC as Random
    NeighborDiscoveryP.Random -> Random;
}