#include<Timer.h>

//This is the file where the main logic goes 

//by declaring this as a generic module, we are able to use this for multiple purposes 
generic module NeighborDiscoveryP(){
    //we need to connect to the .nc file which stores the precursers of what we need 
    provides interface NeighborDiscovery;

    //TMili allows for bidirectional connections between nodes, giving it an alias
    use interface Timer<TMilli> as neighborTimer;
    
    //to be able to communicate with other nodes without collision -> configured in .nc file
    uses interface Random;
}


implementation {
    //when findNeighbors is called the timers are fired at a random interval between 100--399 ms 
    command void NeighborDiscovery.findNeighbors(){
        call neighborTimer.startOneShot(100+ (call Random.rand16() %300));
    }
    
    task void search() {
        "logic: send the msg, if somebody responds, save its id inside table"
         call neighborTimer.startPeriodic(100+ (call Random.rand16() %300));
    }

    event void neighborTimer.fired(){
        post search();
    }


    command  void NeighborDiscovery.printNeighbors();
}