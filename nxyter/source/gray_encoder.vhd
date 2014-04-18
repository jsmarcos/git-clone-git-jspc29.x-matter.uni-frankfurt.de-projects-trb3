-----------------------------------------------------------------------------
--
-- Gray EnCcoder
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gray_encoder is
  generic (
    WIDTH : integer range 2 to 32 := 12   -- Register Width
    );             

  port (
    CLK_IN      : in std_logic;
    RESET_IN    : in std_logic;
    
    -- Input
    BINARY_IN   : in  std_logic_vector(WIDTH - 1 downto 0);

    -- OUTPUT
    GRAY_OUT    : out std_logic_vector(WIDTH - 1 downto 0)
    );

end entity;

architecture Behavioral of  gray_encoder is

  signal gray_o : std_logic_vector(WIDTH - 1 downto 0);

begin
  
  PROC_ENCODER: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        gray_o <= (others => '0');
      else
        gray_o(WIDTH - 1) <= BINARY_IN(WIDTH -1);
        for I in (WIDTH - 2) downto 0 loop
          gray_o(I) <= BINARY_IN(I + 1) xor BINARY_IN(I);
        end loop;
      end if;
    end if;

  end process PROC_ENCODER;

  -- Output
  GRAY_OUT <= gray_o;

end Behavioral;
