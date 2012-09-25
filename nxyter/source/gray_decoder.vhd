-----------------------------------------------------------------------------
--
-- Gray Decoder
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Gray_Decoder is
  
  generic (
    WIDTH : integer := 12);             -- Register Width

  port (
    -- Inputs
    GRAY_IN  : in  std_logic_vector(WIDTH - 1 downto 0);

    -- OUTPUTS
    BINARY_OUT : out std_logic_vector(WIDTH - 1 downto 0)
    );

end Gray_Decoder;


architecture Gray_Decoder of Gray_Decoder is

  signal binary_o : std_logic_vector(WIDTH - 1 downto 0);

begin  -- Gray_Decoder

  -- purpose: decode input
  -- type   : combinational
  -- inputs : GRAY_IN
  -- outputs: binary_o
  PROC_DECODER: process (GRAY_IN)
  begin
    binary_o(WIDTH - 1) <= GRAY_IN(WIDTH - 1);
    
    for I in (WIDTH - 2) to 0 loop
      binary_o(I) <= binary_o(I + 1) xor GRAY_IN(I);
    end loop;
    
  end process PROC_DECODER;

  -- purpose: drive output ports
  -- type   : combinational
  -- inputs : binary_o
  -- outputs: BINARY_OUT
  PROC_OUT: process (binary_o)
  begin
    BINARY_OUT <= binary_o;
    
  end process PROC_OUT;

end Gray_Decoder;
