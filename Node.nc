/*
 * ANDES Lab - University of California, Merced
 * Basic functions of a network node.
 */

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

module Node {
    uses interface Boot;

    uses interface SplitControl as AMControl;
    uses interface Receive;

    uses interface SimpleSend as Sender;
    uses interface CommandHandler;

    uses interface NeighborDiscovery;
}

implementation {
    pack sendPackage;

    // Prototypes
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL,
                  uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

    event void Boot.booted() {
        call AMControl.start();
        
        // ADD DEBUG MESSAGE TO CONFIRM THIS IS CALLED
        // dbg(GENERAL_CHANNEL, "Node %d: About to start neighbor discovery\n", TOS_NODE_ID);
        
        // Start neighbor discovery
        call NeighborDiscovery.start();
        // call Flooding.simpleSend();
        
        // ADD ANOTHER DEBUG MESSAGE
        // dbg(GENERAL_CHANNEL, "Node %d: Neighbor discovery start() called\n", TOS_NODE_ID);

        dbg(GENERAL_CHANNEL, "Booted\n");
    }

    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            dbg(GENERAL_CHANNEL, "Radio On\n");
            // ADD DEBUG MESSAGE HERE TOO
            dbg(GENERAL_CHANNEL, "Node %d: Radio is now on, neighbor discovery should start working\n", TOS_NODE_ID);
        } else {
            // Retry until successful
            call AMControl.start();
        }
    }

    event void AMControl.stopDone(error_t err) {}

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
        // dbg(GENERAL_CHANNEL, "Packet Received\n");
        if (len == sizeof(pack)) {
            pack* myMsg = (pack*) payload;
            // dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
            // dbg(FLOODING_CHANNEL, "SRC: %d, Message: %s\n" myMsg->src, myMsg->payload);
            return msg;
        }
        // dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
        return msg;
    }

    event void CommandHandler.ping(uint16_t destination, uint8_t *payload) {
        dbg(GENERAL_CHANNEL, "PING EVENT \n");
        makePack(&sendPackage, TOS_NODE_ID, destination, 0, 0, 0,
                 payload, PACKET_MAX_PAYLOAD_SIZE);
        call Sender.send(sendPackage, destination);
    }

    event void CommandHandler.printNeighbors() {
        //  delegate to NeighborDiscovery
        dbg(GENERAL_CHANNEL, "Node %d: printNeighbors called\n", TOS_NODE_ID);
        call NeighborDiscovery.print();
    }

    event void CommandHandler.printRouteTable(){}
    event void CommandHandler.printLinkState(){}
    event void CommandHandler.printDistanceVector(){}
    event void CommandHandler.setTestServer(){}
    event void CommandHandler.setTestClient(){}
    event void CommandHandler.setAppServer(){}
    event void CommandHandler.setAppClient(){}

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL,
                  uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
    }
}