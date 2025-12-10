#ifndef __CHAT_H__
#define __CHAT_H__

#include "socket.h"

enum{
    MAX_NUM_OF_CHAT_CLIENTS = 11,
    MAX_USERNAME_LEN = 20,
    SERVER_LISTEN_PORT = 41,
    SERVER_ADDRESS = 1,
    CLIENT_CMD_BUFFER_SIZE = 50,
    SERVER_CMD_BUFFER_SIZE = 50,
    HELLO_CMD = 1,
    MSG_CMD = 2,
    WHISPER_CMD = 3,
    LISTUSR_CMD = 4,
};

typedef nx_struct chatSession{
    nx_uint8_t username[MAX_USERNAME_LEN];
    nx_socket_port_t clientPort;
}chatSession;




#endif