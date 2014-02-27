library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.trb_net_std.all;


entity input_statistics is
  generic(
    INPUTS     : integer range 1 to 32 := 16
    );
  port(
    CLK        : in std_logic;
    
    INPUT      : in  std_logic_vector(INPUTS-1 downto 0);

    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    READ_IN    : in  std_logic := '0';
    ACK_OUT    : out std_logic;
    NACK_OUT   : out std_logic;
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0')
    
    );
end entity;


architecture input_statistics_arch of input_statistics is

signal inp_reg      : std_logic_vector(INPUTS-1 downto 0);

signal trigger_fifo : std_logic;
signal reset_cnt    : std_logic;

signal enable : std_logic_vector(31 downto 0);
signal invert : std_logic_vector(31 downto 0);
signal rate   : unsigned(31 downto 0);

signal fifo_read : std_logic_vector(31 downto 0);
signal fifo_select : integer range 0 to 31;

begin


THE_CONTROL : process 
  variable tmp : integer range 0 to 15;
begin
  wait until rising_edge(CLK);
  ACK_OUT  <= '0';
  NACK_OUT <= '0';
  trigger_fifo  <= '0';
  fifo_read     <= (others => '0');
  fifo_select   <= 0;
  if WRITE_IN = '1' then
    if ADDR_IN(6 downto 4) = "000" then
      ACK_OUT <= '1';
      case ADDR_IN(3 downto 0) is
        when x"0"   => enable <= DATA_IN;
        when x"1"   => invert <= DATA_IN;
        when x"2"   => rate   <= unsigned(DATA_IN);
        when x"f"   => trigger_fifo <= DATA_IN(0);
                       reset_cnt    <= DATA_IN(1);
        when others => NACK_OUT <= '1'; ACK_OUT <= '0';
      end case;
    else 
      NACK_OUT <= '1';
    end if;
  elsif READ_IN = '1' then
    if ADDR_IN(6 downto 4) = "000" then
      ACK_OUT <= '1';
      case ADDR_IN(3 downto 0) is
        when x"0"   => DATA_OUT <= enable;
        when x"1"   => DATA_OUT <= invert;
        when x"2"   => DATA_OUT <= std_logic_vector(rate);
        when x"e"   => DATA_OUT(INPUTS-1 downto 0)  <= inp_reg; DATA_OUT(31 downto INPUTS) <= (others => '0');
        when others => DATA_OUT <= (others => '0');
      end case;
    elsif ADDR_IN(6 downto 4) = "001" or ADDR_IN(6 downto 5) = "010" then
      fifo_read(to_integer(unsigned(ADDR_IN(4 downto 0)))) <= '1';
      fifo_select <= to_integer(unsigned(ADDR_IN(4 downto 0)));
    end if;
  end if;
end process;


inp_reg <= INPUT when rising_edge(CLK);

end architecture;