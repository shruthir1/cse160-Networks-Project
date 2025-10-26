#define AM_ROUTING 63

configuration LinkRoutingC{
    provides interface LinkRouting;
}

implementation {
    components LinkRoutingP;
    components new TimerMilliC() as PeriodicTimer; 
    components new SimpleSend(AM_ROUTING);
    components new AMReceiver(AM_ROUTING);
    
    components NeighborDiscoveryC;
    LinkRoutingP.NeighborDiscovery -> NeighborDiscoveryC;

    LinkRouting = LinkRoutingP.LinkRouting;

    LinkRoutingP.Sender -> SimpleSendC;
    LinkRoutingP.Receive -> AMReceiverC;
    LinkRoutingP.PeriodicTimer -> PeriodicTimer; 

}