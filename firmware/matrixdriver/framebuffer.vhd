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

entity framebuffer is
    Generic ( RamSizeBits : integer := 14 );
    Port ( clk : in  STD_LOGIC;
			  reset : in  STD_LOGIC;
			  frame_addr : in unsigned( (RamSizeBits-1) downto 0);
			  frame_readdata : out std_logic_vector(31 downto 0);
			  access_addr : in unsigned ( (RamSizeBits-1) downto 0);
			  access_readdata : out std_logic_vector(31 downto 0);
			  access_writedata : in std_logic_vector(31 downto 0);
			  access_writeenable : in std_logic );
end framebuffer;

architecture Behavioral of framebuffer is

	constant BankBits : integer := RamSizeBits - 9;
	constant RamBanks : integer := 2**BankBits;
	constant RamBankMax : integer := (RamBanks-1);

	type RamReadArray is array(0 to RamBankMax) of std_logic_vector(31 downto 0);

	signal frameread_ram : RamReadArray;

	signal accessread_ram : RamReadArray;
	signal accesswriteenable : std_logic_vector(RamBankMax downto 0);

begin

	frame_readdata <= frameread_ram(to_integer(frame_addr(frame_addr'left downto 9)));
	access_readdata <= accessread_ram(to_integer(access_addr(access_addr'left downto 9)));
	

ram_generate:
	for i in 0 to RamBankMax generate

		accesswriteenable(i) <= access_writeenable when i = access_addr(access_addr'left downto 9) else '0';

		ram : RAMB16BWER
		generic map (
			-- DATA_WIDTH_A/DATA_WIDTH_B: 0, 1, 2, 4, 9, 18, or 36
			DATA_WIDTH_A => 36, DATA_WIDTH_B => 36,
			-- DOA_REG/DOB_REG: Optional output register (0 or 1)
			DOA_REG => 0, DOB_REG => 0,
			-- EN_RSTRAM_A/EN_RSTRAM_B: Enable/disable RST
			EN_RSTRAM_A => TRUE,
			EN_RSTRAM_B => TRUE,
			-- INIT_FILE: Optional file used to specify initial RAM contents
			INIT_FILE => "NONE",
			-- RSTTYPE: "SYNC" or "ASYNC" 
			RSTTYPE => "SYNC",
			-- RST_PRIORITY_A/RST_PRIORITY_B: "CE" or "SR" 
			RST_PRIORITY_A => "CE",
			RST_PRIORITY_B => "CE",
			-- SIM_COLLISION_CHECK: Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE" 
			SIM_COLLISION_CHECK => "ALL",
			-- SIM_DEVICE: Must be set to "SPARTAN6" for proper simulation behavior
			SIM_DEVICE => "SPARTAN6",
			-- SRVAL_A/SRVAL_B: Set/Reset value for RAM output
			SRVAL_A => X"000000000",
			SRVAL_B => X"000000000",
			-- WRITE_MODE_A/WRITE_MODE_B: "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE" 
			WRITE_MODE_A => "WRITE_FIRST",
			WRITE_MODE_B => "WRITE_FIRST" 
		)
		port map (
			DOA => frameread_ram(i),  -- 32-bit output: A port data output
			ADDRA => std_logic_vector(frame_addr(8 downto 0)) & "00000", -- 14-bit input: A port address input
			CLKA => clk,     			-- 1-bit input: A port clock input
			ENA => '1',       		-- 1-bit input: A port enable input
			REGCEA => '1', 			-- 1-bit input: A port register clock enable input
			RSTA => reset,      -- 1-bit input: A port register set/reset input
			WEA => "0000",       	-- 4-bit input: Port A byte-wide write enable input
			DIA => (others => '0'), -- 32-bit input: A port data input
			DIPA => (others => '0'),-- 4-bit input: A port parity input

			DOB => accessread_ram(i),  -- 32-bit output: A port data output
			ADDRB => std_logic_vector(access_addr(8 downto 0)) & "00000", -- 14-bit input: B port address input
			CLKB => clk,     			-- 1-bit input: B port clock input
			ENB => '1',       		-- 1-bit input: B port enable input
			REGCEB => '1', 			-- 1-bit input: B port register clock enable input
			RSTB => reset,      -- 1-bit input: B port register set/reset input
			WEB => (others => accesswriteenable(i)), -- 4-bit input: Port B byte-wide write enable input
			DIB => access_writedata, -- 32-bit input: B port data input
			DIPB => (others => '0') -- 4-bit input: B port parity input
		);

	end generate;









end Behavioral;

