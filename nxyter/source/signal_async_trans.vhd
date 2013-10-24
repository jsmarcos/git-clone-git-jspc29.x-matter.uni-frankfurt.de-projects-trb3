library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity signal_async_trans is
  generic (
    NUM_FF : integer range 2 to 4 := 2
    );
  port (
    CLK_IN       : in  std_logic;
    RESET_IN     : in  std_logic;
    SIGNAL_A_IN  : in  std_logic;
    SIGNAL_OUT   : out std_logic
    );

end entity;

architecture Behavioral of signal_async_trans is
  signal signal_ff      : std_logic_vector(NUM_FF - 1 downto 0);
  signal signal_o       : std_logic;

begin

  -----------------------------------------------------------------------------
  -- Clock CLK_IN Domain
  -----------------------------------------------------------------------------

  PROC_SYNC_SIGNAL: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      signal_ff(NUM_FF - 1) <= SIGNAL_A_IN;
      if( RESET_IN = '1' ) then
        for i in NUM_FF - 2 downto 0 loop
          signal_ff(i)      <= '0';
        end loop;
      else
        for i in NUM_FF - 2 downto 0 loop
          signal_ff(i)      <= signal_ff(i + 1); 
        end loop;
      end if;
    end if;
  end process PROC_SYNC_SIGNAL;
  signal_o     <= signal_ff(0);
  
-- Outpu Signals
  SIGNAL_OUT   <= signal_o;
  
end Behavioral;
