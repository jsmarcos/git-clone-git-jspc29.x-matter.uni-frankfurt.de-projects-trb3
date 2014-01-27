library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity input_to_trigger_logic is
  generic(
    INPUTS     : integer range 1 to 32 := 24;
    OUTPUTS    : integer range 1 to 16 := 4
    );
  port(
    CLK        : in std_logic;
    
    INPUT      : in  std_logic_vector(INPUTS-1 downto 0);
    OUTPUT     : out std_logic_vector(OUTPUTS-1 downto 0);

    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    READ_IN    : in  std_logic := '0';
    ACK_OUT    : out std_logic;
    NACK_OUT   : out std_logic;
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')
    
    );
end entity;



architecture input_to_trigger_logic_arch of input_to_trigger_logic is

 

begin

OUTPUT <= INPUT(OUTPUTS-1 downto 0);

THE_CONTROL : process begin
  wait until rising_edge(CLK);
  
  
end process;


end architecture;