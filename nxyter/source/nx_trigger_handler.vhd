library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_handler is
  port (
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;

    -- IN
    TRIGGER_IN           : in    std_logic;
    TRIGGER_RELEASE_IN   : in    std_logic;

    -- OUT
    TRIGGER_OUT          : out   std_logic;
    TIMESTAMP_HOLD_OUT   : out   std_logic;
    TRIGGER_BUSY_OUT     : out   std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in    std_logic;
    SLV_WRITE_IN         : in    std_logic;
    SLV_DATA_OUT         : out   std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in    std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in    std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out   std_logic;
    SLV_NO_MORE_DATA_OUT : out   std_logic;
    SLV_UNKNOWN_ADDR_OUT : out   std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_trigger_handler is

  signal start_cycle         : std_logic;
  signal wait_timer_init     : unsigned(7 downto 0);
  signal wait_timer_init_x   : unsigned(7 downto 0);
  signal wait_timer_done     : std_logic;
  signal trigger_o           : std_logic;
  signal trigger_o_x         : std_logic;
  signal timestamp_hold_o    : std_logic;
  signal timestamp_hold_o_x  : std_logic;
  signal trigger_busy_o      : std_logic;
  signal trigger_busy_o_x    : std_logic;
  
  type STATES is (S_IDLE,
                  S_START,
                  S_WAIT_TRIGGER_RELEASE
                  );
  signal STATE, NEXT_STATE : STATES;
  
  -- TRBNet Slave Bus            
  signal slv_data_out_o           : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o       : std_logic;
  signal slv_unknown_addr_o       : std_logic;
  signal slv_ack_o                : std_logic;

  signal reg_timestamp_hold_delay : unsigned(7 downto 0);
  
begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= TRIGGER_IN;
  DEBUG_OUT(2)            <= trigger_o;
  DEBUG_OUT(3)            <= timestamp_hold_o;
  DEBUG_OUT(4)            <= wait_timer_done;
  DEBUG_OUT(15 downto 5)  <= (others => '0');

  -- Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------

  PROC_TRIGGER_HANDLER_TRANSFER: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        trigger_o         <= '0';
        timestamp_hold_o  <= '0';
        trigger_busy_o    <= '1';
        wait_timer_init   <= (others => '0');
        STATE             <= S_IDLE;
      else
        trigger_o         <= trigger_o_x;
        timestamp_hold_o  <= timestamp_hold_o_x;
        trigger_busy_o    <= trigger_busy_o_x;
        wait_timer_init   <= wait_timer_init_x;
        STATE             <= NEXT_STATE;
      end if;
    end if;
  end process PROC_TRIGGER_HANDLER_TRANSFER;

  PROC_TRIGGER_HANDLER: process(STATE,
                                TRIGGER_IN,
                                TRIGGER_RELEASE_IN
                                )
  begin
    trigger_o_x         <= '0';
    timestamp_hold_o_x  <= '0';
    trigger_busy_o_x    <= '1';
    wait_timer_init_x   <= (others => '0');
    
    case STATE is
      when  S_IDLE =>
        if (TRIGGER_IN = '1') then
          trigger_o_x         <= '1';
          timestamp_hold_o_x  <= '1';
          NEXT_STATE          <= S_START;
        else
          trigger_busy_o_x    <= '0';
          NEXT_STATE          <= S_IDLE;
        end if;

      when S_START =>
        NEXT_STATE            <= S_WAIT_TRIGGER_RELEASE;
        
      when S_WAIT_TRIGGER_RELEASE =>
        if (TRIGGER_RELEASE_IN = '0') then
          NEXT_STATE          <= S_WAIT_TRIGGER_RELEASE;
        else
          NEXT_STATE          <= S_IDLE;
        end if;
        
    end case;
  end process PROC_TRIGGER_HANDLER;

  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o           <= (others => '0');
        slv_no_more_data_o       <= '0';
        slv_unknown_addr_o       <= '0';
        start_cycle              <= '0';
        slv_ack_o                <= '0';
        reg_timestamp_hold_delay <= x"01";
      else
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        slv_data_out_o     <= (others => '0');
        slv_ack_o          <= '0';
        start_cycle        <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              reg_timestamp_hold_delay <= SLV_DATA_IN(7 downto 0);
              slv_ack_o                <= '1';
              
            when others =>
              slv_unknown_addr_o       <= '1';

          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(7 downto 0)   <=
                std_logic_vector(reg_timestamp_hold_delay);
              slv_data_out_o(31 downto 8) <= (others => '0');
              slv_ack_o                    <= '1';

            when others =>
              slv_unknown_addr_o           <= '1';

          end case;

        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  
  -- Trigger Output
  TRIGGER_OUT          <= trigger_o;
  TIMESTAMP_HOLD_OUT   <= timestamp_hold_o;
  TRIGGER_BUSY_OUT     <= trigger_busy_o;
  
  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;    

end Behavioral;
