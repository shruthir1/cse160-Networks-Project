#include "../../imcludes/am_types.h"

genetic configuration NeighborDiscovery(int channel){
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