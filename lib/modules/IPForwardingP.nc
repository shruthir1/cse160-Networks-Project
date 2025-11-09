#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"

module IPForwardingP{
    provides interface SimpleSend as IPSender;
    provides interface Receive as IPReceive;

    uses interface SimpleSend as Sender;
    uses interface Receive as InternalReceiver; 

    uses interface LinkRouting;
}


/* The logic (from the video) for this module should be: 
if packet.destination = this node 
    send to local module 
    return;
else if packet protocol == flooding or linkstate or ND 
    pass to local module 
else 
    next hop = reference routing table
    if nextHop exists 
        TTL--
        forwardPacket 
        return;
    else
        drop packet
        return;
*/

implementation{

    command error_t IPSender.send(pack msg, uint16_t dest){
        if(dest == AM_BROADCAST_ADDR){
            dbg(ROUTING_CHANNEL, "Sending broadcast packet\n");
            return call Sender.send(msg, dest);
        }

        uint16_t nextHop = call LinkRouting.getNextHop(dest);
        // nextHop = call LinkRouting.getNextHop(dest);

        if(nextHop < 1 || nextHop >= 0xFFFF){ //(i hope) using 999 to indicate invalid node
                dbg(ROUTING_CHANNEL, "Route wasn't found, next hop was invalid\n");
                return FAIL;
        }

        dbg(ROUTING_CHANNEL, "Next Hop: %u, Final Dest: %u\n", nextHop, dest);
        call Sender.send(msg, nextHop); // actual sending to next dest 
        return SUCCESS;
        
    }


    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len){
        pack *myMsg = (pack *) payload;
        uint16_t curr = 0; 
        uint16_t nextHop = 0; 

        //if its ND or FLooding we return, not dealt with here 
        if (myMsg->protocol != PROTOCOL_PING && myMsg->protocol != PROTOCOL_PINGREPLY) {
            signal IPReceive.receive(msg, payload, len);
            return msg;
        }

        //when packet is meant for this node 
        if(myMsg->dest == TOS_NODE_ID){
            if(myMsg->protocol == PROTOCOL_PING){
                //sending ping reply
                curr = myMsg->src;
				myMsg->src = myMsg->dest;
				myMsg->dest = curr;
                myMsg->protocol = PROTOCOL_PINGREPLY;
				myMsg->TTL = 15;
                call IPSender.send(*myMsg, myMsg->dest);
            }else{
                //ping was delivered locally 
            }

            return msg;
            
        }

        myMsg->TTL--;
        if(myMsg->TTL <= 0) {
            dbg(ROUTING_CHANNEL, "dropping packet\n");
            return msg;
        }

        nextHop = call LinkRouting.getNextHop(myMsg->dest);

        if(nextHop < 1 || nextHop >= 0xFFFF) {
            //invalid hop, dropping packet 
            return msg;
        }
       
        dbg(ROUTING_CHANNEL, "Dest: %u Next Hop: %u\n", myMsg->dest, nextHop);
        
        call IPSender.send(*myMsg, nextHop);
        return msg;
    }

    default event message_t* IPReceive.receive(message_t* msg, void* payload, uint8_t len) {
    return msg;
}
}
