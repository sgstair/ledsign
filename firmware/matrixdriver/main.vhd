
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

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

begin

	-- Build a simple test pattern
	led_r0 <= '1' when counter(27 downto 25) = "000" else '0';
	led_g0 <= '1' when counter(27 downto 25) = "001" else '0';
	led_b0 <= '1' when counter(27 downto 25) = "010" else '0';
	led_r1 <= '1' when counter(27 downto 25) = "011" else '0';
	led_g1 <= '1' when counter(27 downto 25) = "100" else '0';
	led_b1 <= '1' when counter(27 downto 25) = "101" else '0';

	led_oe <= '0' when counter(24 downto 18) = "0000000" else '1';
	
	led_clk <= counter(24);
	led_stb <= '0' when counter(27 downto 25) = "111" else '1';

	led_d <= counter(28);
	led_c <= counter(27);
	led_b <= counter(26);
	led_a <= counter(25);


	process(clk)
	begin
		if clk'event and clk = '1' then
			fpgaled <= counter(25);
			counter <= counter + 1;
			
			
		end if;
	end process;

end Behavioral;

