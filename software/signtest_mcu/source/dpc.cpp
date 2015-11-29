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
#include "dpc.h"
#include "winusbserial.h"
#include "system.h"

unsigned char dpc_suspendcount;

int programcount;

// 1:30 as percentage between 0v and 3.3v
// Current sense is 0.01 Ohm = 10mV/A, amplified by a factor of 56.55555 (10k, 180ohm resistor values) (565.555mV/A)
const int current_limit = 1<<29; // 3.3/4 V = 1.45A;


void led_set_red(int value);
void led_set_green(int value);

void usb_heartbeat();

void spi_sendrecv_accel(unsigned char * data, int bytecount);
void spi_sendrecv_gyro(unsigned char * data, int bytecount);

void motor_reset();
void motor_power_on();
void motor_power_check(int us);
void motor_set_12(int dir);
void motor_set_34(int dir);
void motor_brake_12();
void motor_brake_34();


void dpc_work()
{



}


void dpc_tick()
{
	dpc_suspend();

	if(programcount > 0)
	{
		programcount--;
		if(programcount == 0)
		{
			update_firmware();
		}
	}
	
	dpc_resume();
}


extern "C" void int_I2C0(); // use I2C0 for now, because it isn't being used by anything else.
void int_I2C0()
{
	InterruptClear(INT_I2C0);
	dpc_work();
}

void dpc_trigger()
{
	InterruptTrigger(INT_I2C0);
}

void dpc_suspend()
{
	InterruptDisable(INT_I2C0);
	dpc_suspendcount++;
}

void dpc_resume()
{
	dpc_suspendcount--;
	if(dpc_suspendcount==0)
		InterruptEnable(INT_I2C0);
}

void dpc_init()
{

	programcount = 0;
	InterruptDisable(INT_I2C0);
	InterruptSetPriority(INT_I2C0,31);
	InterruptClear(INT_I2C0);
	dpc_suspendcount=0;

	InterruptEnable(INT_I2C0);
}