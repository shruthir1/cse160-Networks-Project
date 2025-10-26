// #define AM_FLOODING 10 

configuration FloodingC{

	provides interface SimpleSend as FloodSender;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
	// provides interface Flooding; 
}

implementation{

	components FloodingP; 
	components new SimpleSendC(AM_PACK);
	components new AMReceiverC(AM_PACK);
	
	FloodingP.InternalSender -> SimpleSendC;
	FloodingP.InternalReceiver -> AMReceiverC;
	// Flooding = FloodingP.Flooding; 
	 
	MainReceive = FloodingP.MainReceive;
	ReplyReceive = FloodingP.ReplyReceive;
	FloodSender = FloodingP.FloodSender;

}

