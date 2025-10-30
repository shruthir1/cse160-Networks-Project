#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
// #define TIMEOUT_MAX 15
#define LIST_SIZE 256
#define MAX_NEIGHBORS 12

module LinkRoutingP{
    provides interface LinkRouting;
    
    uses interface Timer<TMilli> as LSATimer; 
    uses interface SimpleSend as Sender; 
    uses interface Receive as FloodReceive;
    uses interface NeighborDiscovery;
}

implementation{
    /* Link State Routing Concept: 

    if (All LSA received):
        check: is LSA seq appropriate (should not be one we've seen or less than what weve seen)
        UPDATE TOPOLOGY
        Run Djkstra 
            (record shortest path and back up paths/costs)
    */

    typedef struct {
        uint16_t origin; 
        uint16_t seq; 
        uint8_t count; 
        // uint8_t protocol;
        uint8_t neighbors[MAX_NEIGHBORS];
    } lsa_payload_t;


    uint16_t seq[LIST_SIZE];
    uint8_t topology[LIST_SIZE][LIST_SIZE];

    uint16_t nextHop[LIST_SIZE];

    uint16_t seqNum = 0;

    command void LinkRouting.start(){
         call LSATimer.startPeriodic(5000);
    }

    event void LSATimer.fired(){
        uint8_t i = 0;
        uint8_t nCount = call NeighborDiscovery.getNeighborCount();
        uint16_t* neighborList = call NeighborDiscovery.getNeighborList();
        lsa_payload_t lsa;
        lsa.origin = TOS_NODE_ID;
        lsa.seq = seqNum++;
        lsa.count = nCount; 
        // lsa.protocol = PROTOCOL_LINKSTATE;

        if (nCount > MAX_NEIGHBORS) nCount = MAX_NEIGHBORS;

        for (i = 0; i < nCount; i++) {
            lsa.neighbors[i] = (uint8_t)neighborList[i];
        }

        pack msg; 
        msg.src = TOS_NODE_ID;
        msg.dest = AM_BROADCAST_ADDR;
        msg.protocol = PROTOCOL_LINKSTATE;
        msg.TTL = 15;
        memcpy(msg.payload, &lsa, sizeof(lsa_payload_t));

        
        call Sender.send(msg, AM_BROADCAST_ADDR);
        dbg("linkstate", "Node %u sent LSA seq=%u (%u neighbors)\n", TOS_NODE_ID, lsa.seq, lsa.count);

       
        
    }

    event message_t* FloodReceive.receive(message_t* msg, void* payload, uint8_t len){
        pack* p = (pack*) payload; 
        uint8_t i = 0; 

        //because we only want to deal with linkstate packets we return everything else 
        if (p->protocol != PROTOCOL_LINKSTATE) {
            return msg; 
        }

        lsa_payload_t* lsa = (lsa_payload_t*) p->payload; 

        if(lsa->seq <= seq[lsa->origin]){
            return msg; 
        }

        seq[lsa->origin] = lsa->seq;
        
        //not sure if these two for loops are neccesary 
        for(i = 0; i < LIST_SIZE; i++){
            topology[lsa->origin][i] = 0;
            topology[i][lsa->origin] = 0;
        }

        for (i = 0; i < lsa->count; i++) {
            uint16_t neighbor = lsa->neighbors[i];
            topology[lsa->origin][neighbor] = 1;
            topology[neighbor][lsa->origin] = 1;
        }

         call LinkRouting.shortestPath();

         return msg;
    }

    command void LinkRouting.shortestPath(){
        uint8_t visited[LIST_SIZE];
        uint16_t cost[LIST_SIZE];
        uint8_t parent[LIST_SIZE];
        uint8_t i = 0; 
        uint8_t c = 0;
        uint8_t min = -1;
        uint8_t minCost = 0;

        for(i = 0; i < LIST_SIZE; i++){
            cost[i] = 0xFFFF;
            visited[i] = 0;
            parent[i] = -1;
            nextHop[i] = 0xFFFF;
        }

        cost[TOS_NODE_ID] = 0;

        for(c = 0; c < LIST_SIZE -1; c++ ){
            min = -1; 
            minCost = 0xFFFF;
            for (i = 0; i < LIST_SIZE; i++){
                if(!visted[i] && cost[i] <= minDist){
                    minCost = cost[i];
                    min = i; 
                }
            }

            if(min == -1) break; 
            visited[min] = 1;

            for(i = 0; i < LIST_SIZE; i++){
                if(topology[min][i] && !visited[i] && cost[min] +1 < cost[i]){
                    cost[i] = cost[min];
                    parent[i] = min;
                }
            }

        }


        for(i = 0; i< LIST_SIZE; i++){
            int hop = i; 
            if(i == TOS_NODE_ID || cost[i] == 0xFFFF) continue;

            while (prev[hop] != -1 && parent[hop] != TOS_NODE_ID){
                hop = parent[hop];
            }

            if(parent[hop] == TOS_NODE_ID){
                nextHop[i] = hop;
            }
        }

    }


    command uint16_t LinkRouting.getNextHop(uint16_t dest){
        if(dest >= LIST_SIZE) return 0xFFFF;
        retrn nextHop[dest];
    }

    command void LinkRouting.print(){
        uint8_t i = 0;
        for( i =0; i < LIST_SIZE; i++){
            if(nextHop[i] != 0xFFFF && i != TOS_NODE_ID){
                dbg("linkstate", "  Dest %u → NextHop %u\n", i, nextHop[i]);
            }
        }
    }


}