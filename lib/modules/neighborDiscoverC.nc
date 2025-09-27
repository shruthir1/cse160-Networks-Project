#include "../../includes/am_types.h"
//every module has its own local variables that can accessed by other files through "using interface"

//this is the file where the configuration goes its responsible for connecting the neccesary componenets back to the logic file 
generic configuration NeighborDiscovery(int channel){
    provides interface NeighborDiscovery;
}

implementation{
    //wiring this interface to the P.nc file where the logic lives 
    components new NeighborDiscoverP();
    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    //wires the timer to the P.nc file 
    components new TimerMilliC() as neighborTimer;
    NeighborDiscoveryP.neighborTimer -> neighborTimer;
    
    //wires the random comonent to the P.nc file 
    components RandomC as Random;
    NeighborDiscoveryP.Random -> Random;
}