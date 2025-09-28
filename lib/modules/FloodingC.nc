#include <Timer.h> 
#include "includes/packet.h"
#include "am_types.h"

configuration FloodingC{
	provides interface SimpleSend;
	provides interface Receive as MainReceive;
	provides interface Receive as ReplyReceive;
}

implementation{
	components FloodingP;
	components new SimpleSendC(AM_FLOODING);
	components new AMReceiverC(AM_FLOODING);
	
	// Wire Internal Components
	FloodingP.InternalSender -> SimpleSendC;
	FloodingP.InternalReceiver -> AMReceiverC;
	
	// Provide External Interfaces.
	MainReceive = FloodingP.MainReceive;
	ReplyReceive = FloodingP.ReplyReceive;
	SimpleSend = FloodingP.FloodSender;
}