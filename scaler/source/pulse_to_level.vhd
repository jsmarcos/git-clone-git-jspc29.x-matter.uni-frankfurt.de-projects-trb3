library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.nxyter_components.all;

entity pulse_to_level is
  generic (
    NUM_CYCLES    : integer range 2 to 15 := 4
    );
  port (
    CLK_IN        : in  std_logic;  
    RESET_IN      : in  std_logic;
    
    PULSE_IN      : in  std_logic;  
    LEVEL_OUT     : out std_logic
    );

end entity;

architecture Behavioral of pulse_to_level is
--  attribute HGROUP : string;
--  attribute HGROUP of Behavioral : architecture is "PULSE_TO_LEVEL";

  signal start_timer_x  : std_logic;

  signal start_timer    : std_logic;
  signal timer_done     : std_logic;
  signal level_o        : std_logic;

  type STATES is (IDLE,
                  WAIT_TIMER
                  );
  signal STATE, NEXT_STATE : STATES;
  
begin
  
  timer_static_1: timer_static
    generic map (
      CTR_WIDTH => 5,
      CTR_END   => NUM_CYCLES
      )
    port map (
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      TIMER_START_IN  => start_timer,
      TIMER_DONE_OUT  => timer_done
      );

  PROC_LEVEL_OUT_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        start_timer    <= '0';
        STATE          <= IDLE;
      else
        start_timer    <= start_timer_x;
        STATE          <= NEXT_STATE;
      end if;
    end if;
  end process PROC_LEVEL_OUT_TRANSFER;
  
  PROC_LEVEL_OUT: process(STATE,
                          PULSE_IN,
                          timer_done
                          )
  begin

    case STATE is
      when IDLE =>
        if (PULSE_IN = '1') then
          level_o          <= '1';
          start_timer_x    <= '1';
          NEXT_STATE       <= WAIT_TIMER;
        else
          level_o          <= '0';
          start_timer_x    <= '0';
          NEXT_STATE       <= IDLE;
        end if;

      when WAIT_TIMER =>
        start_timer_x      <= '0';
        if (timer_done = '0') then
          level_o          <= '1';
          NEXT_STATE       <= WAIT_TIMER; 
        else
          level_o          <= '0';
          NEXT_STATE       <= IDLE;
        end if;

    end case;
  end process PROC_LEVEL_OUT;

  -- Output Signals
  LEVEL_OUT   <= level_o;
  
end Behavioral;
