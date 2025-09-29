/*
 * NodeC wiring
 */

configuration NodeC { }
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components ActiveMessageC;
    components new SimpleSendC(AM_PACK);
    components CommandHandlerC;

    // Neighbor discovery components
    components NeighborDiscoveryC;

    Node -> MainC.Boot;

    Node.Receive -> GeneralReceive;

    Node.AMControl -> ActiveMessageC;

    Node.Sender -> SimpleSendC;

    Node.CommandHandler -> CommandHandlerC;

    // FIXED: Wire Node to neighbor discovery with specific interface
    Node.NeighborDiscovery -> NeighborDiscoveryC.NeighborDiscovery;
}