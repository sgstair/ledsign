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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity main is
    Port ( 
		clk : in  STD_LOGIC;
		fpgaled : buffer std_logic;
		led_r0 : out std_logic;
		led_g0 : out std_logic;
		led_b0 : out std_logic;
		led_r1 : out std_logic;
		led_g1 : out std_logic;
		led_b1 : out std_logic;
		led_A : out std_logic;
		led_B : out std_logic;
		led_C : out std_logic;
		led_D : out std_logic;
		led_OE : out std_logic;
		led_STB : out std_logic;
		led_CLK : out std_logic;
		flash_clk : inout std_logic;
		flash_mosi : inout std_logic;
		flash_miso : inout std_logic;
		dbgio1 : inout std_logic;
		usb_dp : inout std_logic;
		usb_dm : inout std_logic;
		usb_connect : inout std_logic
	 );
end main;
architecture Behavioral of main is


component framebuffer is
    Generic ( RamSizeBits : integer := 14 );
    Port ( clk : in  STD_LOGIC;
			  reset : in  STD_LOGIC;
			  frame_addr : in unsigned( (RamSizeBits-1) downto 0);
			  frame_readdata : out std_logic_vector(31 downto 0);
			  access_addr : in unsigned ( (RamSizeBits-1) downto 0);
			  access_readdata : out std_logic_vector(31 downto 0);
			  access_writedata : in std_logic_vector(31 downto 0);
			  access_writeenable : in std_logic );
end component;

component usb_device is
    Port ( clk : in  STD_LOGIC;
           usb_dp : inout  STD_LOGIC;
           usb_dm : inout  STD_LOGIC;
			  usb_connect : inout std_logic;			  
           syncreset : in  STD_LOGIC;
           interface_addr : out unsigned(15 downto 0);
			  interface_read : in std_logic_vector(31 downto 0);
			  interface_write : out std_logic_vector(31 downto 0);
			  interface_re : out std_logic;
			  interface_we : out std_logic);
end component;


signal usb_addr : unsigned(15 downto 0);
signal usb_readdata : std_logic_vector(31 downto 0);
signal usb_writedata : std_logic_vector(31 downto 0);
signal usb_re : std_logic;
signal usb_we : std_logic;

signal counter : unsigned(29 downto 0) := (others => '0');

signal syncreset : std_logic := '1';
signal syncresetcount : unsigned(3 downto 0) := X"1";

signal request_scanline : std_logic := '0';
signal scanline_working : std_logic := '0';
signal scanline_complete : std_logic := '0';
signal scanline_y : unsigned(3 downto 0) := (others => '0');
signal scanline_out_y : unsigned(3 downto 0) := (others => '0');

signal scanline_r0 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_g0 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_b0 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_r1 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_g1 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_b1 : std_logic_vector(9 downto 0) := (others => '0');
signal scanline_pixel : std_logic := '0';


signal bit_position : unsigned(3 downto 0) := (others => '0');

signal led_on_time : unsigned(7 downto 0) := X"10";
signal led_on_counter : unsigned(17 downto 0) := (others => '0');
signal start_oe : std_logic := '0';
signal oe_working : std_logic := '0';
signal oe_done : std_logic := '0';


type led_state_type is ( startoutput, output, display, advance );
signal waitcount : unsigned(3 downto 0);
signal led_state : led_state_type := startoutput;
signal display_completed : std_logic := '0';


signal frameread_addr : unsigned(13 downto 0);
signal frameread_data : std_logic_vector(31 downto 0);

signal frameaccess_addr : unsigned(13 downto 0);
signal frameaccess_readdata : std_logic_vector(31 downto 0);
signal frameaccess_writedata : std_logic_vector(31 downto 0);
signal frameaccess_writeenable :std_logic;

signal pixel_delay : unsigned(1 downto 0);
signal scanline_state : unsigned(2 downto 0);


signal dummy_timer : unsigned(19 downto 0);


type spi_mode_type is (command, writeaddress, writedata);
signal spibits : std_logic_vector(31 downto 0);
signal spibit : unsigned(4 downto 0);
signal spimode : spi_mode_type;
signal spioutbyte : std_logic_vector(7 downto 0);

signal spi_write_address : std_logic_vector(15 downto 0);
signal spi_write_data : std_logic_vector(23 downto 0);

signal spi_address_toggle : std_logic;
signal spi_data_toggle : std_logic;

signal address_toggle_buffer : std_logic_vector(4 downto 0);
signal data_toggle_buffer : std_logic_vector(4 downto 0);

