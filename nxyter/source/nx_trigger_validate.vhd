library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_validate is
  generic (
    BOARD_ID : std_logic_vector(15 downto 0) := x"ffff"
    );
  port (
    CLK_IN               : in  std_logic;  
    RESET_IN             : in  std_logic;

    -- Inputs
    DATA_CLK_IN          : in  std_logic;
    TIMESTAMP_IN         : in  std_logic_vector(13 downto 0);
    CHANNEL_IN           : in  std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_IN  : in  std_logic_vector(2 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    NX_TOKEN_RETURN_IN   : in  std_logic;
    NX_NOMORE_DATA_IN    : in  std_logic;

    TRIGGER_IN           : in  std_logic;
    FAST_CLEAR_IN        : in  std_logic;
    TRIGGER_BUSY_OUT     : out std_logic;
    TIMESTAMP_REF_IN     : in  unsigned(11 downto 0);
    DATA_FIFO_DELAY_OUT  : out std_logic_vector(6 downto 0);
    
    -- Outputs
    DATA_OUT             : out std_logic_vector(31 downto 0);
    DATA_CLK_OUT         : out std_logic;
    NOMORE_DATA_OUT      : out std_logic;

    -- Histogram
    HISTOGRAM_FILL_OUT   : out std_logic;
    HISTOGRAM_BIN_OUT    : out std_logic_vector(6 downto 0);
    HISTOGRAM_ADC_OUT    : out std_logic_vector(11 downto 0);
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );

end entity;

architecture Behavioral of nx_trigger_validate is

  -- Process Channel_Status
  signal channel_index        : std_logic_vector(6 downto 0);
  signal channel_wait         : std_logic_vector(127 downto 0);
  signal channel_done         : std_logic_vector(127 downto 0);
  signal channel_all_done     : std_logic;

  -- Channel Status Commands
  type CS_CMDS is (CS_RESET,
                   CS_TOKEN_UPDATE,
                   CS_SET_WAIT,
                   CS_SET_DONE,
                   CS_NONE
                  );
  signal channel_status_cmd   : CS_CMDS; 
  
  -- Process Timestamp
  signal data_o               : std_logic_vector(31 downto 0);
  signal data_clk_o           : std_logic;
  signal out_of_window_l      : std_logic;
  signal out_of_window_h      : std_logic;
  signal ch_status_cmd_pr     : CS_CMDS;
   
  -- Process Trigger Handler
  signal store_to_fifo        : std_logic;
  signal trigger_busy_o       : std_logic;
  signal nomore_data_o        : std_logic;
  signal wait_timer_init      : unsigned(11 downto 0);
  signal token_return_ctr     : std_logic;
  signal ch_status_cmd_tr     : CS_CMDS;
  
  type STATES is (S_IDLE,
                  S_TRIGGER,
                  S_WAIT_DATA,
                  S_WRITE_HEADER,
                  S_PROCESS_START,
                  S_WAIT_PROCESS_END,
                  S_WRITE_TRAILER,
                  S_SET_NOMORE_DATA
                  );
  signal STATE : STATES;

  signal t_data_o             : std_logic_vector(31 downto 0);
  signal t_data_clk_o         : std_logic;
  signal busy_time_ctr        : unsigned(11 downto 0);
  signal busy_time_min_done   : std_logic;
  signal wait_timer_reset     : std_logic;
  signal event_counter        : unsigned(9 downto 0);
  
  signal readout_mode         : std_logic_vector(2 downto 0);
  signal timestamp_ref        : unsigned(11 downto 0);

  -- Timer
  signal timer_reset          : std_logic;
  signal wait_timer_done      : std_logic;
    
  -- Histogram
  signal histogram_fill_o     : std_logic;
  signal histogram_bin_o      : std_logic_vector(6 downto 0);
  signal histogram_adc_o      : std_logic_vector(11 downto 0);

  -- Data FIFO Delay
  signal data_fifo_delay_o    : std_logic_vector(6 downto 0);

  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;

  signal readout_mode_r       : std_logic_vector(2 downto 0);
  signal trigger_window_begin : unsigned(11 downto 0);
  signal trigger_window_end   : unsigned(11 downto 0);
  signal cts_trigger_delay    : unsigned(11 downto 0);
  signal readout_time_max     : unsigned(11 downto 0);
  signal window_lower_thr_r   : std_logic_vector(11 downto 0);
  signal window_upper_thr_r   : std_logic_vector(11 downto 0);
  
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
  DEBUG_OUT(11)           <= t_data_clk_o;
  DEBUG_OUT(12)           <= wait_timer_done;
  DEBUG_OUT(13)           <= timer_reset;
  DEBUG_OUT(14)           <= busy_time_min_done;
  DEBUG_OUT(15)           <= nomore_data_o;
  
  -- Timer
  nx_timer_1: nx_timer
    generic map(
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => timer_reset,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  timer_reset <= RESET_IN or wait_timer_reset;
  
  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_FILTER_TIMESTAMPS: process (CLK_IN)
    variable ts_ref             : unsigned(11 downto 0);
    variable window_lower_thr   : unsigned(11 downto 0);
    variable window_upper_thr   : unsigned(11 downto 0);
    variable deltaT             : unsigned(11 downto 0);
    variable deltaTStore        : unsigned(11 downto 0);
    
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        data_o               <= (others => '0');
        data_clk_o           <= '0';
        out_of_window_l      <= '0';
        out_of_window_h      <= '0';
        window_lower_thr_r   <= (others => '0');
        window_upper_thr_r   <= (others => '0');
      else
        data_o               <= (others => '0');
        data_clk_o           <= '0';
        out_of_window_l      <= '0';
        out_of_window_h      <= '0';
        ch_status_cmd_pr     <= CS_NONE;

        histogram_fill_o     <= '0';
        histogram_bin_o      <= (others => '0');
        histogram_adc_o      <= (others => '0');
        
        if (DATA_CLK_IN = '1') then
          if (store_to_fifo = '1') then
            ts_ref             := timestamp_ref - cts_trigger_delay;
            window_lower_thr   := trigger_window_begin;
            window_upper_thr   := window_lower_thr + trigger_window_end;
            deltaT             := unsigned(TIMESTAMP_IN(13 downto 2)) - ts_ref;
            deltaTStore        := deltaT - window_lower_thr;
              
            window_lower_thr_r <= window_lower_thr;
            window_upper_thr_r <= window_upper_thr;
              
            if (readout_mode(2) = '0') then
              -- TS window filter Modes
              if (deltaT < window_lower_thr) then
                out_of_window_l        <= '1';
                data_clk_o             <= '0';
                -- IN LUT Data bit setzen.
                channel_index          <= CHANNEL_IN;
                ch_status_cmd_pr       <= CS_SET_WAIT;
              elsif (deltaT > window_upper_thr) then
                out_of_window_h        <= '1';
                data_clk_o             <= '0';
                -- In LUT Done Bit setzen
                channel_index          <= CHANNEL_IN;
                ch_status_cmd_pr       <= CS_SET_DONE;
              else
                -- IN LUT Data bit setzen and Take Data
                channel_index          <= CHANNEL_IN;
                ch_status_cmd_pr       <= CS_SET_WAIT;
                
                case readout_mode(1 downto 0) is              
                  when "00" =>
                    -- RefValue + TS window filter + ovfl valid + parity valid
                    if (TIMESTAMP_STATUS_IN(2) = '0' and
                        TIMESTAMP_STATUS_IN(0) = '0') then 
                      data_o( 1 downto  0)     <= TIMESTAMP_IN(1 downto 0);
                      data_o(11 downto  2)     <= deltaTStore(9 downto 0);
                      data_o(23 downto 12)     <= ADC_DATA_IN;
                      data_o(30 downto 24)     <= CHANNEL_IN;
                      data_o(31)               <= TIMESTAMP_STATUS_IN(2);
                      data_clk_o               <= '1';
                    end if;

                  when "01" =>
                    -- RefValue + TS window filter + ovfl and pileup valid
                    -- + parity valid
                    if (TIMESTAMP_STATUS_IN(2 downto 1) = "000") then 
                      data_o( 1 downto  0)   <= TIMESTAMP_IN(1 downto 0);
                      data_o(11 downto  2)   <= deltaTStore(9 downto 0);
                      data_o(23 downto 12)   <= ADC_DATA_IN;
                      data_o(30 downto 24)   <= CHANNEL_IN;
                      data_o(31)             <= TIMESTAMP_STATUS_IN(2);
                      data_clk_o             <= '1';
                    end if;

                  when others =>
                    -- RefValue + TS window filter + ignore status       
                    data_o( 1 downto  0)   <= TIMESTAMP_IN(1 downto 0);
                    data_o(11 downto  2)   <= deltaTStore(9 downto 0);
                    data_o(23 downto 12)   <= ADC_DATA_IN;
                    data_o(30 downto 24)   <= CHANNEL_IN;
                    data_o(31)             <= TIMESTAMP_STATUS_IN(2);
                    data_clk_o             <= '1';
                                    
                end case;
              end if;
            else
              -- No TS window filter Modes
              case readout_mode(1 downto 0) is              
                when "00" =>
                  -- RefValue + ovfl valid + parity valid
                  if (TIMESTAMP_STATUS_IN(2) = '0' and
                      TIMESTAMP_STATUS_IN(0) = '0') then 
                    data_o( 1 downto  0)     <= TIMESTAMP_IN(1 downto 0);
                    data_o(11 downto  2)     <= deltaTStore(9 downto 0);
                    data_o(23 downto 12)     <= ADC_DATA_IN;
                    data_o(30 downto 24)     <= CHANNEL_IN;
                    data_o(31)               <= TIMESTAMP_STATUS_IN(2);
                    data_clk_o               <= '1';
                  end if;

                when "01" =>
                  -- RefValue + ovfl and pileup valid
                  -- + parity valid
                  if (TIMESTAMP_STATUS_IN(2 downto 1) = "000") then 
                    data_o( 1 downto  0)   <= TIMESTAMP_IN(1 downto 0);
                    data_o(11 downto  2)   <= deltaTStore(9 downto 0);
                    data_o(23 downto 12)   <= ADC_DATA_IN;
                    data_o(30 downto 24)   <= CHANNEL_IN;
                    data_o(31)             <= TIMESTAMP_STATUS_IN(2);
                    data_clk_o             <= '1';
                  end if;

                when others =>
                  -- RefValue + ignore status       
                  data_o( 1 downto  0)   <= TIMESTAMP_IN(1 downto 0);
                  data_o(11 downto  2)   <= deltaTStore(9 downto 0);
                  data_o(23 downto 12)   <= ADC_DATA_IN;
                  data_o(30 downto 24)   <= CHANNEL_IN;
                  data_o(31)             <= TIMESTAMP_STATUS_IN(2);
                  data_clk_o             <= '1';
                  
              end case;
            end if;
            
            -- Fill Histogram
            histogram_fill_o    <= '1';
            histogram_bin_o     <= CHANNEL_IN;
            histogram_adc_o     <= ADC_DATA_IN;
          end if;
          
        end if;
      end if;
    end if;
  end process PROC_FILTER_TIMESTAMPS;

  -----------------------------------------------------------------------------
  -- Trigger Handler
  -----------------------------------------------------------------------------

  PROC_TRIGGER_HANDLER: process(CLK_IN)
    variable min_validation_time : unsigned(11 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or FAST_CLEAR_IN = '1') then
        store_to_fifo         <= '0';
        trigger_busy_o        <= '0';
        nomore_data_o         <= '0';
        wait_timer_init       <= (others => '0');
        wait_timer_reset      <= '0';
        t_data_o              <= (others => '0');
        t_data_clk_o          <= '0';
        busy_time_ctr         <= (others => '0');
        busy_time_min_done    <= '0';
        token_return_ctr      <= '0';
        ch_status_cmd_tr      <= CS_RESET;
        event_counter         <= (others => '0');
        readout_mode          <= (others => '0');
        timestamp_ref         <= (others => '0');
        STATE                 <= S_IDLE;
      else
        store_to_fifo         <= '0';
        wait_timer_init       <= (others => '0');
        wait_timer_reset      <= '0';
        trigger_busy_o        <= '1';
        nomore_data_o         <= '0';
        t_data_o              <= (others => '0');
        t_data_clk_o          <= '0';
        ch_status_cmd_tr      <= CS_NONE;

        min_validation_time := x"020" +
                               (trigger_window_begin / 2) +
                               (trigger_window_end / 2);
        
        case STATE is
          
          when S_IDLE =>
            if (TRIGGER_IN = '1') then
              busy_time_ctr        <= (others => '0');
              STATE                <= S_TRIGGER;
            else
              trigger_busy_o       <= '0';
              STATE                <= S_IDLE;
            end if;
            
          when S_TRIGGER =>
            readout_mode           <= readout_mode_r;
            ch_status_cmd_tr       <= CS_RESET;
            wait_timer_init        <= x"020";    -- wait 320ns for first event
            STATE                  <= S_WAIT_DATA;

          when S_WAIT_DATA =>
            if (wait_timer_done = '0') then
              STATE                <= S_WAIT_DATA;
            else
              timestamp_ref        <= TIMESTAMP_REF_IN;
              STATE                <= S_WRITE_HEADER;
            end if;

          when S_WRITE_HEADER =>
            t_data_o(11 downto 0)  <= timestamp_ref;
            t_data_o(21 downto 12) <= event_counter;
            -- Readout Mode Mapping (so far)
            -- 00: Standard
            -- 01: Special
            -- 10: DEBUG
            -- 11: UNDEF
            case readout_mode is
              when "000"    => t_data_o(23 downto 22) <= "00";
              when "001"    => t_data_o(23 downto 22) <= "01";
              when "100"    => t_data_o(23 downto 22) <= "10";
              when "101"    => t_data_o(23 downto 22) <= "11";
              when others => t_data_o(23 downto 22) <= "11";
            end case;
            t_data_o(31 downto 24) <= BOARD_ID(7 downto 0);
            t_data_clk_o           <= '1';
            
            event_counter          <= event_counter + 1;
            STATE                  <= S_PROCESS_START;
                        
          when S_PROCESS_START =>
            token_return_ctr       <= '0';
            wait_timer_init        <= readout_time_max; 
            store_to_fifo          <= '1';
            STATE                  <= S_WAIT_PROCESS_END;
            
          when S_WAIT_PROCESS_END =>
            if (wait_timer_done    = '1' or
                channel_all_done   = '1' or
                (NX_NOMORE_DATA_IN = '1' and
                 busy_time_ctr     > min_validation_time(11 downto 0))
                )
            then
              wait_timer_reset     <= '1';
              STATE                <= S_WRITE_TRAILER;
            else
              store_to_fifo        <= '1';
              STATE                <= S_WAIT_PROCESS_END;
              
              -- Check Token_Return
              if (busy_time_ctr > min_validation_time) then
                if (readout_mode(2) = '0' and NX_TOKEN_RETURN_IN = '1') then
                  if (token_return_ctr = '1') then
                    ch_status_cmd_tr <= CS_TOKEN_UPDATE;
                  end if;
                  token_return_ctr   <= token_return_ctr or '1';
                end if;
              end if;

            end if;
                    
          when S_WRITE_TRAILER =>
            t_data_o               <= (others => '1');
            t_data_clk_o           <= '1';
            ch_status_cmd_tr       <= CS_RESET;
            STATE                  <= S_SET_NOMORE_DATA;

          when S_SET_NOMORE_DATA =>
            nomore_data_o          <= '1';
            STATE                  <= S_IDLE;
        end case;

        if (STATE /= S_IDLE) then
          busy_time_ctr            <= busy_time_ctr + 1;
        end if;      

        if (busy_time_ctr > min_validation_time) then
          busy_time_min_done <= '1';
        else
          busy_time_min_done <= '0';
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
        channel_wait       <= (others => '0');
        channel_done       <= (others => '0');
        channel_all_done   <= '0';

      else
        -- Check done status
        if (channel_done = all_one) then
          channel_all_done    <= '1';
        end if;

        -- Process Command
        case channel_status_cmd is

          when CS_RESET =>
            channel_wait      <= (others => '0');
            channel_done      <= (others => '0');
            channel_all_done  <= '0';

          when CS_TOKEN_UPDATE =>
            channel_done      <= channel_done or (not channel_wait);
            channel_wait      <= (others => '0');
            
          when CS_SET_WAIT =>
            channel_wait(to_integer(unsigned(channel_index))) <= '1';
      
          when CS_SET_DONE =>
            channel_done(to_integer(unsigned(channel_index))) <= '1';
      
          when others => null;

        end case;
      end if;
    end if;
  end process PROC_CHANNEL_STATUS;

  PROC_DATA_FIFO_DELAY: process(CLK_IN)
    variable fifo_delay : unsigned(11 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        data_fifo_delay_o   <= "0000001";
      else
        fifo_delay := (cts_trigger_delay / 8) + 1;
        if (fifo_delay >= 1 and fifo_delay <= 120) then
          data_fifo_delay_o     <= std_logic_vector(fifo_delay(6 downto 0));
        else
          data_fifo_delay_o     <= "0000001";
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
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        readout_mode_r         <= "000";
        trigger_window_begin   <= x"000";
        trigger_window_end     <= x"040";
        cts_trigger_delay      <= x"000";
        readout_time_max       <= x"640";
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o( 2 downto  0) <= readout_mode_r;
              slv_data_out_o(31 downto  3) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(11 downto  0) <=
                std_logic_vector(trigger_window_begin);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(11 downto  0) <=
                std_logic_vector(trigger_window_end);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0003" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(cts_trigger_delay);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                    <= '1'; 
                          
            when x"0004" =>
              slv_data_out_o(11 downto  0) <=
                std_logic_vector(readout_time_max);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0005" =>
              slv_data_out_o(11 downto  0) <=
                std_logic_vector(busy_time_ctr);
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1'; 

            when x"0006" =>
              slv_data_out_o(11 downto  0) <= timestamp_ref;
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0007" =>
              slv_data_out_o(11 downto  0) <= window_lower_thr_r;
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0008" =>
              slv_data_out_o(11 downto  0) <= window_upper_thr_r;
              slv_data_out_o(31 downto 12) <= (others => '0');
              slv_ack_o                    <= '1';  

            when x"0009" =>
              slv_data_out_o( 6 downto  0)  <=
                std_logic_vector(data_fifo_delay_o);
              slv_data_out_o(31 downto  7) <= (others => '0');
              slv_ack_o                    <= '1'; 
                                     
            when x"000a" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(31 downto 0));
              slv_ack_o                    <= '1'; 

            when x"000b" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(63 downto 32));
              slv_ack_o                    <= '1'; 

            when x"000c" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(95 downto 64));
              slv_ack_o                    <= '1'; 

            when x"000d" =>
              slv_data_out_o               <=
                std_logic_vector(channel_done(127 downto 96));
              slv_ack_o                    <= '1'; 
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';

          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              readout_mode_r             <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                  <= '1';

            when x"0001" =>
              trigger_window_begin       <= SLV_DATA_IN(11 downto 0);
              slv_ack_o                  <= '1';

            when x"0002" =>
              trigger_window_end         <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                  <= '1';
              
            when x"0003" =>
              if (unsigned(SLV_DATA_IN(11 downto 0)) < 960) then
                cts_trigger_delay        <=
                  unsigned(SLV_DATA_IN(11 downto 0));
              end if;
              slv_ack_o                  <= '1';

            when x"0004" =>
              readout_time_max           <=
                unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                  <= '1';
              
            when others  =>
              slv_unknown_addr_o         <= '1';
              slv_ack_o                  <= '0';
          end case;                
        else
          slv_ack_o                      <= '0';
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TRIGGER_BUSY_OUT      <= trigger_busy_o;
  DATA_OUT              <= data_o or t_data_o;
  DATA_CLK_OUT          <= data_clk_o or t_data_clk_o;
  NOMORE_DATA_OUT       <= nomore_data_o;
  DATA_FIFO_DELAY_OUT   <= data_fifo_delay_o;
  
  HISTOGRAM_FILL_OUT    <= histogram_fill_o;
  HISTOGRAM_BIN_OUT     <= histogram_bin_o;
  HISTOGRAM_ADC_OUT     <= histogram_adc_o;
  
  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;

end Behavioral;
