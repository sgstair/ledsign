/*
Copyright (c) 2014 Stephen Stair (sgstair@akkit.org)

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

#include "lpc13xx.h"
#include "winusbserial.h"
#include "system.h"
#include "fifobuf.h"
#include "dpc.h"



char config;
char shouldackin0; 

const void* configdata_start;
short configdata_cursor;
short configdata_length;

unsigned char config_bytes[800];

const char * string1 = "MatrixDriver"; // Manufacturer
const char * string2 = "MatrixDriver Test Device"; // Device name

const char* os_stringdescriptor = "MSFT100A"; // Specify bRequest 0x41 ("A") as the OS Feature descriptor request.


const char* ext_prop_names[] = { "DeviceInterfaceGUID" };
const char* ext_prop_values[] = { "{b86d3dd6-c9d8-4401-959b-efbbd9bf1f3c}" };



const unsigned char os_feature_descriptor[] = {
	0x28, 0x00, 0x00, 0x00, // 0x28 bytes
	0x00, 0x01, // BCD Version ( 0x0100 )
	0x04, 0x00, // wIndex (Extended compat ID)
	0x01,		// count
	0,0,0,0,0,0,0, // 7x reserved
	// Function section
	
	0x00,		// Interface number
	0x01,		// Reserved, must be 1
	'W', 'I', 'N', 'U', 'S', 'B', 0, 0, // Compatible ID
	0,0,0,0,0,0,0,0, // Secondary ID
	0,0,0,0,0,0 // 6x Reserved
};


const unsigned char descriptor_device[]  = {
	0x12, 		// Length
	1, 			// type = DEVICE
	0x00, 0x02, // USB Version = 0x02.0x00
	0x00, 		// Device class = 0
	0, 			// Subclass 0
	0, 			// Protocol = 0
	64, 		// Endpoint 0 size = 64
	0x4c, 0x54, // Vendor ID 0x544C (arbitrary)
	0x7f, 0x4C, // Product ID 0x4C7f "Lt" (arbitrary)
	1, 0, 		// Release 0.01
	1, 			// Manufacturer string
	2, 			// Product String
	3, 			// Serial number string
	1			// Number of configurations
};

const unsigned char descriptor_configuration[] = {
	9,			// Length
	2,			// type = CONFIGURATION
	32,0,		// Full length of configuration
	1,			// Number of interfaces
	1,			// Configuration Index
	0,			// Configuration description string
	0x80,		// Attribute bitmask (must include 0x80)
	0x32,  		// Power drawn (in units of 2mA)
	
	9,			// Length
	4,			// Type = INTERFACE
	0,			// Interface index
	0,			// Alternate index
	2,			// Endpoints used
	0xFF,		// Class (COMM Data class)
	0,			// Subclass
	0,			// Protocol
	0, 			// Function (string)
	
	7,			// Length
	5,			// Type = ENDPOINT
	0x83,		// IN endpoint 3
	2,			// Attributes (BULK)
	64,0,		// Maximum size = 64 bytes
	0, 			// Poll interval = 0
	
	7,			// Length
	5,			// Type = ENDPOINT
	0x03,		// OUT Endpoint 3
	2,			// Attributes (BULK)
	64, 0,		// Maximum size = 64 bytes
	0			// Poll interval = 0
};

const unsigned char usbstring_langids[] = { 4, 3, 9, 4 };



int usb_IsActive()
{
	return config;
}


// USB! We all love USB.

// SIE interface, documented in LPC 13xx user manual section 9.10.2. Examples in 9.11
void Usb_SendCmd(unsigned long cmd)
{
	USBDEVINTCLR = 0xC00;
	USBCMDCODE = cmd | USBCMD_PHASE_COMMAND;
	while(!(USBDEVINTST & 0x400));
}
void Usb_SendData(unsigned char data)
{
	USBDEVINTCLR = 0xC00;
	USBCMDCODE = (data<<16) | USBCMD_PHASE_WRITE;
	while(!(USBDEVINTST & 0x400));
}
unsigned char Usb_RecvData()
{
	USBDEVINTCLR = 0xC00;
	USBCMDCODE = USBCMD_PHASE_READ;
	while(!(USBDEVINTST & 0x400));
	while(!(USBDEVINTST & 0x800));
	return USBCMDDATA&255;
}

// Wrappers for SIE commands - Documented in LPC 13xx user manual section 9.11
void Usb_SetAddress(unsigned char enable, unsigned char address)
{
	Usb_SendCmd(USBCMD_SETADDRESS);
	address = address & 127;
	if(enable) address |= 128;
	Usb_SendData(address);
}

void Usb_ConfigureDevice(unsigned char isconfigured)
{
	Usb_SendCmd(USBCMD_CONFIGUREDEVICE);
	Usb_SendData(isconfigured?1:0);
}

void Usb_SetMode(unsigned char data)
{
	Usb_SendCmd(USBCMD_SETMODE);
	Usb_SendData(data);
}

unsigned char Usb_ReadInterruptStatus()
{
	Usb_SendCmd(USBCMD_READINTERRUPTSTATUS);
	unsigned int status = Usb_RecvData();
	status |= Usb_RecvData()<<8;
	return status;
}

unsigned char Usb_ReadFrameNumber8()
{
	Usb_SendCmd(USBCMD_READFRAMENUMBER);
	return Usb_RecvData();
}

unsigned int Usb_ReadFrameNumber16()
{
	Usb_SendCmd(USBCMD_READFRAMENUMBER);
	unsigned int framenum = Usb_RecvData();
	framenum |= Usb_RecvData()<<8;
	return framenum;
}

unsigned int Usb_ReadChipId()
{
	Usb_SendCmd(USBCMD_READCHIPID);
	unsigned int chipid = Usb_RecvData();
	chipid |= Usb_RecvData()<<8;
	return chipid;
}

void Usb_SetDeviceStatus(unsigned char data)
{
	Usb_SendCmd(USBCMD_SETDEVICESTATUS);
	Usb_SendData(data);
}

unsigned char Usb_GetDeviceStatus()
{
	Usb_SendCmd(USBCMD_GETDEVICESTATUS);
	return Usb_RecvData();
}

unsigned char Usb_GetErrorCode()
{
	Usb_SendCmd(USBCMD_GETERRORCODE);
	return Usb_RecvData();
}

unsigned char Usb_SelectEndpoint(unsigned char endpoint)
{
	Usb_SendCmd(USBCMD_SELECTENDPOINT(endpoint));
	return Usb_RecvData();
}

unsigned char Usb_SelectEndpointClearInterrupt(unsigned char endpoint)
{
	Usb_SendCmd(USBCMD_SELECTENDPOINTC(endpoint));
	return Usb_RecvData();
}

void Usb_SetEndpointStatus(unsigned char endpoint, unsigned char status)
{
	Usb_SendCmd(USBCMD_SETENDPOINTSTATUS(endpoint));
	Usb_SendData(status);
}

unsigned char Usb_ClearBuffer()
{
	Usb_SendCmd(USBCMD_CLEARBUFFER);
	return Usb_RecvData();
}

void Usb_ValidateBuffer()
{
	Usb_SendCmd(USBCMD_VALIDATEBUFFER);
}



// Further wrappers to do helpful things
// Everything uses "physical" endpoint numbers. See LPC13xx user manual section 9.5

// Read the length of an incoming packet on a specific endpoint (assuming there is a packet)
int ReadPacketLength(int ep) 
{
	if((ep&1)==1) return 0; // Can't read from IN endpoint
	ep = ep>>1;
	ep = ep * 4 + 1;
	USBCTRL = ep;
	delayus(0);
	int rxlen = (int)USBRXPLEN;
	if(!(rxlen&0x400)) rxlen = 0;
	return rxlen&0x3FF;
}

// Copy the next available packet on a specific endpoint (assuming there is a packet) into the buffer specified
void ReadPacket(int ep, void* data, int length) // Note: round up to the next multiple of 4 bytes for buffer space.
{
	if((ep&1)==1) return; // Can't read from IN endpoint
	ep = ep>>1;
	ep = ep*4 + 1;
	USBCTRL = ep;
	delayus(0);
	int i=0;
	while((i*4)<length)
	{
		((unsigned long *)data)[i] = USBRXDATA;
		i++;
	}
}

// Send a packet on a specific endpoint (Assuming there is buffer space available) using the buffer specified
void WritePacket(int ep, void* data, int length)
{
	if((ep&1)==0) return; // Can't write to OUT endpoint
	ep = ep>>1;
	ep = ep*4 + 2;
	USBCTRL = ep;
	delayus(0);
	USBTXPLEN = length;
	int i=0;
	if(length==0) length=1;
	while((i*4)<length)
	{
		USBTXDATA = ((unsigned long *)data)[i];
		i++;
	}
}









void DisableEndpoints()
{
	Usb_ConfigureDevice(0); // Not configured: Only respond on default (setup) endpoint, #0
}
void EnableEndpoints()
{
	Usb_ConfigureDevice(1); // We are configured now. Requests to other endpoints will now succeed.
}





void continue_configdata()
{
	int pktlen;
	if(!configdata_start) return; // No packet in flight.

	USBDEVINTCLR = 4; // Clear EP1 interrupt
	Usb_SelectEndpointClearInterrupt(1); // clear endpoint interrupt.
	while(1)
	{
		pktlen = configdata_length - configdata_cursor;
		if(pktlen > 64) pktlen = 64;

		// Can we send a further packet?
		int status = Usb_SelectEndpoint(1);
		if(status&1) break; // No empty buffers remain.

		WritePacket(1, ((char*)configdata_start)+configdata_cursor, pktlen); // Everything uses "physical" endpoint numbers. See LPC13xx user manual section 9.5
		Usb_ValidateBuffer();

		configdata_cursor += 64;
		if(configdata_cursor > configdata_length)
		{
			// This was the last packet.
			configdata_start = 0;

			break;
		}

	}
}

// Send descriptor/etc data back down the config channel
// Have to split it into packets of the endpoint size (here endpoint size is 8 bytes)
// Also have to send an empty packet if the last packet was the max size (8 bytes)
void send_configdata(const void* data, int datalength, int maxlength)
{
	if(datalength > maxlength) datalength = maxlength;
	configdata_start = data;
	configdata_cursor = 0;
	configdata_length = datalength;
	continue_configdata();
}
void send_copyconfigdata(const void* data, int datalength, int maxlength)
{
	if(datalength > maxlength) datalength = maxlength;
	if(datalength > (int)sizeof(config_bytes)) datalength = (int)sizeof(config_bytes);
	memcpy(config_bytes, data, datalength);
	send_configdata(config_bytes, datalength, maxlength);
}

void send_config2bytes(unsigned char byte1, unsigned char byte2, int maxlength)
{
	config_bytes[0] = byte1;
	config_bytes[1] = byte2;
	send_configdata(config_bytes,2,maxlength);
}
void send_config1byte(unsigned char byte1, int maxlength)
{
	config_bytes[0] = byte1;
	send_configdata(config_bytes,1,maxlength);
}

void send_stringdescriptor(const char* string, int maxlength)
{
	// Convert string to string descriptor
	config_bytes[0] = 0; // Will be descriptor length
	config_bytes[1] = 3;

	int i = 2;
	while(*string && i<(int)sizeof(config_bytes))
	{
		config_bytes[i++] = *string++;
		config_bytes[i++] = 0;
	}
	config_bytes[0] = (unsigned char)i;

	send_configdata(config_bytes, i, maxlength);
}

void send_serialnumber(int maxlength)
{
	unsigned char * serialnumber = (unsigned char *)UID;
	// Convert string to string descriptor
	config_bytes[0] = 0; // Will be descriptor length
	config_bytes[1] = 3;

	int i = 2;
	int n = 0;
	while(n<16)
	{
		char digit;

		digit = (serialnumber[15-n]>>4)&15;
		if(digit > 9) digit+= 'A'-10; else digit += '0';
		config_bytes[i++] = digit;
		config_bytes[i++] = 0;

		digit = serialnumber[15-n] & 15;
		if(digit > 9) digit+= 'A'-10; else digit += '0';
		config_bytes[i++] = digit;
		config_bytes[i++] = 0;
		n++;
	}
	config_bytes[0] = (unsigned char)i;

	send_configdata(config_bytes, i, maxlength);
}

int strlen(const char* string)
{
	int i = 0;
	while(*string++) i++;
	return i;
}

void send_ext_prop(int propcount, const char** const names, const char** const values, int maxlength)
{
	// Determine length
	int totallength = 10;
	int i;
	for(i=0;i<propcount;i++)
	{
		totallength += 14 + strlen(names[i])*2 + strlen(values[i])*2 + 4;
	}

	if(totallength > (int)sizeof(config_bytes))
	{
		// Can't really do much here.
		return;
	}

	// Generate header
	i = 0;
	config_bytes[i++] = totallength&255;
	config_bytes[i++] = (totallength>>8)&255;
	config_bytes[i++] = 0;
	config_bytes[i++] = 0;

	config_bytes[i++] = 0;
	config_bytes[i++] = 0x01;

	config_bytes[i++] = 5;
	config_bytes[i++] = 0;

	config_bytes[i++] = propcount;
	config_bytes[i++] = 0;
	

	// for each property...
	for(int n=0; n<propcount; n++)
	{
		const char* string;
		int len = 14 + 4 + strlen(names[n])*2 + strlen(values[n])*2; 
		
		config_bytes[i++] = len&255;
		config_bytes[i++] = (len>>8)&255;
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;
	
		config_bytes[i++] = 1; // Data type = 1, REG_SZ
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;
	
		len = strlen(names[n])*2 + 2;
		config_bytes[i++] = len&255;
		config_bytes[i++] = (len>>8)&255;

		string = names[n];
		while(*string)
		{
			config_bytes[i++] = *string++;
			config_bytes[i++] = 0;
		}
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;


		len = strlen(values[n])*2 + 2;
		config_bytes[i++] = len&255;
		config_bytes[i++] = (len>>8)&255;
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;

		string = values[n];
		while(*string)
		{
			config_bytes[i++] = *string++;
			config_bytes[i++] = 0;
		}
		config_bytes[i++] = 0;
		config_bytes[i++] = 0;
	}

	send_configdata(config_bytes, totallength, maxlength);

}


void HandleSetupPacket()
{
	unsigned char setupreq[8]; // Should be word aligned.
	// read out setup packet
	int readpacket = 0;

	if(ReadPacketLength(0) == 8) // Setup packets should be length 8
	{
		ReadPacket(0, setupreq, 8);
		readpacket = 1;
	}
	Usb_SelectEndpoint(0);
	Usb_ClearBuffer();

	if(!readpacket) return; // Ignore non-setup packet

	// Cancel in flight request.
	configdata_start = 0;
	shouldackin0 = 0;


	// Decode fields for convenience.
	unsigned char bmRequestType = setupreq[0];
	unsigned char bRequest = setupreq[1];
	unsigned short wValue = setupreq[2] | ((unsigned short)setupreq[3]<<8);
	unsigned short wIndex = setupreq[4] | ((unsigned short)setupreq[5]<<8);
	unsigned short wLength = setupreq[6] | ((unsigned short)setupreq[7]<<8);

	// Respond to setup packet!
	switch((bmRequestType&0x60)>>5)
	{
	case 0: // Standard requests
		switch(bRequest) // switch on request type .. See page 248-251 of USB2.0 SPEC
		{
		case 0: // GET_STATUS
			send_config2bytes(0,0,wLength);
			return;
		case 1: // CLEAR_FEATURE
		case 3: // SET_FEATURE
			// Not implementing features.
			break;
		case 5: // SET_ADDRESS 
			if(bmRequestType != 0) break;
			Usb_SetAddress(1,wValue&127); // Address will be set after this exchange completes.
			WritePacket(1,setupreq,0);
			Usb_SelectEndpoint(1);
			Usb_ValidateBuffer();
			return;
		case 6: // GET_DESCRIPTOR
			if(bmRequestType != 0x80) break; // Only handle requests of the right type.
			if((wValue>>8) == 1)
			{ // Device Descriptor
				send_configdata(descriptor_device, sizeof(descriptor_device), wLength);
				return;
			}
			else if((wValue>>8) == 2)
			{ // Configuration Descriptor
				send_configdata(descriptor_configuration, sizeof(descriptor_configuration), wLength);
				return;
			}
			else if((wValue>>8) == 3)
			{ // Request string descriptor...
				switch(wValue&255)
				{
				case 0: // Define list of supported langids
					{
						send_configdata(usbstring_langids,sizeof(usbstring_langids),wLength);
					}
					return;
				case 1:
					send_stringdescriptor(string1, wLength);
					return;
				case 2:
					send_stringdescriptor(string2, wLength);
					return;
				case 3:
					send_serialnumber(wLength);
					//send_stringdescriptor(string3, wLength);
					return;
				case 0xEE: // OS String descriptor
					send_stringdescriptor(os_stringdescriptor, wLength);
					return;
				}
			}
			break;
		case 7: // SET_DESCRIPTOR
			break; // Don't support setting descriptors.
		case 8: // GET_CONFIGURATION
			if(bmRequestType != 0x80) break;
			send_config1byte(config, wLength);
			return;
		case 9: // SET_CONFIGURATION
			if(bmRequestType != 0) break;
			if(wValue > 1) break;
			config = wValue;
			Usb_ConfigureDevice((char)config);
			goto success;
		case 10: // GET_INTERFACE
		case 11: // SET_INTERFACE
			break;
		}
		break;
	case 1: // Class requests

		break;

	case 2: // Vendor requests
		switch(bRequest)
		{
			// In this device, custom vendor requests must be device targeted device->host or host->device requests.
			// ReqeustType 0xC0 = device to host, 0x40 = host to device.
		

			case 0x02: // Reprogram device
				programcount = 5;
				goto success;
				
			// Todo: add relevant vendor commands.
			
			
			case 0x41:
			switch(wIndex)
			{
			case 4: // Extended OS Feature descriptor
				if((wValue>>8) == 0)
				{
					// only respond for page 0
					send_configdata(os_feature_descriptor, sizeof(os_feature_descriptor), wLength);
					return;
				}
				break;
				
			case 5: // Extended Properties OS Descriptor
				if(wValue == 0)
				{
					// Only respond for page 0 of interface 0
					send_ext_prop(sizeof(ext_prop_names)/sizeof(*ext_prop_names), ext_prop_names, ext_prop_values, wLength);
					return;
				}
				break;
			}
			
		}
	
		break;
	case 3: // Reserved
		break;
	}
	// By default stall any unknown transactions.
	Usb_SetEndpointStatus(0,0x80);
	return;
success:
	// Generic success: ACK return transaction.
	WritePacket(1,setupreq,0);
	Usb_SelectEndpoint(1);
	Usb_ValidateBuffer();
}



void usb_reset()
{
	InterruptDisable(INT_USBIRQ);

	// Setup USB interrupts
	USBDEVINTEN = 0x0397; // DEV_STAT, FRAME, EP0,1,3,6,7

	Usb_SetDeviceStatus(0x0); // Disconnect
	int i;
	for(i=0;i<=9;i++)
	{
		Usb_SetEndpointStatus(i,0x20); // Disable all endpoints
		if(i<=7) Usb_SelectEndpointClearInterrupt(i);
	}
	Usb_SetEndpointStatus(0,0x0); // Setup endpoints
	Usb_SetEndpointStatus(1,0x0);
	Usb_SetEndpointStatus(3,0x0); // Enable IN endpoint 1 (LPC13xx user manual 9.5)
	Usb_SetEndpointStatus(6,0x0); // Enable OUT endpoint 3
	Usb_SetEndpointStatus(7,0x0); // Enable IN endpoint 3

	Usb_SetAddress(1, 0);
	DisableEndpoints();

	USBDEVINTCLR = 0x200; // Clear DEV_STAT interrupt.
	Usb_GetDeviceStatus(); // Clears DEV_STAT interrupt.
	Usb_GetErrorCode(); // Discard error code.

	USBDEVINTCLR = 0xFFFF;
	config = 0;
	configdata_start = 0; // Disable sending of config data);

	Usb_SetDeviceStatus(1); // Connect!

	InterruptEnable(INT_USBIRQ);
}



// Handle serial streams
#define USBSER_BUFFER 128

FifoBuffer<USBSER_BUFFER> usbrx;
FifoBuffer<512> usbtx;

// Interrupt interface functions (write to rx buffer, read from tx buffer)

unsigned char usbser_tempbuffer[64]; // Very sad to do it this way, wasting 64 bytes, but it makes the code so much simpler.
// Considering wasting the 64 bytes on the stack, but it's wasted either way...

void usbser_tryrecv() // Endpoint 6 (3 OUT)
{
	int madeprogress = 0;
	while(1)
	{
		int epstatus = Usb_SelectEndpointClearInterrupt(6);
		if(epstatus&1)
		{
			// There is a packet to receive!
			int length = ReadPacketLength(6);
			if(length>64) length=64;
			// Can we get it?
			int available = usbrx.Free();
			if(available >= length)
			{ // We have enough space!
				ReadPacket(6,usbser_tempbuffer,length);
				Usb_ClearBuffer();
				int i;
				for(i=0;i<length;i++)
				{
					usbrx.WriteByte(usbser_tempbuffer[i]);
				}
				madeprogress = 1;
				continue; // Check for another packet
			}
			// We did not have enough space for the packet. 
			// It will sit around until the next FRAME interrupt comes along and then check for more space.
		}
		// There was no packet. Stop looking for more data
		break;
	}
	if(madeprogress) dpc_trigger();
}
void usbser_trysend() // Endpoint 7 (3 IN)
{
	int madeprogress = 0;
	while(1)
	{
		int epstatus = Usb_SelectEndpointClearInterrupt(7);
		if((epstatus&1) == 0)
		{
			// We have space to send a packet! Is there anything to send?
			int available = usbtx.Length();
			if(available>64) available=64; // Can't send more than 64 bytes
			if(available > 0)
			{
				// Some bytes exist, lets send them.
				int i;
				for(i=0;i<available;i++)
				{
					usbser_tempbuffer[i] = usbtx.ReadByte();
				}
				WritePacket(7,usbser_tempbuffer,available);
				Usb_ValidateBuffer();
				madeprogress = 1;
				continue; // Try to send another packet, that was fun.
			}
			// We did not have any bytes to send
		}
		// There was not a buffer available to send bytes in. May or may not have had data to send, but it will wait until a new buffer arrives.
		break;
	}
	if(madeprogress) dpc_trigger();
}

// Serial interface functions 
int Serial_CanRecvByte() 
{
	return usbrx.CanRead();
}
int Serial_RecvByte() // Returns -1 on failure
{
	if(usbrx.CanRead())
	{
		return usbrx.ReadByte();
	}
	return -1;
}
int Serial_PeekByte() // Returns -1 on failure
{
	if(usbrx.CanRead())
	{
		return usbrx.PeekByte();
	}
	return -1;
}
int Serial_PeekByte2() // Returns -1 on failure
{
	if(usbrx.Length() >= 2)
	{
		return usbrx.PeekN(1);
	}
	return -1;
}
int Serial_PeekN(int n) // Returns -1 on failure
{
	if(usbrx.Length() >= n+1)
	{
		return usbrx.PeekN(n);
	}
	return -1;
}


int Serial_BytesToRecv()
{
	return usbrx.Length();
}

int Serial_CanSendByte()
{
	return usbtx.CanWrite();
}
int Serial_SendByte(int b) // returns 0 on failure
{
	if(usbtx.CanWrite())
	{
		usbtx.WriteByte((unsigned char)b);
		return 1;
	}
	return 0;
}
int Serial_BytesCanSend()
{
	return usbtx.Free();
}

int Serial_RecvBytes(unsigned char * bytes, int count)
{
	if(usbrx.Length() < count) return -1;
	usbrx.ReadBytes(bytes,count);
	return count;
}

int Serial_SendBytes(unsigned char * bytes, int count)
{
	if(usbtx.Free() < count) return -1;
	usbtx.WriteBytes(bytes,count);
	return count;
}
int Serial_SendQueued()
{
	return usbtx.Length();
}

void Serial_HintMoreData() // Suggest to USB chipset it should try exchanging data again. Should only call this if you have something worth sending or need it sent quickly (may lower bandwidth otherwise)
{
	// Inject a FRAME interrupt to the USB chipset.
	USBDEVINTSET = 1; // Set FRAME interrupt
}

// Break out interrupt into smaller pieces

void usbint_frame()
{
	// todo: something, anything here.

	usbser_tryrecv(); // Continue working if previously we jammed due to buffer space issues.
	usbser_trysend();
}
void usbint_ep0()
{ // Endpoint 0 OUT (into device)
	// If we got a setup packet, we should handle it
	int ep = Usb_SelectEndpointClearInterrupt(0);
	if(ep&4) { HandleSetupPacket(); }
	else
	{
		if(ep&1) { 	
			Usb_ClearBuffer(); // Pretend we didn't see.
			if(shouldackin0)
			{
				Usb_SelectEndpoint(1);
				WritePacket(1, config_bytes, 0); // Write 0 length ACK (there should be a buffer available)
				Usb_ValidateBuffer(); // Complete
				shouldackin0 = 0;
			}
		} 
	}
	// We really shouldn't see any other types of packets here.
}
void usbint_ep1()
{ // Endpoint 0 IN (out from device)
	// we should see if we need to continue a previous multi-packet setup transaction.

	continue_configdata();
}
void usbint_ep3()
{ // Endpoint 1 IN (out from device)
	// Interrupt endpoint, ignore. No need to send interrupts.
}
void usbint_ep6()
{ // Endpoint 3 OUT (in to device)
	// If we got data, and have space, read it!
	usbser_tryrecv();
}
void usbint_ep7()
{ // Endpoint 3 IN (out from device)
	// Continue a send, if we have additional data to offload.
	usbser_trysend();
}

void usbint_devstat()
{
	// Detect bus reset & change stuff appropriately.
	int status = Usb_GetDeviceStatus();
	// If not connected due to bus reset or connect change, re-setup the USB.
	if(status&0x12) usb_reset();
}





// Usb interrupt!
extern "C" void int_USBIRQ();
void int_USBIRQ()
{
	InterruptClear(INT_USBIRQ);

	if(USBDEVINTST&0x0001)
	{
		USBDEVINTCLR = 0x0001;
		usbint_frame();
	}
	if(USBDEVINTST&0x0002)
	{
		USBDEVINTCLR = 0x0002;
		usbint_ep0();
	}
	if(USBDEVINTST&0x0004)
	{
		USBDEVINTCLR = 0x0004;
		usbint_ep1();
	}
	if(USBDEVINTST&0x0010)
	{
		USBDEVINTCLR = 0x0010;
		usbint_ep3();
	}
	if(USBDEVINTST&0x0080)
	{
		USBDEVINTCLR = 0x0080;
		usbint_ep6();
	}
	if(USBDEVINTST&0x0100)
	{
		USBDEVINTCLR = 0x0100;
		usbint_ep7();
	}
	if(USBDEVINTST&0x0200)
	{
		USBDEVINTCLR = 0x0200;
		usbint_devstat();
	}
	// Done!
}





void usb_init()
{
	// Clear buffers
	usbrx.init();
	usbtx.init();

	InterruptSetPriority(INT_USBIRQ, 8); // Give slightly lower priority than the clock interrupt.

	// Initialize USB chipset
	usb_reset();
}


