library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_i2c_startstop is
  generic (
    i2c_speed : unsigned(11 downto 0) := x"3e8"
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    START_IN             : in  std_logic;  -- Start Sequence
    SELECT_IN            : in  std_logic;  -- '1' -> Start, '0'-> Stop
    SEQUENCE_DONE_OUT    : out std_logic;
    
    -- I2C connections
    SDA_OUT              : out std_logic;
    SCL_OUT              : out std_logic;
    NREADY_OUT           : out std_logic
    );
end entity;

architecture Behavioral of nx_i2c_startstop is

  -- I2C Bus  
  signal sda_o             : std_logic;
  signal scl_o             : std_logic;
  signal sequence_done_o   : std_logic;
  signal wait_timer_init   : unsigned(11 downto 0);

  signal sequence_done_o_x : std_logic;
  signal wait_timer_init_x : unsigned(11 downto 0);
  
  type STATES is (S_IDLE,
                  S_START,
                  S_WAIT_START_1,
                  S_WAIT_START_2,
                  S_WAIT_START_3,
                  
                  S_STOP,
                  S_WAIT_STOP_1,
                  S_WAIT_STOP_2,
                  S_WAIT_STOP_3
                  );
  signal STATE, NEXT_STATE : STATES;

  -- I2C Timer
  signal wait_timer_done    : std_logic;

begin

  -- Timer
  nx_i2c_timer_1: nx_i2c_timer
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  PROC_START_STOP_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sequence_done_o  <= '0';
        wait_timer_init  <= (others => '0');
        STATE <= S_IDLE;
      else
        sequence_done_o  <= sequence_done_o_x;
        wait_timer_init  <= wait_timer_init_x;
        STATE            <= NEXT_STATE;
      end if;
    end if;
  end process PROC_START_STOP_TRANSFER;
  
  PROC_START_STOP: process(STATE)
  begin

    sda_o             <= '1';
    scl_o             <= '1';
    wait_timer_init_x <= (others => '0');
    sequence_done_o_x <= '0';
    
    case STATE is
      when S_IDLE =>
        if (START_IN = '1') then
          if (SELECT_IN = '1') then
            NEXT_STATE <= S_START;
          else
            sda_o      <= '0';
            scl_o      <= '0';
            NEXT_STATE <= S_STOP;
          end if;
        else
          NEXT_STATE <= S_IDLE;
        end if;
        
        -- I2C START Sequence 
      when S_START =>
        wait_timer_init_x <= i2c_speed srl 1;
        NEXT_STATE <= S_WAIT_START_1;

      when S_WAIT_START_1 =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_START_1;
        else
          wait_timer_init_x <= i2c_speed srl 1;
          NEXT_STATE <= S_WAIT_START_2;
        end if;

      when S_WAIT_START_2 =>
        sda_o         <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_START_2;
        else
          wait_timer_init_x <= i2c_speed srl 1;
          NEXT_STATE <= S_WAIT_START_3;
        end if;

      when S_WAIT_START_3 =>
        sda_o         <= '0';
        scl_o         <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_START_3;
        else
          sequence_done_o_x <= '1';
          NEXT_STATE <= S_IDLE;
        end if;

        -- I2C STOP Sequence 
      when S_STOP =>
        sda_o           <= '0';
        scl_o           <= '0';
        wait_timer_init_x <= i2c_speed srl 1;
        NEXT_STATE <= S_WAIT_STOP_1;

      when S_WAIT_STOP_1 =>
        sda_o           <= '0';
        scl_o           <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_STOP_1;
        else
          wait_timer_init_x <= i2c_speed srl 1;
          NEXT_STATE <= S_WAIT_STOP_2;
        end if;

      when S_WAIT_STOP_2 =>
        sda_o <= '0';
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_STOP_2;
        else
          wait_timer_init_x <= i2c_speed srl 1;
          NEXT_STATE <= S_WAIT_STOP_3;
        end if;

      when S_WAIT_STOP_3 =>
        if (wait_timer_done = '0') then
          NEXT_STATE <= S_WAIT_STOP_3;
        else
          sequence_done_o_x <= '1';
          NEXT_STATE <= S_IDLE;
        end if;

    end case;
  end process PROC_START_STOP;



  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  SEQUENCE_DONE_OUT <= sequence_done_o;
  SDA_OUT           <= sda_o;
  SCL_OUT           <= scl_o;
  NREADY_OUT        <= '0';
  
end Behavioral;
