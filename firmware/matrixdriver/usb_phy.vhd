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


entity usb_phy is
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
end usb_phy;





architecture a of usb_phy is


	signal usb_stable : std_logic;
	signal usb_validbit : std_logic;
	signal usb_se0 : std_logic;
	signal usb_bit : std_logic;

	signal usb_buffer : std_logic_vector(7 downto 0);
	
	signal usb_drivebit : std_logic;
	signal usb_drivese0 : std_logic;
	signal usb_out : std_logic;
	


	signal usbi_ringpulse : std_logic;
	signal usbi_ring : std_logic_vector(4 downto 0);
	signal usbi_ringnext : std_logic;
	signal usbi_rxactive : std_logic;
	signal usbi_txactive : std_logic;
	signal usbi_pid : std_logic_vector(3 downto 0);
	signal usbi_lastbits : std_logic_vector(5 downto 0);
	
	signal usbi_crc5 : std_logic_vector(4 downto 0);
	signal usbi_crc16 : std_logic_vector(15 downto 0);
	signal usbi_crcbit : std_logic;
	signal usbi_crcenable : std_logic;
	signal usbi_crcreset : std_logic;
	signal usbi_crc5ok : std_logic;
	signal usbi_crc16ok : std_logic;
	
	signal usbi_rxcrcvalid : std_logic;
	signal usbi_rxcrclastvalid : std_logic;
	signal usbi_crcengaged : std_logic;
	
	
	signal usbi_usingcrc : std_logic;
	signal usbi_usecrc16 : std_logic;
	signal usbi_bytebuffered : std_logic;
	signal usbi_receivedlastbyte : std_logic;
	
	signal usbi_byte : std_logic_vector(7 downto 0);
	signal usbi_bit : unsigned(2 downto 0);
	signal usbi_tempbyte : std_logic_vector(7 downto 0);
	signal usbi_decide : std_logic;
	signal usbi_decide_next : std_logic;
	signal usbi_rxlevel : std_logic;
	
	signal usbi_resetring : std_logic_vector(4 downto 0);
	signal usbi_resetcounter : unsigned(4 downto 0);
	
	signal usbi_bitstufferrordetected : std_logic;
	signal usbi_rxwaitforeop : std_logic;
	
	signal usbi_rxbytetemp : std_logic_vector(7 downto 0);
	signal usbi_rxbytevalid : std_logic;
	
	signal usbrx_ipacketend : std_logic;
	signal usbrx_ierror : std_logic;
	signal usbtxs_icansend : std_logic;
	signal usbrx_inextbyte : std_logic;

	-- The following error fields are cleared at the start of a packet, flagged immediately upon hitting them, and guaranteed to be accurate when packetend pulses.
	signal usbrxi_crcerror : std_logic; 		-- Packet was terminated early due to CRC error
	signal usbrxi_bitstufferror : std_logic; -- Packet was terminated early due to bit stuffing error
	signal usbrxi_eopmissing : std_logic; 	-- Packet was terminated because it was too long.
	signal usbrxi_piderror : std_logic; 		-- PID field is incorrect (compliment mismatch) - This may also lead to an incorrect CRC error from using the wrong CRC.
	signal usbrxi_incomplete : std_logic;	-- Packet was obviously incomplete (not a multiple of 8 bits)
	signal usbrxi_syncerror: std_logic;		-- Packet sync field was not correct.

	signal usbrxi_byte : std_logic_vector(7 downto 0);


	type usb_state is (sync, pid, content, crc1, crc2, eop );

	signal usbrxstate : usb_state;
	signal usbtxstate : usb_state;

