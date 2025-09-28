#include "../../includes/channels.h"
#include "../../includes/packet.h"

#define MAX_HISTORY 50   // store recent (src,seq) pairs to prevent loops

module FloodingP {
    provides interface SimpleSend as FloodSender;
    provides interface Receive as MainReceive;
    provides interface Receive as ReplyReceive;

    uses interface SimpleSend as InternalSender;
    uses interface Receive as InternalReceiver;
}

implementation {
    int seq = 0;

    // History of seen packets
    uint16_t seen_src[MAX_HISTORY];
    uint16_t seen_seq[MAX_HISTORY];
    uint8_t history_count = 0;

    bool seenBefore(uint16_t src, uint16_t s) {
        for (int i = 0; i < history_count; i++) {
            if (seen_src[i] == src && seen_seq[i] == s) return TRUE;
        }
        return FALSE;
    }

    void addHistory(uint16_t src, uint16_t s) {
        if (history_count < MAX_HISTORY) {
            seen_src[history_count] = src;
            seen_seq[history_count] = s;
            history_count++;
        } else {
            // overwrite oldest
            for (int i = 1; i < MAX_HISTORY; i++) {
                seen_src[i-1] = seen_src[i];
                seen_seq[i-1] = seen_seq[i];
            }
            seen_src[MAX_HISTORY-1] = src;
            seen_seq[MAX_HISTORY-1] = s;
        }
    }

    command error_t FloodSender.send(pack msg, uint16_t dest) {
        msg.src = TOS_NODE_ID;
        msg.dest = dest;
        msg.seq = seq++;
        msg.TTL = 10; // initial TTL
        dbg(FLOODING_CHANNEL, "Sending Flood: %s to %d\n", msg.payload, dest);
        return call InternalSender.send(msg, AM_BROADCAST_ADDR);
    }

    event message_t* InternalReceiver.receive(message_t* msg, void* payload, uint8_t len) {
        if (len != sizeof(pack)) return msg;
        pack* p = (pack*) payload;

        dbg(FLOODING_CHANNEL, "Received packet src=%d dest=%d seq=%d ttl=%d payload=%s\n",
            p->src, p->dest, p->seq, p->TTL, p->payload);

        // Drop if already seen
        if (seenBefore(p->src, p->seq)) {
            dbg(FLOODING_CHANNEL, "Already seen, dropping.\n");
            return msg;
        }
        addHistory(p->src, p->seq);

        // Drop if TTL expired
        if (p->TTL == 0) {
            dbg(FLOODING_CHANNEL, "TTL expired, dropping.\n");
            return msg;
        }

        // If final destination
        if (p->dest == TOS_NODE_ID) {
            if (p->protocol == PING) {
                dbg(FLOODING_CHANNEL, "Delivering to MainReceive\n");
                signal MainReceive.receive(msg, payload, len);
            } else if (p->protocol == PING_REPLY) {
                dbg(FLOODING_CHANNEL, "Delivering to ReplyReceive\n");
                signal ReplyReceive.receive(msg, payload, len);
            }
            return msg;
        }

        // Not final destination: forward
        p->TTL--;
        dbg(FLOODING_CHANNEL, "Forwarding packet (ttl now %d)\n", p->TTL);
        call InternalSender.send(*p, AM_BROADCAST_ADDR);

        return msg;
    }
}
