-----------------------------------------------------------------------------
--
-- Gray Decoder
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gray_decoder is
  
  generic (
    WIDTH : integer range 2 to 32 := 12    -- Register Width
    );

  port (
    CLK_IN     : in std_logic;
    RESET_IN   : in std_logic;
    
    -- Input
    GRAY_IN    : in  std_logic_vector(WIDTH - 1 downto 0);

    -- OUTPUT
    BINARY_OUT : out std_logic_vector(WIDTH - 1 downto 0)
    );

end entity;


architecture Behavioral of gray_decoder is

  signal binary_o : std_logic_vector(WIDTH - 1 downto 0);

begin  -- Gray_Decoder

  PROC_DECODER: process (CLK_IN)
    variable b : std_logic_vector(WIDTH -1 downto 0) := (others => '0');
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        b := (others => '0');
      else
        b(WIDTH - 1) := GRAY_IN(WIDTH - 1);
    
        for I in (WIDTH - 2) downto 0 loop
          b(I) := b(I + 1) xor GRAY_IN(I);
        end loop;
      end if;
    end if;
    binary_o <= b;
  end process PROC_DECODER;

-- Output
  BINARY_OUT <= binary_o;
    
end Behavioral;
