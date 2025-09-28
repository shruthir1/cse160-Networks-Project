#include "../../includes/channels.h"
#include "../../includes/packet.h"

#define BEACON_PERIOD 1000
#define MAX_NEIGHBORS 10
#define TIMEOUT 5   // each neighbor is kept alive for 5 beacon intervals

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface Timer<TMilli> as beaconTimer;
    uses interface SimpleSend;
    uses interface Receive;
}

implementation {
    // Neighbor table
    uint16_t neighbors[MAX_NEIGHBORS];
    uint8_t timeouts[MAX_NEIGHBORS];
    uint8_t count = 0;

    // -----------------------------
    // Commands
    // -----------------------------

    command void NeighborDiscovery.start() {
        // Periodic beacon messages
        call beaconTimer.startPeriodic(BEACON_PERIOD);
    }

    command void NeighborDiscovery.print() {
        dbg(NEIGHBOR_CHANNEL, "Current neighbors:\n");
        for (int i = 0; i < count; i++) {
            dbg(NEIGHBOR_CHANNEL, "  Node %d (ttl=%d)\n", neighbors[i], timeouts[i]);
        }
    }

    // -----------------------------
    // Timer Event
    // -----------------------------
    event void beaconTimer.fired() {
        // Send beacon
        pack msg;
        msg.src = TOS_NODE_ID;
        msg.dest = AM_BROADCAST_ADDR;
        msg.protocol = 0;
        msg.seq = 0;
        strcpy(msg.payload, "BEACON");

        dbg(NEIGHBOR_CHANNEL, "Sending beacon...\n");
        call SimpleSend.send(msg, AM_BROADCAST_ADDR);

        // Decrement TTLs
        for (int i = 0; i < count; i++) {
            if (timeouts[i] > 0) {
                timeouts[i]--;
            }
            if (timeouts[i] == 0) {
                dbg(NEIGHBOR_CHANNEL, "Neighbor %d timed out, removing.\n", neighbors[i]);
                // Shift left to remove neighbor
                for (int j = i; j < count - 1; j++) {
                    neighbors[j] = neighbors[j + 1];
                    timeouts[j] = timeouts[j + 1];
                }
                count--;
            }
        }
    }

    // -----------------------------
    // Receive Event
    // -----------------------------
    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        pack* p = (pack*) payload;

        dbg(NEIGHBOR_CHANNEL, "Received beacon from %d\n", p->src);

        // Check if already in neighbor table
        bool found = FALSE;
        for (int i = 0; i < count; i++) {
            if (neighbors[i] == p->src) {
                timeouts[i] = TIMEOUT; // refresh timeout
                found = TRUE;
                break;
            }
        }

        // If new neighbor
        if (!found && count < MAX_NEIGHBORS) {
            neighbors[count] = p->src;
            timeouts[count] = TIMEOUT;
            count++;
            dbg(NEIGHBOR_CHANNEL, "Added new neighbor %d\n", p->src);
        }

        return msg;
    }
}
