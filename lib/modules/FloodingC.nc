// Configuration
#define AM_FLOODING 79

configuration FloodingC{
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
}

implementation{
	components FloodingP;
	components new SimpleSendC(AM_FLOODING);
	components new AMReceiverC(AM_FLOODING);
	

	FloodingP.InternalSender -> SimpleSendC;
	FloodingP.InternalReceiver -> AMReceiverC;
	

	MainReceive = FloodingP.MainReceive;
	ReplyReceive = FloodingP.ReplyReceive;
	SimpleSend = FloodingP.FloodSender;
}