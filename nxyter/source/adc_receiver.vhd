----------------------------------------------------------------------------
-- ADC Pulse height Handler
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.nxyter_components.all;

entity adc_receiver is
  
  port (
    CLK_IN             : in std_logic;  
    RESET_IN           : in std_logic;  
    CLK_ADC_IN         : in std_logic;
    
    ADC_FCLK_IN        : in std_logic_vector(1 downto 0);
    ADC_DCLK_IN        : in std_logic_vector(1 downto 0);
    ADC_SC_CLK32_OUT   : out std_logic;
    ADC_A_IN           : in std_logic_vector(1 downto 0);
    ADC_B_IN           : in std_logic_vector(1 downto 0);
    ADC_NX_IN          : in std_logic_vector(1 downto 0);
    ADC_D_IN           : in std_logic_vector(1 downto 0);

    DEBUG_OUT          : out std_logic_vector(15 downto 0)
    );
end entity;


architecture Behavioral of adc_receiver is

  signal even_bit_reg     : std_logic;
  signal even_bit_ctr     : unsigned(2 downto 0);
  signal even_bits        : std_logic_vector(5 downto 0);
  signal even_word        : std_logic_vector(5 downto 0);
  signal new_even_word    : std_logic;

  signal odd_bit_reg      : std_logic;
  signal odd_bit_ctr      : unsigned(2 downto 0);
  signal odd_bits         : std_logic_vector(5 downto 0);
  signal odd_word         : std_logic_vector(5 downto 0);
  signal new_odd_word     : std_logic;

  signal adc_recv_clk     : std_logic;
  signal adc_recv_bits    : std_logic_vector(3 downto 0);

  -- ADC PLLs
  signal pll_32MHz        : std_logic;
  signal pll_lock_32MHz   : std_logic;

  signal pll_192MHz       : std_logic;
  signal pll_lock_192MHz  : std_logic;
  
begin

  -- Debug
  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= pll_lock_32MHz;
  DEBUG_OUT(2)             <= pll_lock_192MHz;
 -- DEBUG_OUT(3)             <= '0';--pll_32MHz;
 -- DEBUG_OUT(4)             <= '0';--pll_192MHz;
 --
 -- DEBUG_OUT(15 downto 5)   <= (others => '0');

  -----------------------------------------------------------------------------
  -- ADC PLLs
  -----------------------------------------------------------------------------

  pll_adc_clk192_1: pll_adc_clk192
    port map (
      CLK   => CLK_ADC_IN,
      CLKOP => pll_192MHz,
      LOCK  => pll_lock_192MHz
      );
  
   pll_adc_clk32_1: entity work.pll_adc_clk32
    port map (
      CLK    => CLK_ADC_IN,
      CLKOP  => pll_32MHz, 
      LOCK   => pll_lock_32MHz
      );

  -----------------------------------------------------------------------------
  -- ADC 
  -----------------------------------------------------------------------------
  
  adc_ad9222_1: entity work.adc_ad9222
    generic map (
      CHANNELS => 4,
      DEVICES  => 2,
      RESOLUTION => 12
      )
    port map (
      CLK                        => CLK_IN,
      CLK_ADCREF                 => pll_32MHz,
      CLK_ADCDAT                 => pll_192MHz,
      RESTART_IN                 => '0', 
      ADCCLK_OUT                 => ADC_SC_CLK32_OUT, 

      ADC_DATA(0)                => ADC_NX_IN(0), 
      ADC_DATA(1)                => ADC_A_IN(0),
      ADC_DATA(2)                => ADC_B_IN(0), 
      ADC_DATA(3)                => ADC_D_IN(0), 

      ADC_DATA(4)                => ADC_NX_IN(1), 
      ADC_DATA(5)                => ADC_A_IN(1), 
      ADC_DATA(6)                => ADC_B_IN(1), 
      ADC_DATA(7)                => ADC_D_IN(1),

      ADC_DCO                    => ADC_DCLK_IN,
      ADC_FCO                    => ADC_FCLK_IN,

      DATA_OUT(11 downto  0)     => DEBUG_OUT(15 downto 4),
      DATA_OUT(95 downto 12)     => open,

      FCO_OUT                    => open,
      DATA_VALID_OUT(0)          => DEBUG_OUT(3),
      DATA_VALID_OUT(1)          => open,
      DEBUG                      => open
      );
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  ADC_SC_CLK32_OUT    <= pll_32MHz; -- adc_sc_clk32_o;


end Behavioral;
