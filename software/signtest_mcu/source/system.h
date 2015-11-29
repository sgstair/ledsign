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

#ifndef SYSTEM_H
#define SYSTEM_H

// Note! Delayus will only delay for 1/2 the duration it is asked to - it was based on a lower clock speed.
extern "C" void delayus(unsigned long delay);
// Delayms is correct.
void delayms(unsigned long delay);

extern "C" void call_IAP(unsigned long* cmd, unsigned long* res);
extern "C" void call_IAP_noreturn(unsigned long* cmd, unsigned long* res);

void update_firmware();
void ReadDeviceUID();
extern unsigned long UID[4];


extern "C" void memcpy(void* dest, const void* src, int length);




static const int adc_history_length = 64;

extern unsigned short adc_history[3+5*adc_history_length]; // 646 bytes of history, about 6ms worth.


#endif
