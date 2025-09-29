
//we will be sending packets over channels so we need these header files
#include "../../includes/channels.h"
#include "../../includes/packet.h"

#define MAX_HISTORY 50   // store recent (src,seq) pairs to prevent loops, but we dont want to store it too many times

module FloodingP {
    //external interfaces  (exisits outside of module and we're using here)
    provides interface SimpleSend as FloodSender; //for sending packets
    provides interface Receive as MainReceive;   //for recieivng ping packets  
    provides interface Receive as ReplyReceive; //for recieving ping REPLY packets 

    //internal interfaces (from wiring in C file and for this particular implementation)
    uses interface SimpleSend as InternalSender;
    uses interface Receive as InternalReceiver;
    //^^ these two interfaces are used for actual radio communication
}

implementation {
    uint16_t seq = 0;  //sequence number for outgoing packets 
    //^this helps us keep track of missing packets -> ties into scalability 

    // History of seen packets
    uint16_t seen_src[MAX_HISTORY]; // all the sources we've seen -> this way we can track duplicates easily 
    uint16_t seen_seq[MAX_HISTORY]; //all the sequence numbers we've seen -> this way we can find if packet missing as well  
    uint8_t history_count = 0; //how much history we've already recorded

    //to check if we've seen before we need to see the source and the sequence number, if these both exist in our table, we have a packet weve already processed. 
    bool seenBefore(uint16_t src, uint16_t s) {
        uint8_t i;  
        for (i = 0; i < history_count; i++) {
            //if the packet we've recieved has matching src and sequence then we HAVE seen it before
            if (seen_src[i] == src && seen_seq[i] == s) return TRUE;
        }
        return FALSE; //otherwise we have not seen it 
    }


    //add the seen packet's source and sequence to our array of seen id's
    void addHistory(uint16_t src, uint16_t s) {
        uint8_t i;  // Declare variable at top for C89 compliance
        
        if (history_count < MAX_HISTORY) {
            seen_src[history_count] = src; //add curr source address to table
            seen_seq[history_count] = s; //add curr sequence to table 
            history_count++;
        } else {
            // overwrite oldest - shift array left IF table is full
            for (i = 1; i < MAX_HISTORY; i++) {
                seen_src[i-1] = seen_src[i]; //move to the left 
                seen_seq[i-1] = seen_seq[i];
            }
            //after shifting add new values to the table 
            seen_src[MAX_HISTORY-1] = src;
            seen_seq[MAX_HISTORY-1] = s;
        }
    }

    command error_t FloodSender.send(pack msg, uint16_t dest) {
        msg.src = TOS_NODE_ID; // this is the source node
        msg.dest = dest; // we input the destination node 
        msg.seq = seq++; //as we send packets the sequence should increment 
        msg.TTL = 10; // initial TTL
        //this will 
        dbg(FLOODING_CHANNEL, "Sending Flood: %s to %d\n", msg.payload, dest);
        //broadcast packet to all neighbors 
        return call InternalSender.send(msg, AM_BROADCAST_ADDR);
    }

    //packet reception 
    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len) {
        pack* p;    
        pack forward_msg;  // Create copy for forwarding
        
        //if packet size is not expected size then usually something is wrong and packet is dropped 
        if (len != sizeof(pack)) return msg; //we need to make sure the size of the packet matches the expected packet size 
        
        //extract payload/message from the packet we recieved 
        p = (pack*) payload;

        //printing what we received (?)
        dbg(FLOODING_CHANNEL, "Received packet src=%d dest=%d seq=%d ttl=%d payload=%s\n",
            p->src, p->dest, p->seq, p->TTL, p->payload);

        // Drop packet if already seen (avoiding duplicates)
        if (seenBefore(p->src, p->seq)) {
            dbg(FLOODING_CHANNEL, "Already seen, dropping.\n");
            return msg;
        }
        //if we havent seen packet before, then record source and sequence 
        addHistory(p->src, p->seq);

        // Drop if TTL expired
        if (p->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL expired, dropping.\n");
            return msg;
        }

        // If final destination is this node 
        if (p->dest == TOS_NODE_ID) {
            //if this is a packet we received that we do not need to send a reply to, receive packet 
            if (p->protocol == PROTOCOL_PING) {  // Use PROTOCOL_PING instead of PING
                dbg(FLOODING_CHANNEL, "Delivering to MainReceive\n");
                signal MainReceive.receive(msg, payload, len);
            } else if (p->protocol == PROTOCOL_PINGREPLY) {  // Use PROTOCOL_PINGREPLY
               //if this is a packet we need to send a reply to, recieve the packet then send a reply 
                dbg(FLOODING_CHANNEL, "Delivering to ReplyReceive\n");
                signal ReplyReceive.receive(msg, payload, len);
            }
            return msg;
        }

        // Not final destination: forward because of flooding logic 
        // Create a copy of the packet to forward (don't modify original) to all neighbors 
        forward_msg = *p; // this is the packet we are forwarding
        forward_msg.TTL--; // after we send to our neighbors we used a hop
        dbg(FLOODING_CHANNEL, "Forwarding packet (ttl now %d)\n", forward_msg.TTL);
        //send the packet
        call InternalSender.send(forward_msg, AM_BROADCAST_ADDR);

        return msg;
    }
    
    // Default event handlers for the provided interfaces
    //basically what this is doing is that if no one is listening
    //then we should do nothing except return the message to the buffer 
    //this prevents run time crashes because we'll have signaled events that arent wired properly 
    default event message_t* MainReceive.receive(message_t* msg, void* payload, uint8_t len) {
        return msg; //if no one is listening then return message to buffer 
    }
    
    default event message_t* ReplyReceive.receive(message_t* msg, void* payload, uint8_t len) {
        return msg; // if no one is listening then return message to buffer here too 
    }
}
