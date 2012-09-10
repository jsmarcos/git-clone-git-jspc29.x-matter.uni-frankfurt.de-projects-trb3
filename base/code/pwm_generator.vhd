library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity pwm_generator is
  generic(
    CHANNELS   : integer range 1 to 64 := 16;
    RESOLUTION : integer range 1 to 32 := 16
    );
  port(
    CLK        : in std_logic;
    
    DATA_IN    : in  std_logic_vector(31 downto 0) := (others => '0');
    DATA_OUT   : out std_logic_vector(31 downto 0);
    WRITE_IN   : in  std_logic := '0';
    ADDR_IN    : in  std_logic_vector(15 downto 0) := (others => '0');
    
    PWM        : out std_logic_vector(CHANNELS-1 downto 0)
    
    );
end entity;



architecture pwm_arch of pwm_generator is

type ram_t is array(0 to CHANNELS-1) of unsigned(RESOLUTION downto 0);
signal set : ram_t := (others => (others => '0'));

type cnt_t is array(0 to CHANNELS-1) of unsigned(RESOLUTION downto 0);
signal cnt : cnt_t := (others => (others => '0'));

signal last_flag : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal flag      : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
signal pwm_i     : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');


begin

PROC_MEM : process begin
  wait until rising_edge(CLK);
  if WRITE_IN = '1' then
--     set(to_integer(unsigned(ADDR_IN)))(16) <= '0';
    set(to_integer(unsigned(ADDR_IN)))(RESOLUTION-1 downto 0) <= unsigned(DATA_IN(RESOLUTION-1 downto 0));
  end if;
  DATA_OUT(RESOLUTION-1 downto 0) <= std_logic_vector(set(to_integer(unsigned(ADDR_IN)))(RESOLUTION-1 downto 0));
  DATA_OUT(31 downto RESOLUTION)  <= (others => '0');
end process;


gen_channels : for i in 0 to CHANNELS-1 generate
  flag(i)      <= cnt(i)(RESOLUTION);
  last_flag(i) <= flag(i) when rising_edge(CLK);
  pwm_i(i)     <= (last_flag(i) xor flag(i)) when rising_edge(CLK);
  cnt(i)       <= cnt(i) + set(i) when rising_edge(CLK);
end generate;


PWM <= pwm_i;

end architecture;