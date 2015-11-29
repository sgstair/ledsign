@ Generic CRT0 Initialization code.
@
@ Copyright (c) 2014 Stephen Stair (sgstair@akkit.org)
@ 
@ Permission is hereby granted, free of charge, to any person obtaining a copy
@  of this software and associated documentation files (the "Software"), to deal
@  in the Software without restriction, including without limitation the rights
@  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
@  copies of the Software, and to permit persons to whom the Software is
@  furnished to do so, subject to the following conditions:
@ 
@ The above copyright notice and this permission notice shall be included in
@  all copies or substantial portions of the Software.
@ 
@ THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
@  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
@  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
@  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
@  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
@  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
@  THE SOFTWARE.
@ 	
	
	
	.section	".init"
	.global     _start
	.align
	.thumb
@---------------------------------------------------------------------------------
_start:
@---------------------------------------------------------------------------------

	.word 0x10000FFC @ SP value
	.word int_Reset
	.word int_NMI
	.word int_HardFault
	.word int_MemManage
	.word int_BusFault
	.word int_UsageFault
	.word 0 @ Reserved
	.word 0 @ Reserved
	.word 0 @ Reserved
	.word 0 @ Reserved
	.word int_SVCall
	.word int_DbgMon
	.word 0 @ Reserved
	.word int_PendSV
	.word int_SysTick
	
	@ External Interrupt table. Has fully 57 entries (228 bytes)
	
	.word intvec0
	.word intvec1
	.word intvec2
	.word intvec3
	.word intvec4
	.word intvec5
	.word intvec6
	.word intvec7
	.word intvec8
	.word intvec9
	.word intvec10
	.word intvec11
	.word intvec12
	.word intvec13
	.word intvec14
	.word intvec15
	.word intvec16
	.word intvec17
	.word intvec18
	.word intvec19
	.word intvec20
	.word intvec21
	.word intvec22
	.word intvec23
	.word intvec24
	.word intvec25
	.word intvec26
	.word intvec27
	.word intvec28
	.word intvec29
	.word intvec30
	.word intvec31
	.word intvec32
	.word intvec33
	.word intvec34
	.word intvec35
	.word intvec36
	.word intvec37
	.word intvec38
	.word intvec39
	.word int_I2C0
	.word int_CT16B0
	.word int_CT16B1
	.word int_CT32B0
	.word int_CT32B1
	.word int_SSP
	.word int_UART
	.word int_USBIRQ
	.word int_USBFIQ
	.word int_ADC
	.word int_WDT
	.word int_BOD
	.word intvec52
	.word int_PIO3
	.word int_PIO2
	.word int_PIO1
	.word int_PIO0


.thumb_func
int_NMI:
.thumb_func
int_HardFault:
.thumb_func
int_MemManage:
.thumb_func
int_BusFault:
.thumb_func
int_UsageFault:
.thumb_func
int_SVCall:
.thumb_func
int_DbgMon:
.thumb_func
int_PendSV:
.thumb_func
int_SysTick:
.thumb_func
intvec0:
.thumb_func
intvec1:
.thumb_func
intvec2:
.thumb_func
intvec3:
.thumb_func
intvec4:
.thumb_func
intvec5:
.thumb_func
intvec6:
.thumb_func
intvec7:
.thumb_func
intvec8:
.thumb_func
intvec9:
.thumb_func
intvec10:
.thumb_func
intvec11:
.thumb_func
intvec12:
.thumb_func
intvec13:
.thumb_func
intvec14:
.thumb_func
intvec15:
.thumb_func
intvec16:
.thumb_func
intvec17:
.thumb_func
intvec18:
.thumb_func
intvec19:
.thumb_func
intvec20:
.thumb_func
intvec21:
.thumb_func
intvec22:
.thumb_func
intvec23:
.thumb_func
intvec24:
.thumb_func
intvec25:
.thumb_func
intvec26:
.thumb_func
intvec27:
.thumb_func
intvec28:
.thumb_func
intvec29:
.thumb_func
intvec30:
.thumb_func
intvec31:
.thumb_func
intvec32:
.thumb_func
intvec33:
.thumb_func
intvec34:
.thumb_func
intvec35:
.thumb_func
intvec36:
.thumb_func
intvec37:
.thumb_func
intvec38:
.thumb_func
intvec39:

.thumb_func
int_I2C0:
.thumb_func
int_CT16B0:
.thumb_func
int_CT16B1:
.thumb_func
int_CT32B0:
.thumb_func
int_CT32B1:
.thumb_func
int_SSP:
.thumb_func
int_UART:
.thumb_func
int_USBIRQ:
.thumb_func
int_USBFIQ:
.thumb_func
int_ADC:
.thumb_func
int_WDT:
.thumb_func
int_BOD:
.thumb_func
intvec52:
.thumb_func
int_PIO3:
.thumb_func
int_PIO2:
.thumb_func
int_PIO1:
.thumb_func
int_PIO0:
@ "No interrupt" vector.

	@bx lr


@ Setup weak references so C functions can take over these interrupts.
.weak int_I2C0
.weak int_CT16B0
.weak int_CT16B1
.weak int_CT32B0
.weak int_CT32B1
.weak int_SSP
.weak int_UART
.weak int_USBIRQ
.weak int_USBFIQ
.weak int_ADC
.weak int_WDT
.weak int_BOD
.weak int_PIO3
.weak int_PIO2
.weak int_PIO1
.weak int_PIO0

.thumb_func
int_Reset:

@ Oh maybe set up stack.
	movw r3,0x0FFC
	movt r3,0x1000
	mov SP,r3
	

	mov	r0, #0				@ int argc
	mov	r1, #0				@ char	*argv[]
	ldr	r3, =main
	bx r3


	@ extern void delayus(unsigned long delay);
.thumb_func
delayus:
.global delayus
	tst r0,r0
	beq delay_exit
	nop
	nop
	nop
	nop
	sub r0,r0,#1
	b delayus	
delay_exit:
	bx lr

	@ extern void call_IAP_noreturn(u32* cmd, u32* res);
.thumb_func
call_IAP_noreturn:
.global call_IAP_noreturn
	@ Reset stack
	movw r3,0x0000
	movt r3,0x1FFF
	@mov SP,r3

	@ jump to IAP address
	movw r3,0x1ff1
	movt r3,0x1fff
	bx r3
	@ Done! Not possible to return.

	@ extern void call_IAP(u32* cmd, u32* res);
.thumb_func
call_IAP:
.global call_IAP
	@ jump to IAP address
	movw r3,0x1ff1
	movt r3,0x1fff
	bx r3
	


	.align
	.pool
	.end

