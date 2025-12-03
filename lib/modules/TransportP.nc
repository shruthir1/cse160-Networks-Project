#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPPacket.h"
#include <Timer.h>

module TransportP {
    provides interface Transport;
    uses interface Timer<TMilli> as TCPtimer;
    uses interface SimpleSend as Sender;
    uses interface Receive;
    // uses interface PacketHandler;
    uses interface Queue<message_t*> as packetQueue; //tinyOS has its own Queue interface :D 
    uses interface Queue<socket_store_t *> as socketQueue;
    uses interface Pool<message_t> as packetPool;
    uses interface Pool<socket_store_t> as socketPool;
    uses interface Packet;
}

implementation {

    pack myMsg;
    tcp_pack myTCPPack;
    uint8_t tcpPayload[TCP_PACKET_MAX_PAYLOAD_SIZE];
    
    //defining these functions at the top of the file to be used before function is defined (in case function is used before) 
    socket_t getSocket(uint8_t destPort, uint8_t srcPort);
    socket_t getServerSocket(uint8_t destPort);
    void makeTCPpack(tcp_pack* tcpPack, uint8_t destPort, uint8_t srcPort, uint16_t seq, uint8_t ACK, uint8_t lastACK, uint8_t flags, uint8_t window, uint8_t* payload);
    void dumpPack(pack* pkt);
    void dumpTCP(tcp_pack* tcp);

    void dumpPack(pack* pkt){
        // dbg(TRANSPORT_CHANNEL, "source: %d, dest: %d, protocol: %d, payload: %28x\n", pkt->src, pkt->dest, pkt->protocol, pkt->payload);
        logPack(pkt, TRANSPORT_CHANNEL);
    } 

    void dumpTCP(tcp_pack* tcp){
        dbg(TRANSPORT_CHANNEL, "destPort: %d, srcPort: %d, seq: %d, ACK: %d, lastACK: %d, flags: %d, window: %d, payload: %12x\n", tcp->destPort, tcp->srcPort, tcp->seq, tcp->ACK, tcp->lastACK, tcp->flags, tcp->window, tcp->payload);
    }


    // void makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    event void TCPtimer.fired(){
        // pack myMsg = call packetQueue.head(); //returns first packet in the queue 
       
    }

    socket_t getSocket (uint8_t destPort, uint8_t srcPort){
        socket_store_t *sock;
        uint16_t i = 0;
        uint16_t size = call socketQueue.size();

        for(i = 0; i < size-1; i++){
             sock = call socketQueue.element(i);
            if(sock->dest.port == destPort && sock->src == srcPort){
                return i;
            }
        }

        return -1;
    }

        // nx_uint8_t destPort;
        // 	nx_uint8_t srcPort;
        // 	nx_uint8_t seq;
        // 	nx_uint8_t ACK;
        // 	nx_uint8_t lastACK;
        // 	nx_uint8_t flags;
        // 	nx_uint8_t window;
        // 	nx_uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];
     void makeTCPpack(tcp_pack* tcpPack, uint8_t destPort, uint8_t srcPort, uint16_t seq, uint8_t ACK, uint8_t lastACK, uint8_t flags, uint8_t window, uint8_t* payload){
        tcpPack->destPort = destPort;
        tcpPack->srcPort = srcPort;
        tcpPack->seq = seq;
        tcpPack->ACK = ACK;
        tcpPack->lastACK = lastACK;
        tcpPack->flags = flags;
        tcpPack->window = window;

        memcpy(tcpPack->payload, payload, TCP_PACKET_MAX_PAYLOAD_SIZE);
    }


    command socket_t Transport.socket(){
        //get a socket if one is available state should be closed 
        socket_store_t sockStore; //this is on the stack scope does not extend after function ends
        dbg(TRANSPORT_CHANNEL, "socket()\n");
        sockStore.state = CLOSED;
        sockStore.flag = 0;
        sockStore.src = 0;
        sockStore.dest.port = 0;
        sockStore.dest.addr = 0;
        // dbg(TRANSPORT_CHANNEL, "fd before enqueue: %d\n", call socketQueue.size());
        call socketPool.put(&sockStore);
        call socketQueue.enqueue(&sockStore);
        // dbg(TRANSPORT_CHANNEL, "returning fd: %d\n", call socketQueue.size());
        return call socketQueue.size();

    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){ 
        //bind a socket with an address 
        //get() is giving a copy of whats in the list by using a pointer we're able to interact what whats directly in the list (and change it)
        socket_store_t *mySocket;
        dbg(TRANSPORT_CHANNEL, "bind()\n");
        // dbg(TRANSPORT_CHANNEL, "fd: %d\n", fd);
        if(fd <= 0 || fd > call socketQueue.size() || addr == NULL){
            dbg(TRANSPORT_CHANNEL, "invalid parameter\n");
            return FAIL;
        }
        mySocket = call socketQueue.element(fd-1);
        //err handling 
        if(mySocket == NULL){
            dbg(TRANSPORT_CHANNEL, "socket was invalid");
            return FAIL;
        }
        dbg(TRANSPORT_CHANNEL, "mySocket: %p\n", mySocket);
        //only use arrows on pointer vars 
        dbg(TRANSPORT_CHANNEL, "mySocket.src before: %d, addr->port: %d\n", mySocket->src, addr->port);
        mySocket->src = addr->port;
        dbg(TRANSPORT_CHANNEL, "mySocket.src after: %d\n", mySocket->src);
        //mySocket.state does not change on bind()

        return SUCCESS;
        
    }

    command socket_t Transport.accept(socket_t fd){
        /* * @return socket_t - returns a new socket if the connection is
         accepted. this socket is a copy of the server socket but with
         a destination associated with the destination address and port.
        if not return a null socket.
        */

        //basically needs to return a newly connected socket 


    }
    
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        // return success if able to send 
    }

    task void send(){
        dbg(TRANSPORT_CHANNEL, "SEND TASK\n");
        dumpPack(&myMsg);
        dumpTCP(&myTCPPack);
        call Sender.send(myMsg, 1);

    }


    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        // @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
       //this is where the iniating connection part of my pseudocode is happening 
        error_t sent;
        
        socket_store_t *Qsocket = call socketQueue.element(fd -1);
        //ends up being randomized 

        //setting up the SYN packet
        // myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
        makeTCPpack(&myTCPPack, addr->port, 21, 1, 0, 0, SYN_FLAG, 0, tcpPayload);
        //making initial SYN pack
        call Sender.makePack(&myMsg, TOS_NODE_ID, addr->addr, PROTOCOL_TCP, (uint8_t*)&myTCPPack, sizeof(tcp_pack)); //because a SYN packet has no TCP payload
        Qsocket->state = SYN_SENT;
        dbg(TRANSPORT_CHANNEL, "Node %u State is %u \n", TOS_NODE_ID, Qsocket->state);
        // dbg(TRANSPORT_CHANNEL, "dest addr: %d, addr->addr: %d, protocol: %d\n", myMsg.dest, addr->addr, myMsg.protocol);
        dumpPack(&myMsg);
        post send();
        // sent = call Sender.send(myMsg, addr->addr);
        // dbg(TRANSPORT_CHANNEL, "Packet sent status: %d\n", sent);
        Qsocket->dest.port = addr->port;
        Qsocket->dest.addr = addr->addr;
        Qsocket->src = 21;
        // call Transport.receive(&myMsg);

        // if(Qsocket->state == SYN_SENT){
        //     //should confirm that syn-ack was received

        //     Qsocket->state = ESTABLISHED;
        //     dbg(TRANSPORT_CHANNEL, "ACK recieved, there's a connection!\n");
            
        // }

        return SUCCESS;
    
    }

    //when a packet is recieved there are multiple courses of action 
    command error_t Transport.receive(pack* msg){
        uint8_t srcPort = 0;
        uint8_t destPort = 0;
        uint8_t seq = 0;
        uint8_t lastAck = 0;
        uint8_t flags = 0;
        pack myNewMsg;
        socket_store_t *Qsocket;
        //packet for replying 
        tcp_pack* myTCPPack;
        //casting pack to tcp_pack type 
        tcp_pack* myMsg = (tcp_pack*)(msg->payload);
        myTCPPack = (tcp_pack*)(myNewMsg.payload);
         //error handling 
        if(msg == NULL){
            dbg(TRANSPORT_CHANNEL, "recieved packet is null\n");
            return FAIL;
        }
        if(msg->protocol != PROTOCOL_TCP){
            return SUCCESS;
        }
        dbg(TRANSPORT_CHANNEL, "received a packet! : %p\n", msg);
        dbg(TRANSPORT_CHANNEL, "source: %d, dest: %d, protocol: %d, payload: %28x \n", msg->src, msg->dest, msg->protocol, msg->payload);
        dbg(TRANSPORT_CHANNEL, "parsing packet now\n");
        // myMsg = call Packet.getPayload(msg, sizeof(tcp_pack));
        // dbg(TRANSPORT_CHANNEL, "myMsg: %p\n", myMsg);
        // nx_uint8_t destPort;
        // nx_uint8_t srcPort;
        // nx_uint8_t seq;
        // nx_uint8_t ACK;
        // nx_uint8_t lastACK;
        // nx_uint8_t flags;
        // nx_uint8_t window;
        // nx_uint8_t payload[TCP_PACKET_MAX_PAYLOAD_SIZE];
        dbg(TRANSPORT_CHANNEL, "myMsg->destPort: %d\n", myMsg->destPort);
        dbg(TRANSPORT_CHANNEL, "myMsg->srcPort: %d\n", myMsg->srcPort);
        dbg(TRANSPORT_CHANNEL, "myMsg->seq: %d\n", myMsg->seq);
        dbg(TRANSPORT_CHANNEL, "myMsg->ACK: %d\n", myMsg->ACK);
        dbg(TRANSPORT_CHANNEL, "myMsg->lastACK: %d\n", myMsg->lastACK);
        dbg(TRANSPORT_CHANNEL, "myMsg->flags: %d\n", myMsg->flags);
        dbg(TRANSPORT_CHANNEL, "myMsg->window: %d\n", myMsg->window);
        dbg(TRANSPORT_CHANNEL, "myMsg->payload: %12x\n", myMsg->payload);


        //extract TCP header info from received packet 
        srcPort = myMsg->srcPort;
        destPort = myMsg->destPort;
        seq = myMsg->ACK;
        flags = myMsg->flags;

        Qsocket = call socketQueue.element(getSocket(srcPort, destPort));
        

        if(Qsocket->state == LISTEN && flags == SYN_FLAG ){
            //we no longer need to listen for a SYN, we recieved one 
             
            dbg(TRANSPORT_CHANNEL, "server received a SYN!");
            Qsocket->state = SYN_RCVD;
            myTCPPack->destPort = Qsocket->dest.port;
            myTCPPack->srcPort = Qsocket->src;
            myTCPPack->seq = 1;
            myTCPPack->ACK = (myTCPPack->seq)++;
            myTCPPack->flags = SYN_ACK_FLAG;
            call Sender.makePack(&myNewMsg, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, 0, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myNewMsg, Qsocket->dest.addr);
            dbg(TRANSPORT_CHANNEL, "just sent SYN-ACK packet\n");
            // call Transport.listen(fd); //call listen again so we can evalute SYN_RCVD??

        } 
        

        if (Qsocket->state == SYN_RCVD && flags == SYN_ACK_FLAG ){
            //SENDER SENDS LAST ACK
            dbg(TRANSPORT_CHANNEL, "Client Received SYN-ACK, sending ACK \n");
            Qsocket->state = ESTABLISHED; //connection has now been established, machine state changed
            myTCPPack->destPort = Qsocket->dest.port;
            myTCPPack->srcPort = Qsocket->src;
            myTCPPack->seq = 1;
            myTCPPack->ACK = (myTCPPack->seq)++;
            myTCPPack->flags = ACK_FLAG;

            call Sender.makePack(&myNewMsg, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, 0,  PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myNewMsg, Qsocket->dest.addr);

            dbg(TRANSPORT_CHANNEL, "sent SYN-ACK to client, client connection establsihed\n");
        }

        if (Qsocket->state == SYN_RCVD && flags == ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "ACK recieved, server connected!");
                Qsocket->state = ESTABLISHED; //now connection is established between two nodes, so machine state should be connected 
        }

        if(Qsocket->state == FIN_WAIT_1 && flags == FIN_FLAG){
            //SENDER needs to receive both FIN and ACK from server, usually ACK comes first 
            Qsocket->state = FIN_WAIT_2;
            
        }

        if(Qsocket->state == FIN_WAIT_2){
            //SENDER
            Qsocket->state = TIME_WAIT;
            //supposed to wait some time in case retranmissions need to happen and then state == closed
            //also need to send lastAck from client side 
            myTCPPack->destPort = Qsocket->dest.port;
            myTCPPack->srcPort = Qsocket->src; //not sure if this should be initialized to be random
            myTCPPack->seq = 1; //this needs to the ack of the prev packet
            myTCPPack->ACK = (myTCPPack->seq)++;
            myTCPPack->flags = FIN_ACK;

            dbg(TRANSPORT_CHANNEL, "sending last ACK from Client Side\n");
            call Sender.makePack(&myNewMsg, Qsocket->dest.addr, PROTOCOL_TCP, myTCPPack, 0, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myNewMsg, Qsocket->dest.addr);
            
            
        }
         if(Qsocket->state == TIME_WAIT){
            //SENDER
            //needs to wait a bit first

            Qsocket->state == CLOSED;
        }
         if(Qsocket->state == CLOSE_WAIT){
            //RECIEVER
            //sends a FIN and an ACK 
            //sending the ACK
            myTCPPack->destPort = Qsocket->dest.port;
            myTCPPack->srcPort = Qsocket->src;
            myTCPPack->ACK = 0; //this should be based off the incoming FIN's seq (i think)
            myTCPPack->flags = ACK_FLAG;
            myTCPPack->seq = 1;
            call Sender.makePack(&myNewMsg, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, NULL, 0); //because a SYN packet has no TCP payload
            call Sender.send(myNewMsg, Qsocket->dest.addr);

            //sending the fin
            myTCPPack = (tcp_pack*)(myMsg->payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
            myTCPPack->destPort = Qsocket->dest.port;
            myTCPPack->srcPort = Qsocket->src;
            myTCPPack->ACK = 0; //same number as the ack packet being sent 
            myTCPPack->flags = FIN_FLAG;
            myTCPPack->seq = 2; //this needs to be a new num than the ack packet
            call Sender.makePack(&myNewMsg, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, NULL, 0); //because a SYN packet has no TCP payload
            call Sender.send(myNewMsg, Qsocket->dest.addr);

            dbg(ROUTING_CHANNEL, "Acknowledging close, sending ACK and FIN \n");
            Qsocket->state == LAST_ACK;
            // call Transport.close(fd); //call close again when state changes and is not yet == CLOSED??

        }

        


    }

    

    socket_t getServerSocket(uint8_t destination){
        //
    }

    command error_t Transport.listen(socket_t fd){
        //* @return error_t - returns SUCCESS if you are able change the state to listen else FAIL.
       
        socket_store_t *Qsocket = call socketQueue.element(fd -1);

        //server now waits until SYN packet is sent 
        // pack myMsg;
        // tcp_pack* myTCPPack;
        // myTCPPack = (tcp_pack*)(myMsg.payload);

        Qsocket->state = LISTEN;

        return SUCCESS; 
    }

    
    
    
    
    command error_t Transport.close(socket_t fd){
        //where the connection closes, if state is etablished: start fin send
        
        socket_store_t *Qsocket = call socketQueue.element(fd -1);

        

        pack myMsg;
        tcp_pack* myTCPPack;
    
         // mySocket.dest.port = ;
         // mySocket.dest.addr = msg->src; 
        

        if(Qsocket->state == ESTABLISHED){
            //send fin pack the receiver does not call close() when state is established
            //SENDER 
            myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
            myTCPPack->destPort =  Qsocket->src; //not sure if this is right I if we're sending back then dest/src switch?
            myTCPPack->srcPort = Qsocket->dest.port;;
            myTCPPack->ACK = 0; //also not sure if this is right 
            myTCPPack->flags = FIN_FLAG;
            myTCPPack->seq = 1; //how to make this random, should it be random? 
            //sending
            call Sender.makePack(&myMsg, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, NULL, 0); //NULL because a FIN packet has no TCP payload
            Qsocket->state = FIN_WAIT_1;
            dbg(ROUTING_CHANNEL, "Starting close, send FIN \n");
            call Sender.send(myMsg, Qsocket->dest.addr);

        }else{
            Qsocket->state = CLOSED;
        }
    }

    command error_t Transport.release(socket_t fd){
        //@return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
        //not sure what the different between this and close is?? I think this one is asking if the state is closed then return true 
       
        socket_store_t *Qsocket = call socketQueue.element(fd -1);
        if(Qsocket == NULL) return FAIL;
        if(Qsocket->state == CLOSED){
            return SUCCESS;
        }else{ 
            return FAIL;
        }
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){

    }

    task void processTCPpacket(){
        message_t* raw_msg;
        pack* pkt;
        void *payload;
        error_t err;
        if(! call packetQueue.empty()){
            raw_msg = call packetQueue.dequeue();
            payload = call Packet.getPayload(raw_msg, sizeof(pack));

            if(!payload){
                call packetPool.put(raw_msg);
                post processTCPpacket();
                return;
            }

            pkt = (pack*) payload;
            // dbg(TRANSPORT_CHANNEL, "got packet: %p\n", pkt);
            
            dbg(TRANSPORT_CHANNEL, "source: %d, dest: %d, protocol: %d\n", pkt->src, pkt->dest, pkt->protocol);
            err = call Transport.receive(pkt);

            call packetPool.put(raw_msg);
        }

        if(! call packetQueue.empty()){
            post processTCPpacket();
        }
    }

     event message_t* Receive.receive(message_t* raw_msg, void* payload, uint8_t len){
        if (! call packetPool.empty()){
            // dbg(TRANSPORT_CHANNEL, "Receive.receive()\n");
            call packetQueue.enqueue(raw_msg);
            post processTCPpacket();
            return call packetPool.get();
        }
        return raw_msg;
    }

}
