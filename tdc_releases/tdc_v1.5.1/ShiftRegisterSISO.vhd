-------------------------------------------------------------------------------
-- Title      : Register.vhd
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Register.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-10-02
-- Last update: 2013-03-06
-------------------------------------------------------------------------------
-- Description: Used to register signals n levels.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity ShiftRegisterSISO is
  
  generic (
    DEPTH : integer range 1 to 32 := 1;               -- defines the number register level
    WIDTH : integer range 1 to 32 := 1);              -- defines the register size

  port (
    CLK   : in  std_logic;                            -- register clock
    D_IN  : in  std_logic_vector(WIDTH-1 downto 0);   -- register input
    D_OUT : out std_logic_vector(WIDTH-1 downto 0));  -- register out

end ShiftRegisterSISO;

architecture Behavioral of ShiftRegisterSISO is

  type   RegisterArray is array (0 to DEPTH) of std_logic_vector(WIDTH-1 downto 0);
  signal reg : RegisterArray;

  attribute syn_preserve        : boolean;
  attribute syn_preserve of reg : signal is true;
  
begin  -- RTL

  reg(0) <= D_IN;

  GEN_Registers : for i in 1 to DEPTH generate
    Registers : process (CLK)
    begin
      if rising_edge(CLK) then
        reg(i) <= reg(i-1);
      end if;
    end process Registers;
  end generate GEN_Registers;

  D_OUT <= reg(DEPTH);

end Behavioral;
