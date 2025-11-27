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
  /* SETUP

if iniating connection:
   TCPPaacket connectionPacket
   connectionPacket.SYN flag = 1
   connectionPacket.ISN = m 
   window = bufferSize
   mySocket.STATE = SYN_SENT
   send connectionPacket

if receiving pack with recievePacket.SYN == 1 && recievePacket.ACK == 0: 
    (sending syn-ack:)
     TCPPacket responsePacket
     responsePacket.SYN flag = 1
     responsePacket.ACK flag = 1
     responsePacket.acknum = recievePacket.ISN + 1 
     responsePacket.ISN = n 
     window = bufferSize 
     mySocket.STATE = SYN_RECIEVED
     send responsePacket

if receiving recievePacket.SYN == 1 && recievePacket.ACK == 1: 
    (sending ACK:)
     TCPPacket responsePacket
     responePacket.SYN flag = 0
     responsePacket.ACK flag = 1
     responsePacket.acknum = n + 1
     window = bufferSize
     mySocket.STATE = ESTABLISHED
     send responsePacket

if receiving recievePacket.ACK == 1 && otherSocket.STATE = ESTABLISHED:
    STATE = ESTABLISHED
    

  */


   /* TEARDOWN

   enum with state values in the socket header, we wanna set and check for state values too

if mySocket.STATE == ESTABLISHED && starting teardown: 
    (sending the FIN:)
    TCPPacket finpacket
     finpacket.FIN flag = 1
     finpacket.ACK flag = 0
     window = bufferSize
     finpacket.ISN = x (this nums seq num comes from state -> state is global and we can ge tthis from struct)
     finpacket.STATE = FIN_WAIT_1
     send finpacket

//will have to send from both client and server again 
if receiving recievePacket.FIN == 1 && recievePacket.ACK == 0:
    (sending ACK:)
    TCPPacket responsePacket
    responsePacket.ACK flag= 1
    responsePacket.FIN flag = 0
    responsePacket.acknum = x + 1 (m comes from state)
    responsePacket.ISN = y (this connection's sequence num)
    window = bufferSize
    send responsePacket
    mySocket.STATE = CLOSE_WAIT

    (sending FIN:)
    TCPPacket responsePacket2
    responsePacket2.ACK flag = 0
    responsePacket2.FIN flag = 1
    responsePacket2.acknum = x + 1 (same as last packet)
    responsePacket2.ISN = y (same as other packet being sent)
    window = bufferSize
    send repsonsePacket2
    mySocket.STATE = LAST_ACK


if receivePacket.FIN == 0 && recievePacket.ACK == 1 && otherSocket.STATE == CLOSE_WAIT
    (recieivng ACK after sending FIN)
    mySocket.STATE = FIN_WAIT_2
    //not sure if this above conditional is needed???

if receiving recievePacket.FIN == 1 && recievePacket.ACK == 0 && otherSocket.STATE == LAST_ACK
    (recieving FIN after receiving ACK, Sending final ACK)
    TCPPacket finalize
    finalize.FIN flag = 0
    finalize.ACK flag = 1
    finalize.ISN = x + 1 (this connections seq )
    finalize.acknum = y + 1 (this connections ack num)
    window = bufferSize
    send finalize
    mySocket.STATE = CLOSED
    close connection

if recieving recievePacket.ACK == 1 && otherSocket.STATE = CLOSED
    mySocket.STATE = CLOSED

  */

  /* FLOW CONTROL PSUEDOCODE
    we send a window of packets, when we recieve ack's we slide the window by increasing seqNum 
    if i dont receive ack after some time resend all packets 

if(socket.state == ESTABLISHED && receivePacket.data == 1)
    //if the data flag is marked then we apply flow control
    if((lastByteSent - lastByteAcked) < advertisedWindow )
        send data


  */

  /* CONGESTION CONTROL PSUEDOCODE
  
  */
    
    //defining these functions at the top of the file to be used before function is defined (in case function is used before) 
    socket_t getSocket(uint8_t destPort, uint8_t srcPort);
    socket_t getServerSocket(uint8_t destPort);

    void finalizedConnection(socket_t fd);

    void makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

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
        //success if able to bind sockets 
    }

    command socket_t Transport.accept(socket_t fd){
        /* * @return socket_t - returns a new socket if the connection is
         accepted. this socket is a copy of the server socket but with
         a destination associated with the destination address and port.
        if not return a null socket.
        */

    }
    
    command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
        // return success if able to pack packet ??
    }


    void makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      //building our packet
        tcp_pack* myTCPPack;
        packet->src = src;
        packet->dest = dest;
        myTCPPack = (tcp_pack*)(packet->payload);
        myTCPPack->seq = seq;
        packet->protocol = protocol;
        memcpy(packet->payload, payload, length); //puts payload into packet
    }

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
        makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, NULL, 0); //because a SYN packet has no TCP payload
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
                makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
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

            makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
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
                makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                
                //send another fin packet here as well i think nothing but the flags need to be changed 
                myTCPPack->flags = FIN_FLAG;
                dbg(TRANSPORT_CHANNEL, "sending last FIN from receiver");
                makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                mySocket.state = LAST_ACK;

            }else if (mySocket.state == FIN_WAIT_2){
                mySocket.state = TIME_WAIT;
                //supposed to wait some time in case retranmissions need to happen and then state == closed
                //also need to send lastAck from client side 
                mySocket = call SocketList.get(getSocket(destPort, srcPort));
                mySocket.dest.port = srcPort;
                mySocket.dest.addr = mySocket.src;
                myTCPPack->destPort = mySocket.dest.port;
                myTCPPack->srcPort = mySocket.src; //not sure if this should be initialized to be random
                myTCPPack->seq = 1; //this needs to the ack of the prev packet
                myTCPPack->ACK = seq++;
                myTCPPack->flags = FIN_ACK;

                dbg(TRANSPORT_CHANNEL, "sending last ACK from Client Side");
                makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, PROTOCOL_TCP, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                mySocket.state = CLOSED; //not sure if theres supposed to be a timer that times out first 
            }
        }

        if(flags == FIN_ACK){
            if(mySocket.state == LAST_ACK){
                dbg(TRANSPORT_CHANNEL, "Received FIN-ACK");
                mySocket = call SocketList.get(getSocket(destPort, srcPort));
                mySocket.state = CLOSED; //machine state is closed, theres no longer a connection 
            }else if(mySocket.state == FIN_WAIT_1){
                //recieved first ack from receiver side
                mySocket.state = FIN_WAIT_2;

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
    }

    command error_t Transport.close(socket_t fd){
        //where the connection closes 
    }

    command error_t Transport.release(socket_t fd){
        //@return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
    }

    command uint16_t Transport.read(socket_t fd, uint8_t *buff, uint16_t bufflen){

    }

}
