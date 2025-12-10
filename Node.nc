/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <string.h>
#include <stdlib.h> 
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/protocol.h"
#include "includes/floodpack.h"
#include "includes/chat.h"


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

   uses interface List<chatSession> as sessionList;
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
      // call Transport.read();
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
      dbg(GENERAL_CHANNEL, "destination: %d, srcPort: %d, destPort: %d, transferCount: %d\n", destination, srcPort, destPort, transferCount);
      sock = call Transport.socket();
      addr.addr = TOS_NODE_ID;
      addr.port = srcPort;
      err = call Transport.bind(sock, &addr);
      if(err != SUCCESS) return;

      serverAddr.port = destPort;
      // serverAddr.addr = destination;
      serverAddr.addr = 1; //hard-coding for now 
      err = call Transport.connect(sock, &serverAddr);
      //implement error handling 
      if(err != SUCCESS) return;
      //start timer 
      //need to do write
      // call Transport.write();
      err = call Transport.close(sock);
      //error handling
      if(err != SUCCESS) return;

   }

   void processCommand(nx_uint8_t CMD_buffer[], socket_t clientSocket){
      /*
         parse command out of server buffer, looking for white space or \r
         figure out command 
         switch(command):
            case hello
               username, clientPort into sessionList
            case whisper
               
            case msg 
               
            case listusr
               print all users from sessionList
      
      */
      uint8_t position;
      uint8_t action;
      uint8_t j; 
      chatSession session;
      socket_t sock;
      uint8_t username[MAX_USERNAME_LEN];
      uint8_t clientPortString[MAX_CLIENT_PORT_LEN];
      uint8_t msgString[MAX_MSG_LEN];
      uint8_t commandString[SERVER_CMD_BUFFER_SIZE] = {0};

      memset(username, 0, sizeof(username));
      memset(clientPortString, 0, sizeof(clientPortString));
      memset(msgString, 0, sizeof(msgString));

     
      for(j = 0; j < SERVER_CMD_BUFFER_SIZE; j++){
         // dbg(GENERAL_CHANNEL, "j: %d, CMD_buffer[j]: '%c'\n", j, CMD_buffer[j]);
         if(CMD_buffer[j] == '\r' || CMD_buffer[j] == ' '){
            position = j;
            break;
         }
      }


      strncpy(commandString, CMD_buffer, position);
      if(strcmp(commandString, HELLO_STR) == 0){
         action = HELLO_CMD;
      }else if(strcmp(commandString, MSG_STR) == 0){
         action = MSG_CMD;
      }else if(strcmp(commandString, WHISPER_STR) ==0){
         action = WHISPER_CMD;
      }else if(strcmp(commandString, LISTUSR_STR) ==0){
         action = LISTUSR_CMD;
      }

      dbg(GENERAL_CHANNEL, "commandString: '%s', action: %d, CMD_buffer: '%s', position: %d\n", commandString, action, CMD_buffer, position);
      switch(action){
         case HELLO_CMD:
            //finding and saving username 
            for( j=position +1; j<SERVER_CMD_BUFFER_SIZE; j++){
               if(CMD_buffer[j] == ' '){
                  break;
               }
            }
            dbg(GENERAL_CHANNEL, "position: %d, j: %d\n", position, j);
            strncpy(username, &CMD_buffer[position +1], j-position-1);
            dbg(GENERAL_CHANNEL, "username: '%s'\n", username);
            //updating where we want to start from in our parsing 
            position = j;
            //finding and saving clientPort
            for( j=position +1; j<SERVER_CMD_BUFFER_SIZE; j++){
               // dbg(GENERAL_CHANNEL, "j: %d, CMD_buffer[j]: '%c'\n", j, CMD_buffer[j]);
               if(CMD_buffer[j] == '\r'){
                  break;
               }
            }
            // dbg(GENERAL_CHANNEL, "username: '%s'\n", username);
            dbg(GENERAL_CHANNEL, "position: %d, j: %d\n", position, j);
            strncpy(clientPortString, &CMD_buffer[position +1], j-position-1);
            dbg(GENERAL_CHANNEL, "clientPortString: '%s'\n", clientPortString);

            //appending into sessionList
            // dbg(GENERAL_CHANNEL, "username: '%s'\n", username);
            strncpy(session.username, username, sizeof(username));
            dbg(GENERAL_CHANNEL, "session.username: '%s'\n", session.username);
            session.clientPort = atoi(clientPortString);
            dbg(GENERAL_CHANNEL, "session.clientPort: %d, session.username: '%s'\n", session.clientPort, session.username);
            dbg(GENERAL_CHANNEL, "sessionList.size: %d\n", call sessionList.size());
            call sessionList.pushback(session);
            dbg(GENERAL_CHANNEL, "sessionList.size after pushback: %d\n", call sessionList.size());
            break;
         case MSG_CMD:
         //position stores the index where 'msg' ended
            for(j = position+1; j< SERVER_CMD_BUFFER_SIZE; j++){
               if(CMD_buffer[j] == '\r'){
                  break;
               }
            }
            strncpy(msgString, &CMD_buffer[position+1], j-position-1);
            dbg(GENERAL_CHANNEL, "msgString: '%s', position: %d, j: %d\n", msgString, position, j);
            
            for(j = 0; j < call sessionList.size(); j++){
                session = call sessionList.get(j);
                sock = call Transport.getSocket(session.clientPort, SERVER_LISTEN_PORT);
                dbg(GENERAL_CHANNEL, "got clientSocket: %d\n", sock);
               //  call Transport.write(sock, msgString, MAX_MSG_LEN); // we are sending their username and msg back 
                dbg(GENERAL_CHANNEL, "broadcasting msg to user: '%s'\n", session.username);
            }

            break;
         case WHISPER_CMD:
         //position is where we found "whisper" cmd already
            for( j=position +1; j<SERVER_CMD_BUFFER_SIZE; j++){
               if(CMD_buffer[j] == ' '){
                  break;
               }
            }
            dbg(GENERAL_CHANNEL, "position: %d, j: %d\n", position, j);
            strncpy(username, &CMD_buffer[position +1], j-position-1);
            dbg(GENERAL_CHANNEL, "username: '%s'\n", username);
            //updating where we want to start from in our parsing 
            position = j;
            //finding msg
            for( j=position +1; j<SERVER_CMD_BUFFER_SIZE; j++){
               if(CMD_buffer[j] == '\r'){
                  break;
               }
            }

            strncpy(msgString, &CMD_buffer[position +1], j-position-1);
            dbg(GENERAL_CHANNEL, "msgString: '%s'\n", msgString);

            for(j = 0; j < call sessionList.size(); j++){
               session = call sessionList.get(j);
               if(strcmp(session.username, username) == 0){
                  dbg(GENERAL_CHANNEL, "session.username: '%s'\n", session.username);
                  sock = call Transport.getSocket(session.clientPort, SERVER_LISTEN_PORT);
                  dbg(GENERAL_CHANNEL, "got clientSocket: %d\n", sock);
                  // call Transport.write(sock, msgString, MAX_MSG_LEN); // we are sending their username and msg back 
                  
                  /*
                  
                     either add client socket to chat session struct or use getSocket from transport 
                     get socket
                     write 

                     same for broadcast, but we iterate through all client ports, no username neccesary

                     
                  */
               }
            }

            break;
         case LISTUSR_CMD:
            dbg(GENERAL_CHANNEL, "all connected users:\n");
            for(j = 0; j < call sessionList.size(); j++){
               //print all session.username and session.clientPort
               chatSession session = call sessionList.get(j);
               dbg(GENERAL_CHANNEL, "'%s'\n", session.username);
               //we need to send it to the client through write()
               //currently casuing segmenetation fault 
               // call Transport.write(clientSocket, session.username, MAX_USERNAME_LEN);
            }

            break;
      }

   }

   event void CommandHandler.setAppServer(){
      socket_t sock; 
      socket_t clientSock;
      socket_addr_t addr;
      socket_addr_t destAddr;
      error_t err;
      nx_uint8_t serverCMDbuffer[SERVER_CMD_BUFFER_SIZE];
      dbg(GENERAL_CHANNEL, "APP SERVER EVENT\n");
      sock = call Transport.socket();
      addr.addr = SERVER_ADDRESS;
      addr.port = SERVER_LISTEN_PORT;
      err = call Transport.bind(sock, &addr);
      if(err != SUCCESS){
         return;
      }
      //start timer
      err = call Transport.listen(sock);
      //implement error handle
      if(err != SUCCESS) return;          
      clientSock = call Transport.accept(sock);
      destAddr.port = 6;
      call Transport.setDestPort(clientSock, &destAddr);
      call Transport.read(clientSock, serverCMDbuffer, SERVER_CMD_BUFFER_SIZE);
      //simulating and handling the different scenarios 
      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));      
      strncpy(serverCMDbuffer, SIM_HELLO_1, 21);
      processCommand(serverCMDbuffer, clientSock);

      clientSock = call Transport.accept(sock);
      destAddr.port = 10;
      call Transport.setDestPort(clientSock, &destAddr);
      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));      
      strncpy(serverCMDbuffer, SIM_HELLO_2, 17);
      processCommand(serverCMDbuffer, clientSock);

      clientSock = call Transport.accept(sock);
      destAddr.port = 8;
      call Transport.setDestPort(clientSock, &destAddr);
      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));      
      strncpy(serverCMDbuffer, SIM_HELLO_3, 18);
      processCommand(serverCMDbuffer, clientSock);

      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));
      strncpy(serverCMDbuffer, SIM_BROADCAST, 20);
      processCommand(serverCMDbuffer, clientSock);

      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));
      strncpy(serverCMDbuffer, SIM_WHISPER, 26);
      processCommand(serverCMDbuffer, clientSock);

      memset(serverCMDbuffer, 0, sizeof(serverCMDbuffer));
      strncpy(serverCMDbuffer, SIM_LISTUSR, 11);
      processCommand(serverCMDbuffer, clientSock);

      /*
         copy into server command buffer SIM_HELLO
         processCommand(serverCMDbuffer)
         copy into server command buffer SIM_BROADCAST
         processCommand(serverCMDbuffer)
         copy into server command buffer SIM_WHISPER
         processCommand(serverCMDbuffer)
         copy into server command buffer SIM_LISTUSR
         processCommand(serverCMDbuffer)
      
      
      */
      
      

   }

   event void CommandHandler.setAppClient(uint8_t clientPort, uint8_t* username){
      socket_t sock; 
      socket_addr_t addr;
      socket_addr_t serverAddr;
      error_t err;
      nx_uint8_t clientbuffer[CLIENT_CMD_BUFFER_SIZE];
      dbg(GENERAL_CHANNEL, "APP CLIENT EVENT\n");
      dbg(GENERAL_CHANNEL, "clientPort: %d, username: '%s'\n", clientPort, username);
      sock = call Transport.socket();
      addr.addr = TOS_NODE_ID;
      addr.port = clientPort;
      err = call Transport.bind(sock, &addr);
      if(err != SUCCESS){
         return;
      }

     serverAddr.addr = SERVER_ADDRESS;
     serverAddr.port = SERVER_LISTEN_PORT;
     err = call Transport.connect(sock, &serverAddr);
     
     /* can have a sort of global username Array instead of parameter 

      construct a hello message based on clientPort and username
      write to serverSock

      construct a whisper based on hardcoded username 
      write() to serverSock 
      read() server reply if meant for use (use strcmp with username and hardcode)

      construct a broadcast 
      write msg to socket
      read() broadcasted reply 

      construct listusr
      write listusr to socket 
      read() server reply 
     
     */
    
     
   }
}