begin

	usbrx_packetend <= usbrx_ipacketend;
	usbrx_nextbyte <= usbrx_inextbyte;
	usbrx_error <= usbrx_ierror;
	usbtxs_cansend <= usbtxs_icansend;
	
	usbrx_byte <= usbrxi_byte;
	


	-- USB front end
	process(sysclk, rst)
	variable buffer_dp : std_logic;
	variable buffer_dm : std_logic;
	variable temp : std_logic_vector(1 downto 0);
	begin
		if rst = '1' then
			usb_validbit <= '0';
			usb_se0 <= '0';
			usb_bit <= '0';
			usb_buffer <= (others => '0');
			
			usb_stable <= '0';
			
			usb_dp <= 'Z';
			usb_dm <= 'Z';
		
		elsif sysclk'event and sysclk='1' then
			buffer_dp := usb_buffer(5);
			buffer_dm := usb_buffer(4);
			
			
			usb_validbit <= '0';
			usb_se0 <= '0';
			usb_bit <= '0';
			
			temp(1) := buffer_dp;
			temp(0) := buffer_dm;
			
			-- Simulation helper
			if(temp(0) = 'H') then
				temp(0) := '1';
			end if;
			if(temp(0) = 'L') then
				temp(0) := '0';
			end if;
			if(temp(1) = 'H') then
				temp(1) := '1';
			end if;
			if(temp(1) = 'L') then
				temp(1) := '0';
			end if;
			
			
			case (temp) is
			when "00" => usb_se0 <= '1';
			when "01" => usb_validbit <= '1'; usb_bit <= '0';
			when "10" => usb_validbit <= '1'; usb_bit <= '1';
			when "11" =>
			when others =>
			end case;
			
			usb_stable <= '0';
			if(usb_buffer(7 downto 6) = usb_buffer(5 downto 4)) then
				usb_stable <= '1';
			end if;
			
			
			if(usb_drivebit = '1') then
				usb_dp <= usb_out;
				usb_dm <= not usb_out;
			elsif(usb_drivese0 = '1') then
				usb_dp <= '0';
				usb_dm <= '0';
			else
				usb_dp <= 'Z';
				usb_dm <= 'Z';			
			end if;
		
			
			
			
			usb_buffer <= usb_buffer(5 downto 0) & usb_dp & usb_dm;
			-- DP in 7, DM in 6
		end if;
	end process;



	-- Rx/Tx. This section translates the USB interface to a byte stream, handles bit stuffing and identifies/generates CRC.
	-- This section makes only the most limited attempt to decode the USB packets, just provides the overall byte stream sending and receiving.
	-- The CRC values are checked internally and included in the data byte stream. (CRC5 vs CRC16 is determined from the PID field)
	-- Outgoing data automatically generates CRC5 and CRC16 depending on PID.
	
	usbrx_crcerror <= usbrxi_crcerror;
	usbrx_bitstufferror <= usbrxi_bitstufferror;
	usbrx_eopmissing <= usbrxi_eopmissing;
	usbrx_piderror <= usbrxi_piderror;
	usbrx_incomplete <= usbrxi_incomplete;
	usbrx_syncerror <= usbrxi_syncerror;
	usbrx_ierror <= usbrxi_crcerror or usbrxi_bitstufferror or usbrxi_eopmissing or usbrxi_piderror or usbrxi_incomplete or usbrxi_syncerror;

		-- Ring is a 5-bit shift register clock divider configurable to restart at a specific time.
		-- pulse usbi_ringnext to 1 to cause ring(0) to be high next cycle, and every 5th cycle after that.
	usbi_ringpulse <= usbi_ringnext or usbi_ring(0);
	process(sysclk, rst)
	begin
		if rst = '1' then
			usbi_ring <= (others => '0');	
		elsif sysclk'event and sysclk='1' then
			if usbi_ringnext = '1' then
				usbi_ring (1 downto 0) <= "10";
			elsif(usbi_ring(3 downto 0) = "0000") then
				usbi_ring <= usbi_ring(3 downto 0) & '1';
			else
				usbi_ring <= usbi_ring(3 downto 0) & '0';
			end if;
		
		end if;
	end process;
	
		-- Reset detection logic
	process(sysclk, rst)
	begin
		if rst = '1' then
			usbi_resetring <= (others => '0');
			usbi_resetcounter <= (others => '0');
			usb_reset <= '0';
			
		elsif sysclk'event and sysclk='1' then
			if(usb_se0 = '0') then
				usb_reset <= '0';
				usbi_resetcounter <= (others => '0');
			else
				if(usbi_resetring(0) = '1') then
					if usbi_resetcounter < 30 then
						usbi_resetcounter <= usbi_resetcounter + 1;
					else
						usb_reset <= '1';
					end if;
				end if;
			end if;
		
			if(usbi_resetring(3 downto 0) = "0000") then
				usbi_resetring <= usbi_resetring(3 downto 0) & '1';
			else
				usbi_resetring <= usbi_resetring(3 downto 0) & '0';
			end if;
		
		end if;
	end process;		
		
	usbtxs_sending <= usbi_txactive;
	usbtxs_icansend <= ((not usbi_txactive) or ((not usbi_bytebuffered) and (not usbi_receivedlastbyte))) and (not usbi_rxactive);
	usbi_usecrc16 <= '1' when usbi_pid(1 downto 0) = "11" else '0';
	usbi_rxcrcvalid <= usbi_crc16ok when usbi_usecrc16 = '1' else usbi_crc5ok;

	
	process(sysclk, rst)
	variable temp_bit : std_logic;
	variable usbi_decide_next_2 : std_logic;
	begin
		if rst = '1' then
			usb_drivebit <= '0';
			usb_drivese0 <= '0';
			usb_out <= '0';
			
			usbtxs_abort <= '0';
			usbtxs_underrunerror <= '0';
			
			usbrxi_byte <= (others => '0');
			usbrx_inextbyte <= '0';
			usbrx_ipacketend <= '0';
			usbrxi_crcerror <= '0';
			usbrxi_bitstufferror <= '0';
			usbrxi_eopmissing <= '0';
			usbrxi_piderror <= '0';
			usbrxi_incomplete <= '0';
			usbrxi_syncerror <= '0';
			
			usbi_decide <= '0';
			usbi_decide_next <= '0';
			usbi_ringnext <= '0';
			
			usbi_rxactive <= '0';
			usbi_txactive <= '0';
			usbi_pid <= (others => '0');
			usbi_byte <= (others => '0');
			usbi_tempbyte <= (others => '0');
			usbi_bit <= (others => '0');
			
			usbi_crcreset <= '0';
			usbi_crcenable <= '0';
			usbi_crcbit <= '0';
			usbi_rxlevel <= '1';
			
			usbrxstate <= sync;
			usbtxstate <= sync;
			
			usbi_bytebuffered <= '0';
			usbi_usingcrc <= '0';
			usbi_receivedlastbyte <= '0';
			usbi_bitstufferrordetected <= '0';
			
			usbi_rxbytetemp <= (others => '0');
			usbi_rxbytevalid <= '0';
			usbi_crcengaged <= '0';
			usbi_rxwaitforeop <= '0';
		
		elsif sysclk'event and sysclk='1' then
			-- set pulse-drive signals to 0 here, so they will typically only be active for the single cycle they are driven.
			usbtxs_abort <= '0';
			usbrx_inextbyte <= '0';
			usbrx_ipacketend <= '0';
			usbi_ringnext <= '0';
			usbi_crcenable <= '0';
			usbi_crcreset <= '0';
			usbi_decide_next_2 := '0';
		
			if usb_hold_reset = '1' then -- Usb chipset will hold this signal until the software asks to reset. Ignore all traffic.
				-- Cancel any pending transactions.
				usbtxs_abort <= '1';
				usbi_txactive <= '0';
				usbrx_inextbyte <= '0';
				usbrx_ipacketend <= '0';
				usb_drivebit <= '0';
				usb_drivese0 <= '0';
				usb_out <= '0';				
				
				if usbi_rxactive = '1' then
					usbrx_inextbyte <= '1';
					usbrx_ipacketend <= '1';
					usbrxi_incomplete <= '1';
					usbi_rxactive <= '0';
				end if;
				
				
			elsif usbi_rxactive = '1' then
				if usbi_rxwaitforeop = '1' then
					if usb_se0 = '0' and usb_validbit = '1' and usb_bit = '1' and usb_stable = '1' then
						-- End condition. Assume that the higher layer will not start a response packet until the appropriate time has passed (just a few cycles away)
						usbi_rxactive <= '0';
					end if;
				else
			
					if(usbi_ringpulse = '1') then
						-- Todo: consider flagging error if !usb_validbit, which suggests the incoming data is not stable.
						-- This is probably not a concern, invalid data is unlikely to pass the other checks.
						
						if(usb_se0 = '1') then
							-- End of packet condition, wrap up.
							if usbi_bit = "000" then
								-- Ended on an even packet boundary, good!
								usbrxi_crcerror <= usbi_crcengaged and (not usbi_rxcrcvalid);
								
								
							elsif usbi_bit = "001" then
								-- Ended after a single bit, this may be dribble - confirm the previous bit was a valid end point for the packet.
								usbrxi_crcerror <= usbi_crcengaged and (not usbi_rxcrcvalid);
								
							else
								-- Ended at a poor location. Flag this as an error.
								usbrxi_incomplete <= '1';
							end if;
						
							if usbrxstate /= content then -- Ensure we have at least received PID.
								usbrxi_incomplete <= '1';
							end if;

							usbrxi_byte <= usbi_rxbytetemp;
							usbrx_inextbyte <= '1';
							usbrx_ipacketend <= '1';
							usbi_rxwaitforeop <= '1';
							
						else
							usbrxi_bitstufferror <= usbrxi_bitstufferror or usbi_bitstufferrordetected;
							
							usbi_bitstufferrordetected <= '0';
						
							temp_bit := usb_bit xor usbi_rxlevel xor '1';
							usbi_rxlevel <= usb_bit;
							
							if(usbi_lastbits = "111111") then
								if(temp_bit = '1') then
									usbi_bitstufferrordetected <= '1'; -- There is one specific circumstance in which this should not immediately flag an error.
																	-- This could happen legitimiately if this is a repeat of the last bit in the packet (dribble)
								end if;
								-- Otherwise just a normally bit stuffed bit.
							else
								-- This was not a bitstuff bit, so go ahead and record it as a received bit.

								if(usbi_bit = "011") then
									usbi_crcengaged <= usbi_usingcrc; -- need to know at the end of the packet whether we were using CRC for more than a single bit time.
								end if;

								usbi_byte <= temp_bit & usbi_byte(7 downto 1);
								usbi_bit <= usbi_bit + 1;
								usbi_decide_next_2 := '1';
								usbi_crcbit <= temp_bit;
								usbi_crcenable <= usbi_usingcrc;
								usbi_rxcrclastvalid <= usbi_rxcrcvalid; -- Keep track of CRC valid of the previous bit, also for dribble compensation.
								
								
							end if;
							usbi_lastbits <= usbi_lastbits(4 downto 0) & temp_bit;
						end if;
					end if;
					
					if(usbi_decide = '1') then
						-- Determine what to do with the newly received bit.
						if(usbi_bit = "000") then		
							usbrxi_byte <= usbi_rxbytetemp;
							usbrx_inextbyte <= usbi_rxbytevalid;
							
							usbi_rxbytetemp <= usbi_byte;
							usbi_rxbytevalid <= '0';
						
							case usbrxstate is
							when sync =>
								if usbi_byte /= X"80" then
									usbrxi_syncerror <= '1';
								end if;
								usbrxstate <= pid;
							when pid =>
								usbi_rxbytevalid <= '1';
								usbrxstate <= content;
								usbi_usingcrc <= '1';
								usbi_pid <= usbi_byte(3 downto 0);
								if usbi_byte(3 downto 0) /= (not usbi_byte(7 downto 4)) then
									usbrxi_piderror <= '1';
								end if;
								
							when content =>
								usbi_rxbytevalid <= '1';
								
							when others =>
							
							end case;
				
						end if;
					
					end if;
				end if;
			
			elsif usbi_txactive = '1' then
				-- When TX is active, we are always sending a bit, unless EOP.
				
				if(usbi_ringpulse = '1') then
					-- Every 5 cycles (12MHz pulse)					
					usb_drivese0 <= '0';
					
					if usbi_lastbits = "111111" then
						-- Transmit bit stuffing, highest priority
						usb_out <= not usb_out;
						usb_drivebit <= '1';
						usbi_lastbits <= usbi_lastbits(4 downto 0) & '0';
						
					elsif usbtxstate = eop then
						-- Send EOP for 2 bits
						if usbi_bit = "010" then
							-- We have completed our two bits. Drive J for a cycle..
							usbi_txactive <= '0';
							usb_drivebit <= '1';
							usb_out <= '1';
							usb_drivese0 <= '0';
						elsif usbi_bit = "011" then
							-- Finished driving J, return to idle.
							usb_drivebit <= '0';
							usb_drivese0 <= '0';
							usbi_txactive <= '0';
						else
							usb_drivebit <= '0';
							usb_drivese0 <= '1';
						end if;
						usbi_bit <= usbi_bit + 1;
					else
						-- Send next bit in byte.
						usb_drivebit <= '1';
						usb_out <= usbi_byte(0) xor usb_out xor '1'; -- Next bit is NRZI encoded
						usbi_crcbit <= usbi_byte(0);
						usbi_lastbits <= usbi_lastbits(4 downto 0) & usbi_byte(0);
						
						usbi_byte <= '0' & usbi_byte(7 downto 1);
						usbi_bit <= usbi_bit + 1;
						usbi_decide_next_2 := '1'; -- advance the state machine on the next cycle based on the new bit position.
						
						usbi_crcenable <= usbi_usingcrc;
						
					end if;
				end if;
				
				if(usbi_decide = '1') then					
					-- Decision phase
					if(usbi_bit = "000") then
						-- Advance to next byte
						if(usbi_bytebuffered = '1') then
							usbi_byte <= usbi_tempbyte;
							usbi_bytebuffered <= '0';
						else
							if(usbi_receivedlastbyte = '1') then
								-- Send CRC if CRC16, otherwise EOP
								if (usbtxstate = content or usbtxstate = pid) and usbi_usecrc16 = '1' then -- consider moving this block and above _byte logic out to a 3rd cycle, for performance reasons.
																					 -- expressions feeding to _byte and _tempbyte could become expensive with this approach.
									-- Capture & send CRC16		
									usbi_byte <= not usbi_crc16(7 downto 0);
									usbi_tempbyte <= not usbi_crc16(15 downto 8);
									usbi_bytebuffered <= '1';
									usbtxstate <= crc1;
								else
									-- End packet here.
									usbtxstate <= eop;
								end if;
									
							else
								-- Underrun error
								usbtxs_underrunerror <= '1';
								usbtxs_abort <= '1';
								usbi_txactive <= '0';
							end if;
						end if;
							
						
						case usbtxstate is
						when sync =>
							usbtxstate <= pid;
							usbi_pid <= usbi_tempbyte(3 downto 0); -- Save PID
						when pid =>
							if usbi_receivedlastbyte = '0' then
								usbtxstate <= content;
								usbi_usingcrc <= '1';
							end if;
						when content =>
						when crc1 =>
							--usbtxstate <= crc2; -- not really necessary. Above logic will bring us to EOP after CRC.
						when crc2 =>
							--usbtxstate <= eop;
						when eop =>
						end case;
					end if;
					-- CRC5 case, if we completed the 3rd bit of the last byte, acquire crc5 and send it.
					if usbtxstate = content and usbi_receivedlastbyte = '1' and usbi_bytebuffered = '0' then
						if usbi_bit = "011" and usbi_usecrc16 = '0' then
							usbi_byte(4 downto 0) <= not usbi_crc5;
						end if;
					end if;
				
				end if;
			
				-- Get moar bytes
				if usbtx_sendbyte = '1' then
					-- Simple logic, just trust the upper layer to only send that the right time.
					usbi_bytebuffered <= '1';
					usbi_tempbyte <= usbtx_byte;
					usbi_receivedlastbyte <= usbtx_lastbyte;
				end if;
			
			else
				-- Identify if we should start tx or rx.
				usbi_bit <= (others => '0');
				usb_drivebit <= '0';
				usb_drivese0 <= '0';
				usb_out <= '1'; -- Idle state is J, differential 1.
				usbi_lastbits <= (others => '0');
				usbi_decide <= '0';
				usbi_usingcrc <= '0';
				usbi_bytebuffered <= '0';
				usbi_receivedlastbyte <= '0';
				usbi_crcreset <= '1';
				usbi_rxlevel <= '1';
				usbi_rxwaitforeop <= '0';
				usbi_rxbytevalid <= '0';
				usbi_crcengaged <= '0';

				if usb_validbit = '1' and usb_bit = '0' and usb_stable = '1' then
					-- Start receiving a packet
					-- validbit is set when the signal has been stable for 2 cycles. 
					-- Set the ringnext flag so next cycle we will receive the first pulse, and every 5th cycle beyond.
					-- The 3rd cycle we receive the bit should be right in the middle of the bit time for the best conditions possible.
					usbi_rxactive <= '1';
					usbi_ringnext <= '1';
					usbrxstate <= sync;
					
					-- Clear error flags
					usbrxi_crcerror <= '0';
					usbrxi_bitstufferror <= '0';
					usbrxi_eopmissing <= '0';
					usbrxi_piderror <= '0';
					usbrxi_incomplete <= '0';
					usbrxi_syncerror <= '0';
					
				elsif usbtx_sendbyte = '1' then
					-- This should never occur when receiving a byte due to design of the layer above this one.
					usbi_txactive <= '1';
					usbi_tempbyte <= usbtx_byte;
					usbi_byte <= "10000000"; -- Sync byte
					usbtxstate <= sync;
					usbi_ringnext <= '1'; -- Cause pulse next cycle.
					usbi_bytebuffered <= '1';
					usbtxs_underrunerror <= '0';
					usbi_receivedlastbyte <= usbtx_lastbyte;
				
				end if;
			end if;

			usbi_decide <= usbi_decide_next;
			usbi_decide_next <= usbi_decide_next_2; -- Delay decision by 2 cycles so the CRC is complete before we decide.

		end if;
	end process;



	usbi_crc5ok <= '1' when usbi_crc5 = "00110" else '0';
	usbi_crc16ok <= '1' when usbi_crc16 = "1011000000000001" else '0';
	
	-- usb interface crc
	process(sysclk, rst)
	begin
		if rst = '1' then
			usbi_crc5 <= (others => '1');
			usbi_crc16 <= (others => '1');
			
		elsif sysclk'event and sysclk='1' then
			if usbi_crcreset = '1' then
				-- Reset CRC values
				usbi_crc5 <= (others => '1');
				usbi_crc16 <= (others => '1');
			
			elsif usbi_crcenable = '1' then
				-- Advance CRC computation based on usbi_crcbit
				-- Doing this backwards from how the spec describes, in order to have the bits here easily transferred to bytes for sending.
				if((usbi_crc16(0) xor usbi_crcbit) = '1') then
					usbi_crc16 <= ('0' & usbi_crc16(15 downto 1)) xor "1010000000000001";
				else
					usbi_crc16 <= ('0' & usbi_crc16(15 downto 1));
				end if;
				
				if((usbi_crc5(0) xor usbi_crcbit) = '1') then
					usbi_crc5 <= ('0' & usbi_crc5(4 downto 1)) xor "10100";
				else
					usbi_crc5 <= ('0' & usbi_crc5(4 downto 1));
				end if;
					
			end if;
		end if;
	end process;


end a;


