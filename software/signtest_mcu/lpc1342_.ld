
OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)


MEMORY {

	rom	: ORIGIN = 0x00000000, LENGTH = 16k
	iram	: ORIGIN = 0x10000180, LENGTH = 4K-0x180
}

__text_start	=	ORIGIN(rom);
__iram_start	=	ORIGIN(iram);
__iram_top	=	ORIGIN(iram) + LENGTH(iram);;

SECTIONS
{
	. = ORIGIN(rom);
	_start = .;
	
	.text :
	{
		*(.init)
		*(.text*)
		*(.rodata*)
		*(.data)
	} >rom=0xFF

	. = ORIGIN(iram);
	.bss :
	{
		*(.bss)
	} > iram = 0xFF

}
