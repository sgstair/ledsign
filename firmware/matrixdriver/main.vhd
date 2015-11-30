
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
		fpgaled : buffer std_logic
	 );
end main;

architecture Behavioral of main is

signal counter : unsigned(25 downto 0) := (others => '0');

begin

	process(clk)
	begin
		if clk'event and clk = '1' then
			fpgaled <= counter(25);
			counter <= counter + 1;
			
			
		end if;
	end process;

end Behavioral;

