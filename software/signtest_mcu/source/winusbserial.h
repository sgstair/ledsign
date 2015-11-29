#ifndef WINUSBSERIAL_H
#define WINUSBSERIAL_H

// Public USB routines
void usb_init();
int usb_IsActive();


// Serial port related routines
int Serial_CanRecvByte(); 
int Serial_RecvByte(); // Returns -1 on failure
int Serial_PeekByte(); // Returns -1 on failure
int Serial_PeekByte2(); // Returns -1 on failure
int Serial_PeekN(int n); // Returns -1 on failure
int Serial_CanSendByte();
int Serial_SendByte(int b); // returns 0 on failure
int Serial_BytesToRecv();
int Serial_BytesCanSend();
int Serial_RecvBytes(unsigned char * bytes, int count);
int Serial_SendBytes(unsigned char * bytes, int count);
int Serial_SendQueued();
void Serial_HintMoreData(); // Suggest to USB chipset it should try exchanging data again. Should only call this if you have something worth sending or need it sent quickly (may lower bandwidth otherwise)

static const int Serial_ChunkSize = 64;








#endif
