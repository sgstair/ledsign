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
			  usb_connect : inout std_logic;
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

signal usb_reset : std_logic;
signal usb_hold_reset : std_logic;

signal usbtx_byte : std_logic_vector(7 downto 0);
signal usbtx_sendbyte : std_logic;
signal usbtx_lastbyte : std_logic;
signal usbtxs_cansend : std_logic;
signal usbtxs_abort : std_logic;
signal usbtxs_sending : std_logic;
signal usbtxs_underrunerror : std_logic;

signal usbrx_byte : std_logic_vector(7 downto 0);
signal usbrx_nextbyte : std_logic;
signal usbrx_packetend : std_logic;
signal usbrx_crcerror : std_logic;
signal usbrx_bitstufferror : std_logic;
signal usbrx_eopmissing : std_logic;
signal usbrx_piderror : std_logic;
signal usbrx_incomplete : std_logic;
signal usbrx_syncerror : std_logic;
signal usbrx_error : std_logic;

signal romaddr : unsigned(9 downto 0);
signal romdata : std_logic_vector(7 downto 0);

signal ramwritedata : std_logic_vector(7 downto 0);
signal ramwriteenable : std_logic;

signal ramreadaddr : unsigned(9 downto 0);
signal ramreaddata : std_logic_vector(7 downto 0);


type usb_state_type is (idle, ignore, setup1, setup2, out1, out2, in1, in2, setupdata, senddelay, sendstart, preoutdata, outdata, indata, indone);
type usb_setup_data_type is (invalid, sendzlp, sendzlpaddress, sendconfig, senddescriptor, continuedescriptor, recvvendor, sendvendor);
signal usb_state : usb_state_type; 
signal usb_setup_data : usb_setup_data_type;

signal usb_recvdata : std_logic;
signal usb_recvdataindex : std_logic;
signal usb_recvdatasetup : std_logic;

signal usb_address : std_logic_vector(6 downto 0);
signal usb_next_address : std_logic_vector(6 downto 0);
signal usb_latch_address : std_logic;

signal usb_byteindex : unsigned(6 downto 0);
signal usb_endp: unsigned(3 downto 0);

signal usb_requesttype : std_logic_vector(7 downto 0);
signal usb_request : std_logic_vector(7 downto 0);
signal usb_wValue : std_logic_vector(15 downto 0);
signal usb_wIndex : std_logic_vector(15 downto 0);
signal usb_wLength : unsigned(15 downto 0);

signal usb_loaddescriptorindex : unsigned(3 downto 0);
signal usb_descriptorlength : unsigned(7 downto 0);
signal usb_descriptorloc : unsigned(9 downto 0);

signal usb_completeonack : std_logic;
signal usb_advanceonack : std_logic;


signal usb_need_addr : unsigned(15 downto 0);
signal internal_addr : unsigned(15 downto 0);

signal usb_configuration : std_logic_vector(7 downto 0);

type internal_state_type is (idle, writedense);
signal internal_state : internal_state_type;

begin

	usb_connect <= '1';
	usb_hold_reset <= '0';

	interface_addr <= usb_need_addr when internal_state = idle else internal_addr;

-- USB to the rest of the system interface
	process(clk)
	begin
		if clk'event and clk='1' then
			interface_we <= '0';
			case internal_state is
			when idle =>

			when writedense =>
			
			when others => internal_state <= idle;
			end case;
			if syncreset = '1' then
				internal_state <= idle;
			end if;
		end if;
	end process;



