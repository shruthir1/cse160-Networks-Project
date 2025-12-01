/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"
#include "includes/floodpack.h"

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;
   uses interface neighborDiscovery as nd;
   uses interface flooding as flood;
   uses interface Wayfinder;
   uses interface Waysender as router;
   uses interface PacketHandler;
   uses interface CommandHandler;
   uses interface Transport;
}

implementation{
   pack sendPackage;

   event void Boot.booted(){
      call AMControl.start();
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");

         //When done booting, start the ND Ping timer.
         call nd.onBoot();
         call Wayfinder.onBoot();

      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      dbg(HANDLER_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){         
         
         //Pass the packet off to a separate packet handler module.
         dbg(HANDLER_CHANNEL, "Packet -> Handler");
         call PacketHandler.handle((pack*) payload);

         return msg;
      }
      dbg(HANDLER_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT\n");
      call Sender.makePack(&sendPackage, TOS_NODE_ID, destination, PROTOCOL_PING, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
   }

   event void PacketHandler.gotPing(uint8_t* _){}
   event void PacketHandler.gotflood(uint8_t* _){}
   event void flood.gotLSP(uint8_t* _){}
   event void PacketHandler.gotRouted(uint8_t* _){}
   
   event void nd.neighborUpdate(){}
   //Command implementation of flooding
   event void CommandHandler.flood(uint8_t* payload){
      dbg(GENERAL_CHANNEL, "FLOOD EVENT\n");
      call flood.initiate(255, PROTOCOL_FLOOD, payload);  
   }

   event void CommandHandler.route(uint8_t dest, uint8_t* payload){
      dbg(GENERAL_CHANNEL, "ROUTE EVENT\n");
      call router.send(255, dest, PROTOCOL_ROUTING, payload);
   }
   
   event void CommandHandler.printNeighbors(){}

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer( uint16_t address, uint8_t port){
      //   # sock = socket()
      //   # addr = socket_addr() #constructor
      //   # addr.port = port
      //   # addr.addr = address
      //   # bind(sock, addr)
      //   # startTimer ???
      //   # listen(sock)
      //   # newSock = accept(sock)
      //   # buffSize = 100
      //   # buff = [None] * buffSize
      //   # read(newSock, buff, buffSize)
      //   # print(buff)
      //   # close(newSock)
      socket_t sock; 
      socket_t clientSock;
      socket_addr_t addr;
      error_t err;
      dbg(GENERAL_CHANNEL, "TEST SERVER EVENT\n");
      sock = call Transport.socket();
      addr.addr = TOS_NODE_ID;
      addr.port = port;
      err = call Transport.bind(sock, &addr);
      if(err != SUCCESS){
         return;
      }
      //start timer
      err = call Transport.listen(sock);
      //implement error handle
      if(err != SUCCESS) return;          
      clientSock = call Transport.accept(sock);
      //need to still add read()
      err = call Transport.close(clientSock);
      //error handling 
      if(err != SUCCESS) return;



   }

   event void CommandHandler.setTestClient(uint16_t destination, uint8_t srcPort, uint8_t destPort, uint16_t transferCount){
      //   # sock = socket()
      //   # addr = socket_addr()
      //   # addr.port = srcPort
      //   # addr.addr = NODE_ID
      //   # bind(sock, addr)
      //   # serverAddr = socket_addr()
      //   # serverAddr.port = destPort
      //   # serverAddr.addr = destination
      //   # connect(fd, serverAddr)
      //   # startTimer ???
      //   # buff = [None] * transferCount
      //   # for i in range(transferCount):
      //       # buff[i] = i
      //   # write(sock, buff, transferCount)
      //   #print(buff)
      //   #close(sock)

      socket_t sock; 
      socket_t clientSock;
      socket_addr_t addr;
      socket_addr_t serverAddr;
      error_t err;
      dbg(GENERAL_CHANNEL, "TEST CLIENT EVENT\n");
      sock = call Transport.socket();
      addr.addr = TOS_NODE_ID;
      addr.port = srcPort;
      err = call Transport.bind(sock, &addr);
      if(err != SUCCESS) return;

      serverAddr.port = destPort;
      serverAddr.addr = destination;
      err = call Transport.connect(sock, &serverAddr);
      if(err != SUCCESS) return;
      //implement error handling 
      //start timer 
      //need to do write
      err = call Transport.close(sock);
      if(err != SUCCESS) return;
      //implement error handling 
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}
}