begin


	framebufferram: framebuffer
	generic map ( RamSizeBits => 14 )
	port map (
		clk => clk,
		reset => syncreset,
		frame_addr => frameread_addr,
		frame_readdata => frameread_data,
		access_addr => frameaccess_addr,
		access_readdata => frameaccess_readdata,
		access_writedata => frameaccess_writedata,
		access_writeenable => frameaccess_writeenable
		);

	usb_device_inst : usb_device
	port map (
		clk => clk,
		usb_dp => usb_dp,
		usb_dm => usb_dm,
		usb_connect => usb_connect,	  
		syncreset => syncreset,
		interface_addr => usb_addr,
		interface_read => usb_readdata,
		interface_write => usb_writedata,
		interface_re => usb_re,
		interface_we => usb_we
	);



	fpgaled <= '0';

	process(clk)
	begin
		if clk'event and clk = '1' then
			counter <= counter + 1;
			
			-- Generate reset
			if syncresetcount = 0 then
				syncreset <= '0';
			else
				syncreset <= '1';
				syncresetcount <= syncresetcount + 1;
			end if;
			
			
		end if;
	end process;


	-- System to pull data from the framebuffer for LED panel, two pixels per 4 cycles
	process(clk)
	begin
		if clk'event and clk = '1' then
			scanline_pixel <= '0';
			if request_scanline = '1' then
				if scanline_working = '0' then
					scanline_working <= '1';
					-- Prepare to read data
					frameread_addr <= "00000" & scanline_y & "00000";
					pixel_delay <= "00";
				else
					if scanline_complete = '0' then
					
						case pixel_delay is
						when "00" =>
							frameread_addr(10) <= '0';
						when "01" =>
							frameread_addr(10) <= '1';

							scanline_r0 <= "00" & frameread_data(23 downto 16);
							scanline_g0 <= "00" & frameread_data(15 downto 8);
							scanline_b0 <= "00" & frameread_data(7 downto 0);
						when "10" =>
							scanline_r1 <= "00" & frameread_data(23 downto 16);
							scanline_g1 <= "00" & frameread_data(15 downto 8);
							scanline_b1 <= "00" & frameread_data(7 downto 0);
							scanline_pixel <= '1';
							
							-- Advance to next pixel.
							frameread_addr(4 downto 0) <= frameread_addr(4 downto 0) + 1;							
						when "11" =>
							if frameread_addr(4 downto 0) = "00000" then
								scanline_complete <= '1';
							end if;
							
						when others =>
						end case;
						pixel_delay <= pixel_delay + 1;
				
					end if;
				end if;
			else
				scanline_complete <= '0';
				scanline_working <= '0';
			end if;

			if syncreset = '1' then
				scanline_complete <= '0';
				scanline_working <= '0';
			end if;
		end if;
	end process;


	-- System to output scanline data into the LED matrix
	process(clk)
	begin
		if clk'event and clk = '1' then
			case scanline_state is
			when "000" =>
				led_clk <= '0';
			when "001" =>
				led_r0 <= scanline_r0(to_integer(bit_position));
				led_g0 <= scanline_g0(to_integer(bit_position));
				led_b0 <= scanline_b0(to_integer(bit_position));
				led_r1 <= scanline_r1(to_integer(bit_position));
				led_g1 <= scanline_g1(to_integer(bit_position));
				led_b1 <= scanline_b1(to_integer(bit_position));
				led_clk <= '0';
				scanline_state <= "010";
			when "010" =>
				led_clk <= '1';
				scanline_state <= "011";
			when "011" =>
				led_clk <= '1';
				scanline_state <= "000";
			when others =>
				scanline_state <= "000";
			end case;
			
			if scanline_pixel = '1' then
				scanline_state <= "001";
			end if;
			
			if syncreset = '1' then
				led_r0 <= '0';
				led_g0 <= '0';
				led_b0 <= '0';
				led_r1 <= '0';
				led_g1 <= '0';
				led_b1 <= '0';
				led_clk <= '0';
				scanline_state <= "000";
			end if;
		end if;
	end process;

	-- System to output enable for a specific number of cycles
	led_d <= scanline_out_y(3);
	led_c <= scanline_out_y(2);
	led_b <= scanline_out_y(1);
	led_a <= scanline_out_y(0);	
	
	led_oe <= not oe_working;
	
	process(clk)
	begin
		if clk'event and clk = '1' then
			oe_done <= '0';
			
			if oe_working = '1' then
				led_on_counter <= led_on_counter - 1;
				if led_on_counter = 0 then
					oe_done <= '1';
					oe_working <= '0';
				end if;
			end if;
			
			if start_oe = '1' then
				case to_integer(bit_position) is
				when 0 => led_on_counter <= "0000000000" & led_on_time;
				when 1 => led_on_counter <= "000000000" & led_on_time & "0";
				when 2 => led_on_counter <= "00000000" & led_on_time & "00";
				when 3 => led_on_counter <= "0000000" & led_on_time & "000";
				when 4 => led_on_counter <= "000000" & led_on_time & "0000";
				when 5 => led_on_counter <= "00000" & led_on_time & "00000";
				when 6 => led_on_counter <= "0000" & led_on_time & "000000";
				when 7 => led_on_counter <= "000" & led_on_time & "0000000";
				when others =>
					led_on_counter <= "0000000000" & led_on_time;
				end case;
				oe_working <= '1';
			end if;

			if syncreset = '1' then
				oe_working <= '0';
			end if;
		end if;
	end process;	
	
	
	
	-- Coordinating state machine
	process(clk)
	begin
		if clk'event and clk = '1' then
			
			led_STB <= '0';
			start_oe <= '0';
			
			
			case led_state is
			when startoutput =>
				-- start pushing data into the display for a scanline
				request_scanline <= '1';
				led_state <= output;
				
			when output =>
				-- Wait until we're done with the scanline and the previous display
				waitcount <= (others => '0');
				
				if scanline_complete = '1' and oe_working = '0' then
					request_scanline <= '0';
					led_state <= display;
				end if;
				
			when display =>
				-- Add a few cycles of delay to prevent any potential bleeding issues while latching data.
				waitcount <= waitcount + 1;
				case to_integer(waitcount) is
				when 5 =>
					-- Strobe to latch data, latch scanline out bits
					led_STB <= '1';
					scanline_out_y <= scanline_y;
				when 10 => 
					-- Start the display and move on to the next phase.
					start_oe <= '1';
					led_state <= advance;
				when others =>
				end case;
				
			when advance =>
				--  advance to the next bit position or scanline.
				
				if bit_position = 7 then
					scanline_y <= scanline_y + 1;
					bit_position <= (others => '0');
				else
					bit_position <= bit_position + 1;
				end if;
				
				led_state <= startoutput;
				
			when others =>
				led_state <= startoutput;
			end case;

			if syncreset='1' then
				led_state <= startoutput;
				bit_position <= (others => '0');
				scanline_y <= (others => '0');
				scanline_out_y <= (others => '0');
				waitcount <= (others => '0');
			end if;
		end if;
	end process;


	-- SPI interface

	process(clk)
	begin
		if clk'event and clk = '1' then
			frameaccess_writeenable <= '0';
	
			address_toggle_buffer <= spi_address_toggle & address_toggle_buffer(4 downto 1);
			data_toggle_buffer <= spi_data_toggle & data_toggle_buffer(4 downto 1);

			if data_toggle_buffer(1) /= data_toggle_buffer(0) then
				frameaccess_writedata <= X"00" & spi_write_data;
				frameaccess_writeenable <= '1';
			end if;

			if frameaccess_writeenable = '1' then
				frameaccess_addr <= frameaccess_addr + 1; -- Advance address on the next cycle.
			end if;

			if address_toggle_buffer(1) /= address_toggle_buffer(0) then
				frameaccess_addr <= unsigned(spi_write_address(13 downto 0));
			end if;

			if syncreset = '1' then
				address_toggle_buffer <= (others => '0');
				data_toggle_buffer <= (others => '0');
			end if;
		end if;
	end process;


	spibits(0) <= flash_mosi;
	flash_miso <= 'Z' when dbgio1 = '1' else spioutbyte(7);
	
	process(flash_clk)
	begin
		if dbgio1 = '1' then -- CS signal is inactive
			spibit <= (others => '0');
			spioutbyte <= (others => '0');
			spimode <= command;
			
		elsif flash_clk'event and flash_clk = '1' then
			spibits(31 downto 1) <= spibits(30 downto 0); -- Shift bits and prepare for next cycle.
			spioutbyte <= spioutbyte(6 downto 0) & '0';
			spibit <= spibit + 1;
			case spimode is
				when command =>
					if spibit = 7 then
						-- Decide what to do based on command in spibits(7 downto 0).
						-- For now just treat all command bytes as a write data command.
						spibit <= (others => '0');
						spimode <= writeaddress;
					end if;
					
				when writeaddress =>
					if spibit = 15 then
						spi_write_address <= spibits(15 downto 0);
						spibit <= (others => '0');
						spi_address_toggle <= not spi_address_toggle;
						spimode <= writedata;
					end if;
					
				when writedata =>
					if spibit = 23 then
						spi_write_data <= spibits(23 downto 0);
						spibit <= (others => '0');
						spi_data_toggle <= not spi_data_toggle;
					end if;
						
				when others =>
			end case;
		
		
		end if;
	end process;


end Behavioral;