-- USB State machine; 
	process(clk)
	begin
		if clk'event and clk='1' then
			usbtx_sendbyte <= '0';
			usbtx_lastbyte <= '0';
			usbtx_byte <= (others => '0');
			
			case usb_state is
			when idle =>
				usb_byteindex <= (others => '0');
				
				if usbrx_nextbyte = '1' then
					usb_latch_address <= '0';
					usb_advanceonack <= '0';
					usb_completeonack <= '0';
					
					case usbrx_byte(3 downto 0) is
					when "0001" => -- OUT
						usb_recvdata <= '0';
						if usbrx_packetend = '0' then
							usb_state <= out1;
						end if;
					when "1001" => -- IN
						usb_recvdata <= '0';
						if usbrx_packetend = '0' then
							usb_state <= in1;
						end if;
					when "0101" => -- SOF
						if usbrx_packetend = '0' then
							usb_state <= ignore;
						end if;
					when "1101" => -- SETUP
						usb_recvdata <= '0';
						if usbrx_packetend = '0' then
							usb_state <= setup1;
						end if;
					when "0011" => -- DATA0
						if usb_recvdata = '1' and usb_recvdataindex = '0' then
							if usb_recvdatasetup = '1' then
								if usbrx_packetend = '0' then
									usb_state <= setupdata;
								end if;
							else
								if usbrx_packetend = '1' then
									usb_state <= indone;
								else
									usb_state <= indata;
								end if;
							end if;
						end if;
						
					when "1011" => -- DATA1
						if usb_recvdata = '1' and usb_recvdataindex = '1' then
							if usb_recvdatasetup = '0' then -- should always be 0
								if usbrx_packetend = '1' then
									usb_state <= indone;
								else
									usb_state <= indata;
								end if;
							end if;
						end if;
						
					when "0010" => -- ACK
						-- If we sent the packet it is ACKing, advance the data bit.
						if usb_latch_address = '1' then
							usb_address <= usb_next_address;
						end if;
						if usb_advanceonack = '1' then
							usb_descriptorloc <= usb_descriptorloc + 64;
							usb_descriptorlength <= usb_descriptorlength - 64;
						end if;
						if usb_completeonack = '1' then
							usb_setup_data <= invalid;
						end if;
						
					when "1010" => -- NAK
					when others => 
						if usbrx_packetend = '0' then
							usb_state <= ignore;
						end if;
					end case;
				end if;
					
			when ignore =>
				if usbrx_packetend = '1' then
					usb_state <= idle;
				end if;
			when setup1 =>
				if usbrx_nextbyte = '1' then
					if usb_address = usbrx_byte(7 downto 1) then
						usb_state <= setup2;
					else
						usb_state <= idle;
					end if;
					usb_endp(3) <= usbrx_byte(0);
					if usbrx_packetend = '1' then
						usb_state <= idle;
					end if;
				end if;
			when setup2 =>
				if usbrx_nextbyte = '1' then
					usb_endp(2 downto 0) <= unsigned(usbrx_byte(7 downto 5));
					
					if usbrx_packetend = '1' and usbrx_error = '0' then
						usb_recvdata <= '1';
						usb_recvdatasetup <= '1';
						usb_recvdataindex <= '0';
					end if;
					usb_state <= idle;
				end if;
				
			when in1 => -- Data to host
				if usbrx_nextbyte = '1' then
					if usb_address = usbrx_byte(7 downto 1) then
						usb_state <= in2;
					else
						usb_state <= idle;
					end if;
					usb_endp(3) <= usbrx_byte(0);
					if usbrx_packetend = '1' then
						usb_state <= idle;
					end if;
				end if;
			when in2 =>
				if usbrx_nextbyte = '1' then
					usb_endp(2 downto 0) <= unsigned(usbrx_byte(7 downto 5));
					
					if usbrx_packetend = '1' and usbrx_error = '0' then
						usb_state <= senddelay;						
					end if;
					usb_state <= idle;
				end if;
				
			when out1 => -- Data from host
				if usbrx_nextbyte = '1' then
					if usb_address = usbrx_byte(7 downto 1) then
						usb_state <= in2;
					else
						usb_state <= idle;
					end if;
					usb_endp(3) <= usbrx_byte(0);
					if usbrx_packetend = '1' then
						usb_state <= idle;
					end if;
				end if;
			when out2 =>
				if usbrx_nextbyte = '1' then
					usb_endp(2 downto 0) <= unsigned(usbrx_byte(7 downto 5));
					
					if usbrx_packetend = '1' and usbrx_error = '0' then
						usb_recvdata <= '1';
						usb_recvdatasetup <= '0';
						
					end if;
					usb_state <= idle;
				end if;
			
			when setupdata =>
				usb_recvdata <= '0';
				if usbrx_nextbyte = '1' then
					if usbrx_packetend = '1' then
						usb_state <= idle;
					end if;
					usb_setup_data <= invalid;
					
					case to_integer(usb_byteindex) is
						when 0 =>
							usb_requesttype <= usbrx_byte;
						when 1 =>
							usb_request <= usbrx_byte;
						when 2 =>
							usb_wValue(15 downto 8) <= usbrx_byte;
						when 3 =>
							usb_wValue(7 downto 0) <= usbrx_byte;
						when 4 =>
							usb_wIndex(15 downto 8) <= usbrx_byte;
						when 5 =>
							usb_wIndex(7 downto 0) <= usbrx_byte;
						when 6 =>
							usb_wLength(15 downto 8) <= unsigned(usbrx_byte);
						when 7 =>
							usb_wLength(7 downto 0) <= unsigned(usbrx_byte);
							
							if usbrx_error = '0' then
								if usb_requesttype(6 downto 5) = "00" then -- Standard requests
									case usb_request is
									when X"05" => -- SET_ADDRESS
										usb_setup_data <= sendzlpaddress;
										usb_next_address <= usb_wValue(6 downto 0);
										
									when X"06" => -- GET_DESCRIPTOR
										if usb_requesttype = X"80" then
											case usb_wValue(15 downto 8) is
											when X"01" => -- Device descriptor
												usb_setup_data <= senddescriptor;
												usb_loaddescriptorindex <= X"0";
											when X"02" => -- Configuration descriptor
												usb_setup_data <= senddescriptor;
												usb_loaddescriptorindex <= X"1";
											when X"03" => -- String descriptor
												case usb_wValue(7 downto 0) is
													when X"00" => -- Language ID list
														usb_setup_data <= senddescriptor;
														usb_loaddescriptorindex <= X"5";
														
													when X"01" => -- Device name string
														usb_setup_data <= senddescriptor;
														usb_loaddescriptorindex <= X"6";
														
													when X"EE" => -- OS signature
														usb_setup_data <= senddescriptor;
														usb_loaddescriptorindex <= X"4";
													
													when others =>
												end case;
											when others =>
											end case;
										end if;
									
									when X"08" => -- GET_CONFIGURATION
										usb_setup_data <= sendconfig;
									when X"09" => -- SET_CONFIGURATION
										usb_setup_data <= sendzlp; -- don't care too much about configuration yet.
										usb_configuration <= usb_wValue(7 downto 0);
									when others =>
									
									end case;
								elsif usb_requesttype(6 downto 5) = "10" then -- Vendor requests
									case usb_request is
									when X"01" => -- Read/Write framebuffer data
									
									when X"02" => -- Read/Write flash data
										-- Not implemented
									when X"03" => -- Reboot FPGA
										-- Not implemented
										
									when X"FE" => -- OS descriptor request
										if usb_wIndex = X"0004" and usb_wValue(15 downto 8) = X"00" then
											-- OS Feature descriptor
											usb_setup_data <= senddescriptor;
											usb_loaddescriptorindex <= X"2";
										elsif usb_wIndex = X"0005" and usb_wValue = X"0000" then
											-- OS Extended Properties descriptor
											usb_setup_data <= senddescriptor;
											usb_loaddescriptorindex <= X"3";
										end if;
									when others =>
									
									end case;
								end if;
							end if;
						when others =>
					end case;
					usb_byteindex <= usb_byteindex + 1;
				end if;
				
				
			when senddelay =>
				usb_byteindex <= usb_byteindex + 1;
				if usb_byteindex = 15 then
					usb_state <= sendstart;
				end if;
			
			when sendstart =>
				usb_byteindex <= (others => '0');
				-- (invalid, sendzlp, sendzlpaddress, sendconfig, senddescriptor, recvvendor, sendvendor);
				if usbtxs_cansend = '1' then
					usbtx_sendbyte <= '1';
					if usb_setup_data = invalid then
						-- Send a STALL
						usbtx_byte <= X"1E";
						usbtx_lastbyte <= '1';
					else
						-- Send a DATA0/DATA1
						if usb_recvdataindex = '0' then
							usbtx_byte <= X"C3"; -- DATA0
						else
							usbtx_byte <= X"4B"; -- DATA1
						end if;
					end if;
					
					-- Determine circumstance
					case usb_setup_data is
						when invalid =>
							usb_state <= idle;
						when sendzlp =>
							usb_state <= idle;
							usbtx_lastbyte <= '1';
						when sendzlpaddress =>
							usb_state <= idle;
							usbtx_lastbyte <= '1';
							usb_latch_address <= '1';
						when continuedescriptor =>
							if usb_descriptorlength = 0 then
								usb_state <= idle;
								usbtx_lastbyte <= '1';
							else
								usb_state <= preoutdata;
								romaddr <= usb_descriptorloc;
							end if;
						when others =>
							usb_state <= preoutdata;
					end case;
					
				end if;
				
			when preoutdata =>
				-- we have a few cycles before we have to send further data, figure out what we need to send
				case usb_setup_data is
				when senddescriptor =>
					usb_byteindex <= usb_byteindex + 1;
					case to_integer(usb_byteindex) is
						when 0 =>
							romaddr <= "00000" & usb_loaddescriptorindex & "0"; -- Read descriptor location
						when 1 =>
							romaddr(0) <= '1'; -- Read descriptor length
						when 2 =>
							usb_descriptorloc <= unsigned(romdata & "00");
							romaddr <= unsigned(romdata & "00");
						when 3 =>
							usb_descriptorlength <= unsigneD(romdata);
							usb_state <= outdata;
							usb_setup_data <= continuedescriptor;
							usb_byteindex <= (others => '0');
							
					end case;
				
				when others =>
					usb_state <= outdata; -- No setup necessary.
				end case;
				if usbtxs_abort = '1' then
					usb_state <= idle;
					usb_setup_data <= invalid;
				end if;
				
			when outdata =>
				if usbtxs_cansend = '1' then
					usbtx_sendbyte <= '1';
					usb_byteindex <= usb_byteindex + 1;
					case usb_setup_data is
					when sendconfig =>
						usbtx_byte <= usb_configuration;
						usbtx_lastbyte <= '1';
					
					when continuedescriptor =>
						usbtx_byte <= romdata;
						romaddr <= romaddr + 1;
						
					
						if usb_byteindex = 63 then
							usbtx_lastbyte <= '1';
							usb_completeonack <= '1';
						elsif (usb_byteindex + 1) = usb_descriptorlength then
							usbtx_lastbyte <= '1';
							usb_advanceonack <= '1';
						end if;	

						
					
					when others =>
						-- Don't know how to proceed.
						usbtx_byte <= X"EE";
						usbtx_lastbyte <= '1';
					end case;
				end if;
				if usbtxs_abort = '1' then
					usb_state <= idle;
					usb_setup_data <= invalid;
				end if;

			when indata =>

			when indone =>
				-- We were sent a packet that we accepted and now we respond with ack/nak/stall
				
			
			
			when others =>
				usb_state <= idle;
			end case;
						
			if syncreset = '1' or usb_reset = '1' then
				usb_state <= idle;
				usb_setup_data <= invalid;
				usb_recvdata <= '0';
				usb_recvdataindex <= '0';
				usb_recvdatasetup <= '0';
				usb_address <= (others => '0');
				usb_next_address <= (others => '0');
				usb_latch_address <= '0';
				usb_configuration <= (others => '0');
			end if;
		end if;
	end process;








