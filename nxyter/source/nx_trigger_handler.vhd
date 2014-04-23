library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_handler is
  port (
    CLK_IN                     : in  std_logic;
    RESET_IN                   : in  std_logic;
    NX_MAIN_CLK_IN             : in  std_logic;
    NXYTER_OFFLINE_IN          : in  std_logic;
    
    --Input Triggers          
    TIMING_TRIGGER_IN          : in std_logic; -- The raw timing Trigger Signal 
    LVL1_TRG_DATA_VALID_IN     : in std_logic; -- Data Trigger is valid
    LVL1_VALID_TIMING_TRG_IN   : in std_logic; -- Timin Trigger is valid
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic; -- calib trigger w/o ref time
    LVL1_INVALID_TRG_IN        : in std_logic; 

    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    --Response from FEE        
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_FINISHED_OUT      : out std_logic;
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);

    FEE_DATA_0_IN              : in  std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_0_IN        : in  std_logic;
    FEE_DATA_1_IN              : in  std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_1_IN        : in  std_logic;
    
    -- Internal FPGA Trigger
    INTERNAL_TRIGGER_IN        : in  std_logic;

    -- Trigger FeedBack
    TRIGGER_VALIDATE_BUSY_IN   : in  std_logic;
    TRIGGER_BUSY_0_IN          : in  std_logic;
    TRIGGER_BUSY_1_IN          : in  std_logic;
    
    -- OUT
    VALID_TRIGGER_OUT          : out std_logic;
    TIMESTAMP_TRIGGER_OUT      : out std_logic;
    TRIGGER_TIMING_OUT         : out std_logic;
    TRIGGER_STATUS_OUT         : out std_logic;
    FAST_CLEAR_OUT             : out std_logic;
    TRIGGER_BUSY_OUT           : out std_logic;

    -- Pulser
    NX_TESTPULSE_OUT           : out std_logic;
    
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
  attribute HGROUP : string;
  attribute HGROUP of Behavioral : architecture is "NX_TRIGGER_HANDLER";

  -- Timing Trigger Handler
  constant NUM_FF                   : integer := 10;
  signal timing_trigger_ff_p        : std_logic_vector(1 downto 0);
  signal timing_trigger_ff          : std_logic_vector(NUM_FF - 1 downto 0);
  signal timing_trigger_l           : std_logic;
  signal timing_trigger             : std_logic;
  signal timing_trigger_set         : std_logic;
  signal timestamp_trigger_o        : std_logic;

  signal invalid_timing_trigger_n   : std_logic;
  signal invalid_timing_trigger     : std_logic;
  signal invalid_timing_trigger_ctr : unsigned(15 downto 0);

  signal trigger_busy               : std_logic;
  signal fast_clear                 : std_logic;
  
  type TS_STATES is (TS_IDLE,
                     TS_WAIT_VALID_TIMING_TRIGGER,
                     TS_INVALID_TRIGGER,
                     TS_WAIT_TRIGGER_END
                     );
  signal TS_STATE : TS_STATES;

  signal ts_wait_timer_reset        : std_logic;
  signal ts_wait_timer_start        : std_logic;
  signal ts_wait_timer_done         : std_logic;
  
  -- Trigger Handler                
  signal valid_trigger_o            : std_logic;
  signal timing_trigger_o           : std_logic;
  signal status_trigger_o           : std_logic;
  signal fast_clear_o               : std_logic;
  signal trigger_busy_o             : std_logic;
  signal fee_data_o                 : std_logic_vector(31 downto 0);
  signal fee_data_write_o           : std_logic;
  signal fee_data_finished_o        : std_logic;
  signal fee_trg_release_o          : std_logic;
  signal fee_trg_statusbits_o       : std_logic_vector(31 downto 0);
  signal send_testpulse             : std_logic;
  signal testpulse_enable           : std_logic;
  
  type STATES is (S_IDLE,
                  S_CTS_TRIGGER,
                  S_WAIT_TRG_DATA_VALID,
                  S_WAIT_TIMING_TRIGGER_DONE,
                  S_FEE_TRIGGER_RELEASE,
                  S_WAIT_FEE_TRIGGER_RELEASE_ACK,
                  S_INTERNAL_TRIGGER,
                  S_WAIT_TRIGGER_VALIDATE_ACK,
                  S_WAIT_TRIGGER_VALIDATE_DONE
                  );
  signal STATE : STATES;

  type TRIGGER_TYPES is (T_UNDEF,
                         T_IGNORE,
                         T_INTERNAL,
                         T_TIMING,
                         T_SETUP
                         );
  signal TRIGGER_TYPE : TRIGGER_TYPES;
  
  
  -- Testpulse Handler
  type T_STATES is (T_IDLE,
                    T_WAIT_TESTPULE_DELAY,
                    T_SET_TESTPULSE,
                    T_WAIT_TESTPULE_END
                    );
  
  signal T_STATE : T_STATES;

  signal testpulse_delay             : unsigned(11 downto 0);
  signal testpulse_length            : unsigned(11 downto 0);
  signal testpulse_o                 : std_logic;
  signal wait_timer_reset            : std_logic;
  signal wait_timer_start            : std_logic;
  signal wait_timer_done             : std_logic;
  signal wait_timer_end              : unsigned(11 downto 0);
  
  -- Rate Calculation
  signal accepted_trigger_rate_t     : unsigned(27 downto 0);
  signal testpulse_o_clk100          : std_logic;
  signal testpulse_rate_t            : unsigned(27 downto 0);
  signal rate_timer                  : unsigned(27 downto 0);
  
  -- TRBNet Slave Bus                
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;

  signal reg_testpulse_delay         : unsigned(11 downto 0);
  signal reg_testpulse_length        : unsigned(11 downto 0);
  signal reg_testpulse_enable        : std_logic;
  signal accepted_trigger_rate       : unsigned(27 downto 0);
  signal testpulse_rate              : unsigned(27 downto 0);
  signal invalid_t_trigger_ctr_clear : std_logic;
   
  -- Reset
  signal RESET_NX_MAIN_CLK_IN        : std_logic;
  
begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= TIMING_TRIGGER_IN;
  DEBUG_OUT(2)            <= invalid_timing_trigger;
  DEBUG_OUT(3)            <= LVL1_VALID_TIMING_TRG_IN;
  DEBUG_OUT(4)            <= LVL1_TRG_DATA_VALID_IN;
  DEBUG_OUT(5)            <= fee_data_write_o;
  DEBUG_OUT(6)            <= TRIGGER_VALIDATE_BUSY_IN;
  DEBUG_OUT(7)            <= TRIGGER_BUSY_0_IN;
  DEBUG_OUT(8)            <= valid_trigger_o;
  DEBUG_OUT(9)            <= timing_trigger_o;
  DEBUG_OUT(10)           <= fee_data_finished_o;
  DEBUG_OUT(11)           <= fee_trg_release_o;
  DEBUG_OUT(12)           <= trigger_busy_o;
  DEBUG_OUT(13)           <= timestamp_trigger_o;
  DEBUG_OUT(14)           <= send_testpulse;
  DEBUG_OUT(15)           <= testpulse_o;

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  signal_async_trans_RESET_IN: signal_async_trans
    port map (
      CLK_IN      => NX_MAIN_CLK_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_NX_MAIN_CLK_IN
    );

  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------
  
  PROC_TIMING_TRIGGER_HANDLER: process(NX_MAIN_CLK_IN)
    constant pattern : std_logic_vector(NUM_FF - 1 downto 0)
    := (others => '1');
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      timing_trigger_ff_p(1)                   <= TIMING_TRIGGER_IN;
      if (RESET_NX_MAIN_CLK_IN = '1') then 
        timing_trigger_ff_p(0)                 <= '0';
        timing_trigger_ff(NUM_FF - 1 downto 0) <= (others => '0');
        timing_trigger_l                       <= '0';
      else
        timing_trigger_ff_p(0)                 <= timing_trigger_ff_p(1);
        timing_trigger_ff(NUM_FF - 1)          <= timing_trigger_ff_p(0);
        
        for I in NUM_FF - 2 downto 0 loop
          timing_trigger_ff(I)                 <= timing_trigger_ff(I + 1);    
        end loop;
        
        if (timing_trigger_ff = pattern) then
          timing_trigger_l                     <= '1';
        else
          timing_trigger_l                     <= '0';
        end if;
      end if;   
    end if;
  end process PROC_TIMING_TRIGGER_HANDLER;

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => NX_MAIN_CLK_IN,
      RESET_IN  => RESET_NX_MAIN_CLK_IN,
      LEVEL_IN  => timing_trigger_l,
      PULSE_OUT => timing_trigger
      );
    
  -- Timer
  timer_static_2: timer_static
    generic map (
      CTR_WIDTH => 8,
      CTR_END   => 32   -- 128ns
      )
    port map (
      CLK_IN         => NX_MAIN_CLK_IN,
      RESET_IN       => ts_wait_timer_reset,
      TIMER_START_IN => ts_wait_timer_start,
      TIMER_DONE_OUT => ts_wait_timer_done
      );

  PROC_TIMING_TRIGGER_HANDLER: process(NX_MAIN_CLK_IN)
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      testpulse_enable             <= reg_testpulse_enable;
      
      if (RESET_NX_MAIN_CLK_IN = '1') then
        invalid_timing_trigger_n   <= '1';
        ts_wait_timer_start        <= '0';
        ts_wait_timer_reset        <= '1';
        send_testpulse             <= '0';
        timestamp_trigger_o        <= '0';
        TS_STATE                   <= TS_IDLE;     
      else
        invalid_timing_trigger_n   <= '0';
        ts_wait_timer_start        <= '0';
        ts_wait_timer_reset        <= '0';
        send_testpulse             <= '0';
        timestamp_trigger_o        <= '0';

        if (fast_clear = '1') then
          ts_wait_timer_reset      <= '1';
          TS_STATE                 <= TS_IDLE;
        else
          case TS_STATE is
            when  TS_IDLE =>
              -- Wait for Timing Trigger synced to NX_MAIN_CLK_DOMAIN
              if (timing_trigger = '1') then
                if (trigger_busy = '1') then
                  -- If busy is set --> Error
                  TS_STATE                <= TS_INVALID_TRIGGER;
                else
                  if (reg_testpulse_enable = '1') then
                    send_testpulse        <= '1';
                  end if;
                  timestamp_trigger_o     <= '1';
                  ts_wait_timer_start     <= '1';
                  TS_STATE                <= TS_WAIT_VALID_TIMING_TRIGGER;
                end if;
              else
                TS_STATE                  <= TS_IDLE;
              end if;

            when TS_WAIT_VALID_TIMING_TRIGGER =>
              -- Wait and test if CLK_IN Trigger Handler does accepted Trigger 
              if (trigger_busy = '1') then
                -- Trigger has been accepted, stop timer and wait trigger end
                ts_wait_timer_reset       <= '1';
                TS_STATE                  <= TS_WAIT_TRIGGER_END;
              else
                if (ts_wait_timer_done = '1') then
                  -- Timeout after 128ns --> Invalid Trigger Error
                  TS_STATE                <= TS_INVALID_TRIGGER;
                else
                  TS_STATE                <= TS_WAIT_VALID_TIMING_TRIGGER;
                end if;
              end if;

            when TS_INVALID_TRIGGER =>
              invalid_timing_trigger_n    <= '1';
              TS_STATE                    <= TS_IDLE;
              
            when TS_WAIT_TRIGGER_END =>
              if (trigger_busy = '0') then
                TS_STATE                  <= TS_IDLE;
              else
                TS_STATE                  <= TS_WAIT_TRIGGER_END;
              end if;
              
          end case;
        end if;
      end if;
    end if;
  end process PROC_TIMING_TRIGGER_HANDLER;
  
  PROC_TIMING_TRIGGER_COUNTER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        invalid_timing_trigger_ctr    <= (others => '0');
      else
        if (invalid_t_trigger_ctr_clear = '1') then
          invalid_timing_trigger_ctr  <= (others => '0');
        elsif (invalid_timing_trigger = '1') then
          invalid_timing_trigger_ctr  <= invalid_timing_trigger_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_TIMING_TRIGGER_COUNTER;
  
  signal_async_trans_TRIGGER_BUSY: signal_async_trans
    port map (
      CLK_IN      => NX_MAIN_CLK_IN,
      SIGNAL_A_IN => trigger_busy_o,
      SIGNAL_OUT  => trigger_busy
      );

  signal_async_to_pulse_FAST_CLEAR: signal_async_to_pulse
    generic map (
      NUM_FF => 2
      )
    port map (
      CLK_IN     => NX_MAIN_CLK_IN,
      RESET_IN   => RESET_NX_MAIN_CLK_IN,
      PULSE_A_IN => fast_clear_o,
      PULSE_OUT  => fast_clear
      );
  
  pulse_dtrans_INVALID_TIMING_TRIGGER: pulse_dtrans
    generic map (
      CLK_RATIO => 4
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_NX_MAIN_CLK_IN,
      PULSE_A_IN  => invalid_timing_trigger_n,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => invalid_timing_trigger
      );
  
  -----------------------------------------------------------------------------
  
  PROC_TRIGGER_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        valid_trigger_o      <= '0';
        timing_trigger_o     <= '0';
        status_trigger_o     <= '0';
        fee_data_finished_o  <= '0';
        fee_trg_release_o    <= '0';
        fee_trg_statusbits_o <= (others => '0');
        fast_clear_o         <= '0';
        trigger_busy_o       <= '0';
        TRIGGER_TYPE         <= T_UNDEF;
        STATE                <= S_IDLE;
      else
        valid_trigger_o      <= '0';
        timing_trigger_o     <= '0';
        status_trigger_o     <= '0';
        fee_data_finished_o  <= '0';
        fee_trg_release_o    <= '0';
        fee_trg_statusbits_o <= (others => '0');
        fast_clear_o         <= '0';
        trigger_busy_o       <= '1';
        
        if (LVL1_INVALID_TRG_IN = '1') then
          -- There was no valid Timing Trigger at CTS, do a fast clear
          fast_clear_o               <= '1';
          fee_trg_release_o          <= '1';
          STATE                      <= S_IDLE;
        else
          case STATE is
            when  S_IDLE =>
              if (LVL1_VALID_NOTIMING_TRG_IN = '1') then
                -- Calibration Trigger
                if (LVL1_TRG_TYPE_IN = x"e") then
                  -- Status Trigger
                  TRIGGER_TYPE       <= T_SETUP;
                  status_trigger_o   <= '1';
                else
                  -- Something else, Ignore
                  TRIGGER_TYPE       <= T_IGNORE;
                end if;
                STATE                <= S_WAIT_TRG_DATA_VALID;
                
              elsif (LVL1_VALID_TIMING_TRG_IN = '1') then
                if (NXYTER_OFFLINE_IN = '0') then
                  -- Normal Trigger
                  TRIGGER_TYPE       <= T_TIMING;
                  STATE              <= S_CTS_TRIGGER;
                else
                  -- Ignore Trigger for nxyter is offline
                 TRIGGER_TYPE        <= T_IGNORE;
                 STATE               <= S_WAIT_TRG_DATA_VALID;
                end if;
              elsif (INTERNAL_TRIGGER_IN = '1') then
                -- Internal Trigger, not defined yet
                TRIGGER_TYPE         <= T_INTERNAL;
                STATE                <= S_INTERNAL_TRIGGER;
              else
                trigger_busy_o       <= '0';
                TRIGGER_TYPE         <= T_UNDEF;
                STATE                <= S_IDLE;
              end if;     

            when S_CTS_TRIGGER =>
              valid_trigger_o        <= '1';
              timing_trigger_o       <= '1';
              STATE                  <= S_WAIT_TRG_DATA_VALID;
              
            when S_WAIT_TRG_DATA_VALID =>
              if (LVL1_TRG_DATA_VALID_IN = '0') then
                STATE                <= S_WAIT_TRG_DATA_VALID;
              else
                STATE                <= S_WAIT_TIMING_TRIGGER_DONE;
              end if;

            when S_WAIT_TIMING_TRIGGER_DONE =>
              if ((TRIGGER_TYPE = T_TIMING and TRIGGER_BUSY_0_IN = '1') or
                  (TRIGGER_TYPE = T_SETUP  and TRIGGER_BUSY_1_IN = '1')
                  ) then
                STATE                <= S_WAIT_TIMING_TRIGGER_DONE;
              else
                fee_data_finished_o  <= '1';
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
              valid_trigger_o        <= '1';
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

  PROC_EVENT_DATA_MULTIPLEXER: process(TRIGGER_TYPE)
  begin
    case TRIGGER_TYPE is
      when  T_UNDEF | T_IGNORE | T_INTERNAL =>
        fee_data_o                   <= (others => '0');
        fee_data_write_o             <= '0';
        
      when T_TIMING =>
        fee_data_o                   <= FEE_DATA_0_IN;
        fee_data_write_o             <= FEE_DATA_WRITE_0_IN;
        
      when T_SETUP =>
        fee_data_o                   <= FEE_DATA_1_IN;
        fee_data_write_o             <= FEE_DATA_WRITE_1_IN;

    end case;
  end process PROC_EVENT_DATA_MULTIPLEXER;

  timer_1: timer
    generic map (
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => NX_MAIN_CLK_IN,
      RESET_IN       => wait_timer_reset,
      TIMER_START_IN => wait_timer_start,
      TIMER_END_IN   => wait_timer_end,
      TIMER_DONE_OUT => wait_timer_done
      );
  
  PROC_TESTPULSE_HANDLER: process (NX_MAIN_CLK_IN)
  begin 
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      testpulse_delay        <= reg_testpulse_delay;
      testpulse_length       <= reg_testpulse_length;
      
      if (RESET_NX_MAIN_CLK_IN = '1') then
        wait_timer_start     <= '0';
        wait_timer_reset     <= '1';
        testpulse_o          <= '0';
        T_STATE              <= T_IDLE;
      else
        wait_timer_start     <= '0';
        wait_timer_reset     <= '0';
        testpulse_o          <= '0';
        
        if (fast_clear = '1') then
          wait_timer_reset   <= '1';
          T_STATE            <= T_IDLE;
        else
          case T_STATE is

            when T_IDLE => 
              if (send_testpulse = '1') then
                if (reg_testpulse_delay > 0) then
                  wait_timer_end    <= testpulse_delay;
                  wait_timer_start  <= '1';
                  T_STATE           <= T_WAIT_TESTPULE_DELAY;
                else
                  T_STATE           <= T_SET_TESTPULSE;
                end if;
              else
                T_STATE             <= T_IDLE;
              end if;

            when T_WAIT_TESTPULE_DELAY =>
              if (wait_timer_done = '0') then
                T_STATE             <= T_WAIT_TESTPULE_DELAY;
              else
                T_STATE             <= T_SET_TESTPULSE;
              end if;

            when T_SET_TESTPULSE =>
              testpulse_o           <= '1';
              wait_timer_end        <= testpulse_length;
              wait_timer_start      <= '1';
              T_STATE               <= T_WAIT_TESTPULE_END;

            when T_WAIT_TESTPULE_END =>
              if (wait_timer_done = '0') then
                testpulse_o         <= '1';
                T_STATE             <= T_WAIT_TESTPULE_END;
              else
                T_STATE             <= T_IDLE;
              end if;  
              
          end case;           
        end if;
      end if;
    end if;
  end process PROC_TESTPULSE_HANDLER; 

  pulse_dtrans_TESTPULSE_RATE: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_NX_MAIN_CLK_IN,
      PULSE_A_IN  => testpulse_o,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => testpulse_o_clk100
      );
  
  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        accepted_trigger_rate_t     <= (others => '0');
        accepted_trigger_rate       <= (others => '0');
        testpulse_rate_t            <= (others => '0');
        testpulse_rate              <= (others => '0');
        rate_timer                  <= (others => '0');
      else
        if (rate_timer < x"5f5e100") then
          if (timing_trigger_o = '1') then
            accepted_trigger_rate_t            <= accepted_trigger_rate_t + 1;
          end if;

          if (testpulse_o_clk100 = '1') then
            testpulse_rate_t                   <= testpulse_rate_t + 1; 
          end if;
          rate_timer                           <= rate_timer + 1;
        else
          rate_timer                           <= (others => '0');
          accepted_trigger_rate                <= accepted_trigger_rate_t;
          testpulse_rate                       <= testpulse_rate_t;
          
          accepted_trigger_rate_t              <= (others => '0');
          testpulse_rate_t                     <= (others => '0');
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
        slv_data_out_o                 <= (others => '0');
        slv_no_more_data_o             <= '0';
        slv_unknown_addr_o             <= '0';
        slv_ack_o                      <= '0';
        reg_testpulse_delay            <= (others => '0');
        reg_testpulse_length           <= x"064";
        reg_testpulse_enable           <= '0';
        invalid_t_trigger_ctr_clear    <= '1';
      else                             
        slv_unknown_addr_o             <= '0';
        slv_no_more_data_o             <= '0';
        slv_data_out_o                 <= (others => '0');
        slv_ack_o                      <= '0';
        invalid_t_trigger_ctr_clear    <= '0';

        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              reg_testpulse_enable         <= SLV_DATA_IN(0);
              slv_ack_o                    <= '1';

            when x"0001" =>
              reg_testpulse_delay          <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                    <= '1';                

            when x"0002" =>
              reg_testpulse_length         <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                    <= '1';
              
            when x"0003" =>
              invalid_t_trigger_ctr_clear  <= '1';
              slv_ack_o                    <= '1'; 
              
            when others =>
              slv_unknown_addr_o           <= '1';

          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(0)            <= reg_testpulse_enable;
              slv_data_out_o(31 downto 1)  <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(reg_testpulse_delay);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(reg_testpulse_length);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';
            
            when x"0003" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(invalid_timing_trigger_ctr);
              slv_data_out_o(31 downto 26) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0004" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(accepted_trigger_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0005" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(testpulse_rate);
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
  VALID_TRIGGER_OUT         <= valid_trigger_o;
  TIMESTAMP_TRIGGER_OUT     <= timestamp_trigger_o;
  TRIGGER_TIMING_OUT        <= timing_trigger_o;
  TRIGGER_STATUS_OUT        <= status_trigger_o;
  FAST_CLEAR_OUT            <= fast_clear_o;
  TRIGGER_BUSY_OUT          <= trigger_busy_o;

  FEE_DATA_OUT              <= fee_data_o;
  FEE_DATA_WRITE_OUT        <= fee_data_write_o; 
  FEE_DATA_FINISHED_OUT     <= fee_data_finished_o;
  FEE_TRG_RELEASE_OUT       <= fee_trg_release_o;
  FEE_TRG_STATUSBITS_OUT    <= fee_trg_statusbits_o;

  NX_TESTPULSE_OUT          <= testpulse_o;

  -- Slave Bus              
  SLV_DATA_OUT              <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT      <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT      <= slv_unknown_addr_o;
  SLV_ACK_OUT               <= slv_ack_o;    

end Behavioral;
