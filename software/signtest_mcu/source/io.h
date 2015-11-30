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

#ifndef IO_H
#define IO_H

// Functions for interacting with the IO on this board, to be used by USB interface mainly.

void led_set_red(int value);
void led_set_green(int value);
void led_busy(int busy);

void SetPowerDriveState(int value); // 0 = off, 1 = soft-on, 2=on
int GetPowerDriveState();

int GetSense(); // Returns bottom 2 bits as sense pin status. Zero means board is present.
int GetButton(); // Return 1 when PROG button is pressed.

extern int adc_last[3]; // 2:14 raw ADC values: VIN, 3v3, 1v2 sense lines.



void SpiRelease(); // Stop holding Flash pins shared with FPGA
void SpiEngage(); // Take control of flash pins


const int Flash_SectorSize = 4096;
const int Flash_BlockSize = 65536;

const int Flash_ID = 0x014015; // Spansion S25FL116k. 
// Using other parts is possible but the software provides an overridable lockout because sector sizes or commands may change. Todo: SFDP
//const int Flash_ID = 0xC22013; // A flash part from another project compatible with this implementation.


int flash_RDID();
int flash_status();
int flash_waitbusy(); // returns 1 on success, 0 on timeout
void flash_erase_sector(int sectorAddress);
void flash_erase_block(int blockAddress);
void flash_read(int address, int length, unsigned char* data);
void flash_program(int address, int length, unsigned char* data);
void flash_spiexchange(unsigned char * dataSwap, int length);

void fpga_prog(int halt); // 1 = stop FPGA, 0 = run FPGA
void fpga_spiexchange(unsigned char * dataSwap, int length);
int fpga_waitboot(); // Returns 1 on success.

#endif
