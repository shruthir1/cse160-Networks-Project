//this header allows for packet messages to be interpreted 
#include "../../includes/packet.h"

//this .nc file holds all the componenets and interfaces that will be used going forward 


//creates the connection channel for other components (?)
generic configuration NeighborDiscovery(int channel){
   //using key word provides means this program will offer the interface NeighborDiscovery to other programs 
   provides interface NeighborDiscovery
}

//where we wire components together 
implementation{
    //bring in the component from the logic file to connect with thiws file 
    components new NeighborDiscoveryP() as nd;
    //connects the neighbor discovery interface of this file to the P.nc file 
    NeighborDiscovery = nd.NeighborDiscovery;
    
    //bringing a timer componenet -> every time the timer is started a new sequence is sent 
    components new TimerMilliC() as neighborTimer;
    //connecting this to P.nc so P.nc can call the timer in correspondance w this file 
    nd.neighborTimer -> neighborTimer;

    //need to start the timer at random intervals, so we bring in the random component to use 
    components RandomC as Random;
    //connecting to the P.nc file 
    nd.Random -> Random;
}





