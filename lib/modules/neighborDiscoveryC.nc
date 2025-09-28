// Configuration file always has the wiring of the modules schematics 
#define AM_NEIGHBOR 62 //we pick and define a random number so the packets being sent with this attribvute are neighbor discovery packets
//in xxx.nc and xxxC.nc we always list the interface being used or provided in generic configuration
 configuration NeighborDiscoveryC{
	//this is the common characterstic between c and p files because 
    provides interface NeighborDiscovery;
}

implementation{
    //ALWAYS need a componet that represents xxxP.nc file, because the whole point is that we connect the xxxP.nc file to the interfaces we'll use 
	components NeighborDiscoveryP;
    // we use "new" when we dont want a global instance of the component 
    //these componenets will create seperate instasnces for each communication endpoint without interfering w one another 
	components new TimerMilliC() as timer; //timer for when messages are fired 
	components new SimpleSendC(AM_NEIGHBOR) as ssc; //this line is binding an AM id to the sender 
	components new AMReceiverC(AM_NEIGHBOR) as rc; //this line is binding an AM id to the reciver
    // ^^ by binding these am id's to sender and reciver the purpose of the packet send becomes clear
    //so the packets handled by these componenets will only have the id 54

	// Wiring the neighborDiscovery interface with the components we created to the logic file 
	NeighborDiscovery = NeighborDiscoveryP.NeighborDiscovery;

    //connecting the interfaces we are going to use in the P file to the components we declared here 
	NeighborDiscoveryP.SimpleSend -> ssc;
	NeighborDiscoveryP.Receive -> rc;
	NeighborDiscoveryP.timer -> timer;
}