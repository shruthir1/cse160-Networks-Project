#define AM_ROUTING 63

configuration LinkRoutingC{
    provides interface LinkRouting;
    // uses interface Receive as FloodReceive;
}  

implementation {


    components LinkRoutingP;
    components new TimerMilliC() as LSATimer; 
    components FloodingC;
    components NeighborDiscoveryC;
    // components new AMReceiverC(AM_PACK) as LSARx;
    
    LinkRouting = LinkRoutingP.LinkRouting;
    LinkRoutingP.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;
    LinkRoutingP.FloodSender -> FloodingC.FloodSender;
    // LinkRoutingP.FloodReceive -> LSARx;
    LinkRoutingP.Sender -> FloodingC.SimpleSend;
    LinkRoutingP.LSATimer -> LSATimer; 


}