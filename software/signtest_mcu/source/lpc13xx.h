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

#ifndef LPC13xx_H
#define LPC13xx_H

#define REG32(address) *((volatile unsigned long*)(address))
#define ARRAYREG32(address) ((volatile unsigned long*)(address))


// System control - Chapter 3
#define SYSCONTROL_BASE 0x40048000
#define SYSCONTROLREG(reg) REG32(SYSCONTROL_BASE + (reg))

#define SYSMEMREMAP SYSCONTROLREG(0x000)
#define PRESETCTRL SYSCONTROLREG(0x004)
#define SYSPLLCTRL SYSCONTROLREG(0x008)
#define SYSPLLSTAT SYSCONTROLREG(0x00C)
#define USBPLLCTRL SYSCONTROLREG(0x010)
#define USBPLLSTAT SYSCONTROLREG(0x014)
#define SYSOSCCTRL SYSCONTROLREG(0x020)
#define WDTOSCCTRL SYSCONTROLREG(0x024)
#define IRCCTRL SYSCONTROLREG(0x028)
#define SYSRESSTAT SYSCONTROLREG(0x030)
#define SYSPLLCLKSEL SYSCONTROLREG(0x040)
#define SYSPLLCLKUEN SYSCONTROLREG(0x044)
#define USBPLLCLKSEL SYSCONTROLREG(0x048)
#define USBPLLCLKUEN SYSCONTROLREG(0x04C)
#define MAINCLKSEL SYSCONTROLREG(0x070)
#define MAINCLKUEN SYSCONTROLREG(0x074)
#define SYSAHBCLKDIV SYSCONTROLREG(0x078)
#define SYSAHBCLKCTRL SYSCONTROLREG(0x080)
#define SSPCLKDIV SYSCONTROLREG(0x094)
#define UARTCLKDIV SYSCONTROLREG(0x098)
#define TRACECLKDIV SYSCONTROLREG(0x0AC)
#define SYSTICKCLKDIV SYSCONTROLREG(0x0B0)
#define USBCLKSEL SYSCONTROLREG(0x0C0)
#define USBCLKUEN SYSCONTROLREG(0x0C4)
#define USBCLKDIV SYSCONTROLREG(0x0C8)
#define WDTCLKSEL SYSCONTROLREG(0x0D0)
#define WDTCLKUEN SYSCONTROLREG(0x0D4)
#define WDTCLKDIV SYSCONTROLREG(0x0D8)
#define CLKOUTCLKSEL SYSCONTROLREG(0x0E0)
#define CLKOUTUEN SYSCONTROLREG(0x0E4)
#define CLKOUTDIV SYSCONTROLREG(0x0E8)
#define PIOPORCAP0 SYSCONTROLREG(0x100)
#define PIOPORCAP1 SYSCONTROLREG(0x104)
#define BODCTRL SYSCONTROLREG(0x150)
#define SYSTICKCAL SYSCONTROLREG(0x158)
#define STARTAPRP0 SYSCONTROLREG(0x200)
#define STARTERP0 SYSCONTROLREG(0x204)
#define STARTRSRP0CLR SYSCONTROLREG(0x208)
#define STARTSRP0 SYSCONTROLREG(0x20C)
#define STARTAPRP1 SYSCONTROLREG(0x210)
#define STARTERP1 SYSCONTROLREG(0x214)
#define STARTRSRP1CLR SYSCONTROLREG(0x218)
#define STARTSRP1 SYSCONTROLREG(0x21C)
#define PDSLEEPCFG SYSCONTROLREG(0x230)
#define PDAWAKECFG SYSCONTROLREG(0x234)
#define PDRUNCFG SYSCONTROLREG(0x238)
#define DEVICE_ID SYSCONTROLREG(0x3F4)


// Interrupt configuration - Chapter 5
#define NVIC_BASE 0xE000E000
#define NVIC_REG(reg) REG32(NVIC_BASE + (reg))
#define NVIC_ARRAY(reg) ARRAYREG32(NVIC_BASE + (reg))



#define ISER NVIC_ARRAY(0x100)
#define ICER NVIC_ARRAY(0x180)
#define ISPR NVIC_ARRAY(0x200)
#define ICPR NVIC_ARRAY(0x280)
#define IABR NVIC_ARRAY(0x300)
#define IPR NVIC_ARRAY(0x400)

#define ISER0 NVIC_REG(0x100)
#define ISER1 NVIC_REG(0x104)
#define ICER0 NVIC_REG(0x180)
#define ICER1 NVIC_REG(0x184)
#define ISPR0 NVIC_REG(0x200)
#define ISPR1 NVIC_REG(0x204)
#define ICPR0 NVIC_REG(0x280)
#define ICPR1 NVIC_REG(0x284)
#define IABR0 NVIC_REG(0x300)
#define IABR1 NVIC_REG(0x304)
// Neglecting to define all IPRx regs, since the array exists
#define STIR NVIC_REG(0xF00)

