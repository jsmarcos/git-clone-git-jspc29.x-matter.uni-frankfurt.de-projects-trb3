library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.nxyter_components.all;

entity pulse_to_level is
  generic (
    NUM_CYCLES : integer range 2 to 15 := 4
    );
  port (
    CLK_IN        : in  std_logic;  
    RESET_IN      : in  std_logic;
    
    PULSE_IN      : in  std_logic;  
    LEVEL_OUT     : out std_logic
    );

end entity;

architecture Behavioral of pulse_to_level is

  signal start_timer_x  : unsigned(4 downto 0);

  signal start_timer    : unsigned(4 downto 0);
  signal timer_done     : std_logic;
  signal level_o        : std_logic;

  type STATES is (IDLE,
                  WAIT_TIMER
                  );
  signal STATE, NEXT_STATE : STATES;
  
begin
  
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 5
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
        start_timer    <= (others => '0');
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
    constant TIMER_VALUE :
    unsigned(4 downto 0) := to_unsigned(NUM_CYCLES - 1, 5);

  begin

    case STATE is
      when IDLE =>
        if (PULSE_IN = '1') then
          level_o          <= '1';
          start_timer_x    <= TIMER_VALUE;
          NEXT_STATE       <= WAIT_TIMER;
        else
          level_o          <= '0';
          start_timer_x    <= (others => '0');
          NEXT_STATE       <= IDLE;
        end if;

      when WAIT_TIMER =>
        start_timer_x      <= (others => '0');
        if (timer_done = '0') then
          level_o          <= '1';
          NEXT_STATE       <= WAIT_TIMER; 
        else
          level_o          <= '0';
          NEXT_STATE       <= IDLE;
        end if;

    end case;
  end process PROC_CONVERT;

  -- Output Signals
  LEVEL_OUT   <= level_o;
  
end Behavioral;
