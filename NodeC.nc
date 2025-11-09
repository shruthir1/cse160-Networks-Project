configuration NodeC { }
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components ActiveMessageC;
    components CommandHandlerC;
    components IPForwardingC;

    components NeighborDiscoveryC;
    components FloodingC;
    components LinkRoutingC;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    Node.AMControl -> ActiveMessageC;

    Node.CommandHandler -> CommandHandlerC;

    Node.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;
    
    Node.Sender -> IPForwardingC.IPSender;
    IPForwardingC.LinkRouting -> LinkRoutingC.LinkRouting; 

    IPForwardingC.InternalReceiver -> FloodingC.MainReceive;
    IPForwardingC.Sender -> FloodingC.FloodSender;
    // Node.Sender -> FloodingC.FloodSender;

    // LinkRoutingC.FloodReceive -> FloodingC.MainReceive;
    // LinkRoutingC.FloodSender -> FloodingC.FloodSender;

    LinkRoutingC.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;

    Node.LinkRouting -> LinkRoutingC.LinkRouting;
    // LinkRoutingC.FloodReceive -> FloodingC.MainReceive; 

}

