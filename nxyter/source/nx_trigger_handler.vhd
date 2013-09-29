library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_handler is
  port (
    CLK_IN                     : in  std_logic;
    RESET_IN                   : in  std_logic;

    NXYTER_OFFLINE_IN          : in  std_logic;
    
    --LVL1 trigger
    LVL1_TRG_DATA_VALID_IN     : in std_logic;  -- timing trigger valid, later
    LVL1_VALID_TIMING_TRG_IN   : in std_logic;  -- timing trigger synced
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic;  -- timing trigger raw
    LVL1_INVALID_TRG_IN        : in std_logic;  -- ???

    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);

    -- Internal FPGA Trigger
    INTERNAL_TRIGGER_IN        : in  std_logic;

    -- Trigger FeedBack
    TRIGGER_VALIDATE_BUSY_IN   : in  std_logic;
    LVL2_TRIGGER_BUSY_IN       : in  std_logic;
    
    -- OUT
    VALIDATE_TRIGGER_OUT       : out std_logic;
    TIMESTAMP_TRIGGER_OUT      : out std_logic;
    LVL2_TRIGGER_OUT           : out std_logic;
    EVENT_BUFFER_CLEAR_OUT     : out std_logic;
    FAST_CLEAR_OUT             : out std_logic;
    TRIGGER_BUSY_OUT           : out std_logic;

    -- Pulser
    TRIGGER_TESTPULSE_OUT      : out std_logic;
    
    -- Slave bus               
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic;
                               
    -- Debug Line              
    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_trigger_handler is

  -- Trigger Handler
  signal validate_trigger_o       : std_logic;
  signal timestamp_hold           : std_logic;
  signal lvl2_trigger_o           : std_logic;
  signal event_buffer_clear_o     : std_logic;
  signal fast_clear_o             : std_logic;
  signal trigger_busy_o           : std_logic;
  signal fee_trg_release_o        : std_logic;
  signal fee_trg_statusbits_o     : std_logic_vector(31 downto 0);
  signal trigger_testpulse_o      : std_logic;

  type STATES is (S_IDLE,
                  S_CTS_TRIGGER,
                  S_WAIT_TRG_DATA_VALID,
                  S_WAIT_LVL2_TRIGGER_DONE,
                  S_FEE_TRIGGER_RELEASE,
                  S_WAIT_FEE_TRIGGER_RELEASE_ACK,
                  S_INTERNAL_TRIGGER,
                  S_WAIT_TRIGGER_VALIDATE_ACK,
                  S_WAIT_TRIGGER_VALIDATE_DONE
                  );
  signal STATE : STATES;

  -- Timestamp Hold Handler
  type TS_STATES is (TS_IDLE,
                     TS_WAIT_TIMER_DONE
                     );
  signal TS_STATE : TS_STATES;

  signal timestamp_trigger_o         : std_logic;
  signal wait_timer_reset            : std_logic;
  signal wait_timer_init             : unsigned(7 downto 0);
  signal wait_timer_done             : std_logic;

  -- Rate Calculation
  signal accepted_trigger_rate_t     : unsigned(27 downto 0);
  signal rate_timer                  : unsigned(27 downto 0);
  
  -- TRBNet Slave Bus                
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;

  signal reg_timestamp_trigger_delay : unsigned(7 downto 0);
  signal reg_testpulse_enable        : std_logic;
  signal accepted_trigger_rate       : unsigned(27 downto 0);
  
begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= LVL1_VALID_TIMING_TRG_IN;
  DEBUG_OUT(2)            <= LVL1_TRG_DATA_VALID_IN;
  DEBUG_OUT(3)            <= INTERNAL_TRIGGER_IN;
  DEBUG_OUT(4)            <= TRIGGER_VALIDATE_BUSY_IN;
  DEBUG_OUT(5)            <= LVL2_TRIGGER_BUSY_IN;

  DEBUG_OUT(6)            <= validate_trigger_o;
  DEBUG_OUT(7)            <= timestamp_trigger_o;
  DEBUG_OUT(8)            <= lvl2_trigger_o;
  DEBUG_OUT(9)            <= event_buffer_clear_o;
  DEBUG_OUT(10)           <= fee_trg_release_o;
  DEBUG_OUT(11)           <= trigger_busy_o;
  DEBUG_OUT(12)           <= trigger_testpulse_o;
  DEBUG_OUT(13)           <= slv_unknown_addr_o;
  DEBUG_OUT(14)           <= slv_no_more_data_o;
  DEBUG_OUT(15)           <= slv_unknown_addr_o;
