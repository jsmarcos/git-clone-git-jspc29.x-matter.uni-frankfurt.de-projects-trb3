library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity pwm_generator is
  port(
    CLK        : in std_logic;
    
    DATA_IN    : in  std_logic_vector(15 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(15 downto 0);
    WRITE_IN   : in  std_logic := '0';
    COMP_IN    : in  signed(15 downto 0);
    ADDR_IN    : in  std_logic_vector(3 downto 0) := (others => '0');
    
    
    PWM        : out std_logic_vector(31 downto 0)
    
    );
end entity;



architecture pwm_arch of pwm_generator is

type ram_t is array(0 to 15) of unsigned(15 downto 0);
signal set : ram_t := (others => x"87C1");
signal set_tmp : ram_t;

type cnt_t is array(0 to 15) of unsigned(16 downto 0);
signal cnt : cnt_t := (others => (others => '0'));

signal last_flag : std_logic_vector(15 downto 0) := (others => '0');
signal flag      : std_logic_vector(15 downto 0) := (others => '0');
signal pwm_i     : std_logic_vector(15 downto 0) := (others => '0');

signal i         : integer range 0 to 15 := 0;

begin

PROC_MEM : process begin
  wait until rising_edge(CLK);
  if WRITE_IN = '1' then
    set(to_integer(unsigned(ADDR_IN))) <= unsigned(DATA_IN);
  end if;
  DATA_OUT <= std_logic_vector(set(to_integer(unsigned(ADDR_IN))));
end process;


GEN_REAL_VALUES : process begin
  wait until rising_edge(CLK);
  set_tmp(i) <= unsigned(signed(set(i)) + COMP_IN);
  i <= i + 1;
end process;



gen_channels : for i in 0 to 15 generate
  flag(i)      <= cnt(i)(16);
  last_flag(i) <= flag(i) when rising_edge(CLK);
  pwm_i(i)     <= (last_flag(i) xor flag(i)) when rising_edge(CLK);
  cnt(i)       <= cnt(i) + resize(set_tmp(i),17) when rising_edge(CLK);
end generate;


PWM(31 downto 16) <= pwm_i(15 downto 0); --no high-res yet
PWM(15 downto 0 ) <= pwm_i(15 downto 0);

end architecture;