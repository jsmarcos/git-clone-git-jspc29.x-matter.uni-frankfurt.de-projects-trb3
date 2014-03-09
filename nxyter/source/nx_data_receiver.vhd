library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.nxyter_components.all;

entity nx_data_receiver is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_DATA_CLK_TEST_IN  : in std_logic;
    TRIGGER_IN           : in  std_logic;
    
    -- nXyter Ports
    NX_TIMESTAMP_CLK_IN  : in  std_logic;
    NX_TIMESTAMP_IN      : in  std_logic_vector (7 downto 0);

    -- ADC Ports
    ADC_CLK_DAT_IN       : in  std_logic;
    ADC_FCLK_IN          : in  std_logic_vector(1 downto 0);
    ADC_DCLK_IN          : in  std_logic_vector(1 downto 0);
    ADC_SAMPLE_CLK_OUT   : out std_logic;
    ADC_A_IN             : in  std_logic_vector(1 downto 0);
    ADC_B_IN             : in  std_logic_vector(1 downto 0);
    ADC_NX_IN            : in  std_logic_vector(1 downto 0);
    ADC_D_IN             : in  std_logic_vector(1 downto 0);
    ADC_SCLK_LOCK_OUT    : out std_logic;
    
    -- Outputs
    NX_TIMESTAMP_OUT     : out std_logic_vector(31 downto 0);
    ADC_DATA_OUT         : out std_logic_vector(11 downto 0);
    NEW_DATA_OUT         : out std_logic;

    TIMESTAMP_CURRENT_IN : in  unsigned(11 downto 0);
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;

    ERROR_OUT            : out std_logic;
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_data_receiver is

  -- Clock Check
  signal counter_nx_domain           : unsigned(7 downto 0);
  signal counter_nx_ref_domain       : unsigned(7 downto 0);
  signal counter_nx_diff             : unsigned(7 downto 0);
  
  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK Domain
  -----------------------------------------------------------------------------

  -- FIFO DC Input Handler
  signal nx_fifo_write_enable        : std_logic;
  signal nx_timestamp_fff            : std_logic_vector(7 downto 0);
  signal nx_timestamp_ff             : std_logic_vector(7 downto 0);
  signal nx_fifo_full                : std_logic;
  signal nx_fifo_delay               : unsigned(3 downto 0);
  signal nx_fifo_reset               : std_logic;
  
  -- NX_TIMESTAMP_IN Process         
  signal frame_byte_ctr              : unsigned(1 downto 0);
  signal nx_frame_word               : std_logic_vector(31 downto 0);
  signal nx_new_frame                : std_logic;
                                     
  -- Frame Sync Process                    
  signal frame_byte_pos              : unsigned(1 downto 0);
                                     
  -- RS Sync FlipFlop                
  signal nx_frame_synced             : std_logic;
  signal rs_sync_set                 : std_logic;
  signal rs_sync_reset               : std_logic;
                                     
  -- Parity Check                    
  signal parity_error                : std_logic;
                                     
  -- NX Clock Active                 
  signal nx_clk_active_ff_0          : std_logic;
  signal nx_clk_active_ff_1          : std_logic;
  signal nx_clk_active_ff_2          : std_logic;
                                     
  -- ADC Ckl Generator               
  signal adc_clk_skip                : std_logic;
  signal adc_sampling_clk            : std_logic;
  signal johnson_ff_0                : std_logic;
  signal johnson_ff_1                : std_logic;
  signal johnson_counter_sync        : std_logic_vector(1 downto 0);
  signal adc_clk_ok                  : std_logic;

  signal pll_adc_sampling_clk_o      : std_logic;
  signal pll_adc_sampling_clk_lock   : std_logic;
  signal pll_adc_sampling_clk_reset  : std_logic;

  -- PLL ADC Monitor
  signal pll_adc_not_lock            : std_logic;
  signal pll_adc_not_lock_f          : std_logic_vector(1 downto 0);
  signal pll_adc_not_lock_ctr        : unsigned(11 downto 0);
  signal pll_adc_not_lock_ctr_clear  : std_logic;
  
  -- ADC RESET                     
  signal adc_clk_ok_last             : std_logic;
  signal adc_reset_sync_s            : std_logic;
  signal adc_reset_sync              : std_logic;
  signal adc_reset_ctr               : unsigned(11 downto 0);

  -- Reset Handler
  signal startup_reset               : std_logic;
  signal rs_wait_timer_start         : std_logic;
  signal rs_wait_timer_done          : std_logic;

  signal rs_timeout_timer_start      : std_logic;
  signal rs_timeout_timer_done       : std_logic;
  signal rs_timeout_timer_reset      : std_logic;
  
  type R_STATES is (R_IDLE,
                    R_SET_ALL_RESETS,
                    R_WAIT_1,
                    R_WAIT_NX_FRAME_RATE_OK,
                    R_PLL_WAIT_LOCK,
                    R_WAIT_ADC_OK,
                    R_WAIT_DATA_HANDLER_OK
                    );
  signal R_STATE : R_STATES;

  signal frame_rates_reset           : std_logic;
  signal sampling_clk_reset          : std_logic;
  signal adc_reset                   : std_logic;
  signal adc_reset_p                 : std_logic;
  signal output_handler_reset        : std_logic;
  
  signal reset_handler_counter       : unsigned(15 downto 0);
  signal reset_handler_busy          : std_logic;
  signal reset_timeout_flag          : std_logic;

  -----------------------------------------------------------------------------
  -- CLK_IN Domain
  -----------------------------------------------------------------------------

  -- NX FIFO READ ENABLE
  signal nx_fifo_read_enable         : std_logic;
  signal nx_fifo_empty               : std_logic;
  signal nx_read_enable              : std_logic;
  signal nx_fifo_data_valid_t        : std_logic;
  signal nx_fifo_data_valid          : std_logic;
                                     
  -- NX FIFO READ
  type delay_array_t is array(0 to 15) of std_logic_vector(31 downto 0);
  signal nx_timestamp_d              : delay_array_t;
  signal nx_timestamp_t              : std_logic_vector(31 downto 0);
  signal nx_new_timestamp            : std_logic;
  signal nx_new_timestamp_ctr        : unsigned(3 downto 0);
  signal nx_fifo_data                : std_logic_vector(31 downto 0);
                                     
  -- Resync Counter Process                    
  signal resync_counter              : unsigned(11 downto 0);
  signal resync_ctr_inc              : std_logic;
  signal nx_clk_active               : std_logic;
                                     
  -- Parity Error Counter Process                    
  signal parity_error_counter        : unsigned(11 downto 0);
  signal parity_error_ctr_inc        : std_logic;
                                     
  signal reg_nx_frame_synced         : std_logic;

  -----------------------------------------------------------------------------
  -- ADC Data Handler
  -----------------------------------------------------------------------------

  -- ADC Handler
  signal ADC_RESET_AD9228            : std_logic;
  signal adc_data                    : std_logic_vector(11 downto 0);
  signal test_adc_data               : std_logic_vector(11 downto 0);
  signal adc_data_valid              : std_logic;

  signal adc_data_t                  : std_logic_vector(11 downto 0);
  signal adc_new_data                : std_logic;
  signal adc_new_data_ctr            : unsigned(3 downto 0);
  signal adc_notlock_ctr             : unsigned(7 downto 0);
  signal ADC_DEBUG                   : std_logic_vector(15 downto 0);
  signal adc_debug_type              : std_logic_vector(3 downto 0);

  -- Data Output Handler
  type STATES is (IDLE,
                  WAIT_ADC,
                  WAIT_TIMESTAMP
                  );
  signal STATE : STATES;
  signal STATE_d                     : std_logic_vector(1 downto 0);
                                   
  signal nx_timestamp_o              : std_logic_vector(31 downto 0);
  signal adc_data_o                  : std_logic_vector(11 downto 0);
  signal new_data_o                  : std_logic;

  -- Check Nxyter Data Clock via Johnson Counter
  signal nx_data_clock_test_0        : std_logic;
  signal nx_data_clock_test_1        : std_logic;
  signal nx_data_clock               : std_logic;
  signal nx_data_clock_state         : std_logic_vector(3 downto 0);
  signal nx_data_clock_ok            : std_logic;

  signal pll_adc_sample_clk_dphase   : std_logic_vector(3 downto 0);
  signal pll_adc_sample_clk_finedelb : std_logic_vector(3 downto 0);

  -- Rate Calculations
  signal nx_frame_rate_ctr           : unsigned(27 downto 0);
  signal nx_frame_rate               : unsigned(27 downto 0);
  signal adc_frame_rate_ctr          : unsigned(27 downto 0);
  signal adc_frame_rate              : unsigned(27 downto 0);
  signal frame_rate_ctr              : unsigned(27 downto 0);
  signal frame_rate                  : unsigned(27 downto 0);
  signal parity_rate_ctr             : unsigned(27 downto 0);
  signal parity_rate                 : unsigned(27 downto 0);
  signal rate_timer_ctr              : unsigned(27 downto 0);

  -- Error
  signal error_adc0                  : std_logic;
  signal error_adc1                  : std_logic;
  signal error_o                     : std_logic;
  signal error_status_bits           : std_logic_vector(11 downto 0);
  
  -- Rate Errors
  signal nx_frame_rate_offline_last  : std_logic;
  signal nx_frame_rate_offline       : std_logic;
  signal nx_frame_rate_error         : std_logic;
  signal adc_frame_rate_error        : std_logic;
  signal frame_rate_error            : std_logic;
  signal parity_rate_error           : std_logic;
  signal reset_for_offline           : std_logic;
  
  -- Slave Bus                     
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;

  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;
                                   
  signal reset_resync_ctr            : std_logic;
  signal reset_parity_error_ctr      : std_logic;
  signal debug_adc                   : std_logic_vector(1 downto 0);
  signal reset_handler_start_r       : std_logic;
  signal reset_handler_counter_clear : std_logic;
  signal adc_bit_shift               : unsigned(3 downto 0);
  signal johnson_counter_sync_r      : unsigned(1 downto 0);
  signal pll_adc_sample_clk_dphase_r : unsigned(3 downto 0);
  
  -- Reset Domain Transfers
  signal RESET_NX_TIMESTAMP_CLK_IN   : std_logic;
  signal RESET_NX_DATA_CLK_TEST_IN   : std_logic;

  signal debug_state                 : std_logic_vector(3 downto 0);
  
