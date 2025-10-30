#define AM_ROUTING 63

configuration LinkRoutingC{
    provides interface LinkRouting;
    // uses interface Receive as FloodReceive;
}  

implementation {
    components LinkRoutingP;
    components new TimerMilliC() as PeriodicTimer; 
    components FloodingC;
    components NeighborDiscoveryC;
 
    LinkRoutingP.NeighborDiscovery -> NeighborDiscoveryC;
    LinkRoutingP.FloodSender -> FloodingC.FloodSender;
    LinkRoutingP.FloodReceive -> FloodingC.FloodReceive;
    LinkRouting = LinkRoutingP.LinkRouting;
    LinkRoutingP.PeriodicTimer -> PeriodicTimer; 

}