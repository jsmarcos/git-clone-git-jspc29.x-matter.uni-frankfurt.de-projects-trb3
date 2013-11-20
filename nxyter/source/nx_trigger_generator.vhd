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

    TRIGGER_IN           : in  std_logic;  -- must be in NX_MAIN_CLK_DOMAIN
    TRIGGER_OUT          : out std_logic;
    TS_RESET_OUT         : out std_logic;
    TESTPULSE_OUT        : out std_logic;
    TEST_IN              : in  std_logic_vector(31 downto 0);

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

  signal trigger             : std_logic;
  signal start_cycle         : std_logic;
  signal trigger_cycle_ctr   : unsigned(7 downto 0);
  signal wait_timer_init     : unsigned(15 downto 0);
  signal wait_timer_done     : std_logic;
  signal trigger_o           : std_logic;
  signal ts_reset_o          : std_logic;
  signal testpulse_p         : std_logic;
  signal testpulse_o         : std_logic;
  signal extern_trigger      : std_logic;
  
  type STATES is (S_IDLE,
                  S_WAIT_TESTPULSE_END
                  );
  signal STATE : STATES;

  -- Rate Calculation
  signal testpulse               : std_logic;
  signal testpulse_rate_t        : unsigned(27 downto 0);
  signal rate_timer              : unsigned(27 downto 0);
  
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

  signal test_debug              : std_logic;
  
begin

  -- Debug Line
  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= TRIGGER_IN;
  DEBUG_OUT(2)           <= trigger;
  DEBUG_OUT(3)           <= start_cycle;
  DEBUG_OUT(4)           <= wait_timer_done;
  DEBUG_OUT(5)           <= ts_reset_o;
  DEBUG_OUT(6)           <= testpulse_o;
  DEBUG_OUT(7)           <= testpulse;
  DEBUG_OUT(8)           <= test_debug;
  DEBUG_OUT(15 downto 9) <= (others => '0');
  
  PROC_TEST_DEBUG: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        test_debug   <= '0';
      else
        if (TEST_IN = x"7f7f7f06" or TEST_IN = x"0000_0000") then
          test_debug  <= '0';
        else
          test_debug  <= '1';
        end if;
      end if;
    end if;
  end process PROC_TEST_DEBUG;

  -- Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 16
      )
    port map (
      CLK_IN         => NX_MAIN_CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  -----------------------------------------------------------------------------
  -- Generate Trigger
  -----------------------------------------------------------------------------

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => NX_MAIN_CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => TRIGGER_IN,
      PULSE_OUT => trigger
      );
    
  PROC_TESTPULSE_OUT: process(NX_MAIN_CLK_IN)
  begin
    if( rising_edge(NX_MAIN_CLK_IN) ) then
      if (RESET_IN = '1') then
        trigger_o         <= '0';
        testpulse_p       <= '0';
        testpulse_o       <= '0';
        ts_reset_o        <= '0';
        wait_timer_init   <= (others => '0');
        trigger_cycle_ctr <= (others => '0');
        extern_trigger    <= '0';
        STATE             <= S_IDLE;
      else
        trigger_o         <= '0';
        testpulse_p       <= '0';
        testpulse_o       <= '0';
        ts_reset_o        <= '0';
        wait_timer_init   <= (others => '0');
        
        case STATE is
          when  S_IDLE =>
            if (trigger = '1') then
              extern_trigger                  <= '1';
              testpulse_p                     <= '1';
              testpulse_o                     <= '1';
              if (reg_testpulse_length > 1) then
                wait_timer_init(11 downto  0) <= reg_testpulse_length - 1;
                wait_timer_init(15 downto 12) <= (others => '0');
                STATE                         <= S_WAIT_TESTPULSE_END;
              else
                STATE                         <= S_IDLE;
              end if;
            else
              extern_trigger                  <= '0';
              STATE                           <= S_IDLE;
            end if;
 
          when S_WAIT_TESTPULSE_END =>
            if (wait_timer_done = '0') then
              testpulse_o                     <= '1';
              STATE                           <= S_WAIT_TESTPULSE_END;
            else
              STATE                           <= S_IDLE;
            end if;
            
        end case;
      end if;
    end if;
  end process PROC_TESTPULSE_OUT;
  
  -- Transfer testpulse_o to CLK_IN Domain
  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 4
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_IN,
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
          if ( testpulse = '1') then
            testpulse_rate_t      <= testpulse_rate_t + 1;
          end if;
          rate_timer              <= rate_timer + 1;
        else
          testpulse_rate          <= testpulse_rate_t;
          testpulse_rate_t        <= (others => '0');
          rate_timer              <= (others => '0');
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
        reg_trigger_period     <= x"00ff";
        reg_trigger_num_cycles <= x"01";
        reg_testpulse_length   <= x"001";
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
  
  -- Trigger Output
  TRIGGER_OUT          <= trigger_o;
  TS_RESET_OUT         <= ts_reset_o;
  TESTPULSE_OUT        <= testpulse_o;

  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;    

end Behavioral;
