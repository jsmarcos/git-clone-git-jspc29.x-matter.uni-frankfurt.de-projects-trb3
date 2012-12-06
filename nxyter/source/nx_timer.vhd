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

  signal timer_ctr_x     : unsigned(CTR_WIDTH - 1 downto 0);
  signal timer_done_o_x  : std_logic;

  type STATES is (S_IDLE,
                  S_COUNT,
                  S_DONE
                  );
  signal STATE, NEXT_STATE : STATES;

begin

  PROC_TIMER_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timer_ctr     <= (others => '0');
        timer_done_o  <= '0';
        STATE         <= S_IDLE;
      else
        timer_ctr     <= timer_ctr_x;
        timer_done_o  <= timer_done_o_x;
        STATE         <= NEXT_STATE;
      end if;
    end if;
  end process PROC_TIMER_TRANSFER;
  
  PROC_TIMER: process(STATE,
                      TIMER_START_IN,
                      timer_ctr
                      )
  begin 

    timer_done_o_x <= '0';

    case STATE is
      when S_IDLE =>
        if (TIMER_START_IN = 0) then
          NEXT_STATE <= S_IDLE;
        else
          timer_ctr_x <= TIMER_START_IN;
          NEXT_STATE <= S_COUNT;
        end if;
            
      when S_COUNT =>
        if (timer_ctr > 0) then
          timer_ctr_x <= timer_ctr - 1;
          NEXT_STATE <= S_COUNT;
        else
          NEXT_STATE <= S_DONE;
        end if;
        
      when S_DONE =>
        timer_done_o_x <= '1';
        NEXT_STATE <= S_IDLE;
        
    end case;
  end process PROC_TIMER;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMER_DONE_OUT <= timer_done_o;

end Behavioral;
