// Configuration
#define AM_FLOODING 10 //picking the number (same as header file) that when the program recieves it, it knows its a flooding call 

configuration FloodingC{
	//provides interface Flooding;
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
}

implementation{
	components FloodingP; //always need to wire to the logic module 
	components new SimpleSendC(AM_FLOODING);
	components new AMReceiverC(AM_FLOODING);
	
	//wire FloodingP's internal interfaces to the components that send/receive 
	FloodingP.InternalSender -> SimpleSendC;
	FloodingP.InternalReceiver -> AMReceiverC;
	
	//this makes FloodingP's interfaces available to Node.nc so it can connect to other modules too 
	MainReceive = FloodingP.MainReceive;
	ReplyReceive = FloodingP.ReplyReceive;
	SimpleSend = FloodingP.FloodSender;
}