/*

signtest Microcontroller project

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

typedef unsigned char u8;
typedef unsigned long u32;

#include "lpc13xx.h"
#include "system.h"
#include "dpc.h"
#include "winusbserial.h"
#include "fifobuf.h"



// IO mappings (with function) for usbstep board

// PIO0_5 (0) - LEDRED (LEDs are inverted; They're attached to the I2C pins that can only pull down.)
// PIO0_4 (0) - LEDGREEN (also the schematic has the LEDs backwards.)

// PIO0_0 - RST
// PIO0_1 (0) - PROG (free button)
// PIO0_3 (1-VBUS) - USB5V
// PIO0_6 (1) - USB_CONNECT#

// PIO2_0 (0) - JTAG_TDI
// PIO0_2 (0) - JTAG_TDO
// PIO1_6 (0) - JTAG_TCK
// PIO1_7 (0) - JTAG_TMS

// PIO1_8 (0) - SENSE1 (Sense when fpga board is inserted)
// PIO1_9 (0) - SENSE2 
// PIO0_7 (0) - VIN_SOFTIN (~100mA limited power on to 5V)
// PIO1_10 (0D) - VIN_ON (Turn power fully on to 5V)

// PIO0_11 (2-AD0) - MEASURE_VIN (this pin is 1/3 of the fpga board VIN voltage)
// PIO1_0 (2-AD1) - MEASURE_3V3 (Measure 3v3 rail of fpga board)
// PIO1_1 (2-AD2) - MEASURE_1V2 (Measure 1v2 rail of fpga board)

// PIO0_8 (0-GPIO,1-MISO) - FLASH_MISO (attached to SPI flash and FPGA)
// PIO0_9 (0-GPIO,1-MOSI) - FLASH_MOSI
// PIO0_10 (1-GPIO,2-SCK) - FLASH_CLK
// PIO1_5 (0) - FLASH_CS#

// (DBGIO - Extra IO pins wired to the fpga)
// PIO3_2 (0) - DBGIO1, fpga
// PIO1_11 (0D) - DBGIO2, fpga
// PIO1_4 (0D) - DBGIO3, fpga
// PIO1_3 (1D) - DBGIO4, fpga pin (Connected additionally to FPGA_DONE by connecting B11 and B7 on the PCI Express connector on the test board)
// PIO1_2 (1D) - DBGIO5, fpga pin (Connected additionally to FPGA_PROG# by connecting B10 and B8 on the PCI Express connector)


////////////////////////////////////////////////////////////////////////////////
//
//  Stateless I/O
//

// PIO0_5 - LEDRED
int led_red;

void led_set_red_internal(int value)
{
	GPIO0DIR |= (1<<5);
	GPIO0DATA[(1<<5)] = value?0:(1<<5);
}

void led_set_red(int value)
{
	value = value?1:0;
	led_red = value;
	led_set_red_internal(value);
}

void led_busy(int busy)
{
	busy = busy?1:0;
	led_set_red_internal(led_red ^ busy);
}



// PIO0_4 - LEDGREEN

void led_set_green(int value)
{
	GPIO0DIR |= (1<<4);
	GPIO0DATA[(1<<4)] = value?0:(1<<4);
}


// PIO0_7 (0) - VIN_SOFTON (~100mA limited power on to 5V) - Low is enable, release to disable (Board modified to include missing pullup resistors)
// PIO1_10 (0D) - VIN_ON (Turn power fully on to 5V)
int power_state;
void SetPowerDriveState(int value) // 0 = off, 1 = soft-on, 2=on
{
	if(value&2)
	{
		GPIO1DIR |= (1<<10); // Pull gate line down to enable the P-fet
		GPIO1DATA[1<<10] = 0;
	}
	else
	{
		GPIO1DIR &= ~(1<<10); // Release gate line and it will float up to 5V to turn off the P-fet
	}

	if(value&1)
	{
		GPIO0DIR |= (1<<7);
		GPIO0DATA[1<<7] = 0;
	}
	else
	{
		GPIO0DIR &= ~(1<<7);
	}
	
	power_state = value;
}

int GetPowerDriveState()
{
	return power_state;
}


// PIO1_8 (0) - SENSE1 (Sense when fpga board is inserted)
// PIO1_9 (0) - SENSE2 
int GetSense() // Returns bottom 2 bits as sense pin status. Zero means board is present.
{
	GPIO1DIR &= ~(0x300);
	return (GPIO1DATA[0x300] >> 8) & 3;
}


int GetButton() // Return 1 when PROG button is pressed.
{
	GPIO0DIR &= ~(1<<1);
	return (GPIO0DATA[2] == 0);
}



////////////////////////////////////////////////////////////////////////////////
//
//  SPI + FLASH + FPGA
//


const int FlashCmd_ChipErase = 0xC7;
const int FlashCmd_SectorErase = 0x20;
const int FlashCmd_BlockErase = 0xD8;
const int FlashCmd_ReadStatus = 0x05;
const int FlashCmd_ReadStatus2 = 0x35;
const int FlashCmd_ReadStatus3 = 0x33;
const int FlashCmd_WriteEnable = 0x06;
const int FlashCmd_Read = 0x03;
const int FlashCmd_Program = 0x02;
const int FlashCmd_RDID = 0x9F;
const int FlashCmd_PowerDown = 0xB9;
const int FlashCmd_ReleasePowerDown = 0xAB;


// PIO1_2 (1D) - DBGIO5, fpga pin (Connected additionally to FPGA_PROG# by connecting B10 and B8 on the PCI Express connector)
void fpga_prog(int halt) // 1 = stop FPGA, 0 = run FPGA
{

	// halt
	GPIO1DIR |= 1<<2;
	GPIO1DATA[1<<2] = 0;

	if(!halt)
	{
		delayms(2);
		//GPIO1DIR &= ~(1<<2);
		GPIO1DATA[1<<2] = (1<<2);
	}
}

// PIO1_5 (0) - FLASH_CS#
void flash_csenable(int enable)
{
	GPIO1DIR |= (1<<5);
	GPIO1DATA[(1<<5)] = enable?0:(1<<5);
}

// PIO3_2 (0) - DBGIO1, fpga
void fpga_csenable(int enable) // Using DBGIO1 to control assertion.
{
	GPIO3DIR |= (1<<2);
	GPIO3DATA[(1<<2)] = enable?0:(1<<2);
}

void SpiRelease()
{
	// Pull pins back to GPIO and make them inputs
	IOCON_PIO1_5 = 0;								// PIO1_5 (0) - FLASH_CS#
	IOCON_PIO0_8 = 0;								// PIO0_8 (1) - FLASH_MISO (SSP MISO) (also for FPGA)
	IOCON_PIO0_9 = 0;								// PIO0_9 (1) - FLASH_MOSI (SSP MOSI) (also for FPGA)
	IOCON_PIO0_10 = 1;								// PIO0_10 (2) - FLASH_CLK (SSP SCK) (also FPGA)
	GPIO0DIR &= ~(0x700);
	GPIO1DIR &= ~(1<<5);
}
void SpiEngage()
{
	// Configure pins for SPI
	IOCON_PIO1_5 = 0;								// PIO1_5 (0) - FLASH_CS#
	IOCON_PIO0_8 = 1;								// PIO0_8 (1) - FLASH_MISO (SSP MISO) (also for FPGA)
	IOCON_PIO0_9 = 1;								// PIO0_9 (1) - FLASH_MOSI (SSP MOSI) (also for FPGA)
	IOCON_PIO0_10 = 2;								// PIO0_10 (2) - FLASH_CLK (SSP SCK) (also FPGA)
	flash_csenable(0);
}




void SpiInit()
{
	// unreset SSP block
	PRESETCTRL |= 1;

	// configure SSP
	SSP0CR0 = 0x0007; // 8 bit, fast as possible.
	SSP0CPSR = 2; // divide by 2. Minimum possible.
	SSP0CR1 = 0x0002; // enable SSP, set master
	
	// Flush (should be no need)
	while(SSP0SR&4) SSP0DR;	
	
	// Pins have already been configured to SSP, ready to go.
	flash_csenable(0);
	fpga_csenable(0);
	SpiEngage();
	
	// Also enforce an input pin
	// PIO1_3 FPGA_DONE
	GPIO1DIR &= ~(1<<3);
	
	InterruptSetPriority(INT_SSP,64);
	
}



int SpiByte(int byte)
{
	while((SSP0SR&2)==0);
	SSP0DR = byte;
	while((SSP0SR&4)==0);
	return SSP0DR;
}

void SpiData(unsigned char * dataIn, unsigned char * dataOut, int length)
{
	int readcursor = 0;
	int writecursor = 0;

	if(dataIn == 0)
	{
		while(readcursor < length || writecursor < length)
		{
			if(writecursor < length && (SSP0SR&2)) SSP0DR = dataOut[writecursor++];
			if(readcursor < length && readcursor < writecursor && (SSP0SR&4)) { readcursor++; SSP0DR; }
		}
	} else 	if(dataOut == 0) {
		while(readcursor < length || writecursor < length)
		{
			if(writecursor < length && (SSP0SR&2)) { SSP0DR = 0; writecursor++; }
			if(readcursor < length && readcursor < writecursor && (SSP0SR&4)) dataIn[readcursor++] = SSP0DR;
		}
	} else {
		while(readcursor < length || writecursor < length)
		{
			if(writecursor < length && (SSP0SR&2)) SSP0DR = dataOut[writecursor++];
			if(readcursor < length && readcursor < writecursor && (SSP0SR&4)) dataIn[readcursor++] = SSP0DR;
		}
	}
}




void flash_bytecommand(int byte)
{
	flash_csenable(1);
	SpiByte(byte);
	flash_csenable(0);
}
int flash_2bytecommand(int byte, int byte2)
{
	int retval = 0;
	flash_csenable(1);
	SpiByte(byte);
	retval = SpiByte(byte2);
	flash_csenable(0);
	return retval;
}

int flash_RDID()
{
	flash_bytecommand(FlashCmd_ReleasePowerDown);
	delayus(20);

	int retval = 0;
	flash_csenable(1);
	SpiByte(FlashCmd_RDID);
	retval = SpiByte(0)<<16;
	retval |= SpiByte(0)<<8;
	retval |= SpiByte(0);
	flash_csenable(0);
	return retval;
}

int flash_status()
{
	return flash_2bytecommand(FlashCmd_ReadStatus, 0);
}

int flash_busy()
{
	return flash_status()&1;
}

int flash_waitbusy()
{
	// Consider using timer to wait a predictable amount of time.
	int counter = 0;
	while(flash_busy())
	{
		counter++;
		if(counter > 1000000) return 0;
	}
	return 1;
}

void flash_write_enable()
{
	flash_bytecommand(FlashCmd_WriteEnable);
	delayus(10); // Add some small interframe delay.
}

void flash_address24(int address)
{
	SpiByte((address>>16)&0xFF);
	SpiByte((address>>8)&0xFF);
	SpiByte((address)&0xFF);
}

void flash_erase_sector(int sectorAddress)
{
	flash_write_enable();
	
	flash_csenable(1);
	SpiByte(FlashCmd_SectorErase);
	flash_address24(sectorAddress);
	flash_csenable(0);	
}


void flash_erase_block(int blockAddress)
{
	flash_write_enable();
	
	flash_csenable(1);
	SpiByte(FlashCmd_BlockErase);
	flash_address24(blockAddress);
	flash_csenable(0);	
}


void flash_read(int address, int length, unsigned char* data)
{
	flash_csenable(1);
	SpiByte(FlashCmd_Read);
	flash_address24(address);
	SpiData(data, 0, length);
	flash_csenable(0);	
}

void flash_program(int address, int length, unsigned char* data)
{
	flash_write_enable();
	
	flash_csenable(1);
	SpiByte(FlashCmd_Program);
	flash_address24(address);
	SpiData(0, data, length);
	flash_csenable(0);	
}

void flash_spiexchange(unsigned char * dataSwap, int length)
{
	SpiEngage();
	flash_csenable(1);
	SpiData(dataSwap, dataSwap, length);
	flash_csenable(0);
}



void fpga_spiexchange(unsigned char * dataSwap, int length)
{
	SpiEngage();
	fpga_csenable(1);
	SpiData(dataSwap, dataSwap, length);
	fpga_csenable(0);
}

// PIO1_3 (1D) - DBGIO4, fpga pin (Connected additionally to FPGA_DONE by connecting B11 and B7 on the PCI Express connector on the test board)
int fpga_waitboot()
{
	// CDONE will float up when the FPGA is configured - 1 = configured
	int counter = 0;
	while((GPIO1DATA[(1<<3)] & (1<<3)) == 0)
	{
		counter++;
		if(counter > 1000000) return 0;
	}
	delayms(1);
	SpiEngage();
	
	return 1;
}




////////////////////////////////////////////////////////////////////////////////
//
//  System / Timing
//

volatile unsigned int timer_tick;

void timer_init()
{
	InterruptDisable(INT_CT32B1);
	TMR32B1TCR = 0; // disable
	InterruptClear(INT_CT32B1);
	InterruptEnable(INT_CT32B1);
	TMR32B1PR = 0; 
	TMR32B1PC = 0; // reset values
	TMR32B1TC = 0;

	TMR32B1IR = TMR32B1IR; // Reset interrupt flags.

	// Interrupt and reset on match register 0
	TMR32B1MCR = 3;
	//TMR32B1MR0 = 3000000; // Reset every 3M cycles (tick rate of 125ms @ 24MHz)
	TMR32B1MR0 = 240000; // Reset every 240k cycles (tick rate of 100hz/10ms @ 24MHz)

	timer_tick = 0;

	TMR32B1TCR = 1; // Enable
}

unsigned int timer_get_tick()
{
	return timer_tick;
}
unsigned int timer_wait_tick()
{
	u32 tick = timer_get_tick();
	while(tick == timer_get_tick()) asm("WFI"); // lower power but MAY skip a tick in very rare circumstances. Unlikely in this code.
	return timer_get_tick();
}

void ad_work();

extern "C" void int_CT32B1();
void int_CT32B1()
{
	// Clear pending interrupt
	TMR32B1IR = TMR32B1IR;
	InterruptClear(INT_CT32B1);
	timer_tick++;
	ad_work();
}






int adc_last[3];

int adc_count;
int adc_temp[3];

extern "C" void int_ADC(); // occurs about 14k times a second, once every 1700 cycles.
void int_ADC()
{
	adc_temp[0] += ((AD0DR0>>6)&0x3FF);
	adc_temp[1] += ((AD0DR1>>6)&0x3FF);
	adc_temp[2] += ((AD0DR2>>6)&0x3FF);
	adc_count++;
	if(adc_count == 16)
	{
		for(int i=0;i<3;i++)
		{
			adc_last[i] = adc_temp[i];
			adc_temp[i] = 0;
		}
		adc_count = 0;
	}
	
	InterruptClear(INT_ADC);
}



void ad_init()
{

	PDRUNCFG &= ~(1<<4); // turn on power to ADC;
	InterruptDisable(INT_ADC);

	adc_count = 0;
	adc_temp[0] = adc_temp[1] = adc_temp[2] = 0;
	adc_last[0] = adc_last[1] = adc_last[2] = 0;

	// Setup ADCs
	AD0CR = 0;
	// Todo: maybe set up interrupts. For now just convert.
	InterruptClear(INT_ADC);
	InterruptSetPriority(INT_ADC,0); // HIGHEST priority.

	AD0INTEN = 0x04; // Interrupt on AD2 conversion.
	AD0CR = 0x07 | // SEL = AD0,1,2
			(39<<8) | // CLKDIV = 39 (divide by 40) - to achieve 0.6MHz (should be <= 4.5 MHz)
			(1<<16); // BURST - hardware scan through ADC conversions.
	// Burst conversions of 3 ADCs (33 cycles) = approximately 14khz


	InterruptEnable(INT_ADC);
}


// adc update worker task. every tick, wake up and do some stuff.
void ad_work()
{
	// Read ADCs
	dpc_suspend();
	InterruptDisable(INT_ADC);



	InterruptEnable(INT_ADC);
	dpc_resume();


}


//---------------------------------------------------------------------------------
// Program entry point
//---------------------------------------------------------------------------------
int main(void) {
//---------------------------------------------------------------------------------

	SYSAHBCLKCTRL = 0x16D5F; // Turn on clock to important devices (gpio, iocon, CT16B1, CT32B1, ADC)


	
	IOCON_PIO0_5 = 0; 								// PIO0_5 (0) - LEDGREEN
	IOCON_PIO0_4 = 0; 								// PIO0_4 (0) - LEDRED

	IOCON_PIO0_0 = 0 | IOCON_MODE_PULLUP; 		    // PIO0_0 (0)  - RST
	IOCON_PIO0_1 = 0 | IOCON_MODE_PULLUP;			// PIO0_1 - PROG
	IOCON_PIO0_3 = 1; 								// PIO0_3 (1-VBUS) - USB5V
	IOCON_PIO0_6 = 1; 								// PIO0_6 (1) - USB_CONNECT#


	IOCON_PIO2_0 = 0;								// PIO2_0 (0) - JTAG_TDI
	IOCON_PIO0_2 = 0;								// PIO0_2 (0) - JTAG_TDO
	IOCON_PIO1_6 = 0;								// PIO1_6 (0) - JTAG_TCK
	IOCON_PIO1_7 = 0;								// PIO1_7 (0) - JTAG_TMS

	IOCON_PIO1_8 = 0 | IOCON_MODE_PULLUP;			// PIO1_8 (0) - SENSE1 (Sense when fpga board is inserted)
	IOCON_PIO1_9 = 0 | IOCON_MODE_PULLUP;			// PIO1_9 (0) - SENSE2 
	IOCON_PIO0_7 = 0;								// PIO0_7 (0) - VIN_SOFTIN (~100mA limited power on to 5V)
	IOCON_PIO1_10 = 0 | IOCON_ADMODE_DIGITAL;		// PIO1_10 (0D) - VIN_ON (Turn power fully on to 5V)

	IOCON_PIO0_11 = 2;								// PIO0_11 (2-AD0) - MEASURE_VIN (this pin is 1/3 of the fpga board VIN voltage)
	IOCON_PIO1_0 = 2;								// PIO1_0 (2-AD1) - MEASURE_3V3 (Measure 3v3 rail of fpga board)
	IOCON_PIO1_1 = 2;								// PIO1_1 (2-AD2) - MEASURE_1V2 (Measure 1v2 rail of fpga board)

	IOCON_PIO0_8 = 0;								// PIO0_8 (0-GPIO,1-MISO) - FLASH_MISO (attached to SPI flash and FPGA)
	IOCON_PIO0_9 = 0;								// PIO0_9 (0-GPIO,1-MOSI) - FLASH_MOSI
	IOCON_PIO0_10 = 1;								// PIO0_10 (1-GPIO,2-SCK) - FLASH_CLK
	IOCON_PIO1_5 = 0;								// PIO1_5 (0) - FLASH_CS#

													// (DBGIO - Extra IO pins wired to the fpga)
	IOCON_PIO3_2 = 0;								// PIO3_2 (0) - DBGIO1, fpga
	IOCON_PIO1_11 = 0 | IOCON_ADMODE_DIGITAL;		// PIO1_11 (0D) - DBGIO2, fpga
	IOCON_PIO1_4 = 0 | IOCON_ADMODE_DIGITAL;		// PIO1_4 (0D) - DBGIO3, fpga
	IOCON_PIO1_3 = 1 | IOCON_ADMODE_DIGITAL; 		// PIO1_3 (1D) - DBGIO4, fpga pin (Connected additionally to FPGA_DONE by connecting B11 and B7 on the PCI Express connector on the test board)
	IOCON_PIO1_2 = 1 | IOCON_ADMODE_DIGITAL | IOCON_MODE_PULLUP; // PIO1_2 (1D) - DBGIO5, fpga pin (Connected additionally to FPGA_PROG# by connecting B10 and B8 on the PCI Express connector)


	// Set default values for critical pins
	SetPowerDriveState(0);
	led_set_red(0);
	led_set_green(1);

	ReadDeviceUID();

	// Set up clocks for USB.
	if((MAINCLKSEL&3) == 0) // Assuming we are running on the RC osc..
	{
		// Wake up the Crystal OSC
		SYSOSCCTRL = 0;
		PDRUNCFG = 0x040 | 0x400; // Turn on SYSOSC, SYSPLL, USBPLL, ADC (not usb yet)
		delayms(5); // Give clock some time to warm up
		// Setup SYSPLL to provide 24MHz cpu CLK. M=2, P=4
		// Note that 24MHz is technically out of spec (should set waitstates for flash at >20MHz), but this works and is simpler.
		SYSPLLCTRL = 0x41;
		SYSPLLCLKSEL = 1; // select OSC
		SYSPLLCLKUEN=0;
		SYSPLLCLKUEN=1; // update clock source 
		// Setup USBPLL to provide 48MHz USB CLK. M=4, P=2
		USBPLLCTRL = 0x23;
		USBPLLCLKSEL = 1;
		USBPLLCLKUEN=0;
		USBPLLCLKUEN=1; // Update clock source

		// Wait for PLLs to stabilize
		while((SYSPLLSTAT&1) == 0);
		while((USBPLLSTAT&1) == 0);
		delayms(100);
		// Switch system clock over to PLL clock
		MAINCLKSEL = 3;
		MAINCLKUEN = 0;
		MAINCLKUEN = 1;
	}

	delayms(10);

	SpiInit();
	SpiRelease();

	ad_init();
	// Setup periodic timer at 125ms intervals.
	timer_init();

	dpc_init();
	dpc_suspend();


	PDRUNCFG &= ~0x400; // Turn on USB
	usb_init();

	dpc_resume();

	led_set_green(0);

	// Don't return.
	while(1)
	{
		timer_wait_tick();
		dpc_tick();
	}
}


