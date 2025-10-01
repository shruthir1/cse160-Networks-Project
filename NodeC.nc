configuration NodeC { }
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components ActiveMessageC;
    components new SimpleSendC(AM_PACK);
    components CommandHandlerC;

    
    components NeighborDiscoveryC;
    components FloodingC;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    Node.AMControl -> ActiveMessageC;

    Node.Sender -> SimpleSendC;

    Node.CommandHandler -> CommandHandlerC;

    Node.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;
    
    Node.Sender -> FloodingC.SimpleSend;

}