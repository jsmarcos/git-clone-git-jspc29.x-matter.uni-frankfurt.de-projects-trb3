library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity timer is
  generic (
    CTR_WIDTH : integer range 2 to 32  := 12;
    STEP_SIZE : integer range 1 to 100 := 1
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    TIMER_START_IN       : in  std_logic;
    TIMER_END_IN         : in  unsigned(CTR_WIDTH - 1 downto 0);
    TIMER_DONE_OUT       : out std_logic
    );
end entity;

architecture Behavioral of timer is
--  attribute HGROUP : string;
--  attribute HGROUP of Behavioral : architecture is "NX_TIMER";
  
  -- Timer
  signal timer_ctr_x     : unsigned(CTR_WIDTH - 1 downto 0);

  signal timer_ctr       : unsigned(CTR_WIDTH - 1 downto 0);
  signal timer_done_o    : std_logic;

  type STATES is (S_IDLE,
                  S_COUNT
                  );
  signal STATE, NEXT_STATE : STATES;

begin
  
  PROC_TIMER_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timer_ctr      <= (others => '0');
        STATE          <= S_IDLE;
      else
        timer_ctr      <= timer_ctr_x;
        STATE          <= NEXT_STATE;
      end if;
    end if;
  end process PROC_TIMER_TRANSFER; 
  
  PROC_TIMER: process(STATE,
                      TIMER_START_IN,
                      TIMER_END_IN,
                      timer_ctr
                      )
  begin 
    
    case STATE is
      when S_IDLE =>
        timer_done_o      <= '0';
        if (TIMER_START_IN = '1' and TIMER_END_IN > 0) then
          timer_ctr_x     <= TIMER_END_IN - 1;
          NEXT_STATE      <= S_COUNT;
        else
          timer_ctr_x     <= (others => '0');
          NEXT_STATE      <= S_IDLE;
        end if;
        
      when S_COUNT =>
        if (timer_ctr > to_unsigned(STEP_SIZE - 1, CTR_WIDTH)) then
          timer_ctr_x     <= timer_ctr - to_unsigned(STEP_SIZE, CTR_WIDTH);
          timer_done_o    <= '0';
          NEXT_STATE      <= S_COUNT;
        else
          timer_ctr_x     <= (others => '0');
          timer_done_o    <= '1';
          NEXT_STATE      <= S_IDLE;
        end if;

    end case;

  end process PROC_TIMER;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMER_DONE_OUT <= timer_done_o;

end Behavioral;
