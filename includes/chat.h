#ifndef __CHAT_H__
#define __CHAT_H__

#include "socket.h"


#define SIM_HELLO_1 "hello shruthir 6\r\n"  
#define SIM_HELLO_2 "hello acerpa 10\r\n"  
#define SIM_HELLO_3 "hello asmaglov 8\r\n" 
#define SIM_WHISPER "whisper shruthir hi!\r\n" 
#define SIM_BROADCAST "msg hello world\r\n" 
#define SIM_LISTUSR "listusr\r\n" 
#define HELLO_STR "hello"
#define MSG_STR "msg"
#define WHISPER_STR "whisper"
#define LISTUSR_STR "listusr"



enum{
    MAX_NUM_OF_CHAT_CLIENTS = 11,
    MAX_USERNAME_LEN = 20,
    MAX_CLIENT_PORT_LEN = 3,
    MAX_MSG_LEN = 30,
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