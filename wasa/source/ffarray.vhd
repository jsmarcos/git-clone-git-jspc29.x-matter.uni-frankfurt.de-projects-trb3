library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;


entity ffarray is
  port(
    CLK        : in std_logic;
    SIGNAL_IN  : in std_logic;
    
    DATA_OUT   : out std_logic_vector(7 downto 0);
    READ_IN    : in  std_logic := '0';
    EMPTY_OUT  : out std_logic := '0'
    );
end entity;

architecture ffarray_arch of ffarray is

signal CLKt  : std_logic_vector(3 downto 0);
signal CLKa  : std_logic_vector(7 downto 0);

signal final     : std_logic_vector(7 downto 0);
signal final_t   : std_logic_vector(7 downto 0);

type ffarr_t is array(0 to 3) of std_logic_vector(7 downto 0);
signal ffarr : ffarr_t;

type ram_t  is array(0 to 1023) of std_logic_vector(7 downto 0);
signal ram : ram_t;

signal fifo_write : std_logic;


  attribute syn_preserve : boolean;
  attribute syn_keep : boolean;

  attribute syn_preserve of CLKa : signal is true;
  attribute syn_keep     of CLKa : signal is true;
  attribute syn_preserve of CLKt : signal is true;
  attribute syn_keep     of CLKt : signal is true;


begin

THE_PLL : entity work.pll_shifted_clocks
  port map(
    CLKI    => CLK,
    CLKOP   => CLKt(0),
    CLKOS   => CLKt(1),
    CLKOS2  => CLKt(2),
    CLKOS3  => CLKt(3)
    );

CLKa(3 downto 0) <= CLKt(3 downto 0) xor x"0";
CLKa(7 downto 4) <= not CLKt(3 downto 0);

gen_ffarr_first : for i in 0 to 7 generate
  ffarr(0)(i) <= SIGNAL_IN when rising_edge(CLKa(i));
end generate;

gen_ffarr_j : for j in 1 to 3 generate
  gen_ffarr_i : for i in 0 to 7 generate
    ffarr(j)(i) <= ffarr(j-1)(i) when rising_edge(CLKa(maximum(i-j*2,0)));
  end generate;
end generate;


process begin
  wait until rising_edge(CLK);
  final_t <= ffarr(3);
  if ((not and_all(final_t) and or_all(final_t)) = '1') then
    fifo_write <= '1';
    final <= final_t;
  else
    fifo_write <= '0';
  end if;
end process;

    
THE_FIFO : entity work.fifo_1kx8
  port map(
    Data        => final,
    WrClock     => CLK,    --wrong!
    RdClock     => CLK, 
    WrEn        => fifo_write, 
    RdEn        => READ_IN,
    Reset       => '0',
    RPReset     => '0', 
    Q           => DATA_OUT,
    Empty       => EMPTY_OUT,
    Full        => open,
    AlmostEmpty => open,
    AlmostFull  => open
    );
    
end architecture;