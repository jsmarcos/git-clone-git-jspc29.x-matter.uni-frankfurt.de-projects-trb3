library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.scaler_components.all;

entity nx_data_validate is
  port (
    CLK_IN                 : in  std_logic;  
    RESET_IN               : in  std_logic;
                           
    -- Inputs              
    DATA_IN                : in  std_logic_vector(43 downto 0);
    DATA_CLK_IN            : in  std_logic;
                           
    -- Outputs             
    TIMESTAMP_OUT          : out std_logic_vector(13 downto 0);
    CHANNEL_OUT            : out std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_OUT   : out std_logic_vector(2 downto 0);
    ADC_DATA_OUT           : out std_logic_vector(11 downto 0);
    DATA_CLK_OUT           : out std_logic;
                           
    NX_TOKEN_RETURN_OUT    : out std_logic;
    NX_NOMORE_DATA_OUT     : out std_logic;
                           
    -- Slave bus           
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;

    ADC_TR_ERROR_OUT       : out std_logic;
    DISABLE_ADC_IN         : in std_logic;
    ERROR_OUT              : out std_logic;
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );

end entity;

architecture Behavioral of nx_data_validate is

  -- Gray Decoder
  signal nx_timestamp         : std_logic_vector(13 downto 0);
  signal nx_channel_id        : std_logic_vector( 6 downto 0);
  
  -- TIMESTAMP_BITS
  signal new_timestamp        : std_logic;
  signal valid_frame_bits     : std_logic_vector(3 downto 0);
  signal status_bits          : std_logic_vector(1 downto 0);
  signal parity_error         : std_logic;
  signal adc_data             : std_logic_vector(11 downto 0);
  
  -- Validate Timestamp
  signal timestamp_o          : std_logic_vector(13 downto 0);
  signal channel_o            : std_logic_vector(6 downto 0);
  signal timestamp_status_o   : std_logic_vector(2 downto 0);
  signal adc_data_o           : std_logic_vector(11 downto 0);
  signal data_clk_o           : std_logic;

  signal nx_token_return_o    : std_logic;
  signal nx_nomore_data_o     : std_logic;

  signal parity_error_ctr     : unsigned(15 downto 0);
  signal invalid_frame_ctr    : unsigned(15 downto 0);
  signal overflow_ctr         : unsigned(15 downto 0);
  signal pileup_ctr           : unsigned(15 downto 0);

  signal trigger_rate_inc     : std_logic;
  signal pileup_rate_inc      : std_logic;
  signal overflow_rate_inc    : std_logic;

  -- Self Trigger
  signal self_trigger_o       : std_logic;
  
  -- Rate Calculation
  signal nx_trigger_ctr_t     : unsigned(27 downto 0);
  signal nx_trigger_ctr_t_nr  : unsigned(31 downto 0);
  signal frame_ctr_t          : unsigned(27 downto 0);
  signal nx_pileup_ctr_t      : unsigned(27 downto 0);
  signal nx_overflow_ctr_t    : unsigned(27 downto 0);
  signal adc_tr_error_ctr_t   : unsigned(27 downto 0);
  signal adc_tr_update_ctr_t  : unsigned(27 downto 0);
  signal adc_tr_data_ctr_t    : unsigned(27 downto 0);
  
  signal nx_rate_timer        : unsigned(27 downto 0);

  -- ADC Averages
  signal adc_average_divisor  : unsigned(3 downto 0);
  signal adc_average_ctr      : unsigned(15 downto 0);
  signal adc_average_sum      : unsigned(31 downto 0);
  signal adc_average          : unsigned(11 downto 0);
  
  signal adc_data_last        : std_logic_vector(11 downto 0);

  -- Token Return Average
  signal nx_token_return_pipec  : std_logic_vector(9 downto 0);
  signal nx_token_return_pipev  : std_logic_vector(11 downto 0);
  signal adc_tr_value_tmp       : std_logic_vector(11 downto 0);
  signal adc_tr_value           : std_logic_vector(11 downto 0);
  signal adc_tr_data_p          : unsigned(11 downto 0);
  signal adc_tr_data_c          : unsigned(11 downto 0);
  signal adc_tr_data_clk        : std_logic;
  signal adc_tr_limit           : unsigned(11 downto 0);
  signal adc_tr_error_ctr       : unsigned(11 downto 0);
  signal adc_tr_error           : std_logic;
  signal adc_tr_error_status    : std_logic_vector(1 downto 0);
  signal adc_tr_debug_mode      : std_logic;
  signal adc_tr_error_o         : std_logic;
  
  type TR_STATES is (S_IDLE,
                     S_START,
                     S_END
                     );
  signal TR_STATE : TR_STATES;
  
  -- Config
  signal readout_type         : std_logic_vector(1 downto 0);

  -- Error Status
  signal new_timestamp_shift  : std_logic_vector(3 downto 0);
  signal frame_dt_error       : std_logic;
  signal frame_dt_error_ctr   : unsigned(15 downto 0);
  signal frame_rate_error     : std_logic;
  signal error_o              : std_logic;
    
  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal clear_counters       : std_logic;
  signal nx_hit_rate          : unsigned(27 downto 0);
  signal frame_rate           : unsigned(27 downto 0);
  signal nx_pileup_rate       : unsigned(27 downto 0);
  signal nx_overflow_rate     : unsigned(27 downto 0);
  signal adc_tr_error_rate    : unsigned(27 downto 0);
  signal adc_tr_update_rate   : unsigned(27 downto 0);
  signal adc_tr_data_rate     : unsigned(27 downto 0);
  signal invalid_adc          : std_logic;
  signal adc_tr_value_r       : std_logic_vector(11 downto 0);

  signal adc_tr_debug_p       : std_logic;
  signal adc_tr_debug_c       : std_logic;
  signal adc_tr_value_update  : std_logic;
  signal state_debug          : std_logic_vector(1 downto 0);
  