// Interrupt definitions - neglecting PIO registers for start enable.
#define INT_I2C0 40
#define INT_CT16B0 41
#define INT_CT16B1 42
#define INT_CT32B0 43
#define INT_CT32B1 44
#define INT_SSP 45
#define INT_UART 46
#define INT_USBIRQ 47
#define INT_USBFIQ 48
#define INT_ADC 49
#define INT_WDT 50
#define INT_BOD 51
#define INT_PIO3 53
#define INT_PIO2 54
#define INT_PIO1 55
#define INT_PIO0 56

#define INT_MAX 63

static inline void InterruptEnable(int InterruptSource)
{
	ISER[(InterruptSource>>5)] = 1<<(InterruptSource&31);
}
static inline void InterruptDisable(int InterruptSource)
{
	ICER[(InterruptSource>>5)] = 1<<(InterruptSource&31);
}
static inline void InterruptTrigger(int InterruptSource)
{
	ISPR[(InterruptSource>>5)] = 1<<(InterruptSource&31);
}
static inline void InterruptClear(int InterruptSource)
{
	ICPR[(InterruptSource>>5)] = 1<<(InterruptSource&31);
}
static inline int InterruptEnabled(int InterruptSource)
{
	return (ISER[(InterruptSource>>5)] & (1<<(InterruptSource&31))) != 0;
}
static inline int InterruptActive(int InterruptSource)
{
	return (IABR[(InterruptSource>>5)] & (1<<(InterruptSource&31))) != 0;
}
static inline int InterruptPriority(int InterruptSource)
{
	return ((IPR[(InterruptSource>>2)] >> ((InterruptSource&3)*8))>>3) & 0x1F;
}
static inline void InterruptSetPriority(int InterruptSource, int Priority)
{
	unsigned long mask = ~(0xFF << ((InterruptSource&3)*8));
	IPR[(InterruptSource>>2)] = (IPR[(InterruptSource>>2)] & mask) | ((Priority & 0x1F) << (((InterruptSource&3)*8)+3));
}


// IO Configuration - Chapter 6
#define IOCON_BASE 0x40044000
#define IOCON_REG(reg) REG32(IOCON_BASE + (reg))

#define IOCON_PIO2_6 IOCON_REG(0x00)
#define IOCON_PIO2_0 IOCON_REG(0x08)
#define IOCON_PIO0_0 IOCON_REG(0x0C)
#define IOCON_PIO0_1 IOCON_REG(0x10)
#define IOCON_PIO1_8 IOCON_REG(0x14)
#define IOCON_PIO0_2 IOCON_REG(0x1C)
#define IOCON_PIO2_7 IOCON_REG(0x20)
#define IOCON_PIO2_8 IOCON_REG(0x24)
#define IOCON_PIO2_1 IOCON_REG(0x28)
#define IOCON_PIO0_3 IOCON_REG(0x2C)
#define IOCON_PIO0_4 IOCON_REG(0x30)
#define IOCON_PIO0_5 IOCON_REG(0x34)
#define IOCON_PIO1_9 IOCON_REG(0x38)
#define IOCON_PIO3_4 IOCON_REG(0x3C)
#define IOCON_PIO2_4 IOCON_REG(0x40)
#define IOCON_PIO2_5 IOCON_REG(0x44)
#define IOCON_PIO3_5 IOCON_REG(0x48)
#define IOCON_PIO0_6 IOCON_REG(0x4C)
#define IOCON_PIO0_7 IOCON_REG(0x50)
#define IOCON_PIO2_9 IOCON_REG(0x54)
#define IOCON_PIO2_10 IOCON_REG(0x58)
#define IOCON_PIO2_2 IOCON_REG(0x5C)
#define IOCON_PIO0_8 IOCON_REG(0x60)
#define IOCON_PIO0_9 IOCON_REG(0x64)
#define IOCON_PIO0_10 IOCON_REG(0x68)
#define IOCON_PIO1_10 IOCON_REG(0x6C)
#define IOCON_PIO2_11 IOCON_REG(0x70)
#define IOCON_PIO0_11 IOCON_REG(0x74)
#define IOCON_PIO1_0 IOCON_REG(0x78)
#define IOCON_PIO1_1 IOCON_REG(0x7C)
#define IOCON_PIO1_2 IOCON_REG(0x80)
#define IOCON_PIO3_0 IOCON_REG(0x84)
#define IOCON_PIO3_1 IOCON_REG(0x88)
#define IOCON_PIO2_3 IOCON_REG(0x8C)
#define IOCON_PIO1_3 IOCON_REG(0x90)
#define IOCON_PIO1_4 IOCON_REG(0x94)
#define IOCON_PIO1_11 IOCON_REG(0x98)
#define IOCON_PIO3_2 IOCON_REG(0x9C)
#define IOCON_PIO1_5 IOCON_REG(0xA0)
#define IOCON_PIO1_6 IOCON_REG(0xA4)
#define IOCON_PIO1_7 IOCON_REG(0xA8)
#define IOCON_PIO3_3 IOCON_REG(0xAC)