begin
  
  PROC_DEBUG_MULT: process(debug_adc,
                           adc_data,
                           adc_data_valid,
                           test_adc_data,
                           adc_clk_ok,
                           adc_clk_ok_last,
                           adc_clk_skip,
                           adc_reset_sync,
                           adc_reset_sync_s,
                           ADC_RESET_AD9228,
                           nx_new_frame,
                           adc_reset_ctr,
                           nx_fifo_full,
                           nx_fifo_write_enable,
                           nx_fifo_empty,
                           nx_fifo_read_enable,
                           nx_fifo_data_valid,
                           nx_new_timestamp,
                           adc_new_data,
                           STATE_d,
                           new_data_o,
                           nx_frame_synced,
                           rs_sync_reset
                           )
  begin
    case debug_adc is
      when "00" =>
        -- Default
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= TRIGGER_IN;
        DEBUG_OUT(2)            <= nx_fifo_full;
        DEBUG_OUT(3)            <= nx_fifo_write_enable;
        DEBUG_OUT(4)            <= nx_fifo_empty;
        DEBUG_OUT(5)            <= nx_fifo_empty;
        DEBUG_OUT(6)            <= nx_fifo_read_enable;
        DEBUG_OUT(7)            <= nx_fifo_data_valid;
        DEBUG_OUT(8)            <= adc_data_valid;
        DEBUG_OUT(9)            <= nx_new_timestamp;
        DEBUG_OUT(10)           <= adc_new_data;
        DEBUG_OUT(11)           <= nx_fifo_reset;
        DEBUG_OUT(12)           <= '0';
        DEBUG_OUT(13)           <= nx_new_frame;
        DEBUG_OUT(14)           <= new_data_o;
        DEBUG_OUT(15)           <= nx_frame_synced;
     
      when "01" =>
        -- Reset Handler
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= nx_new_frame;
        DEBUG_OUT(2)            <= adc_clk_skip;
        DEBUG_OUT(3)            <= adc_clk_ok;
        DEBUG_OUT(4)            <= adc_reset_sync;
        DEBUG_OUT(5)            <= adc_reset;
        DEBUG_OUT(6)            <= ADC_RESET_AD9228;
        DEBUG_OUT(7)            <= pll_adc_not_lock;
        DEBUG_OUT(8)            <= reset_for_offline;
        DEBUG_OUT(9)            <= nx_fifo_reset;
        DEBUG_OUT(10)           <= reset_handler_busy;
        DEBUG_OUT(11)           <= sampling_clk_reset;
        DEBUG_OUT(15 downto 12) <= debug_state;

      when "10" =>
        -- AD9228 Handler Debug output
        DEBUG_OUT               <= ADC_DEBUG;
                
      when "11" =>
        -- Test Channel
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(3 downto 1)   <= debug_state(2 downto 0);
        DEBUG_OUT(4)            <= reset_handler_busy; 
        DEBUG_OUT(5)            <= nx_frame_rate_offline;
        DEBUG_OUT(6)            <= nx_frame_rate_error;
        DEBUG_OUT(7)            <= pll_adc_not_lock;
        DEBUG_OUT(8)            <= error_adc0;
        DEBUG_OUT(9)            <= adc_frame_rate_error;
        DEBUG_OUT(10)           <= nx_fifo_reset;
        DEBUG_OUT(11)           <= sampling_clk_reset;
        DEBUG_OUT(12)           <= adc_reset;
        DEBUG_OUT(13)           <= output_handler_reset;
        DEBUG_OUT(14)           <= frame_rate_error;
        DEBUG_OUT(15)           <= reset_timeout_flag;
    end case;

  end process PROC_DEBUG_MULT;

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  signal_async_trans_RESET_IN: signal_async_trans
    port map (
      CLK_IN      => NX_TIMESTAMP_CLK_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_NX_TIMESTAMP_CLK_IN
    );

  signal_async_trans_RESET_IN_2: signal_async_trans
    port map (
      CLK_IN      => NX_DATA_CLK_TEST_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_NX_DATA_CLK_TEST_IN
    );
  
  -----------------------------------------------------------------------------
  -- Check NX Data Clk
  -----------------------------------------------------------------------------
  PROC_COUNTER_NX_CLOCK: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_NX_TIMESTAMP_CLK_IN = '1' ) then
        counter_nx_domain <= (others => '0');
      else
        counter_nx_domain <= counter_nx_domain + 1;
      end if;
    end if;
  end process PROC_COUNTER_NX_CLOCK; 

  PROC_COUNTER_NX_REF_CLOCK: process(NX_DATA_CLK_TEST_IN)
  begin
    if (rising_edge(NX_DATA_CLK_TEST_IN) ) then
      if (NX_DATA_CLK_TEST_IN = '1') then
        counter_nx_ref_domain <= (others => '0');
      else
        counter_nx_ref_domain <= counter_nx_ref_domain + 1;
      end if;
    end if;
  end process PROC_COUNTER_NX_REF_CLOCK;

  counter_nx_diff <= counter_nx_ref_domain - counter_nx_domain;
    
  -----------------------------------------------------------------------------
  -- ADC CLK DOMAIN
  -----------------------------------------------------------------------------

  pll_adc_sampling_clk_reset  <=  sampling_clk_reset;

  -- Shift dphase show 0 as optimal value
  pll_adc_sample_clk_dphase   <=
    std_logic_vector(pll_adc_sample_clk_dphase_r - 1);
    
  pll_adc_sampling_clk_2: pll_adc_sampling_clk
    port map (
      CLK       => adc_sampling_clk,
      
      RESET     => pll_adc_sampling_clk_reset,
      FINEDELB0 => pll_adc_sample_clk_finedelb(0),
      FINEDELB1 => pll_adc_sample_clk_finedelb(1),
      FINEDELB2 => pll_adc_sample_clk_finedelb(2),
      FINEDELB3 => pll_adc_sample_clk_finedelb(3),
      DPHASE0   => pll_adc_sample_clk_dphase(0),
      DPHASE1   => pll_adc_sample_clk_dphase(1),
      DPHASE2   => pll_adc_sample_clk_dphase(2),
      DPHASE3   => pll_adc_sample_clk_dphase(3),
      CLKOP     => open,
      CLKOS     => pll_adc_sampling_clk_o,
      LOCK      => pll_adc_sampling_clk_lock
      );

  signal_async_trans_2: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => not pll_adc_sampling_clk_lock,
      SIGNAL_OUT  => pll_adc_not_lock
      );
  
  PROC_PLL_LOCK_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' or pll_adc_not_lock_ctr_clear = '1') then
        pll_adc_not_lock_f     <= (others => '0');
        pll_adc_not_lock_ctr   <= (others => '0');
      else
        pll_adc_not_lock_f(0)  <= pll_adc_not_lock;
        pll_adc_not_lock_f(1)  <= pll_adc_not_lock_f(0);
        
        if (pll_adc_not_lock_f = "01") then
          pll_adc_not_lock_ctr <= pll_adc_not_lock_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_PLL_LOCK_COUNTER;

  ADC_RESET_AD9228   <= RESET_IN or adc_reset;
  adc_ad9228_1: adc_ad9228
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => ADC_RESET_AD9228,
      CLK_ADCDAT_IN        => ADC_CLK_DAT_IN,

      ADC0_SCLK_IN         => pll_adc_sampling_clk_o,
      ADC0_SCLK_OUT        => ADC_SAMPLE_CLK_OUT,
      ADC0_DATA_A_IN       => ADC_NX_IN(0),
      ADC0_DATA_B_IN       => ADC_B_IN(0),
      ADC0_DATA_C_IN       => ADC_A_IN(0),
      ADC0_DATA_D_IN       => ADC_D_IN(0),
      ADC0_DCLK_IN         => ADC_DCLK_IN(0),
      ADC0_FCLK_IN         => ADC_FCLK_IN(0),
                           
      ADC1_SCLK_IN         => pll_adc_sampling_clk_o,
      ADC1_SCLK_OUT        => open,
      ADC1_DATA_A_IN       => ADC_NX_IN(1), 
      ADC1_DATA_B_IN       => ADC_A_IN(1),
      ADC1_DATA_C_IN       => ADC_B_IN(1),
      ADC1_DATA_D_IN       => ADC_D_IN(1),
      ADC1_DCLK_IN         => ADC_DCLK_IN(1),
      ADC1_FCLK_IN         => ADC_FCLK_IN(1),
                           
      ADC0_DATA_A_OUT      => adc_data,
      ADC0_DATA_B_OUT      => test_adc_data,
      ADC0_DATA_C_OUT      => open,
      ADC0_DATA_D_OUT      => open,
      ADC0_DATA_VALID_OUT  => adc_data_valid,
                           
      ADC1_DATA_A_OUT      => open,
      ADC1_DATA_B_OUT      => open,
      ADC1_DATA_C_OUT      => open,
      ADC1_DATA_D_OUT      => open,
      ADC1_DATA_VALID_OUT  => open,

      ADC0_NOTLOCK_COUNTER => adc_notlock_ctr,
      ADC1_NOTLOCK_COUNTER => open,

      ERROR_ADC0_OUT       => error_adc0,
      ERROR_ADC1_OUT       => error_adc1,
      DEBUG_IN             => adc_debug_type,
      DEBUG_OUT            => ADC_DEBUG
      );

  timer_static_RESET_TIMER: timer_static
    generic map (
      CTR_WIDTH => 20,
      CTR_END   => 500000 -- 1ms
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => rs_wait_timer_start,
      TIMER_DONE_OUT => rs_wait_timer_done
      );

  timer_static_RESET_TIMEOUT: timer_static
    generic map (
      CTR_WIDTH => 26,
      CTR_END   => 10000000 -- 1s
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => rs_timeout_timer_reset,
      TIMER_START_IN => rs_timeout_timer_start,
      TIMER_DONE_OUT => rs_timeout_timer_done
      );

  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 4
      )
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_NX_TIMESTAMP_CLK_IN,
      PULSE_A_IN  => adc_reset_sync_s,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => adc_reset_sync
      );
  
  PROC_RESET_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_rates_reset           <= '0';
        nx_fifo_reset               <= '0';
        sampling_clk_reset          <= '0';
        adc_reset_p                 <= '0';
        adc_reset                   <= '0';
        output_handler_reset        <= '0';

        rs_wait_timer_start         <= '0';
        rs_timeout_timer_start      <= '0';
        rs_timeout_timer_reset      <= '1';
        reset_handler_counter       <= (others => '0');
        reset_handler_busy          <= '0';
        reset_timeout_flag          <= '0';
        startup_reset               <= '1';
        R_STATE                     <= R_IDLE;
      else
        frame_rates_reset           <= '0';
        nx_fifo_reset               <= '0';
        sampling_clk_reset          <= '0';
        adc_reset_p                 <= '0';
        adc_reset                   <= '0';
        output_handler_reset        <= '0';

        rs_wait_timer_start         <= '0';
        rs_timeout_timer_start      <= '0';
        rs_timeout_timer_reset      <= '0';
        reset_handler_busy          <= '1';
        
        debug_state   <= x"0";
        
        if (reset_handler_counter_clear = '1') then
          reset_handler_counter       <= (others => '0');
        end if;

        if (rs_timeout_timer_done = '1') then
          -- Reset Timeout
          reset_timeout_flag          <= '1';
        end if;
                
        case R_STATE is
          when R_IDLE => 
            if (reset_for_offline     = '1' or
                --pll_adc_not_lock      = '1' or
                --adc_reset_sync        = '1' or
                reset_handler_start_r = '1' or
                startup_reset         = '1'
                ) then
              if (reset_handler_counter_clear = '0') then
                reset_handler_counter <= reset_handler_counter + 1;
              end if; 
              R_STATE                 <= R_SET_ALL_RESETS;
            else 
              reset_handler_busy      <= '0';
              R_STATE                 <= R_IDLE;
            end if;

          when R_SET_ALL_RESETS =>
            frame_rates_reset         <= '1';
            nx_fifo_reset             <= '1';
            sampling_clk_reset        <= '1';
            adc_reset_p               <= '1';
            adc_reset                 <= '1';
            output_handler_reset      <= '1';

            rs_wait_timer_start       <= '1';  -- wait 1mue to settle
            R_STATE                   <= R_WAIT_1;
            debug_state               <= x"1";

          when R_WAIT_1 =>
            if (rs_wait_timer_done = '0') then
              nx_fifo_reset           <= '1';
              sampling_clk_reset      <= '1';
              adc_reset               <= '1';
              output_handler_reset    <= '1';
              R_STATE                 <= R_WAIT_1;
            else
              -- Release NX Fifo Reset + Start Timeout HAndler
              sampling_clk_reset      <= '1';
              adc_reset               <= '1';
              output_handler_reset    <= '1';
              reset_timeout_flag      <= '0';
              rs_timeout_timer_start  <= '1';
              R_STATE                 <= R_WAIT_NX_FRAME_RATE_OK;
            end if;
            debug_state               <= x"2";

          when R_WAIT_NX_FRAME_RATE_OK =>
            if (nx_frame_rate_offline = '0' and
                nx_frame_rate_error   = '0') then
              -- Release PLL Reset
              adc_reset               <= '1';
              output_handler_reset    <= '1';
              R_STATE                 <= R_PLL_WAIT_LOCK;
            else
              sampling_clk_reset      <= '1';
              adc_reset               <= '1';
              output_handler_reset    <= '1';
              R_STATE                 <= R_WAIT_NX_FRAME_RATE_OK;
            end if;
            debug_state               <= x"3";
            
          when R_PLL_WAIT_LOCK =>
            if (pll_adc_not_lock = '1') then
              adc_reset               <= '1';
              output_handler_reset    <= '1';
              R_STATE                 <= R_PLL_WAIT_LOCK;
            else
              -- Release ADC Reset
              output_handler_reset    <= '1';
              R_STATE                 <= R_WAIT_ADC_OK;
            end if;
            debug_state               <= x"4";
            
          when R_WAIT_ADC_OK =>
            if (error_adc0 = '0' and
                adc_frame_rate_error = '0') then
              -- Release Output Handler Reset
              R_STATE                 <= R_WAIT_DATA_HANDLER_OK;
            else
              R_STATE                 <= R_WAIT_ADC_OK;
            end if;
            debug_state               <= x"5";

          when R_WAIT_DATA_HANDLER_OK =>
            if (frame_rate_error = '0') then
              startup_reset           <= '0';
              R_STATE                 <= R_IDLE;
            else
              R_STATE                 <= R_WAIT_DATA_HANDLER_OK;
            end if;  
            debug_state               <= x"6";
            
        end case;
      end if;
    end if;
  end process PROC_RESET_HANDLER;

  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK_IN Domain
  -----------------------------------------------------------------------------

  -- Merge TS Data 8bit to 32Bit Timestamp Frame
  PROC_8_TO_32_BIT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_NX_TIMESTAMP_CLK_IN = '1' ) then
        frame_byte_ctr    <= (others => '0');
        nx_frame_word     <= (others => '0');
        nx_timestamp_ff   <= (others => '0');
        nx_new_frame      <= '0';
      else
        nx_timestamp_fff  <= NX_TIMESTAMP_IN;
        nx_timestamp_ff   <= nx_timestamp_fff;
        nx_new_frame      <= '0';
        
        case frame_byte_pos is
          when "11" => nx_frame_word(31 downto 24) <= nx_timestamp_ff;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "10" => nx_frame_word(23 downto 16) <= nx_timestamp_ff;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "01" => nx_frame_word(15 downto  8) <= nx_timestamp_ff;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "00" => nx_frame_word( 7 downto  0) <= nx_timestamp_ff;
                       if (frame_byte_ctr = "11") then
                         nx_new_frame              <= '1';
                       end if;
                       frame_byte_ctr              <= (others => '0'); 
        end case;
      end if;
    end if;
  end process PROC_8_TO_32_BIT;
  
  -- Frame Sync process
  PROC_SYNC_TO_NX_FRAME: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_NX_TIMESTAMP_CLK_IN = '1' ) then
        frame_byte_pos    <= "11";
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
      else
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
        if (nx_new_frame = '1') then
          case nx_frame_word is
            when x"7f7f7f06" =>
              rs_sync_set         <= '1';      
              frame_byte_pos      <= frame_byte_pos - 1;
              
            when x"7f7f067f" =>
              rs_sync_reset       <= '1';
              frame_byte_pos      <= frame_byte_pos - 2;
              
            when x"7f067f7f" =>
              rs_sync_reset       <= '1';
              frame_byte_pos      <= frame_byte_pos - 3;
              
            when x"067f7f7f" =>
              rs_sync_reset       <= '1';        
              frame_byte_pos      <= frame_byte_pos - 4;
              
            when others =>
              frame_byte_pos      <= frame_byte_pos - 1;
          end case;
        else
          frame_byte_pos          <= frame_byte_pos - 1;
        end if;
      end if;
    end if;
  end process PROC_SYNC_TO_NX_FRAME;

  -- RS FlipFlop to hold Sync Status
  PROC_RS_FRAME_SYNCED: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1' or rs_sync_reset = '1') then
        nx_frame_synced <= '0';
      elsif (rs_sync_set = '1') then
        nx_frame_synced <= '1';
      end if;
    end if;
  end process PROC_RS_FRAME_SYNCED;

  -- Check Parity
  PROC_PARITY_CHECK: process(NX_TIMESTAMP_CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
    variable parity      : std_logic;
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        parity_error       <= '0';
      else
        parity_error       <= '0';
        if (nx_new_frame = '1' and nx_frame_synced = '1') then
          -- Timestamp Bit #6 is excluded (funny nxyter-bug)
          parity_bits         := nx_frame_word(31)           &
                                 nx_frame_word(30 downto 24) &
                                 nx_frame_word(21 downto 16) &
                                 nx_frame_word(14 downto  8) &
                                 nx_frame_word( 2 downto  1);
          parity              := xor_all(parity_bits);

          if (parity /= nx_frame_word(0)) then
            parity_error   <= '1';
          end if;
        end if;
      end if;
    end if;
  end process PROC_PARITY_CHECK;

  fifo_ts_32to32_dc_1: fifo_ts_32to32_dc
    port map (
      Data          => nx_frame_word,
      WrClock       => NX_TIMESTAMP_CLK_IN,
      RdClock       => CLK_IN,
      WrEn          => nx_fifo_write_enable,
      RdEn          => nx_fifo_read_enable,
      Reset         => nx_fifo_reset,
      RPReset       => nx_fifo_reset,
      Q             => nx_fifo_data,
      Empty         => nx_fifo_empty,
      Full          => nx_fifo_full
      );
  
  nx_fifo_write_enable   <= nx_new_frame and not nx_fifo_full;

  PROC_NX_CLK_ACT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if(RESET_NX_TIMESTAMP_CLK_IN = '1' ) then
        nx_clk_active_ff_0 <= '0';
        nx_clk_active_ff_1 <= '0';
        nx_clk_active_ff_2 <= '0';
      else
        nx_clk_active_ff_0 <= not nx_clk_active_ff_2;
        nx_clk_active_ff_1 <= nx_clk_active_ff_0;
        nx_clk_active_ff_2 <= nx_clk_active_ff_1;
      end if;
    end if;
  end process PROC_NX_CLK_ACT;

  -- ADC Sampling Clock Generator using a Johnson Counter
  PROC_ADC_SAMPLING_CLK_GENERATOR: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        johnson_ff_0   <= '0';
        johnson_ff_1   <= '0';
      else
        if (adc_clk_skip = '0') then
          johnson_ff_0     <= not johnson_ff_1;
          johnson_ff_1     <= johnson_ff_0;
          adc_sampling_clk <= not johnson_ff_1;
        end if;
      end if;
    end if;
    adc_sampling_clk <= johnson_ff_0;
  end process PROC_ADC_SAMPLING_CLK_GENERATOR;

  -- Adjust johnson_counter_sync to show optimal value at 0
  johnson_counter_sync <= std_logic_vector(johnson_counter_sync_r + 3);
  PROC_ADC_SAMPLING_CLK_SYNC: process(NX_TIMESTAMP_CLK_IN)
    variable adc_clk_state : std_logic_vector(1 downto 0);
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        adc_clk_skip       <= '0';
        adc_clk_ok         <= '0';
      else
        adc_clk_state      := johnson_ff_1 & johnson_ff_0;
        adc_clk_skip       <= '0';
        if (nx_new_frame = '1') then
          if (adc_clk_state /= johnson_counter_sync) then
            adc_clk_skip   <= '1';
            adc_clk_ok     <= '0';
          else
            adc_clk_ok     <= '1';        
          end if;
        end if;
      end if;
    end if;
  end process PROC_ADC_SAMPLING_CLK_SYNC;

  PROC_ADC_RESET: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        adc_clk_ok_last     <= '0';
        adc_reset_sync_s    <= '0';
      else
        adc_reset_sync_s    <= '0';
        adc_clk_ok_last     <= adc_clk_ok;
        if (adc_clk_ok_last = '0' and adc_clk_ok = '1') then
          adc_reset_sync_s  <= '1';
        end if;
      end if;
    end if;
  end process PROC_ADC_RESET;
  
  PROC_RESET_CTR: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        adc_reset_ctr        <= (others => '0');
      else
        if (adc_reset_p = '1') then
          adc_reset_ctr      <= adc_reset_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_RESET_CTR;

  -----------------------------------------------------------------------------
  -- NX CLK_IN Domain
  -----------------------------------------------------------------------------

  -- FIFO Read Handler
  nx_fifo_read_enable     <= not nx_fifo_empty;

  PROC_NX_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      nx_fifo_data_valid_t   <= nx_fifo_read_enable;
      if(RESET_IN = '1') then
        nx_fifo_data_valid     <= '0';
      else
        -- Delay read signal by one CLK
        nx_fifo_data_valid     <= nx_fifo_data_valid_t;
      end if;
    end if;
  end process PROC_NX_FIFO_READ_ENABLE;

  PROC_NX_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        nx_timestamp_t         <= (others => '0');
        nx_new_timestamp       <= '0';
        nx_new_timestamp_ctr   <= (others => '0');
        for I in 1 to 15 loop
          nx_timestamp_d(I)    <= (others => '0');
        end loop;
      else
        if (nx_fifo_data_valid = '1') then
          -- Delay Data relative to ADC by 8 steps
          for I in 1 to 15 loop
            nx_timestamp_d(I)  <= nx_timestamp_d(I - 1); 
          end loop; 
          nx_timestamp_d(0)    <= nx_fifo_data;
          nx_timestamp_t       <= nx_timestamp_d(to_integer(nx_fifo_delay));
          nx_new_timestamp     <= '1';
          nx_new_timestamp_ctr <= nx_new_timestamp_ctr + 1;
        else
          nx_timestamp_t       <= x"deadbeef";
          nx_new_timestamp     <= '0';
        end if;
      end if;
    end if;
  end process PROC_NX_FIFO_READ;

  -----------------------------------------------------------------------------
  -- Status Counters
  -----------------------------------------------------------------------------

  -- Domain Transfers
  pulse_dtrans_2: pulse_dtrans
    generic map (
      CLK_RATIO => 3
      )
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_NX_TIMESTAMP_CLK_IN,
      PULSE_A_IN  => rs_sync_reset,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => resync_ctr_inc
      );

  pulse_dtrans_3: pulse_dtrans
    generic map (
      CLK_RATIO => 3
      )
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_NX_TIMESTAMP_CLK_IN,
      PULSE_A_IN  => parity_error,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => parity_error_ctr_inc
      );

  -- nx_frame_synced --> CLK_IN Domain
  signal_async_trans_1: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => nx_frame_synced,
      SIGNAL_OUT  => reg_nx_frame_synced
      );
  
  -- Counters
  PROC_RESYNC_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_resync_ctr = '1') then
        resync_counter   <= (others => '0');
      else
        if (resync_ctr_inc = '1') then
          resync_counter <= resync_counter + 1;
        end if;
      end if;
    end if;
  end process PROC_RESYNC_COUNTER; 

  PROC_PARITY_ERROR_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_parity_error_ctr = '1') then
        parity_error_counter   <= (others => '0');
      else
        if (parity_error_ctr_inc = '1') then
          parity_error_counter <= parity_error_counter + 1;
        end if;
      end if;
    end if;
  end process PROC_PARITY_ERROR_COUNTER;

  -----------------------------------------------------------------------------
  -- ADC Fifo Handler
  -----------------------------------------------------------------------------
  PROC_ADC_DATA_READ: process(CLK_IN)
    variable adcval : unsigned(11 downto 0) := (others => '0');
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        adc_data_t         <= (others => '0');
        adc_new_data       <= '0';
        adc_new_data_ctr   <= (others => '0');
      else
        if (adc_bit_shift(3) = '1') then
          adcval             := unsigned(adc_data) rol
                                to_integer(adc_bit_shift(2 downto 0));
        else
          adcval             := unsigned(adc_data) ror
                                to_integer(adc_bit_shift(2 downto 0));
        end if;
        if (adc_data_valid = '1') then
          adc_data_t       <= std_logic_vector(adcval);
          adc_new_data     <= '1';
          adc_new_data_ctr <= adc_new_data_ctr + 1;
        else
          adc_data_t       <= x"aff";
          adc_new_data     <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC_DATA_READ; 

  -----------------------------------------------------------------------------
  -- Output handler
  -----------------------------------------------------------------------------
  PROC_OUTPUT_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or output_handler_reset = '1') then
        nx_timestamp_o <= (others => '0');
        adc_data_o     <= (others => '0');
        new_data_o     <= '0';
        STATE          <= IDLE;
      else
        case STATE is
          
          when IDLE =>
            STATE_d <= "00";
            if (nx_new_timestamp = '1' and adc_new_data = '1') then
              nx_timestamp_o  <= nx_timestamp_t;
              adc_data_o      <= adc_data_t;
              new_data_o      <= '1';
              STATE           <= IDLE;
            elsif (nx_new_timestamp = '1') then
              nx_timestamp_o  <= nx_timestamp_t;
              adc_data_o      <= (others => '0');
              new_data_o      <= '0';
              STATE           <= WAIT_ADC;
            elsif (adc_new_data = '1') then
              adc_data_o      <= adc_data_t;
              nx_timestamp_o  <= (others => '0');
              new_data_o      <= '0';  
              STATE           <= WAIT_TIMESTAMP;
            else
              nx_timestamp_o  <= (others => '0');
              adc_data_o      <= (others => '0');
              new_data_o      <= '0';  
              STATE           <= IDLE;
            end if;

          when WAIT_ADC =>
            STATE_d <= "01";
            if (adc_new_data = '1') then
              adc_data_o      <= adc_data_t;
              new_data_o      <= '1';
              STATE           <= IDLE;
            else
              new_data_o      <= '0';  
              STATE           <= WAIT_ADC;
            end if;

           when WAIT_TIMESTAMP => 
            STATE_d <= "10";
            if (nx_new_timestamp = '1') then
              nx_timestamp_o  <= nx_timestamp_t;
              new_data_o      <= '1';
              STATE           <= IDLE;
            else
              new_data_o      <= '0';  
              STATE           <= WAIT_TIMESTAMP;
            end if; 

        end case;
      end if;
    end if;
  end process PROC_OUTPUT_HANDLER;

  -----------------------------------------------------------------------------
  -- Rate Counters + Rate Error Check
  -----------------------------------------------------------------------------
  PROC_RATE_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or frame_rates_reset = '1') then
        nx_frame_rate_ctr      <= (others => '0');
        nx_frame_rate          <= (others => '0');
        adc_frame_rate_ctr     <= (others => '0');
        adc_frame_rate         <= (others => '0');
        frame_rate_ctr         <= (others => '0');
        frame_rate             <= (others => '0');
        parity_rate_ctr        <= (others => '0');
        parity_rate            <= (others => '0');
        rate_timer_ctr         <= (others => '0');
      else
        if (rate_timer_ctr < x"5f5e100") then
          rate_timer_ctr                  <= rate_timer_ctr + 1;

          if (nx_fifo_data_valid = '1') then
            nx_frame_rate_ctr             <= nx_frame_rate_ctr + 1;
          end if;
          
          if (adc_data_valid = '1') then
            adc_frame_rate_ctr            <= adc_frame_rate_ctr + 1;
          end if;

          if (new_data_o = '1') then
            frame_rate_ctr                <= frame_rate_ctr + 1;
          end if;

          if (parity_error_ctr_inc = '1') then
            parity_rate_ctr               <= parity_rate_ctr + 1;
          end if;
        else
          rate_timer_ctr                  <= (others => '0');
          nx_frame_rate                   <= nx_frame_rate_ctr;
          adc_frame_rate                  <= adc_frame_rate_ctr;
          frame_rate                      <= frame_rate_ctr;
          parity_rate                     <= parity_rate_ctr;
          
          nx_frame_rate_ctr(27 downto 1)  <= (others => '0');
          nx_frame_rate_ctr(0)            <= nx_fifo_data_valid;

          adc_frame_rate_ctr(27 downto 1) <= (others => '0');
          adc_frame_rate_ctr(0)           <= adc_data_valid;

          frame_rate_ctr(27 downto 1)     <= (others => '0');
          frame_rate_ctr(0)               <= new_data_o;

          parity_rate_ctr(27 downto 1)    <= (others => '0');
          parity_rate_ctr(0)              <= parity_error_ctr_inc;
        end if;
      end if;
    end if;
  end process PROC_RATE_COUNTER;

  -- Check Rates for errors
  PROC_RATE_ERRORS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        nx_frame_rate_offline      <= '1';
        nx_frame_rate_offline_last <= '1';
        nx_frame_rate_error        <= '0';
        adc_frame_rate_error       <= '0';
        frame_rate_error           <= '0';
        parity_rate_error          <= '0';
        reset_for_offline          <= '0';
      else
        if (nx_frame_rate < 2) then
          -- Assuming nxyter not online or does not receive clock
          nx_frame_rate_offline    <= '1';
        else
          nx_frame_rate_offline    <= '0';
        end if;

        if ((nx_frame_rate < x"1dc_d642"  or
             nx_frame_rate > x"1dc_d652")) then
          nx_frame_rate_error      <= '1';
        else
          nx_frame_rate_error      <= '0';
        end if;
          
        if ((adc_frame_rate < x"1dc_d64e" or
             adc_frame_rate > x"1dc_d652")) then
          adc_frame_rate_error     <= '1';
        else
          adc_frame_rate_error     <= '0';
        end if;

        if ((frame_rate < x"1dc_d64e" or
             frame_rate > x"1dc_d652")) then
          frame_rate_error         <= '1';
        else
          frame_rate_error         <= '0';
        end if;

        if (parity_rate > 0) then
          parity_rate_error         <= '1';
        else
          parity_rate_error         <= '0';
        end if;
        
        -- Reset Request to Reset Handler
        nx_frame_rate_offline_last <= nx_frame_rate_offline;
        if (nx_frame_rate_offline_last = '1' and
            nx_frame_rate_offline      = '0') then
          reset_for_offline        <= '1';
        else
          reset_for_offline        <= '0';
        end if;
      end if;
    end if;
  end process PROC_RATE_ERRORS;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';
        reset_resync_ctr              <= '0';
        reset_parity_error_ctr        <= '0';
        debug_adc                     <= (others => '0');
        johnson_counter_sync_r        <= "00";
        pll_adc_sample_clk_dphase_r   <= x"0";
        pll_adc_sample_clk_finedelb   <= (others => '0');
        pll_adc_not_lock_ctr_clear    <= '0';
        nx_fifo_delay                 <= x"8";
        reset_handler_start_r         <= '0';
        reset_handler_counter_clear   <= '0';
        adc_bit_shift                 <= x"0";
        adc_debug_type                <= (others => '0');
      else                      
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';
        reset_resync_ctr              <= '0';
        reset_parity_error_ctr        <= '0';
        pll_adc_not_lock_ctr_clear    <= '0';
        reset_handler_start_r         <= '0';
        reset_handler_counter_clear   <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o                <= nx_timestamp_t;
              slv_ack_o                     <= '1';

            when x"0001" =>
              slv_data_out_o(0)             <= nx_fifo_full;
              slv_data_out_o(1)             <= nx_fifo_empty;
              slv_data_out_o(2)             <= '0';
              slv_data_out_o(3)             <= '0';
              slv_data_out_o(4)             <= nx_fifo_data_valid;
              slv_data_out_o(5)             <= adc_new_data;
              slv_data_out_o(29 downto 5)   <= (others => '0');
              slv_data_out_o(30)            <= '0';
              slv_data_out_o(31)            <= reg_nx_frame_synced;
              slv_ack_o                     <= '1'; 

            when x"0002" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(resync_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0003" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(parity_error_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0004" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(pll_adc_not_lock_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';     

            when x"0005" =>
              slv_data_out_o(1 downto  0)   <= johnson_counter_sync_r;
              slv_data_out_o(31 downto 2)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0006" =>
              slv_data_out_o(3 downto 0)    <=
                std_logic_vector(pll_adc_sample_clk_dphase_r);
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0007" =>
              slv_data_out_o(3 downto 0)    <= pll_adc_sample_clk_finedelb;
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1'; 
              
            when x"0008" =>
              slv_data_out_o(11 downto 0)   <= adc_data_t;
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0009" =>
              slv_data_out_o(11 downto 0)   <= std_logic_vector(adc_reset_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';
 
            when x"000a" =>
              slv_data_out_o(31 downto 0)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"000b" =>
              slv_data_out_o(0)             <= reset_handler_busy;
              slv_data_out_o(31 downto 1)   <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"000c" =>
              slv_data_out_o(15 downto 0)   <= reset_handler_counter;
              slv_data_out_o(31 downto 6)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000d" =>
              slv_data_out_o(3 downto 0)    <= std_logic_vector(nx_fifo_delay);
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000e" =>
              slv_data_out_o(3 downto 0)    <= std_logic_vector(adc_bit_shift);
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000f" =>
              slv_data_out_o(7 downto 0)    <=
                std_logic_vector(adc_notlock_ctr);
              slv_data_out_o(31 downto 8)   <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0010" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(nx_frame_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0011" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(adc_frame_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0012" =>
              slv_data_out_o(11 downto 0)   <= test_adc_data;
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0013" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(frame_rate); 
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0014" =>
              slv_data_out_o(11 downto 0)    <= error_status_bits;
              slv_data_out_o(31 downto 8)   <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0015" =>
              slv_data_out_o(27 downto 0)   <= parity_rate;
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"001e" =>
              slv_data_out_o(1 downto 0)    <= debug_adc;
              slv_data_out_o(31 downto 2)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"001f" =>
              slv_data_out_o(3 downto 0)    <= adc_debug_type;
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o            <= '1';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0002" => 
              reset_resync_ctr              <= '1';
              slv_ack_o                     <= '1'; 

            when x"0003" => 
              reset_parity_error_ctr        <= '1';
              slv_ack_o                     <= '1'; 
    
            when x"0004" =>
              pll_adc_not_lock_ctr_clear    <= '1';
              slv_ack_o                     <= '1';
              
            when x"0005" =>
              johnson_counter_sync_r        <= SLV_DATA_IN(1 downto 0);
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1'; 

            when x"0006" =>
              pll_adc_sample_clk_dphase_r   <=
                unsigned(SLV_DATA_IN(3 downto 0));
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1';   

            when x"0007" =>
              pll_adc_sample_clk_finedelb   <= SLV_DATA_IN(3 downto 0);
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1';   
              
            when x"000b" =>
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1';

            when x"000c" =>
              reset_handler_counter_clear   <= '1';
              slv_ack_o                     <= '1';

            when x"000d" =>
              nx_fifo_delay                 <=
                unsigned(SLV_DATA_IN(3 downto 0));
              slv_ack_o                     <= '1';

            when x"000e" =>
              adc_bit_shift                 <=
                unsigned(SLV_DATA_IN(3 downto 0));
              slv_ack_o                     <= '1';

            when x"001e" =>
              debug_adc                     <= SLV_DATA_IN(1 downto 0);
              slv_ack_o                     <= '1';

            when x"001f" =>
              adc_debug_type                <=
                unsigned(SLV_DATA_IN(3 downto 0));
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o            <= '1';
              
          end case;                
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  -- ErrorPROC_ERROR: process(CLK_IN)
  PROC_ERROR: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        error_status_bits  <= (others => '0');
        error_o            <= '0';
      else
        if (error_adc0            = '1'  or
            pll_adc_not_lock      = '1'  or
            nx_frame_rate_offline = '1'  or
            nx_frame_rate_error   = '1'  or
            adc_clk_ok            = '0'  or
            parity_error_ctr_inc  = '1'  or
            reg_nx_frame_synced   = '0'  or
            adc_frame_rate_error  = '1'  or
            parity_rate_error     = '1'
            ) then
          error_o             <= '1';
        else
          error_o             <= '0';
        end if;

        error_status_bits(0)  <= nx_frame_rate_offline;
        error_status_bits(1)  <= frame_rate_error;
        error_status_bits(2)  <= nx_frame_rate_error;
        error_status_bits(3)  <= adc_frame_rate_error;
        error_status_bits(4)  <= parity_rate_error;
        error_status_bits(5)  <= not reg_nx_frame_synced;
        error_status_bits(6)  <= error_adc0;
        error_status_bits(7)  <= pll_adc_not_lock;
        error_status_bits(8)  <= not adc_clk_ok;
        error_status_bits(9)  <= '0';
        error_status_bits(10) <= '0';
        error_status_bits(11) <= '0';
      end if;
    end if;
  end process PROC_ERROR;

  -- Output Signals

  NX_TIMESTAMP_OUT       <= nx_timestamp_o
                            when new_data_o = '1' else x"0000_0000";
  ADC_DATA_OUT           <= adc_data_o when new_data_o = '1' else x"000";
  NEW_DATA_OUT           <= new_data_o;
  ADC_SCLK_LOCK_OUT      <= pll_adc_sampling_clk_lock;
  ERROR_OUT              <= error_o;
  
  SLV_DATA_OUT           <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT   <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT   <= slv_unknown_addr_o;
  SLV_ACK_OUT            <= slv_ack_o;
  
end Behavioral;
