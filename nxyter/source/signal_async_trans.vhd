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

  signal signal_ff      : signal_ff_t;

  attribute syn_keep : boolean;
  attribute syn_keep of signal_ff      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of signal_ff  : signal is true;
  
begin

  -----------------------------------------------------------------------------
  -- Clock CLK_IN Domain
  -----------------------------------------------------------------------------

  PROC_SYNC_SIGNAL: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      signal_ff(NUM_FF - 1)   <= SIGNAL_A_IN;
      for i in NUM_FF - 2 downto 0 loop
        signal_ff(i)          <= signal_ff(i + 1); 
      end loop;
    end if;
  end process PROC_SYNC_SIGNAL;
  
-- Output Signals
  SIGNAL_OUT      <= signal_ff(0);
  
end Behavioral;
