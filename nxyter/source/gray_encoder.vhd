-----------------------------------------------------------------------------
--
-- Gray EnCcoder
--
-----------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Gray_Encoder is
  generic (
    WIDTH : integer := 12              -- Register Width
    );             

  port (
    CLK_IN      : in std_logic;
    RESET_IN    : in std_logic;
    
    -- Input
    BINARY_IN   : in  std_logic_vector(WIDTH - 1 downto 0);

    -- OUTPUT
    GRAY_OUT    : out std_logic_vector(WIDTH - 1 downto 0)
    );

end Gray_Encoder;

architecture Behavioral of  Gray_Encoder is

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
