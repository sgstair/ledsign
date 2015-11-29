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

#include "lpc13xx.h"
#include "system.h"

void delayms(unsigned long delay)
{
	delayus(delay*2000);
}



unsigned long command[5], result[5];
void Usb_SetDeviceStatus(unsigned char data);
void update_firmware()
{
	// Disable any interrupts that we have set...
	int i;
	for(i=0;i<=INT_MAX;i++) { InterruptDisable(i); }

	// Turn off running hardware...
	TMR32B1TCR = 0;
	TMR32B1MCR = 0; // Disable or IAP will die a painful death.
	TMR32B1MR0 = 0;

	// Switch back to system clock & turn off USB.
	Usb_SetDeviceStatus(0x10); // Disconnect USB (and attempt to bus reset)
	delayms(100);
	PDRUNCFG += 0x400; // Turn off USB
	delayms(20);

	// Switch system clock over to RC clock
	MAINCLKSEL = 0; // set RC clock
	MAINCLKUEN = 0;
	MAINCLKUEN = 1;

	*((unsigned long *)(0x10000054)) = 0x0; // Fix LPC bug

	command[0] = 57;

	call_IAP_noreturn(command, result);
}

unsigned long UID[4];
void ReadDeviceUID()
{
	command[0] = 58;
	result[0] = result[1] = result[2] = result[3] = result[4] = 0x12345678;
	call_IAP(command, result);
	UID[0] = result[1];
	UID[1] = result[2];
	UID[2] = result[3];
	UID[3] = result[4];
}


void memcpy(void* dest, const void* src, int length)
{
	if ((((int)dest & 3) == 0) && (((int)src & 3) == 0) && length > 3)
	{
		unsigned int *dest32, *src32;
		dest32 = (unsigned int*)dest;
		src32 = (unsigned int *)src;
		// Speed hax
		while (length > 3)
		{
			*dest32++ = *src32++;
			length -= 4;
		}
		if (length == 0) return;
		dest = dest32;
		src = src32;
	}
	unsigned char *dest8, *src8;
	dest8 = (unsigned char*)dest;
	src8 = (unsigned char*)src;
	while (length > 0)
	{
		*dest8++ = *src8++;
		length--;
	}
}
