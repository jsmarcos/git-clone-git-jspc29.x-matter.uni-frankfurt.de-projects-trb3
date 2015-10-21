library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity nx_trigger_validate is
  generic (
    BOARD_ID               : std_logic_vector(1 downto 0) := "11";
    VERSION_NUMBER         : std_logic_vector(3 downto 0) := x"1"
    );
  port (
    CLK_IN                 : in  std_logic;  
    RESET_IN               : in  std_logic;
    
    -- Inputs              
    DATA_CLK_IN            : in  std_logic;
    TIMESTAMP_IN           : in  std_logic_vector(13 downto 0);
    CHANNEL_IN             : in  std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_IN    : in  std_logic_vector(2 downto 0);  -- 2: Parity Err
    ADC_DATA_IN            : in  std_logic_vector(11 downto 0); -- 1: Pileup
    NX_TOKEN_RETURN_IN     : in  std_logic;                     -- 0: Ovfl
    NX_NOMORE_DATA_IN      : in  std_logic;
    
    TRIGGER_IN             : in  std_logic;
    TRIGGER_CALIBRATION_IN : in std_logic;
    TRIGGER_BUSY_IN        : in  std_logic;
    FAST_CLEAR_IN          : in  std_logic;
    TRIGGER_BUSY_OUT       : out std_logic;
    TIMESTAMP_FPGA_IN      : in  unsigned(11 downto 0);
    DATA_FIFO_DELAY_OUT    : out std_logic_vector(7 downto 0);
    
    -- Event Buffer I/O    
    DATA_OUT               : out std_logic_vector(31 downto 0);
    DATA_CLK_OUT           : out std_logic;
    NOMORE_DATA_OUT        : out std_logic;
    EVT_BUFFER_CLEAR_OUT   : out std_logic;
    EVT_BUFFER_FULL_IN     : in  std_logic; 
    
    -- Histogram
    HISTOGRAM_RESET_OUT    : out std_logic;
    HISTOGRAM_FILL_OUT     : out std_logic;
    HISTOGRAM_BIN_OUT      : out std_logic_vector(6 downto 0);
    HISTOGRAM_ADC_OUT      : out std_logic_vector(11 downto 0);
    HISTOGRAM_TS_OUT       : out std_logic_vector(8 downto 0);
    HISTOGRAM_PILEUP_OUT   : out std_logic;
    HISTOGRAM_OVERFLOW_OUT : out std_logic;

    -- Slave bus         
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;
    
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );

end entity;

architecture Behavioral of nx_trigger_validate is

  constant S_PARITY            : integer := 2;
  constant S_PILEUP            : integer := 1;
  constant S_OVFL              : integer := 0;
  
  -- Process Channel_Status
  signal channel_index         : std_logic_vector(6 downto 0);
  signal channel_wait          : std_logic_vector(127 downto 0);
  signal channel_done          : std_logic_vector(127 downto 0);
  signal channel_hit           : std_logic_vector(127 downto 0);
  signal channel_all_done      : std_logic;
  
  signal channel_done_r        : std_logic_vector(127 downto 0);
  signal channel_wait_r        : std_logic_vector(127 downto 0);
  signal channel_hit_r         : std_logic_vector(127 downto 0);
  signal channel_all_done_r    : std_logic;
  signal token_update          : std_logic;

  -- Channel Status Commands
  type CS_CMDS is (CS_RESET,
                   CS_CLEAR_WAIT,
                   CS_TOKEN_UPDATE,
                   CS_SET_WAIT,
                   CS_SET_HIT,
                   CS_SET_DONE,
                   CS_NONE
                   );
  signal channel_status_cmd    : CS_CMDS; 
  
  -- Process Calculate Trigger Window
  signal fifo_delay_time       : unsigned(11 downto 0);
  
  -- Process Timestamp
  signal d_data_o              : std_logic_vector(31 downto 0);
  signal d_data_clk_o          : std_logic;
  signal out_of_window_l       : std_logic;
  signal out_of_window_h       : std_logic;
  signal window_hit            : std_logic;
  signal out_of_window_error   : std_logic;
  signal ch_status_cmd_pr      : CS_CMDS;

  -- Window Status Counter
  signal out_of_window_l_ctr   : unsigned(15 downto 0);
  signal window_hit_ctr        : unsigned(15 downto 0);
  signal out_of_window_h_ctr   : unsigned(15 downto 0);
  signal out_of_window_l_ctr_r : unsigned(15 downto 0);
  signal window_hit_ctr_r      : unsigned(15 downto 0);
  signal out_of_window_h_ctr_r : unsigned(15 downto 0);
  signal validation_busy       : std_logic_vector(1 downto 0);
  
  -- Rate Calculations
  signal data_rate_ctr_nr      : unsigned(31 downto 0);       
  signal data_rate_ctr         : unsigned(27 downto 0);
  signal data_rate             : unsigned(27 downto 0);
  signal rate_timer_ctr        : unsigned(27 downto 0);

  -- Self Trigger Mode
  signal self_trigger_mode     : std_logic;

  -- Process Trigger Handler
  signal store_to_fifo         : std_logic;
  signal trigger_busy_o        : std_logic;
  signal nomore_data_o         : std_logic;
  signal wait_timer_start      : std_logic;
  signal wait_timer_start_ns   : std_logic;
  signal wait_timer_init_ns    : unsigned(19 downto 0);
  signal token_return_last     : std_logic;
  signal token_return_first    : std_logic;
  signal ch_status_cmd_tr      : CS_CMDS;
  signal wait_for_data_time_r  : std_logic_vector(19 downto 0);
  signal min_validation_time_r : std_logic_vector(19 downto 0);
  signal skip_wait_for_data    : std_logic;
  signal trigger_calibration   : std_logic;
    
  type STATES is (S_TEST_SELF_TRIGGER,
                  S_IDLE,
                  S_TRIGGER,
                  S_WAIT_DATA,
                  S_WRITE_HEADER,
                  S_PROCESS_START,
                  S_WAIT_PROCESS_END,
                  S_WRITE_TRAILER,
                  S_SET_NOMORE_DATA
                  );
  signal STATE : STATES;

  signal t_data_o              : std_logic_vector(31 downto 0);
  signal t_data_clk_o          : std_logic;
  signal busy_time_ctr         : unsigned(11 downto 0);
  signal wait_timer_reset_all  : std_logic;
  signal min_val_time_expired  : std_logic;
  signal event_counter         : unsigned(9 downto 0);
  signal out_of_window_error_ctr : unsigned(15 downto 0);
  
  signal readout_mode          : std_logic_vector(3 downto 0);
  signal timestamp_fpga_ff     : unsigned(11 downto 0);
  signal timestamp_fpga_f      : unsigned(11 downto 0);
  signal timestamp_fpga        : unsigned(11 downto 0);
  signal timestamp_ref         : unsigned(11 downto 0);
  signal busy_time_ctr_last    : unsigned(11 downto 0);
  signal evt_buffer_clear_o    : std_logic;
  
  -- Timers                     
  signal timer_reset           : std_logic;
  signal wait_timer_done       : std_logic;
  signal wait_timer_done_ns    : std_logic;
  
  -- Histogram
  signal histogram_fill_o      : std_logic;
  signal histogram_bin_o       : std_logic_vector(6 downto 0);
  signal histogram_adc_o       : std_logic_vector(11 downto 0);
  signal histogram_ts_o        : std_logic_vector(8 downto 0);
  signal histogram_pileup_o    : std_logic;
  signal histogram_ovfl_o      : std_logic;

  signal histogram_ts_range    : std_logic_vector(2 downto 0);

  -- Data FIFO Delay           
  signal data_fifo_delay_o     : unsigned(7 downto 0);
  
  -- Output
  signal data_clk_o            : std_logic;
  signal data_o                : std_logic_vector(31 downto 0);
  
  -- Slave Bus                     
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;
  
  signal readout_mode_r                : std_logic_vector(3 downto 0);

  signal out_of_window_error_ctr_clear : std_logic;

  signal histogram_trig_filter : std_logic;
  signal histogram_limits      : std_logic;
  signal histogram_lower_limit : unsigned(13 downto 0);
  signal histogram_upper_limit : unsigned(13 downto 0);
  signal reset_hists           : std_logic;
  signal reset_hists_o         : std_logic;
  
  -- Timestamp Trigger Window Settings
  signal nxyter_cv_time            : unsigned(11 downto 0);
  signal cts_trigger_delay         : unsigned(11 downto 0);
  signal trigger_calibration_delay : unsigned(11 downto 0);
  signal ts_window_offset          : signed(11 downto 0);
  signal ts_window_width           : unsigned(9 downto 0);
  signal readout_time_max          : unsigned(11 downto 0);
  signal fpga_timestamp_offset     : unsigned(11 downto 0);
  
  signal state_d                   : std_logic_vector(1 downto 0);

  -----------------------------------------------------------------------------
  
  attribute syn_keep : boolean;
  attribute syn_keep of timestamp_fpga_ff     : signal is true;
  attribute syn_keep of timestamp_fpga_f      : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of timestamp_fpga_ff : signal is true;
  attribute syn_preserve of timestamp_fpga_f  : signal is true;
  
