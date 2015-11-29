/*
Copyright (c) 2015 Stephen Stair (sgstair@akkit.org)

Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

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