begin

  -- Debug Line
  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= DATA_CLK_IN;
  DEBUG_OUT(2)             <= nx_token_return_o;
  DEBUG_OUT(3)             <= nx_nomore_data_o;
  DEBUG_OUT(4)             <= data_clk_o;
  DEBUG_OUT(5)             <= new_timestamp;
  DEBUG_OUT(6)             <= self_trigger_o;
--  DEBUG_OUT(7)             <= invalid_adc;
  DEBUG_OUT(7)             <= adc_tr_data_clk;
  DEBUG_OUT(8)             <= adc_tr_error;
  DEBUG_OUT(10 downto 9)   <= adc_tr_error_status; 
  DEBUG_OUT(11)            <= adc_tr_debug_p;
  DEBUG_OUT(12)            <= adc_tr_debug_c;
  DEBUG_OUT(13)            <= adc_tr_value_update;
  DEBUG_OUT(15 downto 14)  <= state_debug;


  -----------------------------------------------------------------------------
  -- Data Separation
  -----------------------------------------------------------------------------

  gray_decoder_TIMESTAMP: gray_decoder          -- Decode nx_timestamp
    generic map (
      WIDTH => 14
      )
    port map (
      CLK_IN                  => CLK_IN,
      RESET_IN                => RESET_IN,
      GRAY_IN(13 downto 7)    => not DATA_IN(30 downto 24),
      GRAY_IN( 6 downto 0)    => not DATA_IN(22 downto 16),
      BINARY_OUT              => nx_timestamp
      );
  
  gray_decoder_CHANNEL_ID: gray_decoder          -- Decode Channel_ID
    generic map (
      WIDTH => 7
      )
    port map (
      CLK_IN     => CLK_IN,
      RESET_IN   => RESET_IN,
      GRAY_IN    => DATA_IN(14 downto 8),
      BINARY_OUT => nx_channel_id
      );
  
  -- Separate Timestamp-, Status-, Parity- and Frame-bits
  PROC_TIMESTAMP_BITS: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        valid_frame_bits    <= (others => '0');
        status_bits         <= (others => '0');
        new_timestamp       <= '0';
        adc_data            <= (others => '0');
      else
        if (DATA_CLK_IN = '1') then
          valid_frame_bits(3)       <= DATA_IN(31);
          valid_frame_bits(2)       <= DATA_IN(23);
          valid_frame_bits(1)       <= DATA_IN(15);
          valid_frame_bits(0)       <= DATA_IN(7);
          status_bits               <= DATA_IN(2 downto 1);
          adc_data                  <= DATA_IN(43 downto 32);
          new_timestamp             <= '1';
        else
          valid_frame_bits          <= (others => '0');
          status_bits               <= (others => '0');
          adc_data                  <= (others => '0');
          new_timestamp             <= '0';
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_BITS;    

  -- Check Parity Bit
  PROC_PARITY_CHECKER: process(CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
    variable parity      : std_logic;
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        parity_error        <= '0';
      else
        if (DATA_CLK_IN = '1') then
          -- Timestamp Bit #6 is excluded (funny nxyter-bug)
          parity_bits       := DATA_IN(31)           &
                               DATA_IN(30 downto 24) &
                               DATA_IN(21 downto 16) &
                               DATA_IN(14 downto  8) &
                               DATA_IN( 2 downto  1);
          parity            := xor_all(parity_bits);

          if (parity /= DATA_IN(0)) then
            parity_error    <= '1';
          else
            parity_error    <= '0';
          end if;
        else
          parity_error      <= '0';
        end if;
      end if;
    end if;
  end process PROC_PARITY_CHECKER;

  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_VALIDATE_TIMESTAMP: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        timestamp_o           <= (others => '0');
        channel_o             <= (others => '0');
        timestamp_status_o    <= (others => '0');
        adc_data_o            <= (others => '0');
        data_clk_o            <= '0';
        nx_token_return_o     <= '0';
        nx_nomore_data_o      <= '0';
        trigger_rate_inc      <= '0';
        pileup_rate_inc       <= '0';
        overflow_rate_inc     <= '0';
        parity_error_ctr      <= (others => '0');
        invalid_frame_ctr     <= (others => '0');
        overflow_ctr          <= (others => '0');
        pileup_ctr            <= (others => '0');
        invalid_adc           <= '0';
        adc_tr_data_p         <= (others => '0');
        adc_tr_data_c         <= (others => '0');
        adc_tr_data_clk       <= '0';
        nx_token_return_pipec <= (others => '0');
        nx_token_return_pipev <= (others => '0');
        adc_data_last         <= (others => '0');
        adc_tr_value_tmp      <= (others => '0');
        adc_tr_value_update   <= '0';
        TR_STATE              <= S_IDLE;
        state_debug           <= "00";
      else                    
        timestamp_o           <= (others => '0');
        channel_o             <= (others => '0');
        timestamp_status_o    <= (others => '0');
        adc_data_o            <= (others => '0');
        data_clk_o            <= '0';
        trigger_rate_inc      <= '0';
        pileup_rate_inc       <= '0';
        overflow_rate_inc     <= '0';
        invalid_adc           <= '0';
        adc_tr_data_clk       <= '0';
        adc_tr_value_update   <= '0';

        if (new_timestamp = '1') then

          adc_data_last                      <= adc_data;

          if (parity_error = '1') then
            parity_error_ctr <= parity_error_ctr + 1;
          end if;

          case valid_frame_bits is
            
            -- Data Frame
            when "1000" =>
              ---- Check Overflow
              if ((status_bits(0) = '1') and (clear_counters = '0')) then
                overflow_ctr                 <= overflow_ctr + 1;
                overflow_rate_inc            <= '1';
              end if;
              
              -- Check PileUp
              if ((status_bits(1) = '1') and (clear_counters = '0')) then
                pileup_ctr                   <= pileup_ctr + 1;
                pileup_rate_inc              <= '1';
              end if;   
              
              -- Take Timestamp
              timestamp_o                    <= nx_timestamp;
              channel_o                      <= nx_channel_id;
              timestamp_status_o(2)          <= parity_error;
              timestamp_status_o(1 downto 0) <= status_bits;
              if (adc_tr_debug_mode = '0') then
                adc_data_o                   <= adc_data;
              else
                adc_data_o                   <= std_logic_vector(adc_tr_data_p);
              end if;
              data_clk_o                     <= '1';
              
              if (adc_data = x"aff") then
                invalid_adc                  <= '1';
              end if;

              nx_token_return_o              <= '0';
              nx_nomore_data_o               <= '0';
              trigger_rate_inc               <= '1';
              
              if (nx_token_return_o = '1' and
                  nx_token_return_pipec = "1111111111") then
                -- First Data Word after 5 empty Frames
                adc_tr_data_p                <= unsigned(adc_data_last);
                adc_tr_data_c                <= unsigned(adc_data);
                adc_tr_data_clk              <= '1';
              end if;
                          
            when "0000" =>
              -- Token return and nomore_data
              nx_token_return_o              <= '1';
              nx_nomore_data_o               <= nx_token_return_o;

            when others =>
              -- Invalid frame, not empty, discard timestamp
              if (clear_counters = '0') then
                invalid_frame_ctr            <= invalid_frame_ctr + 1;
              end if;
              nx_token_return_o              <= '0';
              nx_nomore_data_o               <= '0';
              
          end case;

          -- Token Return Check Handler
          case TR_STATE is
            when S_IDLE =>
              if (nx_token_return_pipev(6 downto 0) = "1111111") then
                adc_tr_value_tmp             <= adc_data_last;
                TR_STATE                     <= S_START;
              else
                TR_STATE                     <= S_IDLE;
              end if;
              state_debug                    <= "01";
              
            when S_START =>
              if (nx_token_return_pipev = "111111111111") then
                TR_STATE                     <= S_END;
              elsif (nx_token_return_pipev( 6 downto 0) = "1111111" or
                     nx_token_return_pipev( 7 downto 0) = "11111111" or
                     nx_token_return_pipev( 8 downto 0) = "111111111" or
                     nx_token_return_pipev( 9 downto 0) = "1111111111" or
                     nx_token_return_pipev(10 downto 0) = "11111111111") then
                TR_STATE                     <= S_START;
              else
                TR_STATE                     <= S_IDLE;
              end if;
              state_debug                    <= "10";

            when S_END =>
              adc_tr_value                   <= adc_tr_value_tmp;
              adc_tr_value_update            <= '1';
              TR_STATE                       <= S_IDLE;
              state_debug                    <= "11";
              
          end case;

          -- Token Return Pipeline
          nx_token_return_pipec(0)           <= nx_token_return_o;
          for I in 1 to 9 loop
            nx_token_return_pipec(I)         <= nx_token_return_pipec(I - 1);
          end loop;

          if (TR_STATE /= S_END) then
            nx_token_return_pipev(0)         <= nx_token_return_o;
            for I in 1 to 11 loop
              nx_token_return_pipev(I)       <= nx_token_return_pipev(I - 1);
            end loop;
          else
            nx_token_return_pipev            <= (others => '0');
          end if;
        
        end if;

        -- Reset Counters
        if (clear_counters = '1') then
          invalid_frame_ctr                  <= (others => '0');
          overflow_ctr                       <= (others => '0');
          pileup_ctr                         <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_VALIDATE_TIMESTAMP;

  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        nx_rate_timer        <= (others => '0');

        nx_trigger_ctr_t     <= (others => '0');
        frame_ctr_t          <= (others => '0');
        adc_tr_error_ctr_t   <= (others => '0');
        adc_tr_update_ctr_t  <= (others => '0');
        adc_tr_data_ctr_t    <= (others => '0');
        
        nx_hit_rate          <= (others => '0');
        frame_rate           <= (others => '0');
        adc_tr_error_rate    <= (others => '0');
        adc_tr_update_rate   <= (others => '0');
        adc_tr_data_rate     <= (others => '0');

        nx_trigger_ctr_t_nr  <= (others => '0');
        adc_tr_error_ctr     <= (others => '0');
      else
        if (nx_rate_timer < x"5f5e100") then
          if (trigger_rate_inc = '1') then
            nx_trigger_ctr_t               <= nx_trigger_ctr_t + 1;
            nx_trigger_ctr_t_nr            <= nx_trigger_ctr_t_nr + 1;
          end if;
          if (new_timestamp = '1') then
            frame_ctr_t                    <= frame_ctr_t + 1;
          end if;
          if (pileup_rate_inc = '1') then
            nx_pileup_ctr_t                <= nx_pileup_ctr_t + 1;
          end if;
          if (overflow_rate_inc = '1') then
            nx_overflow_ctr_t              <= nx_overflow_ctr_t + 1;
          end if;                          
          if (adc_tr_error = '1') then     
            adc_tr_error_ctr_t             <= adc_tr_error_ctr_t + 1;
            adc_tr_error_ctr               <= adc_tr_error_ctr + 1;
          end if;                          
          if (adc_tr_value_update = '1') then
            adc_tr_update_ctr_t            <= adc_tr_update_ctr_t + 1;
          end if; 
          if (adc_tr_data_clk = '1') then
            adc_tr_data_ctr_t              <= adc_tr_data_ctr_t + 1;
          end if;

          nx_rate_timer                    <= nx_rate_timer + 1;
        else                               
          nx_hit_rate                      <= nx_trigger_ctr_t;
          frame_rate                       <= frame_ctr_t;
          nx_pileup_rate                   <= nx_pileup_ctr_t;
          nx_overflow_rate                 <= nx_overflow_ctr_t;
          adc_tr_error_rate                <= adc_tr_error_ctr_t;
          adc_tr_update_rate               <= adc_tr_update_ctr_t;
          adc_tr_data_rate                 <= adc_tr_data_ctr_t; 

          nx_trigger_ctr_t(27 downto 1)    <= (others => '0');
          nx_trigger_ctr_t(0)              <= trigger_rate_inc;
                                           
          frame_ctr_t(27 downto 1)         <= (others => '0');
          frame_ctr_t(0)                   <= new_timestamp;
                                           
          nx_pileup_ctr_t(27 downto 1)     <= (others => '0');
          nx_pileup_ctr_t(0)               <= pileup_rate_inc;
                                           
          nx_overflow_ctr_t(27 downto 1)   <= (others => '0');
          nx_overflow_ctr_t(0)             <= overflow_rate_inc;

          adc_tr_error_ctr_t(27 downto 0)  <= (others => '0');
          adc_tr_error_ctr_t(0)            <= adc_tr_error;

          adc_tr_update_ctr_t(27 downto 0)  <= (others => '0');
          adc_tr_update_ctr_t(0)            <= adc_tr_value_update;

          adc_tr_data_ctr_t(27 downto 0)    <= (others => '0');
          adc_tr_data_ctr_t(0)              <= adc_tr_data_clk;
          
          nx_rate_timer                    <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_CAL_RATES;

  PROC_ADC_AVERAGE: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        adc_average_ctr    <= (others => '0');
        adc_average_sum    <= (others => '0');
        adc_average        <= (others => '0');
      else
        if ((adc_average_ctr srl to_integer(adc_average_divisor)) > 0) then
          adc_average        <= (adc_average_sum srl
                               to_integer(adc_average_divisor))(11 downto 0);
          if (data_clk_o = '1') then
            adc_average_sum(11 downto 0)  <= unsigned(adc_data_o);
            adc_average_sum(31 downto 13) <= (others => '0');
            adc_average_ctr  <= x"0001";
          else
            adc_average_sum  <= (others => '0');
            adc_average_ctr  <= (others => '0');
          end if;
        elsif (data_clk_o = '1') then
          adc_average_sum    <= adc_average_sum + unsigned(adc_data_o);
          adc_average_ctr    <= adc_average_ctr + 1;
        end if;

      end if;
    end if;
  end process PROC_ADC_AVERAGE;

  PROC_ADC_TOKEN_RETURN: process(CLK_IN)
    variable lower_limit      : unsigned(11 downto 0);
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        adc_tr_error          <= '0';
        adc_tr_debug_p        <= '0';
        adc_tr_debug_c        <= '0';
        adc_tr_error_status   <= "00";     
      else
        lower_limit            := unsigned(adc_tr_value) - adc_tr_limit;
        adc_tr_error           <= '0';

        if (adc_tr_data_clk = '1' and DISABLE_ADC_IN = '0') then

          if (adc_tr_data_p    > lower_limit) then 
            adc_tr_debug_p     <= '1';
          else
            adc_tr_debug_p     <= '0';
          end if;

          if (adc_tr_data_c    > lower_limit) then
            adc_tr_debug_c     <= '1';
          else
            adc_tr_debug_c     <= '0';
          end if;
          
          if (adc_tr_data_p    > lower_limit and
              adc_tr_data_c    < lower_limit) then
            adc_tr_error_status  <= "00";
            adc_tr_error         <= '0';
            
          elsif (adc_tr_data_p > lower_limit and
                 adc_tr_data_c > lower_limit) then
            adc_tr_error_status  <= "01";
            adc_tr_error         <= '1';
          else
            adc_tr_error_status  <= "10";
            adc_tr_error         <= '1';
          end if;
        end if;

      end if;
    end if;
  end process PROC_ADC_TOKEN_RETURN;
  
  PROC_ERROR_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        frame_rate_error <= '0';
        error_o          <= '0';
      else
        if (adc_tr_error_rate > x"0000020" and DISABLE_ADC_IN = '0') then
          error_o               <= '1';
        else
          error_o               <= '0';
        end if;

        if ((frame_rate < x"1dc_d64e" or
             frame_rate > x"1dc_d652")) then
          frame_rate_error      <= '1';
        else
          frame_rate_error      <= '0';
        end if;
      end if;
    end if;
  end process PROC_ERROR_HANDLER;
  
  PROC_DATA_STREAM_DELTA_T: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        new_timestamp_shift     <= (others => '0');
        frame_dt_error_ctr      <= (others => '0');
        frame_dt_error          <= '0';
      else
        -- Frame
        new_timestamp_shift(0)          <= new_timestamp;
        new_timestamp_shift(3 downto 1) <= new_timestamp_shift(2 downto 0);
        
        case new_timestamp_shift is
          when "1100" | "1110" | "1111" | "0000" =>
            frame_dt_error_ctr          <= frame_dt_error_ctr + 1;            
            frame_dt_error              <= '1';

          when others =>
            frame_dt_error              <= '0';

        end case;

      end if;
    end if;
  end process PROC_DATA_STREAM_DELTA_T;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      adc_tr_value_r         <= adc_tr_value;          
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';
        adc_average_divisor    <= x"3";

        adc_tr_limit           <= x"064";  -- 100
        adc_tr_debug_mode      <= '0';
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';

        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
          
            when x"0000" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(nx_hit_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0001" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(frame_rate);
              slv_data_out_o(30 downto 28)  <= (others => '0');
              slv_data_out_o(31)            <= frame_rate_error;
              slv_ack_o                     <= '1';

            when x"0002" =>
              slv_data_out_o(15 downto 0)
                <= std_logic_vector(parity_error_ctr);
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0003" =>
              slv_data_out_o(15 downto 0)   <=
              std_logic_vector(invalid_frame_ctr);
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';
                           
            when x"0004" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(nx_pileup_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0005" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(nx_overflow_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"0006" =>
              slv_data_out_o(1 downto 0)    <= adc_tr_error_status;
              slv_data_out_o(31 downto 2)   <= (others => '0');
              slv_ack_o                     <= '1'; 
              
            when x"0007" =>
              slv_data_out_o(27 downto 0)
                <= std_logic_vector(adc_tr_error_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"0008" =>
              slv_data_out_o(11 downto 0)   <= adc_tr_value_r;
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0009" =>
              slv_data_out_o(27 downto 0)
                <= std_logic_vector(adc_tr_update_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000a" =>
              slv_data_out_o(27 downto 0)
                <= std_logic_vector(adc_tr_data_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"000b" =>
              slv_data_out_o(11 downto 0)
                <= std_logic_vector(adc_tr_limit);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';  

            when x"000c" =>
              slv_data_out_o(11 downto 0)   <= std_logic_vector(adc_average);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000d" =>
              slv_data_out_o(3 downto 0)    <=
                std_logic_vector(adc_average_divisor);
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"000e" =>
              slv_data_out_o(15 downto 0)   <=
                std_logic_vector(pileup_ctr);
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';
         
            when x"000f" =>
              slv_data_out_o(15 downto 0)   <=
                std_logic_vector(overflow_ctr);
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0010" =>
              slv_data_out_o(11 downto 0)
                <= std_logic_vector(adc_tr_error_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';
                      
            when x"0011" =>
              slv_data_out_o(0)             <= adc_tr_debug_mode;
              slv_data_out_o(31 downto 1)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0012" =>
              slv_data_out_o                <= nx_trigger_ctr_t_nr;
              slv_ack_o                     <= '1';

            when x"0013" =>
              slv_data_out_o(15 downto 0)   <= frame_dt_error_ctr;
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';

            when others  =>
              slv_unknown_addr_o            <= '1';
              slv_ack_o                     <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              clear_counters                <= '1';
              slv_ack_o                     <= '1';

            when x"000b" =>
              adc_tr_limit
                <= unsigned(SLV_DATA_IN(11 downto 0));
              slv_ack_o                     <= '1';  

            when x"000d" =>
              adc_average_divisor           <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                     <= '1';
                  
            when x"0011" =>
              adc_tr_debug_mode             <= SLV_DATA_IN(0);
              slv_ack_o                     <= '1';
  
            when others  =>
              slv_unknown_addr_o            <= '1';
              slv_ack_o                     <= '0';
          end case;                
        else
          slv_ack_o                         <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  adc_tr_error_o         <= adc_tr_error;
  
  TIMESTAMP_OUT          <= timestamp_o;
  CHANNEL_OUT            <= channel_o;
  TIMESTAMP_STATUS_OUT   <= timestamp_status_o;
  ADC_DATA_OUT           <= adc_data_o;
  DATA_CLK_OUT           <= data_clk_o;
  NX_TOKEN_RETURN_OUT    <= nx_token_return_o;
  NX_NOMORE_DATA_OUT     <= nx_nomore_data_o;

  ADC_TR_ERROR_OUT       <= adc_tr_error_o;
  ERROR_OUT              <= error_o;

  -- Slave 
  SLV_DATA_OUT           <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT   <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT   <= slv_unknown_addr_o;
  SLV_ACK_OUT            <= slv_ack_o;

end Behavioral;