begin
  
  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= TRIGGER_IN;
  DEBUG_OUT(2)            <= trigger_busy_o;
  DEBUG_OUT(3)            <= DATA_CLK_IN;
  DEBUG_OUT(4)            <= out_of_window_l;
  DEBUG_OUT(5)            <= out_of_window_h;
  DEBUG_OUT(6)            <= NX_TOKEN_RETURN_IN;
  DEBUG_OUT(7)            <= NX_NOMORE_DATA_IN;
  DEBUG_OUT(8)            <= channel_all_done;
  DEBUG_OUT(9)            <= store_to_fifo;
  DEBUG_OUT(10)           <= data_clk_o;
  DEBUG_OUT(11)           <= out_of_window_error; -- or EVT_BUFFER_FULL_IN;
  DEBUG_OUT(12)           <= TIMESTAMP_STATUS_IN(S_PARITY);
  DEBUG_OUT(13)           <= min_val_time_expired;
  DEBUG_OUT(14)           <= token_update;
  DEBUG_OUT(15)           <= nomore_data_o;

  -- Timer
  timer_1: timer
    generic map(
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => timer_reset,
      TIMER_START_IN => wait_timer_start,
      TIMER_END_IN   => readout_time_max,
      TIMER_DONE_OUT => wait_timer_done
      );

  timer_2: timer
    generic map(
      CTR_WIDTH => 20,
      STEP_SIZE => 10
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => timer_reset,
      TIMER_START_IN => wait_timer_start_ns,
      TIMER_END_IN   => wait_timer_init_ns,
      TIMER_DONE_OUT => wait_timer_done_ns
      );
  
  timer_reset <= RESET_IN or wait_timer_reset_all;
  
  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_FILTER_TIMESTAMPS: process (CLK_IN)
    variable cts_trigger_delay_tmp     : unsigned(11 downto 0);
    variable ts_window_offset_unsigned : unsigned(11 downto 0);
    variable window_lower_thr          : unsigned(11 downto 0);
    variable window_upper_thr          : unsigned(11 downto 0);
    variable ts_window_check_value     : unsigned(11 downto 0);
    variable deltaTStore               : unsigned(13 downto 0);
    variable histTStore                : unsigned(8 downto 0);
    variable store_data                : std_logic;
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        d_data_o                 <= (others => '0');
        d_data_clk_o             <= '0';
        out_of_window_l          <= '0';
        out_of_window_h          <= '0';
        window_hit               <= '0';
        out_of_window_error      <= '0';
        fifo_delay_time          <= (others => '0');
        out_of_window_error_ctr  <= (others => '0');

        histogram_fill_o         <= '0';
        histogram_bin_o          <= (others => '0');
        histogram_adc_o          <= (others => '0');
        histogram_ts_o           <= (others => '0');
        histogram_pileup_o       <= '0';
        histogram_ovfl_o         <= '0';
      else
        d_data_o                 <= (others => '0');
        d_data_clk_o             <= '0';
        out_of_window_l          <= '0';
        out_of_window_h          <= '0';
        window_hit               <= '0';
        out_of_window_error      <= '0';
        fifo_delay_time          <= (others => '0');
        ch_status_cmd_pr         <= CS_NONE;
        
        histogram_fill_o         <= '0';
        histogram_bin_o          <= (others => '0');
        histogram_adc_o          <= (others => '0');
        histogram_ts_o           <= (others => '0');
        histogram_pileup_o       <= '0';
        histogram_ovfl_o         <= '0';
        
        -----------------------------------------------------------------------
        -- Calculate Thresholds and values for FIFO Delay
        -----------------------------------------------------------------------

        cts_trigger_delay_tmp  := cts_trigger_delay;
                
        if (ts_window_offset(11) = '1') then
          -- Offset is negative
          ts_window_offset_unsigned :=
            (unsigned(ts_window_offset) xor x"fff") + 1;
          window_lower_thr       :=
            cts_trigger_delay_tmp + ts_window_offset_unsigned;
        else
          -- Offset is positive
          window_lower_thr       :=
            cts_trigger_delay_tmp - unsigned(ts_window_offset);
        end if;

        -- Calculate FIFO Delay 
        if (window_lower_thr(11) = '0') then
          fifo_delay_time        <= window_lower_thr;  -- unit is 4ns
        else
          fifo_delay_time        <= (others => '0');   
        end if;

        -- Final lower Threshold value relative to TS Reference TS
        window_lower_thr         := timestamp_fpga - window_lower_thr;  
        window_upper_thr         :=
          window_lower_thr + resize(ts_window_width, 12);
          
        ts_window_check_value    :=
          unsigned(TIMESTAMP_IN(13 downto 2)) - window_lower_thr;
        
        -- Timestamp to be stored
        deltaTStore(13 downto 2) := ts_window_check_value;
        deltaTStore( 1 downto 0) := unsigned(TIMESTAMP_IN(1 downto 0));
        
        -----------------------------------------------------------------------
        -- Validate incoming Data
        -----------------------------------------------------------------------
        if (DATA_CLK_IN = '1') then
          
          if (store_to_fifo = '1' and EVT_BUFFER_FULL_IN = '0') then
            store_data                       := '0';
            
            -- TS Window Check  
            if (ts_window_check_value(11) = '1') then
              -- TS below Window: Set WAIT Bit in LUT and discard Data
              channel_index                  <= CHANNEL_IN;
              ch_status_cmd_pr               <= CS_SET_WAIT;
              out_of_window_l                <= '1';
              store_data                     := '0';
            elsif (ts_window_check_value > ts_window_width) then
              -- TS above Window: Set DONE Bit in LUT and discard Data
              channel_index                  <= CHANNEL_IN;
              ch_status_cmd_pr               <= CS_SET_DONE;
              out_of_window_h                <= '1';
              store_data                     := '0';
            elsif ((ts_window_check_value >= 0) and
                   (ts_window_check_value <= ts_window_width)) then
              -- TS in between Window: Set WAIT Bit in LUT and Take Data
              channel_index                  <= CHANNEL_IN;
              ch_status_cmd_pr               <= CS_SET_HIT;
              window_hit                     <= '1';
              store_data                     := '1';
            else
              -- TS Window Error condition, do nothing
              out_of_window_error            <= '1';
              store_data                     := '0';
              if (out_of_window_error_ctr_clear = '0') then
                out_of_window_error_ctr      <= out_of_window_error_ctr + 1;
              end if;
            end if;

            -- TS Window Disabled, always store data 
            if (readout_mode(2)   = '1' or
                self_trigger_mode = '1') then
              store_data                     := '1';
            end if;
            
            if (store_data = '1') then

              case readout_mode(1 downto 0) is              
                
                when "00" =>
                  -- Default Mode
                  if (TIMESTAMP_STATUS_IN(S_PARITY) = '0') then
                    d_data_o(10 downto  0)     <= deltaTStore(10 downto  0);
                    d_data_o(22 downto 11)     <= ADC_DATA_IN;
                    d_data_o(23)               <= TIMESTAMP_STATUS_IN(S_OVFL);
                    d_data_o(24)               <= TIMESTAMP_STATUS_IN(S_PILEUP);
                    d_data_o(31 downto 25)     <= CHANNEL_IN;
                    d_data_clk_o               <= '1';
                  end if;

                when "01" =>
                  -- Extended Timestamp Mode 12Bit
                  if (TIMESTAMP_STATUS_IN(S_PARITY) = '0') then
                    d_data_o(11 downto  0)     <= deltaTStore(11 downto  0);
                    d_data_o(22 downto 12)     <= ADC_DATA_IN(11 downto 1);
                    d_data_o(23)               <= TIMESTAMP_STATUS_IN(S_OVFL);
                    d_data_o(24)               <= TIMESTAMP_STATUS_IN(S_PILEUP);
                    d_data_o(31 downto 25)     <= CHANNEL_IN;
                    d_data_clk_o               <= '1';
                  end if;

                when "10" =>
                  -- Extended Timestamp Mode 14Bit
                  if (TIMESTAMP_STATUS_IN(S_PARITY) = '0') then
                    d_data_o(13 downto  0)     <= deltaTStore;
                    d_data_o(22 downto 14)     <= ADC_DATA_IN(11 downto 3);
                    d_data_o(23)               <= TIMESTAMP_STATUS_IN(S_OVFL);
                    d_data_o(24)               <= TIMESTAMP_STATUS_IN(S_PILEUP);
                    d_data_o(31 downto 25)     <= CHANNEL_IN;
                    d_data_clk_o               <= '1';
                  end if;

                when "11" =>
                  if (TIMESTAMP_STATUS_IN(S_PARITY) = '0') then
                    d_data_o(13 downto  0)     <= deltaTStore;
                    d_data_o(24 downto 14)     <= ADC_DATA_IN(11 downto 1);
                    d_data_o(31 downto 25)     <= CHANNEL_IN;
                    d_data_clk_o               <= '1';
                  end if;

              end case;

              -- Fill Histogram
              if (histogram_trig_filter = '1') then
                case histogram_ts_range is
                  when  "000"  =>
                    histTStore         := deltaTStore( 8 downto 0);
                  when  "001"  =>      
                    histTStore         := deltaTStore( 9 downto 1);
                  when  "010"  =>      
                    histTStore         := deltaTStore(10 downto 2);
                  when  "011"  =>
                    histTStore         := deltaTStore(11 downto 3);
                  when  "100"  =>
                    histTStore         := deltaTStore(12 downto 4);
                  when  "101" =>
                    histTStore         := deltaTStore(13 downto 5);
                  when others =>
                    histTStore         := deltaTStore(12 downto 4);
                end case;
                
                if (histogram_limits = '1') then
                  if (deltaTStore >= histogram_lower_limit and
                      deltaTStore <= histogram_upper_limit) then
                    histogram_fill_o     <= '1';
                    histogram_bin_o      <= CHANNEL_IN;
                    histogram_adc_o      <= ADC_DATA_IN;
                    histogram_ts_o       <= histTStore;
                    histogram_pileup_o   <= TIMESTAMP_STATUS_IN(S_PILEUP);
                    histogram_ovfl_o     <= TIMESTAMP_STATUS_IN(S_OVFL);      
                  end if;
                else
                  histogram_fill_o       <= '1';
                  histogram_bin_o        <= CHANNEL_IN;
                  histogram_adc_o        <= ADC_DATA_IN;
                  histogram_ts_o         <= histTStore;
                  histogram_pileup_o     <= TIMESTAMP_STATUS_IN(S_PILEUP);
                  histogram_ovfl_o       <= TIMESTAMP_STATUS_IN(S_OVFL); 
                end if;
              end if;
            end if;

            if (out_of_window_error_ctr_clear = '1') then
              out_of_window_error_ctr          <= (others => '0');
            end if;
          end if;

          -- Fill Histogram
          if (histogram_trig_filter = '0') then
            histogram_fill_o                   <= '1';
            histogram_bin_o                    <= CHANNEL_IN;
            histogram_adc_o                    <= ADC_DATA_IN;
            histogram_ts_o                     <= (others => '0');
            histogram_pileup_o                 <= TIMESTAMP_STATUS_IN(S_PILEUP);
            histogram_ovfl_o                   <= TIMESTAMP_STATUS_IN(S_OVFL);
          end if;
          
        end if;
      end if;
    end if;
  end process PROC_FILTER_TIMESTAMPS;

  PROC_WINDOW_STATE_CTR: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        out_of_window_l_ctr     <= (others => '0');
        window_hit_ctr          <= (others => '0');
        out_of_window_h_ctr     <= (others => '0');
        out_of_window_l_ctr_r   <= (others => '0');
        window_hit_ctr_r        <= (others => '0');
        out_of_window_h_ctr_r   <= (others => '0');
        validation_busy         <= (others => '0');
      else
        validation_busy(0)           <= store_to_fifo;
        validation_busy(1)           <= validation_busy(0);

        case validation_busy is
          when "00"=>                   -- No validation
            out_of_window_l_ctr      <= (others => '0');
            window_hit_ctr           <= (others => '0');
            out_of_window_h_ctr      <= (others => '0');
            
          when "01"=>                   -- Start validation
            out_of_window_l_ctr      <= (others => '0');
            window_hit_ctr           <= (others => '0');
            out_of_window_h_ctr      <= (others => '0');
            
          when "10"=>                   -- End validation
            out_of_window_l_ctr_r    <= out_of_window_l_ctr;
            window_hit_ctr_r         <= window_hit_ctr;
            out_of_window_h_ctr_r    <= out_of_window_h_ctr;
            
          when "11" =>                  -- Validation
            if (out_of_window_l = '1') then
              out_of_window_l_ctr    <= out_of_window_l_ctr + 1;
            end if;

            if (window_hit = '1') then
              window_hit_ctr         <= window_hit_ctr + 1;
            end if;

            if (out_of_window_h = '1') then
              out_of_window_h_ctr    <= out_of_window_h_ctr + 1;
            end if;

        end case;
      end if;
    end if;
  end process PROC_WINDOW_STATE_CTR;

  PROC_RATE_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        data_rate_ctr_nr       <= (others => '0');      
        data_rate_ctr          <= (others => '0');
        data_rate              <= (others => '0');
        rate_timer_ctr         <= (others => '0');
      else
        if (rate_timer_ctr < x"5f5e100") then
          rate_timer_ctr             <= rate_timer_ctr + 1;

          if (d_data_clk_o = '1') then
            data_rate_ctr            <= data_rate_ctr + 1;
            data_rate_ctr_nr         <= data_rate_ctr_nr + 1;
          end if;
        else
          rate_timer_ctr             <= (others => '0');
          data_rate                  <= data_rate_ctr;

          data_rate_ctr(27 downto 0) <= (others => '0');
          data_rate_ctr(0)           <= d_data_clk_o;
        end if;
      end if;
    end if;
  end process PROC_RATE_COUNTER;
  
  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------

  -- Set Self Trigger Mode Toggle Handler
  PROC_SELF_TRIGGER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        self_trigger_mode    <= '0';
      else
        if (trigger_busy_o = '0') then
          if (readout_mode_r(3) = '1') then
            self_trigger_mode  <= '1';
          else
            self_trigger_mode  <= '0';
          end if;
        end if;
      end if;
    end if;
  end process PROC_SELF_TRIGGER;

  timestamp_fpga_ff <= TIMESTAMP_FPGA_IN when rising_edge(CLK_IN);
  timestamp_fpga_f  <= timestamp_fpga_ff  when rising_edge(CLK_IN);
  
  PROC_TRIGGER_HANDLER: process(CLK_IN)
    variable wait_for_data_time    : unsigned(19 downto 0);
    variable min_validation_time   : unsigned(19 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or FAST_CLEAR_IN = '1') then
        store_to_fifo               <= '0';
        trigger_busy_o              <= '0';
        nomore_data_o               <= '0';
        wait_timer_start            <= '0';
        wait_timer_start_ns         <= '0';
        wait_timer_reset_all        <= '0';
        min_val_time_expired        <= '0';
        t_data_o                    <= (others => '0');
        t_data_clk_o                <= '0';
        busy_time_ctr               <= (others => '0');
        busy_time_ctr_last          <= (others => '0');
        token_return_last           <= '0';
        token_return_first          <= '0';
        ch_status_cmd_tr            <= CS_RESET;
        event_counter               <= (others => '0');
        readout_mode                <= (others => '0');
        timestamp_fpga              <= (others => '0');
        timestamp_ref               <= (others => '0');
        evt_buffer_clear_o          <= '0';
        wait_for_data_time_r        <= (others => '0');
        min_validation_time_r       <= (others => '0');
        trigger_calibration         <= '0';
        STATE                       <= S_TEST_SELF_TRIGGER;
      else
        store_to_fifo               <= '0';
        wait_timer_start            <= '0';
        wait_timer_start_ns         <= '0';
        wait_timer_reset_all        <= '0';
        trigger_busy_o              <= '1';
        nomore_data_o               <= '0';
        t_data_o                    <= (others => '0');
        t_data_clk_o                <= '0';
        ch_status_cmd_tr            <= CS_NONE;
        evt_buffer_clear_o          <= '0';

        -- Wait for Data and minimum Validation Time calculation
        min_validation_time         := resize(ts_window_width * 4, 20);        
        wait_for_data_time          :=
          resize(nxyter_cv_time, 20) + data_fifo_delay_o * 32 + 280; --320;

        -- ?????????????????????????
        if (skip_wait_for_data = '1') then
          min_validation_time       :=
            min_validation_time + wait_for_data_time;  
          wait_for_data_time        := x"00001";
        end if;

        if (trigger_calibration = '1') then
          min_validation_time       :=
            min_validation_time + resize(trigger_calibration_delay, 20);
        end if;

        min_validation_time_r       <= min_validation_time;
        wait_for_data_time_r        <= wait_for_data_time;
        
        -- Check Token Return
        token_return_last           <= NX_TOKEN_RETURN_IN;
        if (store_to_fifo      = '1' and  -- min_val_time handled by TK-UPDATE
            NX_TOKEN_RETURN_IN = '1' and
            token_return_last  = '0') then
          if (min_val_time_expired = '1') then
            if (token_return_first = '1') then
              ch_status_cmd_tr        <= CS_TOKEN_UPDATE;
            else 
              token_return_first      <= '1';
              ch_status_cmd_tr        <= CS_CLEAR_WAIT;
            end if;                
          else
            ch_status_cmd_tr          <= CS_CLEAR_WAIT;
          end if;         
        end if;
        
        case STATE is

          when S_TEST_SELF_TRIGGER =>
            state_d <= "00";
            
            if (self_trigger_mode = '1') then
              -- Wait End of LVL2 Trigger Cycle
              if (TRIGGER_BUSY_IN = '1') then
                STATE                     <= S_TEST_SELF_TRIGGER;
              else
                readout_mode              <= readout_mode_r;
                timestamp_ref             <= (others => '0');
                STATE                     <= S_WRITE_HEADER;
              end if;
            else
              wait_timer_reset_all        <= '1';
              min_val_time_expired        <= '0';
              STATE                       <= S_IDLE;
            end if;
            
          when S_IDLE =>
            state_d <= "01";

            if (TRIGGER_IN = '1') then
              busy_time_ctr               <= (others => '0');
              trigger_calibration         <= TRIGGER_CALIBRATION_IN;
              STATE                       <= S_TRIGGER;
            else
              trigger_calibration         <= '0';
              trigger_busy_o              <= '0';
              min_val_time_expired        <= '0';
              if (self_trigger_mode = '1') then
                ch_status_cmd_tr          <= CS_RESET;
                store_to_fifo             <= '1';
              end if;
              STATE                       <= S_IDLE;
            end if;
            
          when S_TRIGGER =>
            if (self_trigger_mode = '0') then
              readout_mode                <= readout_mode_r;
              
              -- wait for data arrival and clear evt buffer
              wait_timer_start_ns         <= '1';
              wait_timer_init_ns          <= wait_for_data_time;
              evt_buffer_clear_o          <= '1';
              STATE                       <= S_WAIT_DATA;
            else
              STATE                       <= S_WRITE_TRAILER;
            end if;

          when S_WAIT_DATA =>
            if (wait_timer_done_ns = '0') then
              STATE                       <= S_WAIT_DATA;
            else
              -- If Self-Trigger-Mode active set TS Ref to zero 
              if (self_trigger_mode = '1') then
                timestamp_fpga            <= (others => '0');
              else
                timestamp_fpga            <=
                  timestamp_fpga_f + fpga_timestamp_offset;
              end if;

              if (trigger_calibration = '1') then
                timestamp_fpga            <=
                  timestamp_fpga_f + trigger_calibration_delay;
              end if;
              STATE                       <= S_WRITE_HEADER;
            end if;

          when S_WRITE_HEADER =>
            state_d                       <= "10";
            timestamp_ref                 <= timestamp_fpga;

            t_data_o(11 downto 0)         <= timestamp_fpga;
            t_data_o(21 downto 12)        <= event_counter;
            -- Readout Mode Mapping
            -- Bit #3: self Triger mode
            -- Bit #2: 0: activate TS Selection Window
            --         1: disable TS Selection Window, i.e.
            --            data will be written to disk as long as
            --            Readout Time Max (Reg.: 0x8184) is valid
            --
            -- Bit #1..0: 00: Standard
            --            01: UNDEF
            --            10: UNDEF
            --            11: UNDEF
            t_data_o(25 downto 22)        <= readout_mode;
            t_data_o(29 downto 26)        <= VERSION_NUMBER;
            t_data_o(31 downto 30)        <= BOARD_ID;
            t_data_clk_o                  <= '1';
            
            event_counter                 <= event_counter + 1;
            if (self_trigger_mode = '0') then
              STATE                       <= S_PROCESS_START;
            else
              STATE                       <= S_IDLE;
            end if;
            
          when S_PROCESS_START =>
            wait_timer_start              <= '1';
            wait_timer_start_ns           <= '1';
            wait_timer_init_ns            <= min_validation_time;
            token_return_first            <= '0'; 
            ch_status_cmd_tr              <= CS_RESET;
            store_to_fifo                 <= '1';
            STATE                         <= S_WAIT_PROCESS_END;
            
          when S_WAIT_PROCESS_END =>
            -- Check minimum validation time
            if (wait_timer_done_ns = '1') then
              min_val_time_expired        <= '1';
            end if;

            -- Always Exit in case of maximum validation time has expired
            if (wait_timer_done     = '1') then
              wait_timer_reset_all        <= '1';
              STATE                       <= S_WRITE_TRAILER;
            elsif (readout_mode(2)      = '0' and
                   min_val_time_expired = '1' and
                   (channel_all_done     = '1' or
                    NX_NOMORE_DATA_IN    = '1')
                   ) then
              wait_timer_reset_all        <= '1';
              STATE                       <= S_WRITE_TRAILER;
            else
              -- Continue Validation
              store_to_fifo               <= '1';
              STATE                       <= S_WAIT_PROCESS_END;
            end if;

          when S_WRITE_TRAILER =>
            state_d                       <= "11";
            t_data_o                      <= (others => '1');
            t_data_clk_o                  <= '1';
            STATE                         <= S_SET_NOMORE_DATA;

          when S_SET_NOMORE_DATA =>
            nomore_data_o                 <= '1';
            busy_time_ctr_last            <= busy_time_ctr;
            STATE                         <= S_TEST_SELF_TRIGGER;
            
        end case;
        
        if (STATE /= S_IDLE) then
          busy_time_ctr                   <= busy_time_ctr + 1;
        end if;      
        
      end if;
    end if;
  end process PROC_TRIGGER_HANDLER;

  -----------------------------------------------------------------------------
  -- Channel Status Handler
  -----------------------------------------------------------------------------

  PROC_CHANNEL_STATUS_CMD: process(ch_status_cmd_tr,
                                   ch_status_cmd_pr)
  begin
    if (ch_status_cmd_tr /= CS_NONE) then
      channel_status_cmd   <= ch_status_cmd_tr;
    elsif (ch_status_cmd_pr /= CS_NONE) then
      channel_status_cmd   <= ch_status_cmd_pr;
    else
      channel_status_cmd   <= CS_NONE;
    end if;
  end process PROC_CHANNEL_STATUS_CMD;

  PROC_CHANNEL_STATUS: process(CLK_IN)
    constant all_one : std_logic_vector(127 downto 0) := (others => '1');
    
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        channel_wait          <= (others => '0');
        channel_done          <= (others => '0');
        channel_hit           <= (others => '0');
        channel_done_r        <= (others => '0');
        channel_wait_r        <= (others => '0');
        channel_hit_r         <= (others => '0');
        channel_all_done      <= '0';
        channel_all_done_r    <= '0';
        token_update          <= '0';
      else
        token_update          <= '0';
        -- Check done status
        if (channel_status_cmd /= CS_RESET ) then 
          if (channel_done = all_one) then
            channel_all_done  <= '1';
          end if;
        else
          channel_all_done    <= '0';          
          channel_all_done_r  <= channel_all_done;
        end if;

        -- Process Command
        case channel_status_cmd is

          when CS_RESET =>
            channel_wait      <= (others => '0');
            channel_done      <= (others => '0');
            channel_hit       <= (others => '0');
            channel_done_r    <= channel_done;
            channel_hit_r     <= channel_hit;
            channel_wait_r    <= channel_wait;

          when CS_CLEAR_WAIT =>
            channel_wait    <= (others => '0');
            
          when CS_TOKEN_UPDATE =>
            channel_done    <= channel_done or (not channel_wait);
            token_update    <= '1';
            channel_wait    <= (others => '0');
            
          when CS_SET_WAIT =>
            channel_wait(to_integer(unsigned(channel_index))) <= '1';

          when CS_SET_HIT =>
            channel_hit(to_integer(unsigned(channel_index)))  <= '1';
            channel_wait(to_integer(unsigned(channel_index))) <= '1';
            
          when CS_SET_DONE =>
            channel_done(to_integer(unsigned(channel_index))) <= '1';
            
          when CS_NONE => null;

        end case;
      end if;
    end if;
  end process PROC_CHANNEL_STATUS;

  PROC_DATA_FIFO_DELAY: process(CLK_IN)
    variable nx_cvt     : unsigned(11 downto 0);  -- convertion time in 4n steps
    variable fifo_delay : unsigned(11 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        data_fifo_delay_o       <= x"01";
      else
        -- nxyter delay assumed to be 400ns
        nx_cvt                 := nxyter_cv_time / 4;
        if (fifo_delay_time > nx_cvt and fifo_delay_time < 1000) then
          fifo_delay            := (fifo_delay_time - nx_cvt) / 8;   
          data_fifo_delay_o     <= fifo_delay(7 downto 0);
        else
          data_fifo_delay_o     <= x"01";
        end if;
      end if;
    end if;
  end process PROC_DATA_FIFO_DELAY;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';
        
        ts_window_offset              <= (others => '0');
        ts_window_width               <= "0001100100"; -- 100  = 400ns
        cts_trigger_delay             <= x"019";       -- 25   = 100ns
        readout_mode_r                <= "0000";
        readout_time_max              <= x"3e8";       -- 1000 = 10mus
        histogram_trig_filter         <= '1';
        fpga_timestamp_offset         <= (others => '0');
        out_of_window_error_ctr_clear <= '0';
        skip_wait_for_data            <= '0';
        nxyter_cv_time                <= x"190";       -- 400ns

        histogram_lower_limit         <= (others => '0');
        histogram_upper_limit         <= (others => '1');
        reset_hists                   <= '0';
        histogram_limits              <= '0';
        histogram_trig_filter         <= '0';
        histogram_ts_range            <= "100";
        trigger_calibration_delay     <= x"190";       -- 400ns
      else
        slv_data_out_o                   <= (others => '0');
        slv_unknown_addr_o               <= '0';
        slv_no_more_data_o               <= '0';

        cts_trigger_delay(11 downto 10)  <= (others => '0'); 
        readout_time_max(11 downto 10)   <= (others => '0'); 
        out_of_window_error_ctr_clear    <= '0';
        reset_hists                      <= '0';

        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o( 3 downto  0)    <= readout_mode_r;
              slv_data_out_o(31 downto  5)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"0001" =>
              slv_data_out_o(11 downto  0)    <=
                std_logic_vector(ts_window_offset(11 downto 0));
              if (ts_window_offset(11) = '1') then
                slv_data_out_o(31 downto 12)  <= (others => '1');
              else
                slv_data_out_o(31 downto 12)  <= (others => '0');
              end if;
              slv_ack_o                       <= '1';

            when x"0002" =>
              slv_data_out_o(9 downto  0)     <=
                std_logic_vector(ts_window_width);
              slv_data_out_o(31 downto 10)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"0003" =>
              slv_data_out_o(9 downto  0)     <=
                std_logic_vector(cts_trigger_delay(9 downto 0));
              slv_data_out_o(15 downto 10)    <= (others => '0');
              slv_data_out_o(27 downto 16)    <=
                std_logic_vector(trigger_calibration_delay);
              slv_data_out_o(31 downto 28)    <= (others => '0');
              slv_ack_o                       <= '1'; 
              
            when x"0004" =>
              slv_data_out_o(9 downto  0)     <=
                std_logic_vector(readout_time_max(9 downto 0));
              slv_data_out_o(31 downto 10)    <= (others => '0');
              slv_ack_o                       <= '1'; 

            when x"0005" =>
              slv_data_out_o(11 downto  0)    <=
                std_logic_vector(fpga_timestamp_offset);
              slv_data_out_o(31 downto 12)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"0006" =>
              slv_data_out_o(11 downto  0)    <=
                std_logic_vector(busy_time_ctr_last);
              slv_data_out_o(31 downto 12)    <= (others => '0');
              slv_ack_o                       <= '1'; 

            when x"0007" =>
              slv_data_out_o(11 downto  0)    <= timestamp_ref;
              slv_data_out_o(31 downto 12)    <= (others => '0');
              slv_ack_o                       <= '1';  

            when x"0008" =>
              slv_data_out_o(11 downto  0)    <= fifo_delay_time;
              slv_data_out_o(31 downto 12)    <= (others => '0');
              slv_ack_o                       <= '1';  

            when x"0009" =>
              slv_data_out_o(15 downto  0)    <= out_of_window_error_ctr;
              slv_data_out_o(31 downto 16)    <= (others => '0');
              slv_ack_o                       <= '1'; 

            when x"000a" =>
              slv_data_out_o(7 downto  0)     <=
                std_logic_vector(data_fifo_delay_o);
              slv_data_out_o(31 downto  8)    <= (others => '0');
              slv_ack_o                       <= '1'; 

              -- 4x Channel WAIT
              
            when x"000b" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_wait_r(31 downto 0));
              slv_ack_o                       <= '1';  

            when x"000c" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_wait_r(63 downto 32));
              slv_ack_o                       <= '1'; 

            when x"000d" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_wait_r(95 downto 64));
              slv_ack_o                       <= '1'; 

            when x"000e" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_wait_r(127 downto 96));
              slv_ack_o                       <= '1'; 

              -- 4x Channel HIT

            when x"000f" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_hit_r(31 downto 0));
              slv_ack_o                       <= '1';  

            when x"0010" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_hit_r(63 downto 32));
              slv_ack_o                       <= '1'; 

            when x"0011" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_hit_r(95 downto 64));
              slv_ack_o                       <= '1'; 

            when x"0012" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_hit_r(127 downto 96));
              slv_ack_o                       <= '1'; 

              -- 4x Channel DONE
              
            when x"0013" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_done_r(31 downto 0));
              slv_ack_o                       <= '1'; 

            when x"0014" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_done_r(63 downto 32));
              slv_ack_o                       <= '1'; 

            when x"0015" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_done_r(95 downto 64));
              slv_ack_o                       <= '1'; 

            when x"0016" =>
              slv_data_out_o                  <=
                std_logic_vector(channel_done_r(127 downto 96));
              slv_ack_o                       <= '1'; 

            when x"0017" =>
              slv_data_out_o(0)               <= channel_all_done_r;
              slv_data_out_o(31 downto  1)    <= (others => '0');
              slv_ack_o                       <= '1';  
              
            when x"0018" =>
              slv_data_out_o(0)               <= EVT_BUFFER_FULL_IN;
              slv_data_out_o(31 downto  1)    <= (others => '0');
              slv_ack_o                       <= '1'; 

            when x"0019" =>
              slv_data_out_o(19 downto 0)     <= wait_for_data_time_r;
              slv_data_out_o(30 downto  20)   <= (others => '0');
              slv_data_out_o(31)              <= skip_wait_for_data;
              slv_ack_o                       <= '1';  

            when x"001a" =>
              slv_data_out_o(11 downto 0)     <=
                std_logic_vector(nxyter_cv_time);
              slv_data_out_o(31 downto 12)    <= (others => '0');
              slv_ack_o                       <= '1';
                
            when x"001b" =>
              slv_data_out_o(19 downto 0)     <=
                std_logic_vector(min_validation_time_r);
              slv_data_out_o(31 downto 20)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"001c" =>
              slv_data_out_o(15 downto 0)     <=
                std_logic_vector(out_of_window_l_ctr_r);
              slv_data_out_o(31 downto 16)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"001d" =>
              slv_data_out_o(15 downto 0)     <=
                std_logic_vector(window_hit_ctr_r);
              slv_data_out_o(31 downto 16)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"001e" =>
              slv_data_out_o(15 downto 0)     <=
                std_logic_vector(out_of_window_h_ctr_r);
              slv_data_out_o(31 downto 16)    <= (others => '0');
              slv_ack_o                       <= '1';

            when x"001f" =>
              slv_data_out_o(27 downto 0)     <= std_logic_vector(data_rate);
              slv_data_out_o(31 downto 28)    <= (others => '0');
              slv_ack_o                       <= '1';
              
            when x"0020" =>
              slv_data_out_o(13 downto 0)     <=
                std_logic_vector(histogram_lower_limit);
              slv_data_out_o(28 downto 15)    <=
                std_logic_vector(histogram_upper_limit);
              slv_data_out_o(29)              <= '0';
              slv_data_out_o(30)              <= histogram_limits;
              slv_data_out_o(31)              <= histogram_trig_filter;
              slv_ack_o                       <= '1';

            when x"0021" =>
              slv_data_out_o(2  downto 0)     <= histogram_ts_range;
              slv_data_out_o(31 downto 3)     <= (others => '0');
              slv_ack_o                       <= '1';
              
            when others  =>
              slv_unknown_addr_o              <= '1';
              slv_ack_o                       <= '0';

          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              readout_mode_r                  <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                       <= '1';
              
            when x"0001" =>
              if ((signed(SLV_DATA_IN(11 downto 0)) > -2048) and
                  (signed(SLV_DATA_IN(11 downto 0)) <  2048)) then
                ts_window_offset(11 downto 0) <=
                  signed(SLV_DATA_IN(11 downto 0));
              end if;
              slv_ack_o                       <= '1';
              
            when x"0002" =>                   
              ts_window_width                 <=
                unsigned(SLV_DATA_IN(9 downto 0));
              slv_ack_o                       <= '1';
              
            when x"0003" =>
              cts_trigger_delay(9 downto 0)   <=
                unsigned(SLV_DATA_IN(9 downto 0));
              trigger_calibration_delay       <=
                unsigned(SLV_DATA_IN(27 downto 16));
              slv_ack_o                       <= '1';

            when x"0004" =>
              if (unsigned(SLV_DATA_IN(9 downto 0)) >= 1) then
                readout_time_max(9 downto 0)  <=
                  unsigned(SLV_DATA_IN(9 downto 0));
              end if;                         
              slv_ack_o                       <= '1';

            when x"0005" =>
              fpga_timestamp_offset(11 downto 0) <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                       <= '1';

            when x"0009" =>
              out_of_window_error_ctr_clear   <= '1';
              slv_ack_o                       <= '1'; 

            when x"0019" =>
              skip_wait_for_data              <= SLV_DATA_IN(31);
              slv_ack_o                       <= '1'; 

            when x"001a" =>
              nxyter_cv_time                  <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                       <= '1'; 

            when x"0020" =>
              histogram_lower_limit           <= SLV_DATA_IN(13 downto 0);
              histogram_upper_limit           <= SLV_DATA_IN(28 downto 15);
              histogram_limits                <= SLV_DATA_IN(30);
              histogram_trig_filter           <= SLV_DATA_IN(31);
              reset_hists                     <= '1';
              slv_ack_o                       <= '1';
              
            when x"0021" =>
              reset_hists                     <= '1';
              histogram_ts_range              <= SLV_DATA_IN(2 downto 0); 
              slv_ack_o                       <= '1';
              
            when others  =>                   
              slv_unknown_addr_o              <= '1';
              slv_ack_o                       <= '0';
          end case;                           
        else                                  
          slv_ack_o                           <= '0';
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  pulse_to_level_RESET_HISTS: pulse_to_level
    generic map (
      NUM_CYCLES => 15
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => reset_hists,
      LEVEL_OUT => reset_hists_o
      );
  
  data_clk_o             <= d_data_clk_o or t_data_clk_o;
  data_o                 <= d_data_o or t_data_o;

  -----------------------------------------------------------------------------
  
  TRIGGER_BUSY_OUT       <= trigger_busy_o;
  DATA_OUT               <= data_o or t_data_o;
  DATA_CLK_OUT           <= data_clk_o;
  NOMORE_DATA_OUT        <= nomore_data_o;
  DATA_FIFO_DELAY_OUT    <= std_logic_vector(data_fifo_delay_o);
  EVT_BUFFER_CLEAR_OUT   <= evt_buffer_clear_o;

  HISTOGRAM_RESET_OUT    <= reset_hists_o;
  HISTOGRAM_FILL_OUT     <= histogram_fill_o;
  HISTOGRAM_BIN_OUT      <= histogram_bin_o;
  HISTOGRAM_ADC_OUT      <= histogram_adc_o;
  HISTOGRAM_TS_OUT       <= histogram_ts_o;
  HISTOGRAM_PILEUP_OUT   <= histogram_pileup_o;
  HISTOGRAM_OVERFLOW_OUT <= histogram_ovfl_o;
  
  -- Slave 
  SLV_DATA_OUT           <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT   <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT   <= slv_unknown_addr_o;
  SLV_ACK_OUT            <= slv_ack_o;

end Behavioral;
