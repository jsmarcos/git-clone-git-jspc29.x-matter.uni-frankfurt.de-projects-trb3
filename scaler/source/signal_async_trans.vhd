library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_async_trans is
  generic (
    NUM_FF : integer range 2 to 5 := 2
    );
  port (
    CLK_IN       : in  std_logic;
    SIGNAL_A_IN  : in  std_logic;
    SIGNAL_OUT   : out std_logic
    );

end entity;

architecture Behavioral of signal_async_trans is
  type signal_ff_t is array(0 to NUM_FF - 1) of std_logic;

  signal signal_ff   : signal_ff_t;

  attribute syn_keep : boolean;
  attribute syn_keep of signal_ff      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of signal_ff  : signal is true;
  
begin

  -----------------------------------------------------------------------------
  -- Clock CLK_IN Domain
  -----------------------------------------------------------------------------

  signal_ff(NUM_FF - 1)   <= SIGNAL_A_IN when rising_edge(CLK_IN);

  L1: for I in (NUM_FF - 2) downto 0 generate
    signal_ff(I)          <= signal_ff(I + 1) when rising_edge(CLK_IN);
  end generate L1;
    
-- Output Signals
  SIGNAL_OUT      <= signal_ff(0);
  
end Behavioral;
