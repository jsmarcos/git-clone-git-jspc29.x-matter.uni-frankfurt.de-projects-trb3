library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity level_to_pulse is
  
  port (
    CLK_IN        : in std_logic;  
    RESET_IN      : in std_logic;

    LEVEL_IN      : in std_logic;  
    PULSE_OUT     : out std_logic
    );

end level_to_pulse;

architecture Behavioral of level_to_pulse is

  type STATES is (IDLE,
                  WAIT_LOW
                );
  signal STATE : STATES;

  signal pulse_o          : std_logic;

begin

  PROC_CONVERT: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        pulse_o <= '0';
        STATE   <= WAIT_LOW;
      else
        pulse_o <= '0';
        case STATE is

          when IDLE =>
            if (LEVEL_IN = '1') then
              pulse_o <= '1';
              STATE <= WAIT_LOW;
            else
              STATE <= IDLE;
            end if;

          when WAIT_LOW =>
            if (LEVEL_IN = '0') then
              STATE <= IDLE;
            else
              STATE <= WAIT_LOW;
            end if;

           when others => null;

        end case;
      end if;
    end if;
  end process PROC_CONVERT;

  PULSE_OUT <= pulse_o;
    
end Behavioral;
