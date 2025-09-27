#include "includes/packet.h"
//#include<Timer.h>
//#include "includes/am_types.h"
//P.nc file is where the logic goes, wiring is mostly done here work is done 
#include "../../includes/channels.h"

//module vs. generic module: the generic module can take in paramters, module defines a single instance 
 module FloodingP(){
    provides interface Flooding;
    provides interface Receive; 
    //uses interface Receive 
    uses interface SimpleSend as sender;
    uses interface Random; 
}

implementation {
  
    }

   

