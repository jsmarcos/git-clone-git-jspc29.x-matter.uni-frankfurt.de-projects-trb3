library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nx_timer is
  generic (
    CTR_WIDTH : integer := 12
    );
  port(
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;

    TIMER_START_IN       : in unsigned(CTR_WIDTH - 1 downto 0);
    TIMER_DONE_OUT       : out std_logic
    );
end entity;

architecture Behavioral of nx_timer is

  -- Timer
  signal timer_ctr       : unsigned(CTR_WIDTH - 1 downto 0);
  signal timer_done_o    : std_logic;

  type STATES is (S_IDLE,
                  S_COUNT,
                  S_DONE
                  );
  signal STATE : STATES;

begin
  
  PROC_TIMER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timer_ctr     <= (others => '0');
        timer_done_o  <= '0';
        STATE         <= S_IDLE;
      else
        timer_done_o  <= '0';
        
        if (TIMER_START_IN > 0) then
          timer_ctr <= TIMER_START_IN;
          STATE     <= S_COUNT;
        else
          case STATE is
            when S_IDLE =>
              if (TIMER_START_IN = 0) then
                STATE      <= S_IDLE;
              else
                timer_ctr  <= TIMER_START_IN;
                STATE      <= S_COUNT;
              end if;
        
            when S_COUNT =>
              if (timer_ctr > 0) then
                timer_ctr  <= timer_ctr - 1;
                STATE      <= S_COUNT;
              else
                STATE      <= S_DONE;
              end if;
        
            when S_DONE =>
              timer_done_o <= '1';
              STATE        <= S_IDLE;

          end case;
        end if;
      end if;
    end if;
  end process PROC_TIMER;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMER_DONE_OUT <= timer_done_o;

end Behavioral;
