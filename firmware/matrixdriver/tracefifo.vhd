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

entity tracefifo is
    Port ( clk : in  STD_LOGIC;
			  reset : in  STD_LOGIC;
			  write_data : in std_logic_vector(7 downto 0);
			  write_pulse : in std_logic;
			  read_data : out std_logic_vector(7 downto 0);
			  has_data : out std_logic;
			  read_pulse : in std_logic );
end tracefifo;

architecture Behavioral of tracefifo is

	signal ramout_data : std_logic_vector(31 downto 0);
	signal ramwrite_data : std_logic_vector(31 downto 0);
   signal ramwrite_pulse : std_logic;
	
	signal write_address : unsigned(10 downto 0);
	signal nextwrite_address : unsigned(10 downto 0);
	signal read_address : unsigned(10 downto 0);

begin

	read_data <= X"EE" when write_address = read_address else ramout_data(7 downto 0);
	has_data <= '0' when write_address = read_address else '1';
	nextwrite_address <= write_address + 1;

	process(clk)
	begin
		if clk'event and clk='1' then
			ramwrite_pulse <= '0';
			
			if ramwrite_pulse = '1' then
				write_address <= nextwrite_address;
			elsif write_pulse = '1' and write_data /= X"FF" then
				if nextwrite_address /= read_address then
					ramwrite_data(7 downto 0) <= write_data;
					ramwrite_pulse <= '1';
				end if; -- Discard data that would overwrite head.
			end if;
			
			if read_pulse = '1' then
				if read_address /= write_address then
					read_address <= read_address + 1;
				end if;
			end if;
			
			if reset = '1' then
				write_address <= (others => '0');
				read_address <= (others => '0');
			end if;
		end if;
	end process;


	ram : RAMB16BWER
	generic map (
		-- DATA_WIDTH_A/DATA_WIDTH_B: 0, 1, 2, 4, 9, 18, or 36
		DATA_WIDTH_A => 9, DATA_WIDTH_B => 9,
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
		DOA => ramout_data,  -- 32-bit output: A port data output
		ADDRA => std_logic_vector(read_address) & "000", -- 14-bit input: A port address input
		CLKA => clk,     			-- 1-bit input: A port clock input
		ENA => '1',       		-- 1-bit input: A port enable input
		REGCEA => '1', 			-- 1-bit input: A port register clock enable input
		RSTA => reset,      -- 1-bit input: A port register set/reset input
		WEA => "0000",       	-- 4-bit input: Port A byte-wide write enable input
		DIA => (others => '0'), -- 32-bit input: A port data input
		DIPA => (others => '0'),-- 4-bit input: A port parity input

		ADDRB => std_logic_vector(write_address) & "000", -- 14-bit input: B port address input
		CLKB => clk,     			-- 1-bit input: B port clock input
		ENB => '1',       		-- 1-bit input: B port enable input
		REGCEB => '1', 			-- 1-bit input: B port register clock enable input
		RSTB => reset,      -- 1-bit input: B port register set/reset input
		WEB => (others => ramwrite_pulse), -- 4-bit input: Port B byte-wide write enable input
		DIB => ramwrite_data, -- 32-bit input: B port data input
		DIPB => (others => '0') -- 4-bit input: B port parity input
	);








end Behavioral;