#define IOCON_SCKLOC IOCON_REG(0xB0)

#define IOCON_MODE_PULLDOWN 0x08
#define IOCON_MODE_PULLUP 0x10
#define IOCON_MODE_REPEATER 0x18
#define IOCON_HYSTERISIS 0x20
#define IOCON_I2CMODE_DISABLE 0x100
#define IOCON_I2CMODE_NORMAL 0x000
#define IOCON_I2CMODE_FAST 0x200
#define IOCON_ADMODE_ANALOG 0
#define IOCON_ADMODE_DIGITAL 0x80


// GPIO - Chapter 8
#define GPIO_BASE 0x50000000
#define GPIO_BANK_SIZE 0x10000
#define GPIOnBASE(n) (GPIO_BASE + (n)*GPIO_BANK_SIZE)
#define GPIOnREG(n,reg) REG32(GPIOnBASE(n)+(reg))
#define GPIOnARRAY(n,reg) ARRAYREG32(GPIOnBASE(n)+(reg))

#define GPIOnDATA(n) GPIOnARRAY((n),0)
#define GPIOnDIR(n) GPIOnREG((n),0x8000)
#define GPIOnIS(n) GPIOnREG((n),0x8004)
#define GPIOnIBE(n) GPIOnREG((n),0x8008)
#define GPIOnIEV(n) GPIOnREG((n),0x800c)
#define GPIOnIE(n) GPIOnREG((n),0x8010)
#define GPIOnRIS(n) GPIOnREG((n),0x8014)
#define GPIOnMIS(n) GPIOnREG((n),0x8018)
#define GPIOnIC(n) GPIOnREG((n),0x801c)

#define GPIO0DATA GPIOnDATA(0)
#define GPIO0DIR GPIOnDIR(0)
#define GPIO0IS GPIOnIS(0)
#define GPIO0IBE GPIOnIBE(0)
#define GPIO0IEV GPIOnIEV(0)
#define GPIO0IE GPIOnIE(0)
#define GPIO0RIS GPIOnRIS(0)
#define GPIO0MIS GPIOnMIS(0)
#define GPIO0IC GPIOnIC(0)

#define GPIO1DATA GPIOnDATA(1)
#define GPIO1DIR GPIOnDIR(1)
#define GPIO1IS GPIOnIS(1)
#define GPIO1IBE GPIOnIBE(1)
#define GPIO1IEV GPIOnIEV(1)
#define GPIO1IE GPIOnIE(1)
#define GPIO1RIS GPIOnRIS(1)
#define GPIO1MIS GPIOnMIS(1)
#define GPIO1IC GPIOnIC(1)

#define GPIO2DATA GPIOnDATA(2)
#define GPIO2DIR GPIOnDIR(2)
#define GPIO2IS GPIOnIS(2)
#define GPIO2IBE GPIOnIBE(2)
#define GPIO2IEV GPIOnIEV(2)
#define GPIO2IE GPIOnIE(2)
#define GPIO2RIS GPIOnRIS(2)
#define GPIO2MIS GPIOnMIS(2)
#define GPIO2IC GPIOnIC(2)

#define GPIO3DATA GPIOnDATA(3)
#define GPIO3DIR GPIOnDIR(3)
#define GPIO3IS GPIOnIS(3)
#define GPIO3IBE GPIOnIBE(3)
#define GPIO3IEV GPIOnIEV(3)
#define GPIO3IE GPIOnIE(3)
#define GPIO3RIS GPIOnRIS(3)
#define GPIO3MIS GPIOnMIS(3)
#define GPIO3IC GPIOnIC(3)





// USB Device - Chapter 9
#define USB_BASE 0x40020000
#define USB_REG(reg) REG32(USB_BASE + (reg))

#define USBDEVINTST USB_REG(0x00)
#define USBDEVINTEN USB_REG(0x04)
#define USBDEVINTCLR USB_REG(0x08)
#define USBDEVINTSET USB_REG(0x0C)
#define USBCMDCODE USB_REG(0x10)
#define USBCMDDATA USB_REG(0x14)
#define USBRXDATA USB_REG(0x18)
#define USBTXDATA USB_REG(0x1C)
#define USBRXPLEN USB_REG(0x20)
#define USBTXPLEN USB_REG(0x24)
#define USBCTRL USB_REG(0x28)
#define USBDEVFIQSEL USB_REG(0x2C)

