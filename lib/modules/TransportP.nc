#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPPacket.h"
#include <Timer.h>

module TransportP {
    provides interface Transport;
    uses interface Timer<TMilli> as TCPtimer; //retranmission timer
    uses interface Timer<TMilli> as timeWaitTimer; //timer for TIME_WAIT on close 
    uses interface SimpleSend as Sender;
    uses interface Receive;
    uses interface PacketHandler;
    uses interface Queue<message_t*> as packetQueue; //tinyOS has its own Queue interface :D 
    uses interface Queue<socket_store_t*> as timeWaitQueue;
    uses interface Queue<socket_store_t *> as socketQueue;
    uses interface Queue<pack*> as sendQueue;
    uses interface Pool<message_t> as packetPool;
    uses interface Pool<pack> as sendPool;
    uses interface Pool<socket_store_t> as socketPool;
    uses interface Packet;
}

implementation {

    pack outgoingPack;
    tcp_pack outgoingTCPPack;
    uint8_t tcpPayload[TCP_PACKET_MAX_PAYLOAD_SIZE];
    
    //defining these functions at the top of the file to be used before function is defined (in case function is used before) 
    // socket_t getSocket(uint8_t destPort, uint8_t srcPort);
    socket_t getServerSocket(uint8_t destPort);
    void makeTCPpack(tcp_pack* tcpPack, uint8_t destPort, uint8_t srcPort, uint16_t seq, uint8_t ACK, uint8_t lastACK, uint8_t flags, uint8_t window, uint8_t* payload);
    void dumpPack(pack* pkt);
    void dumpTCP(tcp_pack* tcp);
    char* socketFlag(uint8_t flag);
    char* socketState(enum socket_state state);
    void dumpSocket(socket_store_t * sock);

    //dumpPack() will display the contents of a packet for debugging purposes
    void dumpPack(pack* pkt){
        // dbg(TRANSPORT_CHANNEL, "source: %d, dest: %d, protocol: %d, payload: %28x\n", pkt->src, pkt->dest, pkt->protocol, pkt->payload);
        logPack(pkt, TRANSPORT_CHANNEL);
    } 

    //dumpTCP() will display the contents of a tcp header packet for purposes
    void dumpTCP(tcp_pack* tcp){
        dbg(TRANSPORT_CHANNEL, "destPort: %d, srcPort: %d, seq: %d, ACK: %d, lastACK: %d, flags: %s, window: %d, payload: %12x\n", tcp->destPort, tcp->srcPort, tcp->seq, tcp->ACK, tcp->lastACK, socketFlag(tcp->flags), tcp->window, tcp->payload);
    }

    char* socketFlag(uint8_t flag){
        switch(flag){
            case DATA_FLAG:
                return "DATA";
                break;
            case DATA_ACK_FLAG:
                return "DATA ACK";
                break;
            case SYN_FLAG:
                return "SYN";
                break;
            case SYN_ACK_FLAG:
                return "SYN ACK";
                break;
            case ACK_FLAG:
                return "ACK";
                break;
            case FIN_FLAG:
                return "FIN";
                break;
            case FIN_ACK:
                return "FIN ACK";
                break;
            default: 
                return "UNKNOWN";
                break;
            
        }
    }

    char* socketState(enum socket_state state){
        switch(state){
            case CLOSED:
                return "CLOSED";
                break;
            case LISTEN:
                return "LISTEN";
                break;
            case ESTABLISHED:
                return "ESTABLISHED";
                break;
            case SYN_SENT:
                return "SYN SENT";
                break;
            case SYN_RCVD:
                return "SYN RECEIVED";
                break;
            case CLOSE_WAIT:
                return "CLOSE_WAIT";
                break;
            case LAST_ACK:
                return "LAST ACK";
                break;
            case FIN_WAIT_1:
                return "FIN WAIT 1";
                break;
            case FIN_WAIT_2:
                return "FIN WAIT 2";
                break;
            case TIME_WAIT:
                return "TIME_WAIT";
                break;
            default:
                return "UNKNOWN STATE";
                break;
        }   
    }

    void dumpSocket(socket_store_t * sock){
        dbg(TRANSPORT_CHANNEL, "flag: %s, state: %s, src: %d, dest.addr: %d, dest.port: %d\n", socketFlag(sock->flag), socketState(sock->state), sock->src, sock->dest.addr, sock->dest.port);
    
    }

    /*
      TCP retransmit timer is expired, this is for reliability 
      Want to check if the last queue element is equal to the lastAck time, 
      if not equal, we want to retransmit everything that was not yet acked 
      this references the queue where we store each packets getNow() + RTT (expected arrival time)
    */
    event void TCPtimer.fired(){
        // pack outgoingPack = call packetQueue.head(); //returns first packet in the queue 
       
    }

    
    //obtain corresponding socket fd given destination and source ports 
    //this function is used to find socket when fd is not passed as parameter, but we have packet information 
    command socket_t Transport.getSocket (uint8_t destPort, uint8_t srcPort){
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
    
    //creates TCP header packet by setting all struct members to intended values
    //have been using this to alter the global var outgoingTCPPack to accomodate each tcp header flag change
    //outgoingTCPPack becomes the payload for IP packet that we're going to transmit
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

    //obtains a socket, state must be closed because state hasn't changed yet 
    command socket_t Transport.socket(){
        //get a socket if one is available state should be closed 
        socket_store_t * sockStore; //this is on the stack scope does not extend after function ends
        dbg(TRANSPORT_CHANNEL, "socket()\n");
        sockStore = call socketPool.get(); //similar to malloc()
        sockStore->state = CLOSED;
        sockStore->flag = 255;
        sockStore->src = 255;
        sockStore->dest.port = 255;
        sockStore->dest.addr = 255;
        // dbg(TRANSPORT_CHANNEL, "fd before enqueue: %d\n", call socketQueue.size());
        dumpSocket(sockStore);
        call socketQueue.enqueue(sockStore);
        // dbg(TRANSPORT_CHANNEL, "returning fd: %d\n", call socketQueue.size());
        return call socketQueue.size();

    }

    //attaches the inputted address to the socket.src, this address will then be assosiated with the socket
    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){  
        //get() is giving a copy of whats in the list by using a pointer we're able to interact what whats directly in the list (and change it)
        socket_store_t *mySocket;
        dbg(TRANSPORT_CHANNEL, "bind()\n");
        // dbg(TRANSPORT_CHANNEL, "fd: %d\n", fd);
        if(fd <= 0 || fd > call socketQueue.size() || addr == NULL){
            dbg(TRANSPORT_CHANNEL, "invalid parameter\n");
            return FAIL;
        }
        // dbg(TRANSPORT_CHANNEL, "socketQueue.size() = %d\n", call socketQueue.size());
        mySocket = call socketQueue.element(fd-1);
        //err handling 
        if(mySocket == NULL){
            dbg(TRANSPORT_CHANNEL, "socket was invalid\n");
            return FAIL;
        }
        dbg(TRANSPORT_CHANNEL, "mySocket: %p\n", mySocket);
        //only use arrows on pointer vars 
        dbg(TRANSPORT_CHANNEL, "mySocket.src before: %d, addr->port: %d\n", mySocket->src, addr->port);
        mySocket->src = addr->port;
        // dbg(TRANSPORT_CHANNEL, "mySocket.src after: %d\n", mySocket->src);
        dumpSocket(mySocket);
        //mySocket.state does not change on bind()

        return SUCCESS;
        
    }

    
    command socket_t Transport.accept(socket_t fd){
        /* * @return socket_t - returns a new socket if the connection is
         accepted. this socket is a copy of the server socket but with
         a destination associated with the destination address and port.
        if not return a null socket.
        */
        dbg(TRANSPORT_CHANNEL, "accept()\n");
        //going to be signaled from Transport.recieve();
        //basically needs to return a newly connected socket 


    }
    
    //application puts what is in its buffer into the TCP buffer for server to ack
    /*
        bool isWrapped = FALSE;
        if(lastSend > lastAck) isWrapped = TRUE;
        if(!isWrapped):
            if(lastSent - lastAcked <= window)
                makeTCPpack()
                makePack()
                send pack

                transmissionqueue.dequeue(getNow + RTT)
                call TCPtimer
                lastByteSend += packetLength
        */
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        // SENDER SIDE -- here is where the sliding window happens
        bool isWrapped;
        uint16_t bytesWritten;
        pack * sendPack;

        //socket we are writing from 
        socket_store_t *Qsocket = call socketQueue.element(fd);
        
        dbg(TRANSPORT_CHANNEL, "write()");
        if(Qsocket->state != ESTABLISHED) return 0; //all other states indicated we are still in handshake 
        if(Qsocket->lastWritten < Qsocket->lastAck){
            isWrapped = TRUE; 
        } else{
            isWrapped = FALSE;
        } 

        //if pool is empty then we dont have data to send, sendPool stores all the packets we want to send 
        if(! call sendPool.empty()) return 0;

        sendPack = call sendPool.get(); 


        if(!isWrapped){
            if(Qsocket->lastSent - Qsocket->lastAck < Qsocket->effectiveWindow){
                //data being put into the buffer should not be larger than the buffer size 
               if(Qsocket->lastAck + bufflen <= SOCKET_BUFFER_SIZE){
                    //copying from socket into buffer 
                    memcpy(&Qsocket->sendBuff[Qsocket->lastAck], buff, bufflen);
                    bytesWritten = bufflen;

               }else{
                    //if we are out of bounds then we only send the amount of data that would not overwhelm the buffer
                    memcpy(&Qsocket->sendBuff[Qsocket->lastAck], buff, SOCKET_BUFFER_SIZE - Qsocket->lastAck);
                    bytesWritten = SOCKET_BUFFER_SIZE - Qsocket->lastAck;
               }
            }
        }else{ //if window is wrapped 
            //we flip the subtraction statement
            if(Qsocket->lastAck - Qsocket->lastSent < Qsocket->effectiveWindow){
                //checking if in bounds again
                if(Qsocket->lastAck + bufflen <= SOCKET_BUFFER_SIZE){
                    memcpy(&Qsocket->sendBuff[Qsocket->lastAck], buff, bufflen);
                    bytesWritten = bufflen;
                }else{
                    //if not in bounds only send capable data amount 
                    memcpy(&Qsocket->sendBuff[Qsocket->lastAck], buff, SOCKET_BUFFER_SIZE - Qsocket->lastAck);
                    bytesWritten = SOCKET_BUFFER_SIZE - Qsocket->lastAck;

                }
            }
        }

        //make and send the TCP back to the server to load of their buffer and read 
        makeTCPpack(&outgoingTCPPack, Qsocket->dest.addr, Qsocket->src, outgoingTCPPack.seq, Qsocket->lastAck,  Qsocket->lastWritten, DATA_FLAG, Qsocket->effectiveWindow, buff );
        call Sender.makePack(&outgoingPack,  Qsocket->dest.addr, TOS_NODE_ID, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack) );
       //this should be done in a task that pulls of a queue 
        call Sender.send(outgoingPack,  Qsocket->dest.addr);
        //we should also be recording the time this was sent into the transmission queue 

        //sliding the window 
        Qsocket->lastWritten+= bytesWritten;
        Qsocket-> lastAck+= bytesWritten;
        return bytesWritten;
            
    }

    //debugging send/receive
    task void send(){
        dbg(TRANSPORT_CHANNEL, "SEND TASK\n");
        dumpPack(&outgoingPack);
        dumpTCP(&outgoingTCPPack);
        call Sender.send(outgoingPack, 1);

    }


    //handshake begins here, intial SYN packet sent and state changed, done by CLIENT only 
    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        // @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
       //this is where the iniating connection part of my pseudocode is happening 
        error_t sent;
        
        socket_store_t *Qsocket = call socketQueue.element(fd -1);
        //ends up being randomized 

        //setting up the SYN packet
        dbg(TRANSPORT_CHANNEL, "called transport.connect()\n");
        makeTCPpack(&outgoingTCPPack, addr->port, Qsocket->src, 1, 0, 0, SYN_FLAG, 0, tcpPayload);
        //making initial SYN pack
        call Sender.makePack(&outgoingPack, TOS_NODE_ID, addr->addr, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack)); //because a SYN packet has no TCP payload
        Qsocket->state = SYN_SENT;
        // dbg(TRANSPORT_CHANNEL, "Node %u State is %u \n", TOS_NODE_ID, Qsocket->state);
        dumpSocket(Qsocket);
        // dbg(TRANSPORT_CHANNEL, "dest addr: %d, addr->addr: %d, protocol: %d\n", outgoingPack.dest, addr->addr, outgoingPack.protocol);
        dumpPack(&outgoingPack);
        post send();
        // sent = call Sender.send(outgoingPack, addr->addr);
        // dbg(TRANSPORT_CHANNEL, "Packet sent status: %d\n", sent);
        Qsocket->dest.port = addr->port;
        Qsocket->dest.addr = addr->addr;
        Qsocket->src = 21;
    

        return SUCCESS;
    
    }

    /*  PROCESSES ALL INCOMING PACKETS 
        when a packet is recieved there are multiple courses of action:
        this handles handshake and teardown, receives SYN and FIN while transmitting 
        the next corresponding SYN-ACK, FIN's, and ACK's
    */
    command error_t Transport.receive(pack* msg){
        uint8_t srcPort = 0;
        uint8_t destPort = 0;
        uint8_t seq = 0;
        uint8_t lastAck = 0;
        uint8_t flags = 0;
        uint8_t ACK = 0;
        pack newPack;
        socket_store_t *Qsocket;
        //packet for replying 
        tcp_pack* incomingTCPpack = (tcp_pack*)(msg->payload);
        // dbg(TRANSPORT_CHANNEL, "called transport.receive()\n");
        makeTCPpack(&outgoingTCPPack, incomingTCPpack->destPort,incomingTCPpack->srcPort, incomingTCPpack->ACK, (incomingTCPpack->seq)++, incomingTCPpack->lastACK, incomingTCPpack->flags,  incomingTCPpack->window, tcpPayload);
      
        //ERROR HANDLING 
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
        // outgoingPack = call Packet.getPayload(msg, sizeof(tcp_pack));
        // dbg(TRANSPORT_CHANNEL, "outgoingPack: %p\n", outgoingPack);
    
        //debug using dumpTCP and check global var usage here 
        // dumpTCP(&outgoingTCPPack); //this is the packet we loaded info into and created
        // dumpTCP(&incomingTCPpack); //this is the incoming tcp header


        Qsocket = call socketQueue.element(call Transport.getSocket(srcPort, destPort));
        
        //HANDSHAKE: RECEIVING SYN FROM CLIENT, SENDING SYN-ACK FROM SERVER
        //state change: LISTEN -> SYN_RCVD
        if(Qsocket->state == LISTEN && flags == SYN_FLAG ){
            //we no longer need to listen for a SYN, we recieved one 
            dbg(TRANSPORT_CHANNEL, "server received a SYN!");
            Qsocket->state = SYN_RCVD;
            makeTCPpack(&outgoingTCPPack, Qsocket->dest.port, Qsocket->src, outgoingTCPPack.seq +1, 1, incomingTCPpack->lastACK, SYN_ACK_FLAG,  incomingTCPpack->window, tcpPayload);
            // newPack = (pack*) outgoingTCPPack; 
            call Sender.makePack(&outgoingPack, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack));
            call Sender.send(outgoingPack, Qsocket->dest.addr);
            dbg(TRANSPORT_CHANNEL, "just sent SYN-ACK packet\n");
            // call Transport.listen(fd); //call listen again so we can evalute SYN_RCVD??

        } 
        
        //HANDSHAKE: RECEIVING SYN-ACK FROM SERVER, SENDING ACK FROM CLIENT 
        //state change: SYN_SENT -> ESTABLISHED
        if (Qsocket->state == SYN_SENT && flags == SYN_ACK_FLAG ){
            //SENDER SENDS LAST ACK
            dbg(TRANSPORT_CHANNEL, "Client Received SYN-ACK, sending ACK \n");
            Qsocket->state = ESTABLISHED; //connection has now been established, machine state changed
            makeTCPpack(incomingTCPpack, Qsocket->dest.port, Qsocket->src, outgoingTCPPack.seq +1, 1, incomingTCPpack->lastACK, ACK_FLAG,  incomingTCPpack->window, tcpPayload);
            call Sender.makePack(&outgoingPack, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack));
            call Sender.send(outgoingPack, Qsocket->dest.addr);

            dbg(TRANSPORT_CHANNEL, "sent SYN-ACK to client, client connection establsihed\n");
        }

        //HANDSHAKE: RECEIVING ACK FROM CLIENT, CONNECTION ESTABLISHED FOR SERVER 
        //state change: SYN_RCVD -> ESTABLISHED
        if (Qsocket->state == SYN_RCVD && flags == ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "ACK recieved, server connected!");
                Qsocket->state = ESTABLISHED; //now connection is established between two nodes, so machine state should be connected 
        }

        //TEARDOWN: CLOSE() called, TEARDOWN INIATOR IS RECEIVING BOTH FIN AND ACK FROM TEARDOWN RESPONDER
        //state change: FIN_WAIT_1 ->  FIN_WAIT_2
        if(Qsocket->state == FIN_WAIT_1 && flags == ACK_FLAG){
            //teardown iniator needs to receive both FIN and ACK from responder, usually ACK comes first 
            Qsocket->state = FIN_WAIT_2;
            
        }

        //TEARDOWN: ACKS WERE RECEIVED BY INIATOR, INIATOR NOW MOVES TO TIME_WAIT (in case retransmission happens)
        //state change: FIN_WAIT_2 -> TIME_WAIT
        if(Qsocket->state == FIN_WAIT_2){
            //TEARDOWN INIATOR
            Qsocket->state = TIME_WAIT;
            //supposed to wait some time in case retranmissions need to happen and then state == closed
            call timeWaitTimer.startOneShot(100); //waiting a 100ms or 0.1s
            makeTCPpack(&outgoingTCPPack, Qsocket->dest.port, Qsocket->src, outgoingTCPPack.seq + 1, 1, incomingTCPpack->lastACK, FIN_ACK,  incomingTCPpack->window, tcpPayload);
            dbg(TRANSPORT_CHANNEL, "sending last ACK from Client Side\n");
            call Sender.makePack(&outgoingPack,TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack));
            call Sender.send(outgoingPack, Qsocket->dest.addr);
            
            
        }

        //TEARDOWN: INIATOR IS IN TIME_WAIT 
        //state change: TIME_WAIT -> CLOSED
        //if(Qsocket->state == TIME_WAIT)
        //this is in timeWaitTimer.fired() below


        //TEARDOWN: RESPONDER SENDING FIN and ACK IN RESPONSE TO FIN PACKET BEING RECEIVED 
        //state change: CLOSE_WAIT -> LAST_ACK
        // if(Qsocket->state == CLOSE_WAIT) 
        //^ this is in close() below

        


    }

    //TEARDOWN: INIATOR IS IN TIME_WAIT, when timer fired we change state 
    //state change: TIME_WAIT -> CLOSED
    event void timeWaitTimer.fired(){
        socket_store_t* Qsocket = call timeWaitQueue.dequeue();
        Qsocket->state = CLOSED;
       
    }
    

    socket_t getServerSocket(uint8_t destination){
        //
    }

    //only used by server, changes state to LISTEN to signify ready to accept connections 
    command error_t Transport.listen(socket_t fd){
        //* @return error_t - returns SUCCESS if you are able change the state to listen else FAIL.
        socket_store_t *Qsocket = call socketQueue.element(fd -1);
        dbg(TRANSPORT_CHANNEL, "called transport.listen()\n");

        Qsocket->state = LISTEN;

        return SUCCESS; 
    }

    
    
    
    //starts teardown, if not responds by setting state to CLOSED
    //if we are the responder to a teardown we change from CLOSE_WAIT to LAST_ACK, transmit, then close
    command error_t Transport.close(socket_t fd){
        //where the connection closes, if state is etablished: start fin send
        
        socket_store_t *Qsocket = call socketQueue.element(fd -1);
    
         // mySocket.dest.port = ;
         // mySocket.dest.addr = msg->src; 
        
        dbg(TRANSPORT_CHANNEL, "called transport.close()\n");
        if(Qsocket->state == ESTABLISHED){
            //send fin pack the receiver does not call close() when state is established
            //SENDER 
            makeTCPpack(&outgoingTCPPack, Qsocket->src, Qsocket->dest.port, outgoingTCPPack.ACK, 1, Qsocket->lastAck, FIN_FLAG,  Qsocket->effectiveWindow, tcpPayload);
            //sending
            call Sender.makePack(&outgoingPack, TOS_NODE_ID, Qsocket->dest.addr, PROTOCOL_TCP, (uint8_t*)&outgoingTCPPack, sizeof(tcp_pack)); //NULL because a FIN packet has no TCP payload
            Qsocket->state = FIN_WAIT_1;
            dbg(TRANSPORT_CHANNEL, "Starting close, send FIN \n");
            call Sender.send(outgoingPack, Qsocket->dest.addr);

        //part of the teardown sequence this is when 
        }else if(Qsocket->state == CLOSE_WAIT){
             Qsocket->state = LAST_ACK; 
             //send last acks tbd
             Qsocket->state = CLOSED;
        }else{
            Qsocket->state = CLOSED;
        }
    }

    //optional hard close 
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

    //reads TCP buffer and sends ACKS
    //copies from TCP buffer into Application buffer 
    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){
        //this is where the server reads packets 
        bool isWrapped;
        uint8_t bytesRead;
        socket_store_t *sock = call socketQueue.element(fd - 1);
        //can only send if established 
        if(sock == NULL || sock->state != ESTABLISHED){
            dbg(TRANSPORT_CHANNEL, "cannot read\n");
            bytesRead = 0;
            return bytesRead;
        }
        
        //checking for wrapped scenario
        if(sock->lastRead > sock->lastRcvd){
            isWrapped = FALSE;
        }else{
            isWrapped = TRUE;
        }
        
        //if we're not wrapped, we dont want to exceed buffersuize 
        // if(!isWrapped){
          

        // }if(isWrapped){
            
                
            
        // }

        memcpy(buff, &sock->rcvdBuff[sock->lastRead], bufflen);
        bytesRead = bufflen;

        sock->lastRead = sock->lastRead + bytesRead;
        // sock->lastRcvd = sock->lastRcvd + 1; 
        return bytesRead;
    }

    //task for processing incoming TCP packets 
    //Post by Receive.receive() below
    task void processTCPpacket(){
        message_t* raw_msg;
        pack* pkt;
        void *payload;
        error_t err;
        //if we have packets in the queue 
        if(! call packetQueue.empty()){
            //storing packet in raw_msg
            raw_msg = call packetQueue.dequeue();
            //storing payload in payload
            payload = call Packet.getPayload(raw_msg, sizeof(pack));

            //if no payload 
            if(!payload){
                //put the message back for processing 
                call packetPool.put(raw_msg);
                //post packet for processing again
                post processTCPpacket();
                return;
            }
            //casting to pack* so packet can be processed 
            pkt = (pack*) payload;
            if(pkt->protocol == PROTOCOL_TCP){
                dbg(TRANSPORT_CHANNEL, "Got TCP packet\n");
            }
            // dbg(TRANSPORT_CHANNEL, "got packet: %p\n", pkt);
            
            // dbg(TRANSPORT_CHANNEL, "source: %d, dest: %d, protocol: %d\n", pkt->src, pkt->dest, pkt->protocol);
            err = call Transport.receive(pkt);
            
            //release pool entry for reuse
            call packetPool.put(raw_msg);
        }
        //this is for iteration, as long as queue has packets we process them 
        if(! call packetQueue.empty()){
            post processTCPpacket();
        }
    }
    
    //wired in Receiver
     event message_t* Receive.receive(message_t* raw_msg, void* payload, uint8_t len){
        if (! call packetPool.empty()){
            // dbg(TRANSPORT_CHANNEL, "Receive.receive()\n");
            call packetQueue.enqueue(raw_msg);
            //post task for packet processing
            post processTCPpacket();
            return call packetPool.get();
        }
        return raw_msg;
    }
    
     /* Used for other modules, disregard. */
    event void PacketHandler.gotPing(uint8_t* incomingMsg) {}
    event void PacketHandler.gotflood(uint8_t* incomingMsg) {}
    event void PacketHandler.gotRouted(uint8_t* incomingMsg) {}

}
