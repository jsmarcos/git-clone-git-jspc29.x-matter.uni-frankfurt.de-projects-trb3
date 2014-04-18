library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_generator is
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_MAIN_CLK_IN       : in  std_logic;

    TRIGGER_BUSY_IN      : in  std_logic;
    
    TRIGGER_IN           : in  std_logic;  -- must be in NX_MAIN_CLK_DOMAIN
    TRIGGER_OUT          : out std_logic;
    TS_RESET_OUT         : out std_logic;
    TESTPULSE_OUT        : out std_logic;
    
    TIMESTAMP_IN         : in  std_logic_vector(31 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    DATA_CLK_IN          : in  std_logic;
    SELF_TRIGGER_OUT     : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_trigger_generator is
  signal start_cycle         : std_logic;
  signal trigger_cycle_ctr   : unsigned(7 downto 0);
  signal wait_timer_start    : std_logic;
  signal wait_timer_init     : unsigned(11 downto 0);
  signal wait_timer_done     : std_logic;
  signal trigger_o           : std_logic;
  signal ts_reset_o          : std_logic;
  signal testpulse_o         : std_logic;
  signal testpulse_o_b       : std_logic;
  signal testpulse_p         : std_logic;
  signal extern_trigger      : std_logic;
  
  type STATES is (S_IDLE,
                  S_WAIT_TESTPULSE_END
                  );
  signal STATE : STATES;

  -- Rate Calculation
  signal testpulse               : std_logic;
  signal testpulse_rate_t        : unsigned(27 downto 0);
  signal rate_timer              : unsigned(27 downto 0);

  -- Self Trigger
  
  type ST_STATES is (ST_IDLE,
                     ST_BUSY
                     );
  signal ST_STATE : ST_STATES;

  signal self_trigger_ctr        : unsigned(4 downto 0);
  signal self_trigger_busy       : std_logic;
  signal self_trigger            : std_logic;
  signal self_trigger_o          : std_logic;
  
  -- TRBNet Slave Bus            
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;

  signal reg_trigger_period      : unsigned(15 downto 0);
  signal reg_testpulse_length    : unsigned(11 downto 0);
  signal reg_trigger_num_cycles  : unsigned(7 downto 0);      
  signal reg_ts_reset_on         : std_logic;
  signal testpulse_rate          : unsigned(27 downto 0);

  -- Reset
  signal RESET_NX_MAIN_CLK_IN : std_logic;
  
begin
  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= DATA_CLK_IN;
  DEBUG_OUT(2)            <= start_cycle;
  DEBUG_OUT(3)            <= ts_reset_o;
  DEBUG_OUT(4)            <= testpulse_o_b;
  DEBUG_OUT(5)            <= testpulse;
  DEBUG_OUT(6)            <= self_trigger;
  DEBUG_OUT(7)            <= self_trigger_o;
  DEBUG_OUT(8)            <= self_trigger_busy;
  DEBUG_OUT(9)            <= TRIGGER_BUSY_IN;
  DEBUG_OUT(15 downto 10) <= (others => '0');
  
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
  
  -- Timer
  timer_1: timer
    generic map (
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => NX_MAIN_CLK_IN,
      RESET_IN       => RESET_NX_MAIN_CLK_IN,
      TIMER_START_IN => wait_timer_start,
      TIMER_END_IN   => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );
  wait_timer_init   <= reg_testpulse_length - 1;

  -----------------------------------------------------------------------------
  -- Generate Trigger
  -----------------------------------------------------------------------------
  
  PROC_TESTPULSE_OUT: process(NX_MAIN_CLK_IN)
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      if (RESET_NX_MAIN_CLK_IN = '1') then
        trigger_o         <= '0';
        testpulse_o       <= '0';
        testpulse_p       <= '0';
        ts_reset_o        <= '0';
        wait_timer_start  <= '0';
        trigger_cycle_ctr <= (others => '0');
        extern_trigger    <= '0';
        STATE             <= S_IDLE;
      else
        trigger_o         <= '0';
        testpulse_o       <= '0';
        testpulse_p       <= '0';
        ts_reset_o        <= '0';
        wait_timer_start  <= '0';

        case STATE is
          when  S_IDLE =>
            if (TRIGGER_IN = '1') then
              extern_trigger                  <= '1';
              testpulse_o                     <= '1';
              testpulse_p                     <= '1';
              if (reg_testpulse_length > 0) then
                wait_timer_start              <= '1';
                STATE                         <= S_WAIT_TESTPULSE_END;
              else
                STATE                         <= S_IDLE;
              end if;
            else
              extern_trigger                  <= '0';
              STATE                           <= S_IDLE;
            end if;
 
          when S_WAIT_TESTPULSE_END =>
            if (WAIT_TIMER_DONE = '0') then
              testpulse_o                     <= '1';
              STATE                           <= S_WAIT_TESTPULSE_END;
            else
              STATE                           <= S_IDLE;
            end if;
            
        end case;
      end if;
    end if;
  end process PROC_TESTPULSE_OUT;
  
  -- Transfer testpulse_p to CLK_IN Domain
  pulse_dtrans_TESTPULSE: pulse_dtrans
    generic map (
      CLK_RATIO => 6
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_NX_MAIN_CLK_IN,
      PULSE_A_IN  => testpulse_p,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => testpulse
      );

  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        testpulse_rate_t          <= (others => '0');
        testpulse_rate            <= (others => '0');
        rate_timer                <= (others => '0');
      else
        if (rate_timer < x"5f5e100") then
          if (testpulse = '1') then
            testpulse_rate_t            <= testpulse_rate_t + 1;
          end if;
          rate_timer                    <= rate_timer + 1;
        else
          testpulse_rate                <= testpulse_rate_t;

          testpulse_rate_t(27 downto 1) <= (others => '0');
          testpulse_rate_t(0)           <= testpulse;

          rate_timer                    <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_CAL_RATES;

  -----------------------------------------------------------------------------
  -- Self Trigger
  -----------------------------------------------------------------------------

  PROC_SELF_TRIGGER: process(CLK_IN)
    variable frame_bits : std_logic_vector(3 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        self_trigger_ctr   <= (others => '0');
        self_trigger_busy  <= '0';
        self_trigger       <= '0';
      else
        frame_bits := TIMESTAMP_IN(31) &
                      TIMESTAMP_IN(23) &
                      TIMESTAMP_IN(15) &
                      TIMESTAMP_IN(7);
        self_trigger            <= '0';
        self_trigger_busy       <= '0';

        case ST_STATE is
          when ST_IDLE =>
            if (TRIGGER_BUSY_IN = '0' and
                DATA_CLK_IN     = '1' and
                frame_bits      = "1000") then
              self_trigger_ctr  <= "10100";  -- 20
              self_trigger      <= '1';
              ST_STATE          <= ST_BUSY;
            else
              self_trigger_ctr  <= (others => '0');
              ST_STATE          <= ST_IDLE;
            end if;
            
          when ST_BUSY =>
            if (self_trigger_ctr > 0) then
              self_trigger_ctr  <= self_trigger_ctr  - 1;
              self_trigger_busy <= '1';
              ST_STATE          <= ST_BUSY;
            else
              ST_STATE          <= ST_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_SELF_TRIGGER;

  pulse_to_level_SELF_TRIGGER: pulse_to_level
    generic map (
      NUM_CYCLES => 8
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => self_trigger,
      LEVEL_OUT => self_trigger_o
      );
    
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        reg_trigger_period     <= x"00ff";
        reg_trigger_num_cycles <= x"01";
        reg_testpulse_length   <= x"064";
        reg_ts_reset_on        <= '0';
        slv_data_out_o         <= (others => '0');
        slv_no_more_data_o     <= '0';
        slv_unknown_addr_o     <= '0';
        start_cycle            <= '0';
        slv_ack_o              <= '0';
      else
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        slv_data_out_o     <= (others => '0');
        start_cycle        <= '0';


        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              if (unsigned(SLV_DATA_IN(11 downto 0)) > 0) then
                reg_testpulse_length       <=
                  unsigned(SLV_DATA_IN(11 downto 0));
              end if;
              slv_ack_o                    <= '1';

            when others =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(11 downto 0)  <=
                std_logic_vector(reg_testpulse_length);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(27 downto 0)  <= std_logic_vector(testpulse_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
              slv_ack_o                    <= '1';

            when others =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;

        else
          slv_ack_o                        <= '0';
        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- Buffer for timing 
  testpulse_o_b        <= testpulse_o when rising_edge(NX_MAIN_CLK_IN);
  
  -- Trigger Output
  TRIGGER_OUT          <= trigger_o;
  TS_RESET_OUT         <= ts_reset_o;
  TESTPULSE_OUT        <= testpulse_o_b;
  SELF_TRIGGER_OUT     <= self_trigger_o;
  
  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;    

end Behavioral;
