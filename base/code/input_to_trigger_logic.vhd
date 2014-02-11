library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


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

type reg_t is array(0 to OUTPUTS-1) of std_logic_vector(31 downto 0);
signal enable : reg_t;
signal invert : reg_t;

begin


THE_CONTROL : process 
  variable tmp : integer range 0 to 15;
begin
  wait until rising_edge(CLK);
  ACK_OUT  <= '0';
  NACK_OUT <= '0';
  tmp := to_integer(unsigned(ADDR_IN(5 downto 2)));
  if WRITE_IN = '1' then
    ACK_OUT <= '1';
    case ADDR_IN(1 downto 0) is
      when "00"   => enable(tmp) <= DATA_IN;
      when "01"   => invert(tmp) <= DATA_IN;
      when others => NACK_OUT <= '1'; ACK_OUT <= '0';
    end case;
  elsif READ_IN = '1' then
    ACK_OUT <= '1';
    case ADDR_IN(1 downto 0) is
      when "00"   => DATA_OUT <= enable(tmp);
      when "01"   => DATA_OUT <= invert(tmp);
      when others => DATA_OUT <= (others => '0');
    end case;
  end if;
end process;

gen_outs : for i in 0 to OUTPUTS-1 generate
  OUTPUT(i) <= or_all((INPUT xor invert(i)(INPUTS-1 downto 0)) and enable(i)(INPUTS-1 downto 0));
end generate;



end architecture;