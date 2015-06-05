library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.scaler_components.all;

entity pulse_delay is
  generic (
    DELAY : integer range 2 to 16777216 := 100
    );
  port (
    CLK_IN        : in  std_logic;  
    RESET_IN      : in  std_logic;
    
    PULSE_IN      : in  std_logic;  
    PULSE_OUT     : out std_logic
    );

end entity;

architecture Behavioral of pulse_delay is
  signal start_timer_x  : std_logic;

  signal start_timer    : std_logic;
  signal timer_done     : std_logic;
  signal pulse_o        : std_logic;

  type STATES is (IDLE,
                  WAIT_TIMER
                  );
  signal STATE, NEXT_STATE : STATES;
  
begin
  
  timer_static_1: timer_static
    generic map (
      CTR_WIDTH => 24,
      CTR_END   => (DELAY - 1)
      )
    port map (
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      TIMER_START_IN  => start_timer,
      TIMER_DONE_OUT  => timer_done
      );

  PROC_CONVERT_TRANSFER: process(CLK_IN)
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
  end process PROC_CONVERT_TRANSFER; 
  
  PROC_CONVERT: process(STATE,
                        PULSE_IN,
                        timer_done
                        )
 
  begin
    pulse_o                <= '0';
    case STATE is
      when IDLE =>
        if (PULSE_IN = '1') then
          start_timer_x    <= '1';
          pulse_o          <= '0';
          NEXT_STATE       <= WAIT_TIMER;
        else
          start_timer_x    <= '0';
          pulse_o                <= '0';
          NEXT_STATE       <= IDLE;
        end if;

      when WAIT_TIMER =>
        start_timer_x      <= '0';
        if (timer_done = '0') then
          pulse_o          <= '0';
          NEXT_STATE       <= WAIT_TIMER; 
        else
          pulse_o          <= '1';
          NEXT_STATE       <= IDLE;
        end if;

    end case;
  end process PROC_CONVERT;

  -- Output Signals
  PULSE_OUT   <= pulse_o;
  
end Behavioral;
