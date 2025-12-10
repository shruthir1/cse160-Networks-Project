interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void flood(uint8_t* payload);
   event void route(uint8_t dest, uint8_t* payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint16_t address, uint8_t port);
   event void setTestClient(uint16_t destination, uint8_t srcPort, uint8_t destPort, uint16_t transferCount);
   event void setAppServer();
   event void setAppClient(uint8_t clientPort, uint8_t* username);
}
