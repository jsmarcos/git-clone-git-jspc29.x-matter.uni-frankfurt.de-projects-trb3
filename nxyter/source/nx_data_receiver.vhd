library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.nxyter_components.all;

entity nx_data_receiver is
  generic (
    DEBUG_ENABLE : boolean := false
    );
  port(
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
    TRIGGER_IN             : in  std_logic;
    NX_ONLINE_IN           : in  std_logic;
    NX_CLOCK_ON_IN         : in  std_logic;

    -- nXyter Ports        
    NX_TIMESTAMP_CLK_IN    : in  std_logic;
    NX_TIMESTAMP_IN        : in  std_logic_vector (7 downto 0);
    NX_TIMESTAMP_RESET_OUT : out std_logic;
    
    -- ADC Ports
    ADC_CLK_DAT_IN         : in  std_logic;
    ADC_FCLK_IN            : in  std_logic_vector(1 downto 0);
    ADC_DCLK_IN            : in  std_logic_vector(1 downto 0);
    ADC_SAMPLE_CLK_OUT     : out std_logic;
    ADC_A_IN               : in  std_logic_vector(1 downto 0);
    ADC_B_IN               : in  std_logic_vector(1 downto 0);
    ADC_NX_IN              : in  std_logic_vector(1 downto 0);
    ADC_D_IN               : in  std_logic_vector(1 downto 0);
    ADC_SCLK_LOCK_OUT      : out std_logic;
                           
    -- Outputs             
    DATA_OUT               : out std_logic_vector(43 downto 0);
    DATA_CLK_OUT           : out std_logic;
    
    -- Slave bus           
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;

    ADC_TR_ERROR_IN        : in  std_logic;
    DISABLE_ADC_OUT        : out std_logic;
    ERROR_OUT              : out std_logic;
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_data_receiver is

  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK Domain
  -----------------------------------------------------------------------------

  -- NX_TIMESTAMP_IN Process         
  signal nx_timestamp_delay_f        : unsigned(2 downto 0);
  signal nx_timestamp_delay          : unsigned(2 downto 0);
  signal nx_shift_register_delay     : std_logic_vector(5 downto 0);
  signal nx_frame_word_ff            : std_logic_vector(7 downto 0);
  signal nx_frame_word_f             : std_logic_vector(7 downto 0);

  signal nx_frame_word_t             : std_logic_vector(31 downto 0);
  signal nx_frame_clk_t              : std_logic;
                                     
  -- Frame Sync Process                    
  signal frame_byte_pos              : unsigned(1 downto 0);
  signal nx_frame_word               : std_logic_vector(31 downto 0);
  signal nx_frame_clk                : std_logic;
  
  -- RS Sync FlipFlop                
  signal nx_frame_synced             : std_logic;
  signal rs_sync_set                 : std_logic;
  signal rs_sync_reset               : std_logic;

  -- NX Frame Delay
  signal nx_frame_word_s             : std_logic_vector(31 downto 0);
  signal nx_frame_clk_s              : std_logic;
  
  -- Clock Domain Transfer NX Data
  signal fifo_nx_reset_i             : std_logic;
  signal fifo_nx_write_enable        : std_logic;
  signal fifo_nx_read_enable         : std_logic;
  signal fifo_nx_empty               : std_logic;
  signal fifo_nx_full                : std_logic;
  signal fifo_nx_data                : std_logic_vector(31 downto 0);
  signal fifo_nx_data_clk_tt         : std_logic;
  signal fifo_nx_data_clk_t          : std_logic;
  signal fifo_nx_data_clk            : std_logic;
  signal nx_data                     : std_logic_vector(31 downto 0);
  signal nx_data_clk                 : std_logic;                               

  -----------------------------------------------------------------------------
  
  -- ADC Ckl Generator               
  signal adc_sclk_skip               : std_logic;
  signal adc_sampling_clk            : std_logic;
  signal johnson_ff_0                : std_logic;
  signal johnson_ff_1                : std_logic;
  signal johnson_counter_sync        : std_logic_vector(1 downto 0);
  signal adc_sclk_ok                 : std_logic;
  signal adc_sclk_ok_c100            : std_logic;

  signal pll_adc_sampling_clk_o      : std_logic;
  signal pll_adc_sampling_clk_lock   : std_logic;
  signal pll_adc_sampling_clk_reset  : std_logic;

  -- PLL ADC Monitor
  signal pll_adc_not_lock            : std_logic;
  signal pll_adc_not_lock_shift      : std_logic_vector(1 downto 0);
  signal pll_adc_not_lock_ctr        : unsigned(11 downto 0);
  signal pll_adc_not_lock_ctr_clear  : std_logic;
  
  -- ADC RESET                     
  signal adc_sclk_ok_last            : std_logic;
  signal adc_reset_sync_s            : std_logic;
  signal adc_reset_sync              : std_logic;
  signal adc_reset_ctr               : unsigned(11 downto 0);

  -----------------------------------------------------------------------------
  -- ADC Data Handler
  -----------------------------------------------------------------------------

  -- ADC Handler
  signal ADC_RESET_AD9228            : std_logic;
  signal adc_data                    : std_logic_vector(11 downto 0);
  signal adc_data_clk                : std_logic;
  signal adc_locked                  : std_logic;
  signal adc_notlocked_p             : std_logic;
  
  signal adc_data_s                  : std_logic_vector(11 downto 0);
  signal adc_data_s_clk              : std_logic;
  signal adc_sloppy_frame            : std_logic;
  signal ADC_DEBUG                   : std_logic_vector(15 downto 0);

  signal adc_error                   : std_logic;
  signal adc_error_p                 : std_logic;
  
  -- Merge Data Streams
  signal adc_data_buffer             : std_logic_vector(11 downto 0);
  signal adc_data_buffer_filled      : std_logic;
  signal data_m                      : std_logic_vector(43 downto 0);
  signal data_clk_m                  : std_logic;
  signal merge_error                 : std_logic;
  signal merge_error_ctr             : unsigned(11 downto 0);  

  -- Data Output Handler
  signal data_o                      : std_logic_vector(43 downto 0);
  signal data_clk_o                  : std_logic;
  
  -- ADC Sampling Clock Phase adjustment
  signal pll_adc_sample_clk_dphase   : std_logic_vector(3 downto 0);
  signal pll_adc_sample_clk_finedelb : std_logic_vector(3 downto 0);

  -- Rate Calculations
  signal nx_frame_rate_ctr           : unsigned(27 downto 0);
  signal nx_frame_rate               : unsigned(27 downto 0);
  signal adc_frame_rate_ctr          : unsigned(27 downto 0);
  signal adc_frame_rate              : unsigned(27 downto 0);
  signal frame_rate_ctr              : unsigned(27 downto 0);
  signal frame_rate                  : unsigned(27 downto 0);
  signal parity_err_rate_ctr         : unsigned(27 downto 0);
  signal parity_err_rate             : unsigned(27 downto 0);
  signal rate_timer_ctr              : unsigned(27 downto 0);
  
  -- Error
  signal error_o                     : std_logic;
  signal error_status_bits           : std_logic_vector(15 downto 0);
  signal adc_notlock_counter         : unsigned(27 downto 0);
  signal adc_error_counter           : unsigned(27 downto 0);
  signal nx_online                   : std_logic;
  signal nx_online_shift             : std_logic_vector(1 downto 0);
  signal reset_after_offline         : std_logic;
  
  -- Rate Errors
  signal nx_frame_rate_error         : std_logic;
  signal adc_frame_rate_error        : std_logic;
  signal frame_rate_error            : std_logic;
  signal parity_rate_error           : std_logic;

  -- Events per Second Errors
  signal nx_frame_not_sync           : std_logic;
  signal nx_frame_not_sync_cur       : std_logic;
  signal adc_dt_error_cur            : std_logic;
  signal adc_dt_error                : std_logic;
  signal timestamp_dt_error_cur      : std_logic;
  signal timestamp_dt_error          : std_logic;
  
  -- Data Stream DeltaT Error Counters
  signal adc_dt_shift_reg            : std_logic_vector(3 downto 0);
  signal timestamp_dt_shift_reg      : std_logic_vector(3 downto 0);
  signal adc_dt_error_ctr            : unsigned(11 downto 0);
  signal timestamp_dt_error_ctr      : unsigned(11 downto 0);

  signal adc_dt_error_p              : std_logic;
  signal adc_dt_error_c100           : std_logic;
  signal timestamp_dt_error_p        : std_logic;
  signal timestamp_dt_error_c100     : std_logic;

  -----------------------------------------------------------------------------
  -- CLK Domain Transfer
  -----------------------------------------------------------------------------

  -- Slave Bus                         
  signal slv_data_out_o                : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o            : std_logic;
                                       
  signal slv_unknown_addr_o            : std_logic;
  signal slv_ack_o                     : std_logic;
                                       
  signal reset_resync_ctr              : std_logic;
  signal reset_parity_error_ctr        : std_logic;
  signal debug_mode                    : std_logic_vector(2 downto 0);
  signal reset_handler_start_r         : std_logic;
  signal johnson_counter_sync_r        : unsigned(1 downto 0);
  signal pll_adc_sample_clk_dphase_r   : unsigned(3 downto 0);
  signal pll_adc_sample_clk_finedelb_r : unsigned(3 downto 0);
  signal nx_timestamp_delay_adjust     : std_logic;
  signal nx_timestamp_delay_r          : unsigned(2 downto 0);
  signal reset_inhibit_r               : std_logic;
  signal nx_timestamp_delay_a          : unsigned(2 downto 0);
  signal nx_timestamp_delay_s          : unsigned(2 downto 0);
  signal nx_timestamp_delay_actr       : unsigned(15 downto 0);
  signal nx_frame_word_delay_rr        : unsigned(1 downto 0);
  signal nx_frame_word_delay_r         : unsigned(1 downto 0);
  signal adc_dt_error_ctr_r            : unsigned(11 downto 0);
  signal timestamp_dt_error_ctr_r      : unsigned(11 downto 0);
  signal merge_error_ctr_r             : unsigned(11 downto 0);
  signal nx_frame_synced_rr            : std_logic;
  signal nx_frame_synced_r             : std_logic;
  signal disable_adc_r                 : std_logic;
  signal adc_debug_type_r              : std_logic_vector(3 downto 0);
  
  -----------------------------------------------------------------------------
  -- Reset Handler
  -----------------------------------------------------------------------------
  signal startup_reset               : std_logic;
  signal rs_wait_timer_start         : std_logic;
  signal rs_wait_timer_done          : std_logic;

  signal rs_timeout_timer_start      : std_logic;
  signal rs_timeout_timer_done       : std_logic;
  signal rs_timeout_timer_reset      : std_logic;

  signal nx_timestamp_reset_o        : std_logic;
  signal nx_fifo_reset_handler       : std_logic;

  signal reset_handler_trigger       : std_logic_vector(15 downto 0);
  
  type R_STATES is (R_IDLE,
                    R_WAIT_INHIBIT,
                    R_START,
                    R_WAIT_0,
                    R_WAIT_NX_FRAME_SYNC,
                    R_RESET_TIMESTAMP,
                    R_WAIT_1,
                    R_SET_ALL_RESETS,
                    R_WAIT_2,
                    R_WAIT_NX_FRAME_RATE_OK,
                    R_WAIT_DATA_HANDLER_OK
                    );
  signal R_STATE :  R_STATES;

  signal reset_inhibit               : std_logic;
  signal frame_rates_reset           : std_logic;
  signal pll_adc_clk_reset           : std_logic;
  signal adc_reset_handler           : std_logic;
  signal adc_reset_p                 : std_logic;
  signal output_handler_reset        : std_logic;
  
  signal reset_handler_counter       : unsigned(15 downto 0);
  signal reset_handler_busy          : std_logic;
  signal reset_timeout_flag          : std_logic;

  -- Resync Counter Process                    
  signal resync_counter              : unsigned(11 downto 0);
  signal resync_ctr_inc              : std_logic;
  signal nx_clk_active               : std_logic;
                                     
  -- Parity Error Counter Process                    
  signal parity_error_b              : std_logic;
  signal parity_error_c100           : std_logic;
  signal parity_error_counter        : unsigned(11 downto 0);

  -- Reset Domain Transfers
  signal reset_nx_timestamp_clk_in_ff : std_logic;
  signal reset_nx_timestamp_clk_in_f  : std_logic;
  signal RESET_NX_TIMESTAMP_CLK_IN    : std_logic;

  signal reset_nx_data_clk_in_ff      : std_logic;
  signal reset_nx_data_clk_in_f       : std_logic;

  signal debug_state                  : std_logic_vector(3 downto 0);
  
  -- Keep FlipFlops, do not change to shift registers ----------- 

  attribute syn_keep : boolean;

  attribute syn_keep of nx_frame_word_f                   : signal is true;
  
  attribute syn_keep of reset_nx_timestamp_clk_in_ff      : signal is true;
  attribute syn_keep of reset_nx_timestamp_clk_in_f       : signal is true;

  attribute syn_keep of reset_nx_data_clk_in_ff           : signal is true;
  attribute syn_keep of reset_nx_data_clk_in_f            : signal is true;

  attribute syn_keep of nx_timestamp_delay_f              : signal is true;
  attribute syn_keep of nx_timestamp_delay                : signal is true;
  
  attribute syn_preserve : boolean;

  attribute syn_preserve of nx_frame_word_f               : signal is true;
  
  attribute syn_preserve of reset_nx_timestamp_clk_in_ff  : signal is true;
  attribute syn_preserve of reset_nx_timestamp_clk_in_f   : signal is true;

  attribute syn_preserve of reset_nx_data_clk_in_ff       : signal is true;
  attribute syn_preserve of reset_nx_data_clk_in_f        : signal is true;

  attribute syn_preserve of nx_timestamp_delay_f          : signal is true;
  attribute syn_preserve of nx_timestamp_delay            : signal is true;

begin

  DFALSE: if (DEBUG_ENABLE = false) generate
    DEBUG_OUT                <= (others => '0');
  end generate DFALSE;
  
  DTRUE: if (DEBUG_ENABLE = true) generate
    PROC_DEBUG_MULT: process(debug_mode,
                             adc_data,
                             adc_data_clk,
                             adc_sclk_ok,
                             adc_sclk_skip,
                             adc_reset_sync,
                             adc_reset_sync_s,
                             ADC_RESET_AD9228,
                             nx_frame_clk,
                             adc_reset_ctr,
                             adc_data_s_clk,
                             data_clk_o,
                             nx_frame_synced,
                             rs_sync_reset
                             )
    begin
      case debug_mode is
        when "001" =>
          -- Reset Handler
          DEBUG_OUT(0)            <= CLK_IN;
          DEBUG_OUT(1)            <= nx_data_clk;
          DEBUG_OUT(2)            <= adc_data_clk; 
          DEBUG_OUT(3)            <= adc_sclk_ok;
          DEBUG_OUT(4)            <= adc_reset_sync;
          DEBUG_OUT(5)            <= adc_reset_handler;
          DEBUG_OUT(6)            <= nx_online;
          DEBUG_OUT(7)            <= pll_adc_not_lock;
          DEBUG_OUT(8)            <= reset_after_offline;
          DEBUG_OUT(9)            <= reset_handler_busy;
          DEBUG_OUT(10)           <= merge_error;
          DEBUG_OUT(11)           <= data_clk_m; --pll_adc_sampling_clk_reset;
          DEBUG_OUT(15 downto 12) <= debug_state;

        when "010" =>
          -- AD9228 Handler Debug output
          DEBUG_OUT               <= ADC_DEBUG;
          
        when "011" =>
          -- Test Channel
          DEBUG_OUT(0)            <= CLK_IN;
          DEBUG_OUT(3 downto 1)   <= debug_state(2 downto 0);
          DEBUG_OUT(4)            <= reset_handler_busy; 
          DEBUG_OUT(5)            <= '0';
          DEBUG_OUT(6)            <= nx_frame_rate_error;
          DEBUG_OUT(7)            <= pll_adc_not_lock;
          DEBUG_OUT(8)            <= '0';
          DEBUG_OUT(9)            <= adc_frame_rate_error;
          DEBUG_OUT(10)           <= nx_fifo_reset_handler;
          DEBUG_OUT(11)           <= pll_adc_sampling_clk_reset;
          DEBUG_OUT(12)           <= adc_reset_handler;
          DEBUG_OUT(13)           <= output_handler_reset;
          DEBUG_OUT(14)           <= frame_rate_error;
          DEBUG_OUT(15)           <= reset_timeout_flag;

        when "100" =>
          -- AD9228 Handler Debug output
          DEBUG_OUT(0)            <= CLK_IN;
          DEBUG_OUT(1)            <= '0';
          DEBUG_OUT(2)            <= nx_frame_clk;
          DEBUG_OUT(3)            <= nx_data_clk;
          DEBUG_OUT(4)            <= adc_data_clk;
          DEBUG_OUT(5)            <= '0';
          DEBUG_OUT(6)            <= adc_dt_error_p; 
          DEBUG_OUT(9 downto 7)   <= (others => '0');
          DEBUG_OUT(10)           <= timestamp_dt_error_p;
          DEBUG_OUT(11)           <= '0';
          DEBUG_OUT(12)           <= merge_error;
          DEBUG_OUT(14 downto 13) <= (others => '0');
          DEBUG_OUT(15)           <= data_clk_o;

        when "101" =>
          -- AD9228 Handler Debug output
          DEBUG_OUT(0)            <= CLK_IN;
          DEBUG_OUT(1)            <= '0';
          DEBUG_OUT(2)            <= nx_frame_clk;
          DEBUG_OUT(3)            <= '0';
          DEBUG_OUT(4)            <= '0';
          DEBUG_OUT(5)            <= merge_error;
          DEBUG_OUT(6)            <= '0';
          DEBUG_OUT(7)            <= '0';
          DEBUG_OUT(9 downto 8)   <= (others => '0');
          DEBUG_OUT(10)           <= '0';
          DEBUG_OUT(11)           <= '0';
          DEBUG_OUT(15 downto 12) <= (others => '0');

        when "110" =>
          DEBUG_OUT(0)            <= nx_frame_clk_s;  --data_clk_o;
          DEBUG_OUT(15 downto 1)  <= nx_frame_word_s(14 downto 0); --data_m(14 downto 0);

        when "111" =>
          DEBUG_OUT(0)            <= nx_data_clk;
          DEBUG_OUT(15 downto 1)  <= nx_data(14 downto 0);
          
        when others =>
          -- Default
          DEBUG_OUT(0)            <= CLK_IN;
          DEBUG_OUT(1)            <= TRIGGER_IN;
          DEBUG_OUT(2)            <= data_clk_o;
          DEBUG_OUT(3)            <= nx_fifo_reset_handler;
          DEBUG_OUT(4)            <= '0';
          DEBUG_OUT(5)            <= '0';
          DEBUG_OUT(6)            <= '0';
          DEBUG_OUT(7)            <= '0';
          DEBUG_OUT(8)            <= '0';
          DEBUG_OUT(9)            <= nx_frame_clk;
          DEBUG_OUT(10)           <= '0';
          DEBUG_OUT(11)           <= adc_data_s_clk;
          DEBUG_OUT(12)           <= data_clk_o;
          DEBUG_OUT(13)           <= parity_error_c100;
          DEBUG_OUT(14)           <= merge_error;
          DEBUG_OUT(15)           <= nx_frame_synced;

      end case;

    end process PROC_DEBUG_MULT;

  end generate DTRUE;
  
  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  reset_nx_timestamp_clk_in_ff  <= RESET_IN
                                   when rising_edge(NX_TIMESTAMP_CLK_IN);
  reset_nx_timestamp_clk_in_f   <= reset_nx_timestamp_clk_in_ff
                                   when rising_edge(NX_TIMESTAMP_CLK_IN); 
  RESET_NX_TIMESTAMP_CLK_IN     <= reset_nx_timestamp_clk_in_f
                                   when rising_edge(NX_TIMESTAMP_CLK_IN);

  -----------------------------------------------------------------------------
  -- PLL Handler
  -----------------------------------------------------------------------------

  PROC_PLL_PHASE_SETUP: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      -- Shift dphase to show 0 as optimal value in standard setup
      pll_adc_sample_clk_dphase     <=
        std_logic_vector(13 + pll_adc_sample_clk_dphase_r);
      pll_adc_sample_clk_finedelb   <=
        std_logic_vector(8 + pll_adc_sample_clk_finedelb_r);
    end if;
  end process  PROC_PLL_PHASE_SETUP;
  
  pll_adc_sampling_clk_2: entity work.pll_adc_sampling_clk
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

  PROC_PLL_LOCK_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if( RESET_IN = '1' or pll_adc_not_lock_ctr_clear = '1') then
        pll_adc_not_lock_shift  <= (others => '0');
        pll_adc_not_lock_ctr    <= (others => '0');
      else
        pll_adc_not_lock_shift(0)  <= pll_adc_not_lock;
        pll_adc_not_lock_shift(1)  <= pll_adc_not_lock_shift(0);
        
        if (pll_adc_not_lock_shift = "01") then
          pll_adc_not_lock_ctr  <= pll_adc_not_lock_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_PLL_LOCK_COUNTER;


  timer_static_RESET_TIMER: timer_static
    generic map (
      CTR_WIDTH => 20,
      CTR_END   => 500000 -- 5ms
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => rs_wait_timer_start,
      TIMER_DONE_OUT => rs_wait_timer_done
      );

  timer_static_RESET_TIMEOUT: timer_static
    generic map (
      CTR_WIDTH => 32,
      CTR_END   => 2000000000 -- 10s
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => rs_timeout_timer_reset,
      TIMER_START_IN => rs_timeout_timer_start,
      TIMER_DONE_OUT => rs_timeout_timer_done
      );
  
  -----------------------------------------------------------------------------
  -- ADC Sampling Clock Generator using a Johnson Counter
  -----------------------------------------------------------------------------

  PROC_ADC_SAMPLING_CLK_GENERATOR: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (adc_sclk_skip = '0') then
        johnson_ff_0     <= not johnson_ff_1;
        johnson_ff_1     <= johnson_ff_0;
      end if;
      adc_sampling_clk   <= not johnson_ff_1;
    end if;
  end process PROC_ADC_SAMPLING_CLK_GENERATOR;

  -- Adjust johnson_counter_sync to show optimal value at 0
  
  PROC_ADC_SAMPLING_CLK_SYNC: process(NX_TIMESTAMP_CLK_IN)
    variable adc_sclk_state : std_logic_vector(1 downto 0);
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        johnson_counter_sync  <= (others => '0');
        adc_sclk_skip         <= '0';
        adc_sclk_ok           <= '0';
      else
        johnson_counter_sync <= std_logic_vector(johnson_counter_sync_r);
        adc_sclk_state        := johnson_ff_1 & johnson_ff_0;
        adc_sclk_skip         <= '0';
        if (nx_frame_clk = '1') then
          if (adc_sclk_state /= johnson_counter_sync) then
            adc_sclk_skip     <= '1';
            adc_sclk_ok       <= '0';
          else
            adc_sclk_ok       <= '1';        
          end if;
        end if;
      end if;
    end if;
  end process PROC_ADC_SAMPLING_CLK_SYNC;
  
  PROC_ADC_RESET: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        adc_sclk_ok_last    <= '0';
        adc_reset_sync_s    <= '0';
      else
        adc_reset_sync_s    <= '0';
        adc_sclk_ok_last    <= adc_sclk_ok;
        if (adc_sclk_ok_last = '0' and adc_sclk_ok = '1') then
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
  -- NX Timestamp Handler 
  -----------------------------------------------------------------------------

  -- First: Use three Input FIFO to relax Timing
  nx_frame_word_ff  <= NX_TIMESTAMP_IN   when rising_edge(NX_TIMESTAMP_CLK_IN);
  nx_frame_word_f   <= nx_frame_word_ff when rising_edge(NX_TIMESTAMP_CLK_IN);
  
  -- Second: Merge TS Data 8bit to 32Bit Timestamp Frame
  PROC_8_TO_32_BIT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        nx_frame_word_t     <= (others => '0');
        nx_frame_word       <= (others => '0');
        nx_frame_clk_t      <= '0';
        nx_frame_clk        <= '0';
      else
        case frame_byte_pos is
          when "11" => nx_frame_word_t(31 downto 24) <= nx_frame_word_f;
                       nx_frame_clk_t                <= '0';
                       
          when "10" => nx_frame_word_t(23 downto 16) <= nx_frame_word_f;
                       nx_frame_clk_t                <= '0';

          when "01" => nx_frame_word_t(15 downto  8) <= nx_frame_word_f;
                       nx_frame_clk_t                <= '0';

          when "00" => nx_frame_word_t( 7 downto  0) <= nx_frame_word_f;
                       nx_frame_clk_t                <= '1';
        end case;

        -- Output Frame
        if (nx_frame_clk_t = '1') then
          nx_frame_word                              <= nx_frame_word_t;
          nx_frame_clk                               <= '1';
        else
          nx_frame_word                              <= x"0000_0001";
          nx_frame_clk                               <= '0';
        end if;
      end if;
    end if;
  end process PROC_8_TO_32_BIT;
  
  -- TS Frame Sync process
  PROC_SYNC_TO_NX_FRAME: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        frame_byte_pos    <= "11";
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
      else
        rs_sync_set       <= '0';
        rs_sync_reset     <= '0';
        if (nx_frame_clk_t = '1') then
          case nx_frame_word_t is
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
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        nx_frame_synced     <= '0';
      else
        if (rs_sync_reset = '1') then
          nx_frame_synced   <= '0';
        elsif (rs_sync_set = '1') then
          nx_frame_synced   <= '1';
        end if;
      end if;
    end if;
  end process PROC_RS_FRAME_SYNCED;
  
  -- Check Parity Bit
  PROC_PARITY_CHECKER: process(NX_TIMESTAMP_CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
    variable parity      : std_logic;
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_NX_TIMESTAMP_CLK_IN = '1') then
        parity_error_b       <= '0';
      else
        if (nx_frame_clk = '1') then
          -- Timestamp Bit #6 is excluded (funny nxyter-bug)
          parity_bits      := nx_frame_word(31)           &
                              nx_frame_word(30 downto 24) &
                              nx_frame_word(21 downto 16) &
                              nx_frame_word(14 downto  8) &
                              nx_frame_word( 2 downto  1);
          parity           := xor_all(parity_bits);

          if (parity /= nx_frame_word(0)) then
            parity_error_b   <= '1';
          else
            parity_error_b   <= '0';
          end if;
        else
          parity_error_b     <= '0';
        end if;
      end if;
    end if;
  end process PROC_PARITY_CHECKER;

  -- Delay NX Data relative to ADC Data
  dynamic_shift_register33x64_1: entity work.dynamic_shift_register33x64
    port map (
      Din(31 downto 0) => nx_frame_word,
      Din(32)          => nx_frame_clk,
      Addr             => nx_shift_register_delay,
      Clock            => NX_TIMESTAMP_CLK_IN,
      ClockEn          => '1',
      Reset            => RESET_NX_TIMESTAMP_CLK_IN,
      Q(31 downto 0)   => nx_frame_word_s,
      Q(32)            => nx_frame_clk_s
      );
  
  -- Timestamp Input Delay relative to ADC
  nx_timestamp_delay_f  <= nx_timestamp_delay_s
                           when rising_edge(NX_TIMESTAMP_CLK_IN);
  nx_timestamp_delay    <= nx_timestamp_delay_f
                           when rising_edge(NX_TIMESTAMP_CLK_IN);
  PROC_NX_SHIFT_REGISTER_DELAY: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if(RESET_NX_TIMESTAMP_CLK_IN = '1') then
        nx_shift_register_delay       <= (others => '0');
      else
        case nx_timestamp_delay is
          when "000" =>                  
            nx_shift_register_delay   <= "001111"; -- 15
            
          when "001" =>                  
            nx_shift_register_delay   <= "010011"; -- 19

          when "010" =>                  
            nx_shift_register_delay   <= "010111"; -- 23
            
          when "011" =>                  
            nx_shift_register_delay   <= "011011"; -- 27
            
          when "100" =>                  
            nx_shift_register_delay   <= "011111"; -- 31
            
          when "101" =>                  
            nx_shift_register_delay   <= "100011"; -- 35
            
          when "110" =>                  
            nx_shift_register_delay   <= "100111"; -- 39

          when "111" =>                  
            nx_shift_register_delay   <= "101011"; -- 43
          
        end case;
      end if;
    end if;
  end process PROC_NX_SHIFT_REGISTER_DELAY;

  -----------------------------------------------------------------------------
  -- Clock Domain Transfer Nxyter Data Stream
  -----------------------------------------------------------------------------
  
  fifo_nxyter_32to32_dc_1: entity work.fifo_nxyter_32to32_dc
    port map (
      Data    => nx_frame_word_s,
      WrClock => NX_TIMESTAMP_CLK_IN,
      RdClock => CLK_IN,
      WrEn    => fifo_nx_write_enable,
      RdEn    => fifo_nx_read_enable,
      Reset   => RESET_IN,
      RPReset => fifo_nx_reset_i,
      Q       => fifo_nx_data,
      Empty   => fifo_nx_empty,
      Full    => fifo_nx_full
      );

  fifo_nx_reset_i         <= RESET_IN or nx_fifo_reset_handler;
  fifo_nx_write_enable    <= not fifo_nx_full and nx_frame_clk_s;
  fifo_nx_read_enable     <= not fifo_nx_empty;

  PROC_NX_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      fifo_nx_data_clk_tt    <= fifo_nx_read_enable;
      if(RESET_IN = '1') then
        fifo_nx_data_clk_t    <= '0';
        fifo_nx_data_clk      <= '0';
      else
        -- Delay read signal by two Clock Cycles
        fifo_nx_data_clk_t    <= fifo_nx_data_clk_tt;
        fifo_nx_data_clk      <= fifo_nx_data_clk_t;
      end if;
    end if;
  end process PROC_NX_FIFO_READ_ENABLE;

  PROC_NX_FIFO_READ_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if(RESET_IN = '1') then
        nx_data         <= (others => '0');      
        nx_data_clk     <= '0';
      else
        if (fifo_nx_data_clk = '1') then
         nx_data        <= fifo_nx_data;
         nx_data_clk    <= '1';
        else
         nx_data        <= (others => '0');      
         nx_data_clk    <= '0'; 
        end if;
      end if;
    end if;
  end process PROC_NX_FIFO_READ_HANDLER;

  -----------------------------------------------------------------------------
  -- ADC Input Handler
  -----------------------------------------------------------------------------

  ADC_RESET_AD9228         <= RESET_IN or adc_reset_handler;

  adc_ad9228_1: adc_ad9228
    generic map (
      DEBUG_ENABLE => false
      )
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      CLK_ADCDAT_IN        => ADC_CLK_DAT_IN,
      RESET_ADCS           => ADC_RESET_AD9228,

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
      ADC0_DATA_B_OUT      => open,
      ADC0_DATA_C_OUT      => open,
      ADC0_DATA_D_OUT      => open,
      ADC0_DATA_CLK_OUT    => adc_data_clk,
                           
      ADC1_DATA_A_OUT      => open,
      ADC1_DATA_B_OUT      => open,
      ADC1_DATA_C_OUT      => open,
      ADC1_DATA_D_OUT      => open,
      ADC1_DATA_CLK_OUT    => open,

      ADC0_LOCKED_OUT      => adc_locked,
      ADC1_LOCKED_OUT      => open,

      ADC0_SLOPPY_FRAME    => adc_sloppy_frame,
      ADC1_SLOPPY_FRAME    => '0',

      ADC0_ERROR_OUT       => adc_error,
      ADC1_ERROR_OUT       => open,

      DEBUG_IN             => adc_debug_type_r,
      DEBUG_OUT            => ADC_DEBUG
      );

  -----------------------------------------------------------------------------
  -- Merge Data Streams Timestamps and ADC Value
  -----------------------------------------------------------------------------

  PROC_DATA_MERGE_HANDLER_TRANSFER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1' or output_handler_reset = '1') then
        data_m                  <= (others => '0');
        data_clk_m              <= '0';
        adc_data_buffer         <= (others => '0');
        adc_data_buffer_filled  <= '0';
        merge_error             <= '0';
      else
        data_m                  <= (others => '0');
        data_clk_m              <= '0';
        merge_error             <= '0';

        if (nx_data_clk = '1') then
          -- Look for ADC Data
          if (adc_data_clk = '1') then
            data_m(43 downto 32)    <= adc_data;
          elsif (adc_data_buffer_filled = '1') then
            data_m(43 downto 32)    <= adc_data_buffer;
            adc_data_buffer_filled  <= '0';
          else
            -- No ADC Data Available, error
            data_m(43 downto 32)    <= (others => '0');
            merge_error             <= '1';
          end if;

          data_m(31 downto 0)       <= nx_data;
          data_clk_m                <= '1';

        elsif (adc_data_clk = '1') then
          if (adc_data_buffer_filled = '0') then
            adc_data_buffer         <= adc_data;
            adc_data_buffer_filled  <= '1';
          else
            -- Already Full, error
            merge_error             <= '1';
            adc_data_buffer_filled  <= '0';
          end if;
        end if;

      end if;
    end if;
  end process PROC_DATA_MERGE_HANDLER_TRANSFER;

   -----------------------------------------------------------------------------
  -- Signal Domain Transfers
  -----------------------------------------------------------------------------
  signal_async_trans_2: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => not pll_adc_sampling_clk_lock,
      SIGNAL_OUT  => pll_adc_not_lock
      );

  pulse_dtrans_parity_error: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => NX_TIMESTAMP_CLK_IN,
      RESET_A_IN  => RESET_NX_TIMESTAMP_CLK_IN,
      PULSE_A_IN  => parity_error_b,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => parity_error_c100
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
  
  signal_async_trans_ADC_SCLK_OK: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => adc_sclk_ok,
      SIGNAL_OUT  => adc_sclk_ok_c100
      );
  
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

  -----------------------------------------------------------------------------
  -- Status Counters
  -----------------------------------------------------------------------------

  level_to_pulse_ADC_NOTLOCKED: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => not adc_locked,
      PULSE_OUT => adc_notlocked_p
      );

  level_to_pulse_ADC_ERROR: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => adc_error,
      PULSE_OUT => adc_error_p
      );
  
  -- Counters
  PROC_RESYNC_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
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
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1' or reset_parity_error_ctr = '1') then
        parity_error_counter   <= (others => '0');
      else
        if (parity_error_c100 = '1') then
          parity_error_counter <= parity_error_counter + 1;
        end if;
      end if;
    end if;
  end process PROC_PARITY_ERROR_COUNTER;

  PROC_MERGE_ERROR_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then 
        merge_error_ctr          <= (others => '0'); 
      else
        if (merge_error = '1') then
          merge_error_ctr        <= merge_error_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_MERGE_ERROR_COUNTER;
  
  -----------------------------------------------------------------------------
  -- Rate Counters + Rate Error Check
  -----------------------------------------------------------------------------

  PROC_RATE_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1' or frame_rates_reset = '1') then
        nx_frame_rate_ctr      <= (others => '0');
        nx_frame_rate          <= (others => '0');
        adc_frame_rate_ctr     <= (others => '0');
        adc_frame_rate         <= (others => '0');
        frame_rate_ctr         <= (others => '0');
        frame_rate             <= (others => '0');
        parity_err_rate_ctr    <= (others => '0');
        parity_err_rate        <= (others => '0');
        rate_timer_ctr         <= (others => '0');
      else
        if (rate_timer_ctr < x"5f5e100") then
          rate_timer_ctr                    <= rate_timer_ctr + 1;

          if (nx_data_clk = '1') then
            nx_frame_rate_ctr               <= nx_frame_rate_ctr + 1;
          end if;                           
                                            
          if (adc_data_clk = '1') then    
            adc_frame_rate_ctr              <= adc_frame_rate_ctr + 1;
          end if;                           
                                            
          if (data_clk_o = '1') then        
            frame_rate_ctr                  <= frame_rate_ctr + 1;
          end if;                           
                                            
          if (parity_error_c100 = '1') then      
            parity_err_rate_ctr             <= parity_err_rate_ctr + 1;
          end if;                           
        else                                
          rate_timer_ctr                    <= (others => '0');
          nx_frame_rate                     <= nx_frame_rate_ctr;
          adc_frame_rate                    <= adc_frame_rate_ctr;
          frame_rate                        <= frame_rate_ctr;
          parity_err_rate                   <= parity_err_rate_ctr;
                                            
          nx_frame_rate_ctr(27 downto 1)    <= (others => '0');
          nx_frame_rate_ctr(0)              <= nx_data_clk;
                                            
          adc_frame_rate_ctr(27 downto 1)   <= (others => '0');
          adc_frame_rate_ctr(0)             <= adc_data_clk;
                                            
          frame_rate_ctr(27 downto 1)       <= (others => '0');
          frame_rate_ctr(0)                 <= data_clk_o;

          parity_err_rate_ctr(27 downto 1)  <= (others => '0');
          parity_err_rate_ctr(0)            <= parity_error_c100;
        end if;
        
      end if;
    end if;
  end process PROC_RATE_COUNTER;
  
  -- Check Rates for errors
  PROC_RATE_ERRORS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        nx_frame_rate_error        <= '1';
        adc_frame_rate_error       <= '1';
        frame_rate_error           <= '1';
        parity_rate_error          <= '1';
      else
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

        if (parity_err_rate > 2) then
          parity_rate_error        <= '1';
        else
          parity_rate_error        <= '0';
        end if;
      end if;
    end if;
  end process PROC_RATE_ERRORS;

  -----------------------------------------------------------------------------
 
  adc_dt_error_c100 <= adc_dt_error_p;
  timestamp_dt_error_c100 <= timestamp_dt_error_p;
    
  PROC_EVENT_ERRORS_PER_SECOND: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1' or frame_rates_reset = '1') then
        nx_frame_not_sync_cur   <= '0';
        nx_frame_not_sync       <= '1';
        adc_dt_error_cur        <= '0';
        adc_dt_error            <= '1';
        timestamp_dt_error_cur  <= '0';
        timestamp_dt_error      <= '1';
      else
        if (rate_timer_ctr < x"5f5e100") then
          if (nx_frame_synced_r = '0') then
            nx_frame_not_sync_cur   <= '1';
          end if;
          if (adc_dt_error_c100 = '1') then
            adc_dt_error_cur        <= '1';
          end if;
          if (timestamp_dt_error_c100 = '1') then
            timestamp_dt_error_cur  <= '1';
          end if;
        else
          nx_frame_not_sync         <= nx_frame_not_sync_cur;
          adc_dt_error              <= adc_dt_error_cur;
          timestamp_dt_error        <= timestamp_dt_error_cur;
          nx_frame_not_sync_cur     <= '0';
          adc_dt_error_cur          <= '0';
          timestamp_dt_error_cur    <= '0';
        end if;
      end if;
    end if;
  end process PROC_EVENT_ERRORS_PER_SECOND;
    
  PROC_DATA_STREAM_DELTA_T: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        adc_dt_shift_reg        <= (others => '0');
        timestamp_dt_shift_reg  <= (others => '0');
        adc_dt_error_ctr        <= (others => '0');
        timestamp_dt_error_ctr  <= (others => '0');  
      else
             
        -- ADC
        adc_dt_shift_reg(0)          <= adc_data_clk;
        adc_dt_shift_reg(3 downto 1) <= adc_dt_shift_reg(2 downto 0);
        
        case adc_dt_shift_reg is
          when "1100" | "1110" | "1111" | "0000" =>
            adc_dt_error_ctr         <= adc_dt_error_ctr + 1;
            adc_dt_error_p           <= '1';
            
          when others =>
            adc_dt_error_p           <= '0';
            
        end case;

        -- TimeStamp
        timestamp_dt_shift_reg(0)    <= nx_data_clk;
        timestamp_dt_shift_reg(3 downto 1)
          <= timestamp_dt_shift_reg(2 downto 0);
        
        case timestamp_dt_shift_reg is
          when "1100" | "1110" | "0000" =>
            timestamp_dt_error_ctr   <= timestamp_dt_error_ctr + 1;
            timestamp_dt_error_p     <= '1';

          when others =>
            timestamp_dt_error_p     <= '0';

        end case;

      end if;
    end if;
  end process PROC_DATA_STREAM_DELTA_T;

  -----------------------------------------------------------------------------
  -- Reset Handler
  -----------------------------------------------------------------------------

  pll_adc_sampling_clk_reset        <= pll_adc_clk_reset or adc_reset_sync;  

  reset_inhibit                     <= (not disable_adc_r and
                                        ADC_TR_ERROR_IN) or
                                       reset_inhibit_r;
  
  PROC_RESET_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if( RESET_IN = '1' ) then
        frame_rates_reset           <= '0';
        nx_fifo_reset_handler       <= '0';
        pll_adc_clk_reset           <= '0';
        output_handler_reset        <= '0';
        adc_reset_p                 <= '0';
        adc_reset_handler           <= '0';

        rs_wait_timer_start         <= '0';
        rs_timeout_timer_start      <= '0';
        rs_timeout_timer_reset      <= '1';
        reset_handler_counter       <= (others => '0');
        reset_handler_busy          <= '0';
        reset_timeout_flag          <= '0';
        startup_reset               <= '1';
        nx_timestamp_reset_o        <= '0';
        reset_handler_trigger       <= (others => '0');
        R_STATE                     <= R_IDLE;
      else
        frame_rates_reset           <= '0';
        pll_adc_clk_reset           <= '0';
        nx_fifo_reset_handler       <= '0';
        output_handler_reset        <= '0';
        adc_reset_p                 <= '0';
        adc_reset_handler           <= '0';

        rs_wait_timer_start         <= '0';
        rs_timeout_timer_start      <= '0';
        rs_timeout_timer_reset      <= '0';
        reset_handler_busy          <= '1';
        nx_timestamp_reset_o        <= '0';

        debug_state                 <= x"0";

        if (nx_online = '0') then
          -- If Nxyter is 0ffline nothing will happen
          rs_timeout_timer_reset    <= '1';
          reset_timeout_flag        <= '0';
          R_STATE                   <= R_IDLE;
        elsif (reset_handler_start_r = '1') then
          -- Reset by register always wins, start it
          rs_timeout_timer_reset    <= '1';
          reset_timeout_flag        <= '0';
          reset_handler_trigger(0)  <= '1';
          reset_handler_trigger(15 downto 1) <= (others => '0');
          R_STATE                   <= R_START;
        elsif (rs_timeout_timer_done = '1') then
          -- Reset Timeout, retry RESET
          rs_timeout_timer_reset    <= '1';
          reset_timeout_flag        <= '1';
          reset_handler_trigger(0)  <= '0';
          reset_handler_trigger(1)  <= '1';
          reset_handler_trigger(15 downto 2) <= (others => '0');
          R_STATE                   <= R_START;
        else
          
          case R_STATE is
            when R_IDLE => 
              if (nx_online = '1') then
                if (reset_inhibit = '1') then
                  rs_wait_timer_start       <= '1';
                  R_STATE                   <= R_WAIT_INHIBIT;
                elsif (nx_frame_not_sync     = '1' or 
                       nx_frame_rate_error   = '1' or
                       timestamp_dt_error    = '1' or
                       parity_rate_error     = '1' or
                       frame_rate_error      = '1' or
                       reset_after_offline   = '1' or
                       startup_reset         = '1'
                       ) then

                  reset_handler_trigger(1 downto 0) <= (others => '0');
                  reset_handler_trigger( 2) <= startup_reset;
                  reset_handler_trigger( 3) <= nx_frame_not_sync;
                  reset_handler_trigger( 4) <= timestamp_dt_error;
                  reset_handler_trigger( 5) <= parity_rate_error; 
                  reset_handler_trigger( 6) <= frame_rate_error;
                  reset_handler_trigger( 7) <= reset_after_offline;
                  reset_handler_trigger( 8) <= startup_reset;
                  reset_handler_trigger(15 downto 9) <= (others => '0');
                  
                  R_STATE                 <= R_START;
                else 
                  reset_timeout_flag      <= '0';
                  rs_timeout_timer_reset  <= '1';
                  reset_handler_busy      <= '0';
                  R_STATE                 <= R_IDLE;
                end if;
              else
                reset_timeout_flag        <= '0';
                rs_timeout_timer_reset    <= '1';
                reset_handler_busy        <= '0';
                R_STATE                   <= R_IDLE;
              end if;
              debug_state                <= x"1";

            when R_WAIT_INHIBIT =>
              if (rs_wait_timer_done = '0') then
                R_STATE                  <= R_WAIT_INHIBIT;
              else
                frame_rates_reset        <= '1';
                R_STATE                  <= R_IDLE;
              end if;
              debug_state                <= x"b";
              
            when R_START =>
              -- First wait 1mue for NX_MAIN_CLK, have to put lock status here
              -- to check in the future.
              rs_wait_timer_start        <= '1';
              R_STATE                    <= R_WAIT_0;
              debug_state                <= x"2";
              
            when R_WAIT_0 =>
              if (rs_wait_timer_done = '0') then
                R_STATE                  <= R_WAIT_0;
              else
                R_STATE                  <= R_RESET_TIMESTAMP;
              end if;  
              debug_state                <= x"3";  
              
            when R_RESET_TIMESTAMP =>
              -- must reset/resync Timestamp clock and data transmission clock
              -- of nxyter first, afterwards wait a bit to let settle down
              reset_handler_counter      <= reset_handler_counter + 1;
              nx_timestamp_reset_o       <= '1';
              rs_wait_timer_start        <= '1';  -- wait 1mue to settle
              R_STATE                    <= R_WAIT_1;  
              debug_state                <= x"4";

            when R_WAIT_1 =>
              if (rs_wait_timer_done = '0') then
                R_STATE                  <= R_WAIT_1;
              else
                R_STATE                  <= R_SET_ALL_RESETS;
              end if;  
              debug_state                <= x"5";  

            when R_SET_ALL_RESETS =>
              -- timer reset should be finished, can we check status,
              -- To be done?
              -- now set reset of all handlers
              frame_rates_reset          <= '1';
              pll_adc_clk_reset          <= '1';
              nx_fifo_reset_handler      <= '1';
              output_handler_reset       <= '1';
              
              -- give resets 1mue to take effect  
              rs_wait_timer_start        <= '1';  
              R_STATE                    <= R_WAIT_2;
              debug_state                <= x"6";
                            
            when R_WAIT_2 =>
              frame_rates_reset          <= '1';
              pll_adc_clk_reset          <= '1';
              nx_fifo_reset_handler      <= '1';
              output_handler_reset       <= '1';
              if (rs_wait_timer_done = '0') then
                R_STATE                  <= R_WAIT_2;
              else
                -- now start timeout timer and begin to release resets
                -- step by step
                rs_timeout_timer_start   <= '1';
                R_STATE                  <= R_WAIT_NX_FRAME_SYNC;
              end if;
              debug_state                <= x"7"; 

            when R_WAIT_NX_FRAME_SYNC =>
              pll_adc_clk_reset          <= '1';
              nx_fifo_reset_handler      <= '1';
              output_handler_reset       <= '1';
              if (nx_frame_not_sync = '1') then
                R_STATE                  <= R_WAIT_NX_FRAME_SYNC;
              else
                -- Next: Release PLL Reset, i.e. sampling_clk_reset
                --       Release NX FIFO Reset
                R_STATE                  <= R_WAIT_NX_FRAME_RATE_OK;
              end if;
              debug_state                <= x"8";

            when R_WAIT_NX_FRAME_RATE_OK =>
              output_handler_reset     <= '1';
              if (nx_frame_rate_error   = '1') then
                R_STATE                <= R_WAIT_NX_FRAME_RATE_OK;
              else
                -- Next: Release Output Handler Reset
                R_STATE                <= R_WAIT_DATA_HANDLER_OK;
              end if;
                debug_state                <= x"9";
              
            when R_WAIT_DATA_HANDLER_OK =>
              if (frame_rate_error  = '1') then
                R_STATE                 <= R_WAIT_DATA_HANDLER_OK;
              else
                startup_reset           <= '0';
                reset_timeout_flag      <= '0';
                rs_timeout_timer_reset  <= '1';
                R_STATE                 <= R_IDLE;
              end if;
              debug_state               <= x"a";
          end case;
        end if;
      end if;
    end if;
  end process PROC_RESET_HANDLER;

  -----------------------------------------------------------------------------
  -- Error Status
  -----------------------------------------------------------------------------
  PROC_ERROR_STATUS: process(CLK_IN)
    variable error_mask : std_logic_vector(15 downto 0);
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        nx_online                <= '0';
        nx_online_shift          <= (others => '0');
        reset_after_offline      <= '0';
        error_status_bits        <= (others => '0');
        error_o                  <= '0';
        adc_notlock_counter      <= (others => '0');
        adc_error_counter        <= (others => '0');
      else
        error_status_bits(0)             <= not nx_online;
        error_status_bits(1)             <= frame_rate_error;
        error_status_bits(2)             <= nx_frame_rate_error;
        error_status_bits(3)             <= adc_frame_rate_error;
        error_status_bits(4)             <= parity_rate_error;
        error_status_bits(5)             <= not nx_frame_synced_r;
        error_status_bits(6)             <= '0';
        error_status_bits(7)             <= pll_adc_not_lock;
        error_status_bits(8)             <= not adc_sclk_ok_c100;
        error_status_bits(9)             <= not adc_locked;
        error_status_bits(10)            <= timestamp_dt_error;
        error_status_bits(11)            <= adc_dt_error;
        error_status_bits(12)            <= reset_handler_busy;
        error_status_bits(15 downto 13)  <= (others => '0');

        nx_online                  <= NX_CLOCK_ON_IN and NX_ONLINE_IN;
        nx_online_shift(0)         <= nx_online;
        nx_online_shift(1)         <= nx_online_shift(0);
        if (nx_online_shift = "01") then
          reset_after_offline      <= '1';
        else
          reset_after_offline      <= '0';
        end if;

        if (disable_adc_r = '1') then
          error_mask := x"f437";
        else
          error_mask := x"0000";
        end if;
                        
        if ((error_status_bits and error_mask) = x"0000") then
          error_o                        <= '0';
        else
          error_o                        <= '1';
        end if;

        if (adc_notlocked_p = '1') then
         adc_notlock_counter             <= adc_notlock_counter + 1;
        end if;

        if (adc_error_p = '1') then
         adc_error_counter               <= adc_error_counter + 1;
        end if;

      end if;
    end if;
  end process PROC_ERROR_STATUS;

  PROC_NX_TIMESTAMP_DELAY_ADJUST: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        nx_timestamp_delay_a          <= (others => '0');
        nx_timestamp_delay_actr       <= (others => '0'); 
      else
        -- Automatic nx_timestamp_delay adjust
        if (disable_adc_r = '0' and
            nx_timestamp_delay_adjust = '1'
            and ADC_TR_ERROR_IN = '1') then
          if (nx_timestamp_delay_a <= "100") then
            nx_timestamp_delay_a      <= nx_timestamp_delay_a + 1;
          else
            nx_timestamp_delay_a      <= (others => '0');
          end if;
          nx_timestamp_delay_actr     <= nx_timestamp_delay_actr + 1;
        end if;

        -- Multiplexer
        if (nx_timestamp_delay_adjust = '1') then
          nx_timestamp_delay_s        <= nx_timestamp_delay_a;
        else
          nx_timestamp_delay_s        <= nx_timestamp_delay_r;
        end if;
      end if;
    end if;
  end process PROC_NX_TIMESTAMP_DELAY_ADJUST;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  PROC_SLAVE_BUS_BUFFER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      nx_frame_synced_rr                <= nx_frame_synced;
      
      if (RESET_IN = '1') then
        nx_frame_synced_r               <= '0';
        adc_dt_error_ctr_r              <= (others => '0');
        timestamp_dt_error_ctr_r        <= (others => '0');
        merge_error_ctr_r               <= (others => '0');
      else
        nx_frame_synced_r               <= nx_frame_synced_rr;
        adc_dt_error_ctr_r              <= adc_dt_error_ctr;
        timestamp_dt_error_ctr_r        <= timestamp_dt_error_ctr;
        merge_error_ctr_r               <= merge_error_ctr;
      end if;
    end if;
  end process PROC_SLAVE_BUS_BUFFER;
  
  -- Slave Bus
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if( RESET_IN = '1' ) then
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';

        reset_resync_ctr              <= '0';
        reset_parity_error_ctr        <= '0';
        johnson_counter_sync_r        <= "00";
        pll_adc_sample_clk_dphase_r   <= x"5";
        pll_adc_sample_clk_finedelb_r <= (others => '0');
        pll_adc_not_lock_ctr_clear    <= '0';
        nx_timestamp_delay_adjust     <= '1';
        nx_timestamp_delay_r          <= "011";
        reset_inhibit_r               <= '0';
        reset_handler_start_r         <= '0';
        adc_debug_type_r              <= (others => '0');
        debug_mode                    <= (others => '0');
        disable_adc_r                 <= '0';
        adc_sloppy_frame              <= '0';
      else                      
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';
        reset_resync_ctr              <= '0';
        reset_parity_error_ctr        <= '0';
        pll_adc_not_lock_ctr_clear    <= '0';
        reset_handler_start_r         <= '0';
        reset_inhibit_r               <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(15 downto 0)   <= error_status_bits;
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0001" =>
              slv_data_out_o(0)             <= reset_handler_busy;
              slv_data_out_o(1)             <= reset_timeout_flag;
              slv_data_out_o(15 downto 2)   <= (others => '0');
              slv_data_out_o(31 downto 16)  <= reset_handler_trigger;
              slv_ack_o                     <= '1';  
                       
            when x"0002" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(frame_rate); 
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"0003" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(nx_frame_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';  
              
            when x"0004" =>
              slv_data_out_o(27 downto 0)   <= std_logic_vector(adc_frame_rate);
              slv_data_out_o(30 downto 28)  <= (others => '0');
              slv_data_out_o(30)            <= adc_sloppy_frame;
              slv_data_out_o(31)            <= disable_adc_r;
              slv_ack_o                     <= '1';  

            when x"0005" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(parity_err_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0006" =>
              slv_data_out_o(2 downto 0)    <=
                std_logic_vector(nx_timestamp_delay_s);
              slv_data_out_o(14 downto 3)   <= (others => '0');
              slv_data_out_o(15)            <= nx_timestamp_delay_adjust;
              slv_data_out_o(31 downto 16)  <= nx_timestamp_delay_actr;
              slv_ack_o                     <= '1';

            when x"0007" =>
              slv_data_out_o(3 downto 0)    <=
                std_logic_vector(pll_adc_sample_clk_dphase_r);
              slv_data_out_o(15 downto 4)   <= (others => '0');
              slv_data_out_o(19 downto 16)  <=
                std_logic_vector(pll_adc_sample_clk_finedelb_r);
              slv_data_out_o(31 downto 20)   <= (others => '0');
              slv_ack_o                     <= '1';
                  
            when x"0008" =>
              slv_data_out_o(15 downto 0)   <=
                std_logic_vector(reset_handler_counter);
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0009" =>
              slv_data_out_o(11 downto 0)   <=
                std_logic_vector(adc_reset_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000a" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(adc_notlock_counter);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
            
            when x"000b" =>
              slv_data_out_o(11 downto 0)   <=
                std_logic_vector(merge_error_ctr_r);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"000c" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(resync_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"000d" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(parity_error_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"000e" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(pll_adc_not_lock_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';     
                 
            when x"000f" =>
              slv_data_out_o(11 downto 0)   <=
                std_logic_vector(adc_dt_error_ctr_r);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0010" =>
              slv_data_out_o(11 downto 0)   <=
                std_logic_vector(timestamp_dt_error_ctr_r);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0011" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(adc_error_counter);
              slv_data_out_o(31 downto 15)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"001d" =>
              slv_data_out_o(1 downto  0)   <= johnson_counter_sync_r;
              slv_data_out_o(31 downto 2)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"001e" =>
              slv_data_out_o(2 downto 0)    <= debug_mode;
              slv_data_out_o(31 downto 3)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"001f" =>
              slv_data_out_o(3 downto 0)    <= adc_debug_type_r;
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';

            when others  =>
              slv_unknown_addr_o            <= '1';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" =>
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1';

            when x"0004" =>                   
              disable_adc_r                 <= SLV_DATA_IN(31); 
              adc_sloppy_frame              <= SLV_DATA_IN(30);
              reset_inhibit_r               <= '1';
              slv_ack_o                     <= '1';

            when x"0006" =>
              nx_timestamp_delay_r          <=
                unsigned(SLV_DATA_IN(2 downto 0));
              nx_timestamp_delay_adjust     <= SLV_DATA_IN(15);
              reset_inhibit_r               <= '1';
              slv_ack_o                     <= '1';

            when x"0007" =>
              pll_adc_sample_clk_dphase_r   <=
                unsigned(SLV_DATA_IN(3 downto 0));
              pll_adc_sample_clk_finedelb_r <=
                unsigned(SLV_DATA_IN(19 downto 16));
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1';   
    

            when x"000c" => 
              reset_resync_ctr              <= '1';
              slv_ack_o                     <= '1'; 

            when x"000d" => 
              reset_parity_error_ctr        <= '1';
              slv_ack_o                     <= '1'; 

            when x"000e" =>
              pll_adc_not_lock_ctr_clear    <= '1';
              slv_ack_o                     <= '1';
          
            when x"001d" =>
              johnson_counter_sync_r
                <= unsigned(SLV_DATA_IN(1 downto 0)) + 1;
              reset_handler_start_r         <= '1';
              slv_ack_o                     <= '1'; 
          
            when x"001e" =>
              debug_mode                    <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                     <= '1';

            when x"001f" =>
              adc_debug_type_r              <=
                unsigned(SLV_DATA_IN(3 downto 0));
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o            <= '1';
              
          end case;                
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;

  -- Output Signals
  data_o                   <= data_m;
  data_clk_o               <= data_clk_m;
  
  NX_TIMESTAMP_RESET_OUT   <= nx_timestamp_reset_o;
  DATA_OUT                 <= data_o;
  DATA_CLK_OUT             <= data_clk_o;
  ADC_SCLK_LOCK_OUT        <= pll_adc_sampling_clk_lock;
  DISABLE_ADC_OUT          <= disable_adc_r;
  ERROR_OUT                <= error_o;
                           
  SLV_DATA_OUT             <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT     <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT     <= slv_unknown_addr_o;
  SLV_ACK_OUT              <= slv_ack_o;
  
end Behavioral;