-- Use initial memory contents of this RAM block to store USB descriptor information
-- Starting is an array of pairs of <location/4>, <byte length>
-- Descriptors in the system:
-- 0 Device Descriptor
-- 1 Configuration Descriptor
-- 2 OS Descriptor
-- 3 OS Extended Property Descriptor
-- 4 OS String Descriptor (String 0xEE)
-- 5 Language IDs string (string 0)
-- 6 Product name string (string 1)

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
		INIT_00 => X"0412092011281b833c1241044234000012011002000000404c54734c00000001",
		INIT_01 => X"000100000902200001010080320904000002ff00000007058102400000070501",
		INIT_02 => X"0240000028000000000104000100000000000000000157494e55534200000000",
		INIT_03 => X"0000000000000000000000008300010000010000002800440065007600690063",
		INIT_04 => X"00650049006e007400650072006600610063006500470055004900440000004e",
		INIT_05 => X"007b00360037003100610034006100650063002d0039003700650061002d0034",
		INIT_06 => X"003300340035002d0038003300640039002d0066003700650039006500300062",
		INIT_07 => X"00350030006500630037007d0000000012034d00530046005400310030003000",
		INIT_08 => X"fe0000000403090434034c00650064005300690067006e0020004d0061007400",
		INIT_09 => X"720069007800200043006f006e00740072006f006c006c006500720000000000",
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
      ADDRAWRADDR => std_logic_vector(romaddr) & "000", -- 13-bit input: A port address/Write address input
      CLKAWRCLK => clk,     -- 1-bit input: A port clock/Write clock input
      ENAWREN => ramwriteenable,         -- 1-bit input: A port enable/Write enable input
      REGCEA => '1',           -- 1-bit input: A port register enable input
      RSTA => syncreset,               -- 1-bit input: A port set/reset input
      WEAWEL => "0" & ramwriteenable,           -- 2-bit input: A port write enable input
      -- Port A Data: 16-bit (each) input: Port A data
      DIADI => X"00" & ramwritedata,             -- 16-bit input: A port data/LSB data input
      DIPADIP => "00",         -- 2-bit input: A port parity/LSB parity input
      -- Port B Address/Control Signals: 13-bit (each) input: Port B address and control signals (read port
      -- when RAM_MODE="SDP")
      DOBDO(7 downto 0) => ramreaddata,             -- 16-bit output: B port data/LSB data output
      ADDRBRDADDR => std_logic_vector(ramreadaddr) & "000", -- 13-bit input: B port address/Read address input
      CLKBRDCLK => '0',     -- 1-bit input: B port clock/Read clock input
      ENBRDEN => '0',         -- 1-bit input: B port enable/Read enable input
      REGCEBREGCE => '0', -- 1-bit input: B port register enable/Register enable input
      RSTBRST => '0',         -- 1-bit input: B port set/reset input
      WEBWEU => "00",           -- 2-bit input: B port write enable input
      -- Port B Data: 16-bit (each) input: Port B data
      DIBDI => (others => '0'),             -- 16-bit input: B port data/MSB data input
      DIPBDIP => "00"          -- 2-bit input: B port parity/MSB parity input
   );



