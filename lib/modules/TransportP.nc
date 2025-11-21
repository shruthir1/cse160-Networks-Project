#include "../../includes/channels.h"
#include "../../includes/protocol.h"
#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCPPacket.h"
#include <Timer.h>

module TransportP {
    provides interface Transport;
    uses interface Timer<TMilli> as beaconTimer;
    uses interface SimpleSend as Sender;
    // uses interface Receive;
    uses interface Queue<pack> as packetQueue; //tinyOS has its own Queue interface :D 
    uses interface List<socket_t> as SocketList;
}

implementation {
  /*  Handshake or SETUP 

if iniating connection:
   connection.state = intiating
   TCPPaacket connectionPacket
   connectionPacket.SYN flag = 1
   connectionPacket.ISN = m 
   send connectionPacket

if receiving pack with recievePacket.SYN == 1 && recievePacket.ACK == 0: 
    (sending syn-ack:)
     TCPPacket responsePacket
     responsePacket.SYN flag = 1
     responsePacket.ACK flag = 1
     responsePacket.acknum = recievePacket.ISN + 1 
     responsePacket.ISN = n 
     send responsePacket

if receiving recievePacket.SYN == 1 && recievePacket.ACK == 1: 
    (sending ACK:)
     TCPPacket responsePacket
     responePacket.SYN flag = 0
     responsePacket.ACK flag = 1
     responsePacket.acknum = n + 1
     send responsePacket

  */

   /* Teardown

   enum with state values in the socket header, we wanna set and check for state values too

  if starting teardown: 
    (sending the FIN:)
    TCPPacket finpacket
     finpacket.FIN flag = 1
     finpacket.ACK flag = 0
     finpacket.ISN = x (this nums seq num comes from state -> state is global and we can ge tthis from struct)
     send finpacket

//will have to send from both client and server again 
  if receiving recievePacket.FIN == 1 && recievePacket.ACK == 0:
    (sending FIN-ACK:)
    TCPPacket responsePacket
    responsePacket.ACK flag= 1
    responsePacket.FIN flag = 0
    responsePacket.acknum = x + 1 (m comes from state)
    responsePacket.ISN = y (this connection's sequence num)
    send responsePacket

    TCPPacket responsePacket2
    responsePacket2.ACK flag = 1
    responsePacket2.FIN flag = 1
    responsePacket2.acknum = x + 1 (same as last packet)
    responsePacket2.ISN = y (same as other packet being sent)
    send repsonsePacket2

  if receiving recievePacket.FIN == 1 && recievePacket.ACK == 1 
    TCPPacket lastAck
    lastAck.FIN flag = 0
    lastAck.ACK flag = 1
    lastAck.ISN = x + 1 (this connections seq )
    lastAck.acknum = y + 1 (this connections ack num)
    send lastAck
    close connection

  */
    
    //base connections on proper ports, from where to where am I transporting data? 
    socket_t getSocket(uint8_t destPort, uint8_t srcPort);
    socket_t getServerSocket(uint8_t destPort);

    event void beaconTimer.fired(){
        pack myMsg = call packetQueue.head(); //returns first packet in the queue 
        pack sendMsg; //declaring a new packet that we'll send 
        
        tcp_pack* myTCPPack = (tcp_pack *)(myMsg.payload); //tcp header
        socket_t mySocket = getSocket(myTCPPack->srcPort, myTCPPack->destPort);

        if(mySocket.dest.port){
            call SocketList.pushback(mysocket);

            call Transport.makePack(&sendMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send
        }
    }

    socket_t getSocket (uint8_t destPort, uint8_t srcPort){
        socket_t currSocket;
        uint16_t i = 0;
        uint16_t size = call SocketList.size();

        for(i = 0; i < size; i++ ){
            currSocket = call SocketList.get(i);
            if(currSocket.dest.port == srcPort && currSocket.src.port == destPort){
                return currSocket;
            }
        }
    }



    command socket_t Transport.socket(){
        //get a socket if one is available state should be closed 

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
    
    // command uint16_t Transport.write(socket_t fd, uint8_t *buff, uint16_t bufflen){
    //     // return success if able to pack packet 
    // }

    command void Transport.makePack(pack *packet, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      //building our packet
        packet->src = src;
        packet->dest = dest;
        packet->TTL = TTL;
        packet->seq = seq;
        packet->protocol = protocol;
        memcpy(packet->payload, payload, length); //puts payload into packet
    }

    command error_t Transport.connect(socket_t fd, socket_addr_t * addr){
        // @return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
       //this is where the iniating connection part of my pseudocode is happening 
        pack myMsg;
        tcp_pack* myTCPPack;
        socket_t mySocket = fd;

        myTCPPack = (tcp_pack*)(myMsg.payload);
        myTCPPack->destort = mySocket.dest.port;
        myTCPPack->srcPort = mySocket.src.port;
        myTCPPack->ACK = 0;
        myTCPPack->flags = SYN_FLAG;
        myTCPPack->seq = 1;
        //making initial SYN pack
        call Transport.makePack(&myMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
        mySocket.state = SYN_SENT;
        dbg(ROUTING_CHANNEL, "Node %u State is %u \n", mySocket.src.addr, mySocket.state);
        call Sender.send(myMsg, mySocket.dest.addr);
    
    }

    //when a packet is recieved there are multiple courses of action 
    command error_t Transport.Recieve(pack* msg){
       //intialized to store the values were gonna look at from incoming packet 
        uint8_t srcPort = 0;
        uint8_t destPort = 0;
        uint8_t seq = 0;
        uint8_t lastAck = 0;
        uint8_t flags = 0;
        uint16_t bufflen = TCP_PACKET_MAX_PAYLOAD_SIZE;
        uint16_t i = 0; //counter for sliding window
        uint16_t j = 0;
        uint32_t key = 0;
        socket_t mySocket;
        //going inside IP layer and isolating TCP packet
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
            mySocket = getServerSocket(destPort); //reciever socket
            if(mySocket.state == LISTEN){
                //we no longer need to listen for a SYN, we recieved one
                mySocket.state = SYN_RCVD;
                mySocket.dest.port = srcPort;
                mySocket.dest.addr = msg->src; // sending the SYN-ACK back to the sender
                call SocketList.pushback(mySocket); //this socket (that recieved the syn) is now not available anymore!!

                myTCPPack = (tcp_pack*)(myNewMsg.payload); // we want to isolate the TCP header
                myTCPPack->destPort = mySocket.dest.port;
                myTCPPack->srcPort = mySocket.src.port;
                myTCPPack->seq = 1;
                myTCPPack->ACK = seq++;
                myTCPPack->flags = SYN_ACK_FLAG;
                call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
                call Sender.send(myNewMsg, mySocket.dest.addr);
                dbg(TRANSPORT_CHANNEL, "just sent SYN-ACK packet");

            }
        }

        if (flags == SYN_ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "Received SYN-ACK \n");
            mySocket.state = ESTABLISHED; //connection has now been established, machine state changed
            mySocket = getSocket(destPort, srcPort); //the sender socket 
            call SocketList.pushback(mySocket); //the socket receiving the ack is now not avialable anymore
            
            myTCPPack = (tcp_pack*)(myNewMsg.payload); //isolating the TCP header
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mySocket.src.port;
            myTCPPack->seq = 1;
            myTCPPack->ACK = seq++;
            myTCPPack->flags = SYN_ACK_FLAG;

            call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
            call Sender.send(myNewMsg, mySocket.dest.addr);

            dbg(TRANSPORT_CHANNEL, "sent SYN-ACK");

            finalizedConnection(mySocket); //at this point we've sent the ACK and are ready for data flow 

        }

         if (flags == ACK_FLAG){
            dbg(TRANSPORT_CHANNEL, "ACK recieved, there's a connection!")
            mySocket = getSocket(destPort, srcPort); //sender socket
            if(mySocket.state == SYN_RCVD){
                mySocket.state = ESTABLISHED; //now connection is established between two nodes, so machine state should be connected 
                call SocketList.pushback(mySocket); //every time the state is changed we put updated socket in list
            }
        }


        if(flags == FIN_FLAG){
            dbg(TRANSPORT_CHANNEL, "received FIN, need to begin teardown");
            mySocket = getSocket(destPort, srcPort);
            mySocket.dest.port = srcPort;
            mySocket.dest.addr = msg->src;

            myTCPPack = (tcp_pack*)(myNewMsg.payload); //want to look at TCP header
            //configuring the packet to send a FIN-ACK
            myTCPPack->destPort = mySocket.dest.port;
            myTCPPack->srcPort = mysocket.src.port;
            myTCPPack->seq = 1;
            myTCPPack->ACK = seq++;
            myTCPPack->flags = FIN_ACK;

            dbg(TRANSPORT_CHANNEL, "Sending FIN-ACK");
            call Transport.makePack(&myNewMsg, TOS_NODE_ID, mySocket.dest.addr, 15, 4, 0, myTCPPack, PACKET_MAX_PAYLOAD_SIZE);
			call Sender.send(myNewMsg, mySocket.dest.addr);

        }

        if(flags == FIN_ACK){
            dbg(TRANSPORT_CHANNEL, "Received FIN-ACK");
            mySocket = getSocket(destPort, srcPort);
            mySocket.state = CLOSED; //machine state is closed, theres no longer a connection 
        }




    }

    command void finalizedConnection(socket_t fd){
       //start sending data after connection is finalized
        pack myMsg;
        tcp_pack* TCPPacket;

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

    comamnd error_t Transport.release(socket_t fd){
        //@return socket_t - returns SUCCESS if you are able to attempt a closure with the fd passed, else return FAIL.
    }

   

}
