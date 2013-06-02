library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use nxyter_components.all;

entity pulse_to_level is
  generic (
    NUM_CYCLES : unsigned(4 downto 0) := "11111"
    );
  port (
    CLK_IN        : in  std_logic;  
    RESET_IN      : in  std_logic;
    
    PULSE_IN      : in  std_logic;  
    LEVEL_OUT     : out std_logic
    );

end pulse_to_level;

architecture Behavioral of pulse_to_level is

  signal start_timer  : unsigned(4 downto 0);
  signal timer_done   : std_logic;
  signal level_o      : std_logic;

  type STATES is (IDLE,
                  WAIT_TIMER
                );
  signal STATE : STATES;
  
begin

  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 5
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => start_timer,
      TIMER_DONE_OUT => timer_done
      );
  
  PROC_CONVERT: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        start_timer <= (others => '0');
        level_o     <= '0';
        STATE       <= IDLE;
      else
        level_o <= '0';
        start_timer <= (others => '0');

        case STATE is

          when IDLE =>
            if (PULSE_IN = '1') then
              level_o     <= '1';
              start_timer <= NUM_CYCLES;
              STATE <= WAIT_TIMER;
            else
              STATE <= IDLE;
            end if;

          when WAIT_TIMER =>
            level_o     <= '1';
            if (timer_done = '1') then
              STATE <= IDLE;
            else
              STATE <= WAIT_TIMER;
            end if;

           when others => null;

        end case;
      end if;
    end if;
  end process PROC_CONVERT;

  LEVEL_OUT <= level_o;
    
end Behavioral;
