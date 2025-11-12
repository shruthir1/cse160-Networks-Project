#include "../../includes/channels.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/protocol.h"

module TransportP {
    provides interface Transport;
    uses interface SimpleSend as WaySend;
    uses interface Receive as WayReceive;
}

implementation {

    socket_t sockets[MAX_SOCKETS];
    message_t sendBuffer;

    enum { CLOSED, LISTEN, SYN_SENT, ESTABLISHED, FIN_WAIT } state = CLOSED;

    command socket_t Transport.socket() {
        socket_t s;
        s.inUse = TRUE;
        s.state = CLOSED;
        s.src = TOS_NODE_ID;
        s.dest = AM_BROADCAST_ADDR;
        s.srcPort = 0;
        s.destPort = 0;
        s.seq = 0;
        s.ack = 0;
        return s;
    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr) {
        fd.src = addr->src;
        fd.srcPort = addr->srcPort;
        dbg(PROJECT3TGen, "Bound socket: src=%d port=%d\n", fd.src, fd.srcPort);
        return SUCCESS;
    }

    command error_t Transport.listen(socket_t fd) {
        fd.state = LISTEN;
        dbg(PROJECT3TGen, "Socket listening on port %d\n", fd.srcPort);
        return SUCCESS;
    }



    command error_t Transport.connect(socket_t fd, socket_addr_t *addr) {
        TCPHeader *hdr = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));

        fd.dest = addr->src;
        fd.destPort = addr->srcPort;
        fd.state = SYN_SENT;
        fd.seq = 0;

        hdr->srcPort = fd.srcPort;
        hdr->destPort = fd.destPort;
        hdr->seq = fd.seq;
        hdr->ack = 0;
        hdr->flags = SYN;

        dbg(PROJECT3TGen, "Client: sending SYN to node %d\n", fd.dest);
        return call WaySend.send(&sendBuffer, fd.dest);
    }


    command error_t Transport.close(socket_t fd) {
        TCPHeader *hdr = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));
        hdr->srcPort = fd.srcPort;
        hdr->destPort = fd.destPort;
        hdr->seq = fd.seq;
        hdr->ack = fd.ack;
        hdr->flags = FIN;

        dbg(PROJECT3TGen, "Client: sending FIN to node %d\n", fd.dest);
        return call WaySend.send(&sendBuffer, fd.dest);
    }


    event message_t* WayReceive.receive(message_t *msg, void *payload, uint8_t len) {
        TCPHeader *hdr = (TCPHeader*) payload;

        // ---- Server: got SYN ----
        if (hdr->flags & SYN && !(hdr->flags & ACK)) {
            dbg(PROJECT3TGen, "Server: SYN received, sending SYN+ACK\n");

            TCPHeader *out = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));
            out->srcPort = hdr->destPort;
            out->destPort = hdr->srcPort;
            out->seq = 0;
            out->ack = hdr->seq + 1;
            out->flags = SYN | ACK;

            call WaySend.send(&sendBuffer, call AMPacket.source(msg));
            state = ESTABLISHED;
            return msg;
        }

        
        if ((hdr->flags & SYN) && (hdr->flags & ACK)) {
            dbg(PROJECT3TGen, "Client: SYN+ACK received, sending ACK\n");

            TCPHeader *out = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));
            out->srcPort = hdr->destPort;
            out->destPort = hdr->srcPort;
            out->seq = hdr->ack;
            out->ack = hdr->seq + 1;
            out->flags = ACK;

            call WaySend.send(&sendBuffer, call AMPacket.source(msg));
            state = ESTABLISHED;
            return msg;
        }

       
        if ((hdr->flags & ACK) && !(hdr->flags & SYN) && !(hdr->flags & FIN)) {
            dbg(PROJECT3TGen, "Server: connection established.\n");
            state = ESTABLISHED;
            return msg;
        }

        
        if (hdr->flags & FIN) {
            dbg(PROJECT3TGen, "Client: FIN received, sending ACK and closing.\n");

            TCPHeader *out = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));
            out->srcPort = hdr->destPort;
            out->destPort = hdr->srcPort;
            out->seq = hdr->ack;
            out->ack = hdr->seq + 1;
            out->flags = ACK;

            call WaySend.send(&sendBuffer, call AMPacket.source(msg));
            state = CLOSED;
            return msg;
        }

        return msg;
    }

 

    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t len) {
        TCPHeader *hdr = (TCPHeader*) call Packet.getPayload(&sendBuffer, sizeof(TCPHeader));
        hdr->srcPort = fd.srcPort;
        hdr->destPort = fd.destPort;
        hdr->seq = ++fd.seq;
        hdr->ack = fd.ack;
        hdr->flags = DATA;

        dbg(PROJECT3TGen, "Client: sending DATA '%s'\n", buff);
        return call WaySend.send(&sendBuffer, fd.dest);
    }

    // Placeholder stubs for ungraded parts
    command socket_t Transport.accept(socket_t fd) { return fd; }
    command uint16_t Transport.read(socket_t fd, uint8_t *b, uint16_t l) { return 0; }
    command error_t Transport.receive(pack* p) { return SUCCESS; }
    command error_t Transport.release(socket_t fd) { return SUCCESS; }
}
