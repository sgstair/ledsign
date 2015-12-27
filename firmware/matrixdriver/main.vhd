
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
		led_CLK : out std_logic
	 );
end main;

architecture Behavioral of main is

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


signal frameread_addr : unsigned(10 downto 0);
signal frameread_data : std_logic_vector(31 downto 0);

signal frameread_ram1 : std_logic_vector(31 downto 0);
signal frameread_ram2 : std_logic_vector(31 downto 0);

signal framewrite_enable :std_logic;
signal framewrite_enables : std_logic_vector(1 downto 0);
signal framewrite_addr : unsigned(10 downto 0);
signal framewrite_data : std_logic_vector(31 downto 0);

signal pixel_delay : unsigned(1 downto 0);
signal scanline_state : unsigned(2 downto 0);


signal dummy_timer : unsigned(19 downto 0);

begin

	frameread_data <= frameread_ram1 when frameread_addr(10) = '0' else
							frameread_ram2;

	framewrite_enables <= 	"00" when framewrite_enable = '0' else
									"01" when framewrite_addr(10) = '0' else
									"10";


   ram1 : RAMB16BWER
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
      SIM_DEVICE => "SPARTAN3ADSP",
      -- SRVAL_A/SRVAL_B: Set/Reset value for RAM output
      SRVAL_A => X"000000000",
      SRVAL_B => X"000000000",
      -- WRITE_MODE_A/WRITE_MODE_B: "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE" 
      WRITE_MODE_A => "WRITE_FIRST",
      WRITE_MODE_B => "WRITE_FIRST" 
   )
   port map (
      DOA => frameread_ram1,  -- 32-bit output: A port data output
      ADDRA => std_logic_vector(frameread_addr(8 downto 0)) & "00000", -- 14-bit input: A port address input
      CLKA => clk,     			-- 1-bit input: A port clock input
      ENA => '1',       		-- 1-bit input: A port enable input
      REGCEA => '1', 			-- 1-bit input: A port register clock enable input
      RSTA => syncreset,      -- 1-bit input: A port register set/reset input
      WEA => "0000",       	-- 4-bit input: Port A byte-wide write enable input
      DIA => (others => '0'), -- 32-bit input: A port data input
      DIPA => (others => '0'),-- 4-bit input: A port parity input

      ADDRB => std_logic_vector(framewrite_addr(8 downto 0)) & "00000", -- 14-bit input: B port address input
      CLKB => clk,     			-- 1-bit input: B port clock input
      ENB => '1',       		-- 1-bit input: B port enable input
      REGCEB => '1', 			-- 1-bit input: B port register clock enable input
      RSTB => syncreset,      -- 1-bit input: B port register set/reset input
      WEB => (others => framewrite_enables(0)), -- 4-bit input: Port B byte-wide write enable input
      DIB => framewrite_data, -- 32-bit input: B port data input
      DIPB => (others => '0') -- 4-bit input: B port parity input
   );


   ram2 : RAMB16BWER
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
      SIM_DEVICE => "SPARTAN3ADSP",
      -- SRVAL_A/SRVAL_B: Set/Reset value for RAM output
      SRVAL_A => X"000000000",
      SRVAL_B => X"000000000",
      -- WRITE_MODE_A/WRITE_MODE_B: "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE" 
      WRITE_MODE_A => "WRITE_FIRST",
      WRITE_MODE_B => "WRITE_FIRST" 
   )
   port map (
      DOA => frameread_ram2,  -- 32-bit output: A port data output
      ADDRA => std_logic_vector(frameread_addr(8 downto 0)) & "00000", -- 14-bit input: A port address input
      CLKA => clk,     			-- 1-bit input: A port clock input
      ENA => '1',       		-- 1-bit input: A port enable input
      REGCEA => '1', 			-- 1-bit input: A port register clock enable input
      RSTA => syncreset,      -- 1-bit input: A port register set/reset input
      WEA => "0000",       	-- 4-bit input: Port A byte-wide write enable input
      DIA => (others => '0'), -- 32-bit input: A port data input
      DIPA => (others => '0'),-- 4-bit input: A port parity input

      ADDRB => std_logic_vector(framewrite_addr(8 downto 0)) & "00000", -- 14-bit input: B port address input
      CLKB => clk,     			-- 1-bit input: B port clock input
      ENB => '1',       		-- 1-bit input: B port enable input
      REGCEB => '1', 			-- 1-bit input: B port register clock enable input
      RSTB => syncreset,      -- 1-bit input: B port register set/reset input
      WEB => (others => framewrite_enables(1)), -- 4-bit input: Port B byte-wide write enable input
      DIB => framewrite_data, -- 32-bit input: B port data input
      DIPB => (others => '0') -- 4-bit input: B port parity input
   );

	process(clk)
	begin
		if clk'event and clk = '1' then
			fpgaled <= counter(25);
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
					frameread_addr <= "00" & scanline_y & "00000";
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


	-- Dummy thing to write through the RAM for now, so something is visible.

	process(clk)
	begin
		if clk'event and clk = '1' then
			framewrite_enable <= '0';
			
			framewrite_data <= framewrite_data(30 downto 0) & (framewrite_data(30) xor framewrite_data(29)); -- Random number generation
			if framewrite_data = X"00000000" then
				framewrite_data <= X"12345678";
			end if;
			
			dummy_timer <= dummy_timer + 1;
			if dummy_timer = 1000000 then
				framewrite_enable <= '1';
				framewrite_addr <= framewrite_addr + 1;
				-- debug framewrite_data <= X"0000" & std_logic_vector(framewrite_addr(6 downto 3)) & X"0" & std_logic_vector(framewrite_addr(7 downto 0) + 1);
				dummy_timer <= (others => '0');
			end if;

		end if;
	end process;

	-- SPI interface
	


end Behavioral;

