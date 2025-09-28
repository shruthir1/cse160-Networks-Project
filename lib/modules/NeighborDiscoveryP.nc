// #include "../../includes/channels.h"
// #include "../../includes/packet.h"

// #define BEACON_PERIOD 1000
// #define MAX_NEIGHBORS 10
// #define TIMEOUT 5   // neighbor timeout after 5 beacon intervals

// module NeighborDiscoveryP {
//     provides interface NeighborDiscovery;

//     uses interface Timer<TMilli> as beaconTimer;
//     uses interface SimpleSend;
//     uses interface Receive;
// }

// implementation {
//     // Neighbor table, creating an array 
//     uint16_t neighbors[MAX_NEIGHBORS]; //meighbors that respond 
//     uint8_t timeouts[MAX_NEIGHBORS]; //neighbors that didnt respond 
//     uint8_t count = 0;

//     command void NeighborDiscovery.start() {
//         call beaconTimer.startPeriodic(BEACON_PERIOD); //start the timer when program starts
//     }

//     command void NeighborDiscovery.print() {
//         //dbg(NEIGHBOR_CHANNEL, "Current neighbors:\n");
//         uint8_t i = 0;
//         for ( i = 0; i < count; i++) {
//             dbg(NEIGHBOR_CHANNEL, "  Node %d (ttl=%d)\n", neighbors[i], timeouts[i]);
//         }
//     }

// //when the timer is fired:
//     event void beaconTimer.fired() {
//         uint8_t j = 0; 
//         uint8_t i =0;
//         // Broadcast a beacon packet this is from the table he shows in the video - APP layer
//         pack msg; //defining the message
//         msg.src = TOS_NODE_ID; //this nodes source address
//         msg.dest = AM_BROADCAST_ADDR; //destination address 
//         msg.protocol = "";
//         msg.seq = 0; //sequence number 
//         strcpy(msg.payload, "BEACON"); //set the payload 

//        // dbg(NEIGHBOR_CHANNEL, "Boop: sending beacon...\n"); 
//         call SimpleSend.send(msg, AM_BROADCAST_ADDR); //send the packet through a broadcast

//         // Decrement TTLs everytime the packets makes a hop
//         for ( i = 0; i < count; i++) {
//             if (timeouts[i] > 0) {
//                 timeouts[i]--;
//             }
//             //if the neighbor times out then we need to delete the neighbor from the list
//             if (timeouts[i] == 0) {
//                 //dbg(NEIGHBOR_CHANNEL, "Neighbor %d timed out, removing.\n", neighbors[i])
//                 for ( j = i; j < count - 1; j++) {
//                     neighbors[j] = neighbors[j + 1];
//                     timeouts[j] = timeouts[j + 1];
//                 }
//                 count--; //responsive neighbor count reduces
//             }
//         }
//     }

//     //
//     event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
//         if (len != sizeof(pack)) return msg;
//         pack* p = (pack*) payload;

//         if (strcmp(p->payload, "BEACON") == 0) {
//             uint8_t i =0;
//             dbg(NEIGHBOR_CHANNEL, "Received beacon from %d\n", p->src);

//             // Check if already in neighbor table
//             bool found = FALSE;
//             for ( i = 0; i < count; i++) {
//                 if (neighbors[i] == p->src) {
//                     timeouts[i] = TIMEOUT; // refresh
//                     found = TRUE;
//                 }
//             }

//             // If new neighbor
//             if (!found && count < MAX_NEIGHBORS) {
//                 neighbors[count] = p->src;
//                 timeouts[count] = TIMEOUT;
//                 count++;
//                 dbg(NEIGHBOR_CHANNEL, "Added new neighbor %d\n", p->src);
//             }
//         }

//         return msg;
//     }
// }
#include "../../includes/channels.h"
#include "../../includes/packet.h"

#define BEACON_PERIOD 1000
#define MAX_NEIGHBORS 10
#define TIMEOUT 5   // neighbor timeout after 5 beacon intervals

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as beaconTimer;
    uses interface SimpleSend;
    uses interface Receive;
}

implementation {
    // Neighbor table, creating an array 
    uint16_t neighbors[MAX_NEIGHBORS]; //neighbors that respond 
    uint8_t timeouts[MAX_NEIGHBORS]; //neighbors that didnt respond 
    uint8_t count = 0;

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
        // Declare ALL variables at the top - C89 style required by nesC
        uint8_t j = 0; 
        uint8_t i = 0;
        pack msg; //defining the message
        
        // Broadcast a beacon packet this is from the table he shows in the video - APP layer
        msg.src = TOS_NODE_ID; //this nodes source address
        msg.dest = AM_BROADCAST_ADDR; //destination address 
        msg.protocol = PROTOCOL_PING; // Fixed: use proper protocol instead of empty string
        msg.seq = 0; //sequence number 
        strcpy(msg.payload, "BEACON"); //set the payload 

       // dbg(NEIGHBOR_CHANNEL, "Boop: sending beacon...\n"); 
        call SimpleSend.send(msg, AM_BROADCAST_ADDR); //send the packet through a broadcast

        // Decrement TTLs everytime the packets makes a hop
        for ( i = 0; i < count; i++) {
            if (timeouts[i] > 0) {
                timeouts[i]--;
            }
            //if the neighbor times out then we need to delete the neighbor from the list
            if (timeouts[i] == 0) {
                //dbg(NEIGHBOR_CHANNEL, "Neighbor %d timed out, removing.\n", neighbors[i]);
                for ( j = i; j < count - 1; j++) {
                    neighbors[j] = neighbors[j + 1];
                    timeouts[j] = timeouts[j + 1];
                }
                count--; //responsive neighbor count reduces
                i--; // Important: decrement i since we shifted elements down
            }
        }
    }

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        // Declare ALL variables at the top of the function - THIS WAS THE MAIN ISSUE
        pack* p;
        uint8_t i;
        bool found;
        
        if (len != sizeof(pack)) return msg;
        
        p = (pack*) payload;

        if (strcmp(p->payload, "BEACON") == 0) {
            dbg(NEIGHBOR_CHANNEL, "Received beacon from %d\n", p->src);

            // Check if already in neighbor table
            found = FALSE;
            for (i = 0; i < count; i++) {
                if (neighbors[i] == p->src) {
                    timeouts[i] = TIMEOUT; // refresh
                    found = TRUE;
                    break; // Added break for efficiency
                }
            }

            // If new neighbor
            if (!found && count < MAX_NEIGHBORS) {
                neighbors[count] = p->src;
                timeouts[count] = TIMEOUT;
                count++;
                dbg(NEIGHBOR_CHANNEL, "Added new neighbor %d\n", p->src);
            }
        }

        return msg;
    }
}