usb_phy_inst : usb_phy
port map (
	sysclk => clk,
	rst => syncreset,
	
	-- USB Physical interface
	usb_dp => usb_dp,
	usb_dm => usb_dm,
	
	-- USB Reset
	usb_reset => usb_reset,
	usb_hold_reset => usb_hold_reset,
	
	
	-- Transmit interface
	usbtx_byte => usbtx_byte,
	usbtx_sendbyte => usbtx_sendbyte,
	usbtx_lastbyte => usbtx_lastbyte,
	usbtxs_cansend => usbtxs_cansend,
	usbtxs_abort => usbtxs_abort,
	usbtxs_sending => usbtxs_sending,
	usbtxs_underrunerror => usbtxs_underrunerror,
	
	-- Receive interface
	usbrx_byte => usbrx_byte,
	usbrx_nextbyte => usbrx_nextbyte,
	usbrx_packetend => usbrx_packetend,
	usbrx_crcerror => usbrx_crcerror,
	usbrx_bitstufferror => usbrx_bitstufferror,
	usbrx_eopmissing => usbrx_eopmissing,
	usbrx_piderror => usbrx_piderror,
	usbrx_incomplete => usbrx_incomplete,
	usbrx_syncerror => usbrx_syncerror,
	usbrx_error => usbrx_error

);

end Behavioral;

