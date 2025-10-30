// the neighborDiscover.nc file is responsible for the things that need to boot up prior to the program starting 
//this is where the interface is declared and the starting functions listed ''
interface NeighborDiscovery{
	command void start();
	command void print();
	command uint16_t* getNeighborList();
	command uint8_t getNeighborCount();
}