#define USBCMD_PHASE_COMMAND		0x00000500
#define USBCMD_PHASE_READ			0x00000200
#define USBCMD_PHASE_WRITE			0x00000100
#define USBCMD_SETADDRESS			0x00D00000
#define USBCMD_CONFIGUREDEVICE		0x00D80000
#define USBCMD_SETMODE				0x00F30000
#define USBCMD_READINTERRUPTSTATUS	0x00F40000
#define USBCMD_READFRAMENUMBER		0x00F50000
#define USBCMD_READCHIPID			0x00FD0000
#define USBCMD_SETDEVICESTATUS		0x00FE0000
#define USBCMD_GETDEVICESTATUS		0x00FE0000
#define USBCMD_GETERRORCODE			0x00FF0000
#define USBCMD_SELECTENDPOINT(n)	(((n)&0xFF)<<16)
#define USBCMD_SELECTENDPOINTC(n)	((((n)+0x40)&0xFF)<<16)
#define USBCMD_SETENDPOINTSTATUS(n)	((((n)+0x40)&0xFF)<<16)
#define USBCMD_CLEARBUFFER			0x00F20000
#define USBCMD_VALIDATEBUFFER		0x00FA0000




// SSP (Synchronous Serial Port) - Chapter 13
#define SSP_BASE 0x40040000
#define SSP_REG(reg) REG32(SSP_BASE+(reg))

#define SSP0CR0		SSP_REG(0x000)
#define SSP0CR1		SSP_REG(0x004)
#define SSP0DR		SSP_REG(0x008)
#define SSP0SR		SSP_REG(0x00C)
#define SSP0CPSR	SSP_REG(0x010)
#define SSP0MSC		SSP_REG(0x014)
#define SSP0RIS		SSP_REG(0x018)
#define SSP0MIS		SSP_REG(0x01C)
#define SSP0ICR		SSP_REG(0x020)


// Timers (32bit) - Chapter 15
#define CT32B0_BASE 0x40014000
#define CT32B1_BASE 0x40018000

#define CT32B0_REG(reg) REG32(CT32B0_BASE + (reg))
#define CT32B1_REG(reg) REG32(CT32B1_BASE + (reg))



#define TMR32B0IR CT32B0_REG(0x00)
#define TMR32B0TCR CT32B0_REG(0x04)
#define TMR32B0TC CT32B0_REG(0x08)
#define TMR32B0PR CT32B0_REG(0x0C)
#define TMR32B0PC CT32B0_REG(0x10)
#define TMR32B0MCR CT32B0_REG(0x14)
#define TMR32B0MR0 CT32B0_REG(0x18)
#define TMR32B0MR1 CT32B0_REG(0x1C)
#define TMR32B0MR2 CT32B0_REG(0x20)
#define TMR32B0MR3 CT32B0_REG(0x24)
#define TMR32B0CCR CT32B0_REG(0x28)
#define TMR32B0CR0 CT32B0_REG(0x2C)
#define TMR32B0EMR CT32B0_REG(0x3C)
#define TMR32B0CTCR CT32B0_REG(0x70)
#define TMR32B0PWMC CT32B0_REG(0x74)

#define TMR32B1IR CT32B1_REG(0x00)
#define TMR32B1TCR CT32B1_REG(0x04)
#define TMR32B1TC CT32B1_REG(0x08)
#define TMR32B1PR CT32B1_REG(0x0C)
#define TMR32B1PC CT32B1_REG(0x10)
#define TMR32B1MCR CT32B1_REG(0x14)
#define TMR32B1MR0 CT32B1_REG(0x18)
#define TMR32B1MR1 CT32B1_REG(0x1C)
#define TMR32B1MR2 CT32B1_REG(0x20)
#define TMR32B1MR3 CT32B1_REG(0x24)
#define TMR32B1CCR CT32B1_REG(0x28)
#define TMR32B1CR0 CT32B1_REG(0x2C)
#define TMR32B1EMR CT32B1_REG(0x3C)
#define TMR32B1CTCR CT32B1_REG(0x70)
#define TMR32B1PWMC CT32B1_REG(0x74)


// ADC - Chapter 18
#define ADC_BASE 0x4001C000
#define ADC_REG(reg) REG32(ADC_BASE + (reg))

#define AD0CR ADC_REG(0x00)
#define AD0GDR ADC_REG(0x04)
#define AD0INTEN ADC_REG(0x0C)
#define AD0DR0 ADC_REG(0x10)
#define AD0DR1 ADC_REG(0x14)
#define AD0DR2 ADC_REG(0x18)
#define AD0DR3 ADC_REG(0x1C)
#define AD0DR4 ADC_REG(0x20)
#define AD0DR5 ADC_REG(0x24)
#define AD0DR6 ADC_REG(0x28)
#define AD0DR7 ADC_REG(0x2C)
#define AD0STAT ADC_REG(0x30)














#endif