----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:09:56 07/28/2013 
-- Design Name: 
-- Module Name:    BlockMemory - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity BlockMemory is
  generic (
    DataWidth    : integer := 10;
    AddressWidth : integer := 10);
  port (
    clk    : in  std_logic;
    WrEn   : in  std_logic;
    WrAddr : in  std_logic_vector(AddressWidth - 1 downto 0);
    Din    : in  std_logic_vector(DataWidth - 1 downto 0);
    ReAddr : in  std_logic_vector(AddressWidth - 1 downto 0);
    Dout   : out std_logic_vector(DataWidth - 1 downto 0));
end BlockMemory;

architecture Behavioral of BlockMemory is
  
  type   memory_type is array ((2**AddressWidth) - 1 downto 0) of std_logic_vector(DataWidth - 1 downto 0);
  signal memory : memory_type := (others => (others => '0'));

begin

  MemoryControll : process(clk)
  begin  -- process MemoryControll
    if rising_edge(clk) then
      Dout <= memory(to_integer(unsigned(ReAddr)));   --read memory
      if(WrEn = '1') then
        memory(to_integer(unsigned(WrAddr))) <= Din;  -- write memory
      end if;
    end if;
  end process MemoryControll;


end Behavioral;