--  DEBUG_OUT(15 downto 13) <= (others => '0');

  -- Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => wait_timer_reset,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  wait_timer_reset   <= RESET_IN or fast_clear_o;
  
  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------

  PROC_TRIGGER_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        validate_trigger_o   <= '0';
        timestamp_hold       <= '0';
        lvl2_trigger_o       <= '0';
        fee_trg_release_o    <= '0';
        fee_trg_statusbits_o <= (others => '0');
        fast_clear_o         <= '0';
        event_buffer_clear_o <= '0';
        trigger_busy_o       <= '0';
        trigger_testpulse_o  <= '0';
        STATE                <= S_IDLE;
      else
        validate_trigger_o   <= '0';
        timestamp_hold       <= '0';
        lvl2_trigger_o       <= '0';
        fee_trg_release_o    <= '0';
        fee_trg_statusbits_o <= (others => '0');
        fast_clear_o         <= '0';
        event_buffer_clear_o <= '0';
        trigger_busy_o       <= '1';
        trigger_testpulse_o  <= '0';

        if (LVL1_INVALID_TRG_IN = '1') then
          fast_clear_o         <= '1';
          fee_trg_release_o    <= '1';
          STATE                <= S_IDLE;
        else
          case STATE is
            when  S_IDLE =>
              if (LVL1_VALID_NOTIMING_TRG_IN = '1') then
                STATE                <= S_WAIT_TRG_DATA_VALID;
                
              elsif (LVL1_VALID_TIMING_TRG_IN = '1') then
                if (NXYTER_OFFLINE_IN = '1') then
                  STATE              <= S_WAIT_TRG_DATA_VALID;
                else
                  STATE              <= S_CTS_TRIGGER;
                end if;
              elsif (INTERNAL_TRIGGER_IN = '1') then
                STATE                <= S_INTERNAL_TRIGGER;
              else
                trigger_busy_o       <= '0';
                STATE                <= S_IDLE;
              end if;     

              -- CTS Trigger Handler
            when S_CTS_TRIGGER =>
              event_buffer_clear_o   <= '1';
              validate_trigger_o     <= '1';
              timestamp_hold         <= '1';
              lvl2_trigger_o         <= '1';
              if (reg_testpulse_enable = '1') then
                trigger_testpulse_o  <= '1';
              end if;
              STATE                  <= S_WAIT_TRG_DATA_VALID;

            when S_WAIT_TRG_DATA_VALID =>
              if (LVL1_TRG_DATA_VALID_IN = '0') then
                STATE                <= S_WAIT_TRG_DATA_VALID;
              else
                STATE                <= S_WAIT_LVL2_TRIGGER_DONE;
              end if;

            when S_WAIT_LVL2_TRIGGER_DONE =>
              if (LVL2_TRIGGER_BUSY_IN = '1') then
                STATE                <= S_WAIT_LVL2_TRIGGER_DONE;
              else
                STATE                <= S_FEE_TRIGGER_RELEASE;
              end if;

            when S_FEE_TRIGGER_RELEASE =>
              fee_trg_release_o      <= '1';
              STATE                  <= S_WAIT_FEE_TRIGGER_RELEASE_ACK;
              
            when S_WAIT_FEE_TRIGGER_RELEASE_ACK =>
              if (LVL1_TRG_DATA_VALID_IN = '1') then
                STATE                <= S_WAIT_FEE_TRIGGER_RELEASE_ACK;
              else
                STATE                <= S_IDLE;
              end if;
              
              -- Internal Trigger Handler
            when S_INTERNAL_TRIGGER =>
              validate_trigger_o     <= '1';
              timestamp_hold         <= '1';
              event_buffer_clear_o   <= '1';
              STATE                  <= S_WAIT_TRIGGER_VALIDATE_ACK;

            when S_WAIT_TRIGGER_VALIDATE_ACK =>
              if (TRIGGER_VALIDATE_BUSY_IN = '0') then
                STATE                <= S_WAIT_TRIGGER_VALIDATE_ACK;
              else
                STATE                <= S_WAIT_TRIGGER_VALIDATE_DONE;
              end if;
              
            when S_WAIT_TRIGGER_VALIDATE_DONE =>
              if (TRIGGER_VALIDATE_BUSY_IN = '1') then
                STATE                <= S_WAIT_TRIGGER_VALIDATE_DONE;
              else
                STATE                <= S_IDLE;
              end if;
              
          end case;
        end if;
      end if;
    end if;
  end process PROC_TRIGGER_HANDLER;

  PROC_SEND_TIMSTAMP_TRIGGER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or NXYTER_OFFLINE_IN = '1') then
        wait_timer_init      <= (others => '0');
        timestamp_trigger_o  <= '0';
        TS_STATE             <= TS_IDLE;
      else
        wait_timer_init      <= (others => '0');
        timestamp_trigger_o  <= '0';

        case TS_STATE is

          when TS_IDLE =>
            if (timestamp_hold = '0') then
              TS_STATE            <= TS_IDLE;
            else
              wait_timer_init     <= reg_timestamp_trigger_delay;
              TS_STATE            <= TS_WAIT_TIMER_DONE;
            end if;

          when TS_WAIT_TIMER_DONE =>
            if (wait_timer_done = '0') then
              TS_STATE            <= TS_WAIT_TIMER_DONE;
            else
              timestamp_trigger_o <= '1';
              TS_STATE            <= TS_IDLE;
            end if;

        end case;
            
      end if;
    end if;
  end process PROC_SEND_TIMSTAMP_TRIGGER;

  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        accepted_trigger_rate_t     <= (others => '0');
        accepted_trigger_rate       <= (others => '0');
        rate_timer                  <= (others => '0');
      else
        if (rate_timer < x"5f5e100") then
          if (lvl2_trigger_o = '1') then
            accepted_trigger_rate_t <= accepted_trigger_rate_t + 1;
          end if;
          rate_timer                <= rate_timer + 1;
        else
          accepted_trigger_rate     <= accepted_trigger_rate_t;
          accepted_trigger_rate_t   <= (others => '0');
          rate_timer                <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_CAL_RATES;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o              <= (others => '0');
        slv_no_more_data_o          <= '0';
        slv_unknown_addr_o          <= '0';
        slv_ack_o                   <= '0';
        reg_timestamp_trigger_delay <= x"01";
        reg_testpulse_enable        <= '0';
      else
        slv_unknown_addr_o          <= '0';
        slv_no_more_data_o          <= '0';
        slv_data_out_o              <= (others => '0');
        slv_ack_o                   <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              if (unsigned(SLV_DATA_IN(7 downto 0)) > 0) then
                reg_timestamp_trigger_delay <=
                  unsigned(SLV_DATA_IN(7 downto 0));
              end if;
              slv_ack_o                   <= '1';

            when x"0001" =>
              reg_testpulse_enable        <= SLV_DATA_IN(0);
              slv_ack_o                   <= '1';
              
            when others =>
              slv_unknown_addr_o          <= '1';

          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(7 downto 0)   <=
                std_logic_vector(reg_timestamp_trigger_delay);
              slv_data_out_o(31 downto 8)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(0)            <= reg_testpulse_enable;
              slv_data_out_o(31 downto 1)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(accepted_trigger_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
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
  VALIDATE_TRIGGER_OUT      <= validate_trigger_o;
  TIMESTAMP_TRIGGER_OUT     <= timestamp_trigger_o;
  LVL2_TRIGGER_OUT          <= lvl2_trigger_o;
  EVENT_BUFFER_CLEAR_OUT    <= event_buffer_clear_o;
  FAST_CLEAR_OUT            <= fast_clear_o;
  TRIGGER_BUSY_OUT          <= trigger_busy_o;
  FEE_TRG_RELEASE_OUT       <= fee_trg_release_o;
  FEE_TRG_STATUSBITS_OUT    <= fee_trg_statusbits_o;

  TRIGGER_TESTPULSE_OUT     <= trigger_testpulse_o;

  -- Slave Bus              
  SLV_DATA_OUT              <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT      <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT      <= slv_unknown_addr_o;
  SLV_ACK_OUT               <= slv_ack_o;    

end Behavioral;
