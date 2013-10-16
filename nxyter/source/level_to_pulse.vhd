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

end entity;

architecture Behavioral of level_to_pulse is

  type STATES is (IDLE,
                  WAIT_LOW
                );
  signal STATE, NEXT_STATE : STATES;

  signal pulse_o          : std_logic;

begin

  PROC_CONVERT_TRANSFER:process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        STATE     <= IDLE;
      else
        STATE     <= NEXT_STATE;
      end if;
    end if;
  end process PROC_CONVERT_TRANSFER;

  
  PROC_CONVERT: process(STATE,
                        LEVEL_IN
                        )
  begin
    
    case STATE is
      when IDLE =>
        if (LEVEL_IN = '1') then
          pulse_o     <= '1';
          NEXT_STATE  <= WAIT_LOW;
        else
          pulse_o     <= '0';
          NEXT_STATE  <= IDLE;
        end if;

      when WAIT_LOW =>
        pulse_o       <= '0';
        if (LEVEL_IN = '0') then
          NEXT_STATE  <= IDLE;
        else
          NEXT_STATE  <= WAIT_LOW;
        end if;

    end case;

  end process PROC_CONVERT;

  -- Output Signals
  PULSE_OUT    <= pulse_o;
    
end Behavioral;
