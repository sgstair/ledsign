-- 
-- This source is released under the MIT License (MIT)
-- 
-- Copyright (c) 2016 Stephen Stair (sgstair@akkit.org)
-- 
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
-- 

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity usb_device is
    Port ( clk : in std_logic;
           usb_dp : inout std_logic;
           usb_dm : inout std_logic;
			  usb_connect : out std_logic;
           syncreset : in std_logic;
           interface_addr : out unsigned(15 downto 0);
			  interface_read : in std_logic_vector(31 downto 0);
			  interface_write : out std_logic_vector(31 downto 0);
			  interface_re : out std_logic; -- Request read; Data will be present on the 2nd cycle after re was high
			  interface_we : out std_logic -- Request write; address/write data will be latched and written.
			  );
end usb_device;

architecture Behavioral of usb_device is

component usb_phy is
port (
	sysclk : in std_logic;
	rst : in std_logic;
	
	-- USB Physical interface
	usb_dp : inout std_logic;
	usb_dm : inout std_logic;
	
	-- USB Reset
	usb_reset : out std_logic; -- Indication that we received a reset signal
	usb_hold_reset : in std_logic; -- Hold reset of the lower level high until this layer says it's ok to continue.
	
	
	-- Transmit interface
	usbtx_byte : in std_logic_vector(7 downto 0);
	usbtx_sendbyte : in std_logic;
	usbtx_lastbyte : in std_logic;
	usbtxs_cansend : out std_logic;
	usbtxs_abort : out std_logic;
	usbtxs_sending : out std_logic;
	usbtxs_underrunerror : out std_logic;
	
	-- Receive interface
	usbrx_byte : out std_logic_vector(7 downto 0);
	usbrx_nextbyte : out std_logic;
	usbrx_packetend : out std_logic;
	usbrx_crcerror : out std_logic;
	usbrx_bitstufferror : out std_logic;
	usbrx_eopmissing : out std_logic;
	usbrx_piderror : out std_logic;
	usbrx_incomplete : out std_logic;
	usbrx_syncerror : out std_logic;
	usbrx_error : out std_logic

);
end component;



signal romaddr : unsigned(9 downto 0);
signal romdata : std_logic_vector(7 downto 0);

begin














-- Use initial memory contents of this RAM block to store USB descriptor information

   RAMB8BWER_inst : RAMB8BWER
   generic map (
      -- DATA_WIDTH_A/DATA_WIDTH_B: 'If RAM_MODE="TDP": 0, 1, 2, 4, 9 or 18; If RAM_MODE="SDP": 36'
      DATA_WIDTH_A => 9,
      DATA_WIDTH_B => 9,
      -- DOA_REG/DOB_REG: Optional output register (0 or 1)
      DOA_REG => 0,
      DOB_REG => 0,
      -- EN_RSTRAM_A/EN_RSTRAM_B: Enable/disable RST
      EN_RSTRAM_A => TRUE,
      EN_RSTRAM_B => TRUE,
      -- INIT_00 to INIT_1F: Initial memory contents.
      INIT_00 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_01 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_02 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_03 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_04 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_05 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_06 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_07 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_08 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_09 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_0F => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_10 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_11 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_12 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_13 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_14 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_15 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_16 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_17 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_18 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_19 => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1A => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1B => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1C => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1D => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1E => X"0000000000000000000000000000000000000000000000000000000000000000",
      INIT_1F => X"0000000000000000000000000000000000000000000000000000000000000000",
      -- INIT_A/INIT_B: Initial values on output port
      INIT_A => X"00000",
      INIT_B => X"00000",
      -- INIT_FILE: Not Supported
      INIT_FILE => "NONE",                                                             -- Do not modify
      -- RAM_MODE: "SDP" or "TDP" 
      RAM_MODE => "TDP",
      -- RSTTYPE: "SYNC" or "ASYNC" 
      RSTTYPE => "SYNC",
      -- RST_PRIORITY_A/RST_PRIORITY_B: "CE" or "SR" 
      RST_PRIORITY_A => "CE",
      RST_PRIORITY_B => "CE",
      -- SIM_COLLISION_CHECK: Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE" 
      SIM_COLLISION_CHECK => "ALL",
      -- SRVAL_A/SRVAL_B: Set/Reset value for RAM output
      SRVAL_A => X"00000",
      SRVAL_B => X"00000",
      -- WRITE_MODE_A/WRITE_MODE_B: "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE" 
      WRITE_MODE_A => "WRITE_FIRST",
      WRITE_MODE_B => "WRITE_FIRST" 
   )
   port map (
      -- Port A Data: 16-bit (each) output: Port A data
      DOADO(7 downto 0) => romdata,             -- 16-bit output: A port data/LSB data output
      ADDRAWRADDR => romaddr & "000", -- 13-bit input: A port address/Write address input
      CLKAWRCLK => clk,     -- 1-bit input: A port clock/Write clock input
      ENAWREN => '0',         -- 1-bit input: A port enable/Write enable input
      REGCEA => '1',           -- 1-bit input: A port register enable input
      RSTA => syncreset,               -- 1-bit input: A port set/reset input
      WEAWEL => "00",           -- 2-bit input: A port write enable input
      -- Port A Data: 16-bit (each) input: Port A data
      DIADI => (others => '0'),             -- 16-bit input: A port data/LSB data input
      DIPADIP => "00",         -- 2-bit input: A port parity/LSB parity input
      -- Port B Address/Control Signals: 13-bit (each) input: Port B address and control signals (read port
      -- when RAM_MODE="SDP")
      ADDRBRDADDR => (others => '0'), -- 13-bit input: B port address/Read address input
      CLKBRDCLK => '0',     -- 1-bit input: B port clock/Read clock input
      ENBRDEN => '0',         -- 1-bit input: B port enable/Read enable input
      REGCEBREGCE => '0', -- 1-bit input: B port register enable/Register enable input
      RSTBRST => '0',         -- 1-bit input: B port set/reset input
      WEBWEU => "00",           -- 2-bit input: B port write enable input
      -- Port B Data: 16-bit (each) input: Port B data
      DIBDI => (others => '0'),             -- 16-bit input: B port data/MSB data input
      DIPBDIP => "00"          -- 2-bit input: B port parity/MSB parity input
   );


end Behavioral;

