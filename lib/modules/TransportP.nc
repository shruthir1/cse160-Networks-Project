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
    // uses interface Receive;
    // uses interface PacketHandler;
    uses interface Queue<pack> as packetQueue; //tinyOS has its own Queue interface :D 
    uses interface List<socket_store_t> as SocketList; //socket_t is an index to the array of sockets we  have 
}

implementation {
    
    //defining these functions at the top of the file to be used before function is defined (in case function is used before) 
    socket_t getSocket(uint8_t destPort, uint8_t srcPort);
    socket_t getServerSocket(uint8_t destPort);

    void finalizedConnection(socket_t fd);

    // void makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    event void TCPtimer.fired(){
        pack myMsg = call packetQueue.head(); //returns first packet in the queue 
       
    }

    socket_t getSocket (uint8_t destPort, uint8_t srcPort){
        socket_store_t currSocket;
        uint16_t i = 0;
        uint16_t size = call SocketList.size();

        for(i = 0; i < size; i++ ){
            currSocket = call SocketList.get(i);
            if(currSocket.dest.port == destPort && currSocket.src == srcPort){
                return i;
            }
        }

        return -1;
    }



    command socket_t Transport.socket(){
        //get a socket if one is available state should be closed 
        socket_store_t sockStore;
        sockStore.state = CLOSED;
        sockStore.flag = 0;
        sockStore.src = 0;
        sockStore.dest.port = 0;
        sockStore.dest.addr = 0;

        call SocketList.pushback(sockStore);
        return call SocketList.size();

    }

    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){ 
        //bind a socket with an address 
        //get() is giving a copy of whats in the list by using a pointer we're able to interact what whats directly in the list (and change it)
        socket_store_t mySocket = call SocketList.get(fd);
        //only use arrows on pointer vars 
        mySocket.src = addr->port;
        //mySocket.state does not change on bind()
        
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
        // return success if able to pack packet ??
    }



    // void makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
    //   //building our packet
    //     tcp_pack* myTCPPack;
    //     packet->src = src;
    //     packet->dest = dest;
    //     myTCPPack = (tcp_pack*)(packet->payload);
    //     myTCPPack->seq = seq;
    //     packet->protocol = protocol;
    //     memcpy(packet->payload, payload, length); //puts payload into packet
    // }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        // @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
       //this is where the iniating connection part of my pseudocode is happening 
        pack myMsg;
        tcp_pack* myTCPPack;
        socket_store_t mySocket = call SocketList.get(fd);
        mySocket.dest.port = addr->port;
        mySocket.dest.addr = addr->addr;
        mySocket.src = 123; //ends up being randomized 

        //setting up the SYN packet
        myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
        myTCPPack->destPort = mySocket.dest.port;
        myTCPPack->srcPort = mySocket.src;
        myTCPPack->ACK = 0;
        myTCPPack->flags = SYN_FLAG;
        myTCPPack->seq = 1;
        //making initial SYN pack
        call Sender.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, NULL, 0); //because a SYN packet has no TCP payload
        mySocket.state = SYN_SENT;
        dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src, mySocket.state);
        call Sender.send(myMsg, mySocket.dest.addr);
    
    }

    //when a packet is recieved there are multiple courses of action 
    command error_t Transport.receive(pack* msg){
       //intialized to store the values were gonna look at from incoming packet 
        uint8_t srcPort = 0;
        uint8_t destPort = 0;
        uint8_t seq = 0;
        uint8_t lastAck = 0;
        uint8_t flags = 0;
        uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE;
        uint32_t key = 0;
        socket_store_t mySocket;
        //going inside IP layer and isolating TCP packet (i think)
        tcp_pack* myMsg = (tcp_pack*)(msg->payload);

        //packet for replying 
        pack myNewMsg;
        tcp_pack* myTCPPack;

        //extract TCP header info from received packet 
        srcPort = myMsg->srcPort;
        destPort = myMsg->destPort;
        seq = myMsg->ACK;
        flags = myMsg->flags;

        if(flags == SYN_FLAG){
            dbg(TRANSPORT_CHANNEL, "just recieved a SYN, preparing for SYN-ACK");
            mySocket = call SocketList.get(getServerSocket(destPort)); //client socket
            if(mySocket.state == LISTEN){
                //we no longer need to listen for a SYN, we recieved one
                mySocket.state = SYN_RCVD;
                mySocket.dest.port = srcPort;
                mySocket.dest.addr = msg->src; // sending the SYN-ACK back to the sender
                call SocketList.pushback(mySocket); //this socket (that recieved the syn) is now not available anymore!!

                myTCPPack = (tcp_pack*)(myNewMsg.payload); // we want to isolate the TCP header
                myTCPPack->destPort = mySocket.dest.port;
                myTCPPack->srcPort = mySocket.src;
                myTCPPack->seq = 1;
                myTCPPack->ACK = seq++;
                myTCPPack->flags = SYN_ACK_FLAG;
                call Sender.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                dbg(TRANSPORT_CHANNEL, "just sent SYN-ACK packet");

            }
        }

        if (flags == SYN_ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "Received SYN-ACK \n");
            mySocket.state = ESTABLISHED; //connection has now been established, machine state changed
            mySocket = call SocketList.get(getSocket(destPort, srcPort)); //the sender socket 
            call SocketList.pushback(mySocket); //the socket receiving the ack is now not avialable anymore
            
            myTCPPack = (tcp_pack*)(myNewMsg.payload); //isolating the TCP header
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mySocket.src;
            myTCPPack->seq = 1;
            myTCPPack->ACK = seq++;
            myTCPPack->flags = ACK_FLAG;

            call Sender.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myNewMsg, mySocket.dest.addr);

            dbg(TRANSPORT_CHANNEL, "sent SYN-ACK");

            finalizedConnection(getSocket(mySocket.dest.port, mySocket.src)); //at this point we've sent the ACK and are ready for data flow 

        }

         if (flags == ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "ACK recieved, there's a connection!");
            mySocket = call SocketList.get(getSocket(destPort, srcPort)); //sender socket
            if(mySocket.state == SYN_RCVD){
                mySocket.state = ESTABLISHED; //now connection is established between two nodes, so machine state should be connected 
                call SocketList.pushback(mySocket); //every time the state is changed we put updated socket in list(?)
            }
        }


        if(flags == FIN_FLAG){
            if(mySocket.state == ESTABLISHED){
                dbg(TRANSPORT_CHANNEL, "received FIN, need to begin teardown");
                mySocket = call SocketList.get(getSocket(destPort, srcPort));
                mySocket.dest.port = srcPort;
                mySocket.dest.addr = msg->src;

                mySocket.state = CLOSE_WAIT;

                myTCPPack = (tcp_pack*)(myNewMsg.payload); //want to look at TCP header
                //configuring the packet to send a FIN-ACK
                myTCPPack->destPort = mySocket.dest.port;
                myTCPPack->srcPort = mySocket.src;
                myTCPPack->seq = 1;
                myTCPPack->ACK = seq++;
                myTCPPack->flags = FIN_ACK;

                dbg(TRANSPORT_CHANNEL, "Sending FIN-ACK from reciever");
                call Sender.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                
                //send another fin packet here as well i think nothing but the flags need to be changed 
                myTCPPack->flags = FIN_FLAG;
                dbg(TRANSPORT_CHANNEL, "sending last FIN from receiver");
                call Sender.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                mySocket.state = LAST_ACK;

            }
        }

        


    }

    
    void finalizedConnection(socket_t fd){
       //start sending data after connection is finalized

       
    

    }

    socket_t getServerSocket(uint8_t destination){
        //
    }

    command error_t Transport.listen(socket_t fd){
        //* @return error_t - returns SUCCESS if you are able change the state to listen else FAIL.
        socket_store_t mySocket = call SocketList.get(fd);
        mySocket.state = LISTEN;
        //server now waits until SYN packet is sent 
    }

    command error_t Transport.close(socket_t fd){
        //where the connection closes, if state is etablished: start fin send
        socket_store_t mySocket = call SocketList.get(fd);
        pack myMsg;
        tcp_pack* myTCPPack;

        if(mySocket.state == ESTABLISHED){
            //send fin pack the receiver does not call close() when state is established
            //SENDER 
            myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
            myTCPPack->destPort = mySocket.dest.port; //not sure if this is right 
            myTCPPack->srcPort = mySocket.src;
            myTCPPack->ACK = 0; //also not sure if this is right 
            myTCPPack->flags = FIN_FLAG;
            myTCPPack->seq = 1; //should this be random?
            //sending
            call Sender.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, NULL, 0); //NULL because a FIN packet has no TCP payload
            mySocket.state = FIN_WAIT_1;
            dbg(ROUTING_CHANNEL, "Starting close, send FIN \n");
            call Sender.send(myMsg, mySocket.dest.addr);


        }else if(mySocket.state == FIN_WAIT_1){
            //SENDER
            mySocket.state = FIN_WAIT_2;
        }else if(mySocket.state == FIN_WAIT_2){
            //SENDER
            mySocket.state = TIME_WAIT;
            //supposed to wait some time in case retranmissions need to happen and then state == closed
            //also need to send lastAck from client side 
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mySocket.src; //not sure if this should be initialized to be random
            myTCPPack->seq = 1; //this needs to the ack of the prev packet
            myTCPPack->ACK = (myTCPPack->seq)++;
            myTCPPack->flags = FIN_ACK;

            dbg(TRANSPORT_CHANNEL, "sending last ACK from Client Side");
            call Sender.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myMsg, mySocket.dest.addr);
            
        }else if(mySocket.state == TIME_WAIT){
            //SENDER
            //needs to wait a bit first

            mySocket.state == CLOSED;
        }else if(mySocket.state == CLOSE_WAIT){
            //RECIEVER
            //sends a FIN and an ACK 
            //sending the ACK
            myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mySocket.src;
            myTCPPack->ACK = 0; //this should be based off the incoming FIN's seq (i think)
            myTCPPack->flags = ACK_FLAG;
            myTCPPack->seq = 1;
            call Sender.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, NULL, 0); //because a SYN packet has no TCP payload
            call Sender.send(myMsg, mySocket.dest.addr);

            //sending the fin
            myTCPPack = (tcp_pack*)(myMsg.payload); //we're using a TCPPack pointer to the payload of the IP packet, because this is where the TCP header lies
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mySocket.src;
            myTCPPack->ACK = 0; //same number as the ack packet being sent 
            myTCPPack->flags = FIN_FLAG;
            myTCPPack->seq = 2; //this needs to be a new num than the ack packet
            call Sender.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, NULL, 0); //because a SYN packet has no TCP payload
            call Sender.send(myMsg, mySocket.dest.addr);

            dbg(ROUTING_CHANNEL, "Acknowledging close, sending ACK and FIN \n");
            mySocket.state == LAST_ACK;

        }else if(mySocket.state == LAST_ACK){
            //RECIEVER
            dbg(TRANSPORT_CHANNEL, "Received Last FIN-ACK, now closing socket");
            mySocket = call SocketList.get(getSocket(myTCPPack->srcPort, myTCPPack->destPort));
            mySocket.state = CLOSED;

        }else{
            mySocket.state = CLOSED;
        }
    }

    command error_t Transport.release(socket_t fd){
        //@return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
        //not sure what the different between this and close is?? I think this one is asking if the state is closed then return true 
        socket_store_t mySocket = call SocketList.get(fd);
        if(mySocket.state == CLOSED){
            return 0;
        }else{ 
            return 1;
        }
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){

    }

}
