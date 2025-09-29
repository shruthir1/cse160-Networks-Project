//Configuration file always has the wiring of the modules schematics 
configuration NeighborDiscoveryC {
    //common shared interface between c and p files
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP; //always need a P file component to wire everything 
    components new TimerMilliC() as beaconTimer; //timer so that we know when to deem a neighbor unresponsive 
    components new SimpleSendC(AM_PACK) as ssc; //to send packets
    components new AMReceiverC(AM_PACK) as rc; //to recieve ping when connection is established 

    NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery; //wiring this interface to P interface 

    NeighborDiscoveryP.SimpleSend -> ssc; //wiring the sending configurations between the P and C files
    NeighborDiscoveryP.Receive -> rc; //wiring the recieving configurations between the P and C files 
    NeighborDiscoveryP.beaconTimer -> beaconTimer; //connecting the timers 
}
