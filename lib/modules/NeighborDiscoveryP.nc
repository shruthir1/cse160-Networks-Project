#include "../../includes/channels.h" 
#include "../../includes/packet.h" 

#define BEACON_PERIOD 1000 //every one second we send a message 
#define MAX_NEIGHBORS 20 // because there are twenty nodes so far 
#define TIMEOUT 5   // neighbor TTL ends after 5 beacon intervals

module NeighborDiscoveryP {
    //shared interface between this file and c file 
    provides interface NeighborDiscovery;

    //because we send and recieive packets over time intervals 
    uses interface Timer<TMilli> as beaconTimer;
    uses interface SimpleSend;
    uses interface Receive;
}

implementation {
    // Neighbor table, creating an array 
    uint16_t neighbors[MAX_NEIGHBORS]; //neighbors that respond 
    uint8_t timeouts[MAX_NEIGHBORS]; //neighbors that didnt respond 
    uint8_t count = 0; // # of repsonive neighbors -> index that we are on for the arrays 

    command void NeighborDiscovery.start() {
        call beaconTimer.startPeriodic(BEACON_PERIOD); //start the timer when program starts
    }

    command void NeighborDiscovery.print() {
        //dbg(NEIGHBOR_CHANNEL, "Current neighbors:\n");
        uint8_t i = 0;
        for ( i = 0; i < count; i++) {
            dbg(NEIGHBOR_CHANNEL, "  Node %d (ttl=%d)\n", neighbors[i], timeouts[i]);
        }
    }

//when the timer is fired:
    event void beaconTimer.fired() {
        uint8_t j = 0; 
        uint8_t i = 0;
        pack msg; //defining the message
        
        // Broadcast a beacon packet this is from the table he shows in the video - APP layer
        msg.src = TOS_NODE_ID; //this nodes source address
        msg.dest = AM_BROADCAST_ADDR; //destination address 
        msg.protocol = PROTOCOL_PING; // use proper protocol instead of empty string (empty string was giving me bugs)
        msg.seq = 0; //sequence number (this way we know what # packet we are sending/recivieng) -> useful for detencing duplicates
        strcpy(msg.payload, "Hellooo"); //set the payload 

       // dbg(NEIGHBOR_CHANNEL, "Boop: sending beacon...\n"); 
        call SimpleSend.send(msg, AM_BROADCAST_ADDR); //send the packet to neighbors

        // Decrement TTLs everytime the packets makes a hop
        for ( i = 0; i < count; i++) {
            if (timeouts[i] > 0) {
                timeouts[i]--;
            }
            //if the neighbor's TTL is 0 then we did not hear from the neighbor over five beancon periods 
            if (timeouts[i] == 0) {
                //dbg(NEIGHBOR_CHANNEL, "Neighbor %d timed out, removing.\n", neighbors[i]);
                //remove the neighbor 
                for ( j = i; j < count - 1; j++) {
                    neighbors[j] = neighbors[j + 1]; //shift left 
                    timeouts[j] = timeouts[j + 1];
                }
                count--; //unresponsive neighbor then count reduces
                i--; // decrement i since we shifted elements down
            }
        }
    }

    
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack* p;
        uint8_t i;
        bool found;
        
        //if packet size is not whats expected we drop packet 
        if (len != sizeof(pack)) return msg;
        
        //view payload 
        p = (pack*) payload;

        //we know we discovered a neighbor if the payload is the neighbor discovery message 
        if (strcmp(p->payload, "Hellooo") == 0) {
            dbg(NEIGHBOR_CHANNEL, "Received beacon from %d\n", p->src);

            // After receiving packet Check if already in neighbor table (if it has same src address)
            found = FALSE; 
            //loops through all neighbors 
            for (i = 0; i < count; i++) {
                //if the packet matches the rest of the neighbors we know the neighbor is still active
                if (neighbors[i] == p->src) {
                    timeouts[i] = TIMEOUT; //saying neighbor is still active 
                    break; 
                }
            }

            // If new neighbor found then add them into the table 
            if (!found && count < MAX_NEIGHBORS) {
                neighbors[count] = p->src; //add the new neighbors source id 
                timeouts[count] = TIMEOUT; //update TTL table 
                count++; //increase # of neighbors we found 
                //debug message that prints when the connection is made over neighbor channel 
                dbg(NEIGHBOR_CHANNEL, "Added new neighbor %d\n", p->src);
            }
        }

        return msg; //when you run recieve.recieve you use its buffer, at the end you have to return it 
    }
}