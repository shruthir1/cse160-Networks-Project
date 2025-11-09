#define AM_FORWARDING 81 

configuration IPForwardingC{
    provides interface SimpleSend as IPSender; //for pings
    provides interface Receive as IPReceive;
}

implementation{
    components IPForwardingP;
    components new SimpleSendC(AM_FORWARDING); //sending outbound packets componenet 
    components new AMReceiverC(AM_FORWARDING); //recieving packets coming inbound componenet

    components LinkRoutingC; 

    IPForwardingP.LinkRouting -> LinkRoutingC.LinkRouting;

    IPForwardingP.Sender -> SimpleSendC;
    IPForwardingP.InternalReceiver -> AMReceiverC;

    //might need to fix these two lines (naming)
    IPReceive = IPForwardingP.IPReceive;
    SimpleSend = IPForwardingP.IPSender; 
}

