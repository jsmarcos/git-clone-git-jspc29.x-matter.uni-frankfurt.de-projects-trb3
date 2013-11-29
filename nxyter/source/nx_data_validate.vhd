library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity nx_data_validate is
  port (
    CLK_IN               : in  std_logic;  
    RESET_IN             : in  std_logic;

    -- Inputs
    NX_TIMESTAMP_IN      : in  std_logic_vector(31 downto 0);
    ADC_DATA_IN          : in  std_logic_vector(11 downto 0);
    NEW_DATA_IN          : in  std_logic;

    -- Outputs
    TIMESTAMP_OUT        : out std_logic_vector(13 downto 0);
    CHANNEL_OUT          : out std_logic_vector(6 downto 0);
    TIMESTAMP_STATUS_OUT : out std_logic_vector(2 downto 0);
    ADC_DATA_OUT         : out std_logic_vector(11 downto 0);
    DATA_VALID_OUT       : out std_logic;

    NX_TOKEN_RETURN_OUT  : out std_logic;
    NX_NOMORE_DATA_OUT   : out std_logic;

    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
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
  signal parity_bit           : std_logic;
  signal parity               : std_logic;
  signal adc_data             : std_logic_vector(11 downto 0);
  
  -- Validate Timestamp
  signal timestamp_o          : std_logic_vector(13 downto 0);
  signal channel_o            : std_logic_vector(6 downto 0);
  signal timestamp_status_o   : std_logic_vector(2 downto 0);
  signal adc_data_o           : std_logic_vector(11 downto 0);
  signal data_valid_o         : std_logic;

  signal nx_token_return_o    : std_logic;
  signal nx_nomore_data_o     : std_logic;
  
  signal invalid_frame_ctr    : unsigned(15 downto 0);
  signal overflow_ctr         : unsigned(15 downto 0);
  signal pileup_ctr           : unsigned(15 downto 0);
  signal parity_error_ctr     : unsigned(15 downto 0);

  signal trigger_rate_inc     : std_logic;
  signal frame_rate_inc       : std_logic;

  -- Rate Calculation
  signal nx_trigger_ctr_t     : unsigned(27 downto 0);
  signal nx_frame_ctr_t       : unsigned(27 downto 0);
  signal nx_rate_timer        : unsigned(27 downto 0);

  -- ADC Averages
  signal adc_average_divisor  : unsigned(3 downto 0);
  signal adc_average_ctr      : unsigned(8 downto 0);
  signal adc_average_sum      : unsigned(24 downto 0);
  signal adc_average          : unsigned(11 downto 0);
  signal adc_data_last        : std_logic_vector(11 downto 0);
  signal adc_av               : std_logic;
  
  -- Config
  signal readout_type         : std_logic_vector(1 downto 0);

  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal clear_counters       : std_logic;
  signal nx_hit_rate          : unsigned(27 downto 0);
  signal nx_frame_rate        : unsigned(27 downto 0);
  
  signal invalid_adc : std_logic;
  
begin

  -- Debug Line
  DEBUG_OUT(0)                    <= CLK_IN;
  DEBUG_OUT(1)                    <= nx_token_return_o;
  DEBUG_OUT(2)                    <= nx_nomore_data_o;
  DEBUG_OUT(3)                    <= data_valid_o;
  DEBUG_OUT(4)                    <= new_timestamp;
  DEBUG_OUT(8 downto 5)           <= (others => '0');
  DEBUG_OUT(15 downto 9)          <= channel_o;
  --DEBUG_OUT(6 downto 4)           <= timestamp_status_o;
  --DEBUG_OUT(7)                    <= nx_token_return_o;
  --DEBUG_OUT(8)                    <= invalid_adc;--nx_nomore_data_o;
  
  --DEBUG_OUT(15 downto 9)          <= channel_o;

  -----------------------------------------------------------------------------
  -- Gray Decoder for Timestamp and Channel Id
  -----------------------------------------------------------------------------

  Gray_Decoder_1: Gray_Decoder          -- Decode nx_timestamp
    generic map (
      WIDTH => 14
      )
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      GRAY_IN(13 downto 7) => not NX_TIMESTAMP_IN(30 downto 24),
      GRAY_IN( 6 downto 0) => not NX_TIMESTAMP_IN(22 downto 16),
      BINARY_OUT           => nx_timestamp
      );

  Gray_Decoder_2: Gray_Decoder          -- Decode Channel_ID
    generic map (
      WIDTH => 7
      )
    port map (
      CLK_IN     => CLK_IN,
      RESET_IN   => RESET_IN,
      GRAY_IN    => NX_TIMESTAMP_IN(14 downto 8),
      BINARY_OUT => nx_channel_id
      );

  -- Separate Status-, Parity- and Frame-bits, calculate parity
  PROC_TIMESTAMP_BITS: process (CLK_IN)
    variable parity_bits : std_logic_vector(22 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        valid_frame_bits    <= (others => '0');
        status_bits         <= (others => '0');
        parity_bit          <= '0';
        parity              <= '0';
        new_timestamp       <= '0';
        adc_data            <= (others => '0');
      else
        -- Timestamp Bit #6 is excluded (funny nxyter-bug)
        parity_bits         := NX_TIMESTAMP_IN(31 downto 24) &
                               NX_TIMESTAMP_IN(21 downto 16) &
                               NX_TIMESTAMP_IN(14 downto  8) &
                               NX_TIMESTAMP_IN( 2 downto  1);
        valid_frame_bits    <= (others => '0');
        status_bits         <= (others => '0');
        parity_bit          <= '0';
        parity              <= '0';
        new_timestamp       <= '0';
        adc_data            <= (others => '0');
        
        if (NEW_DATA_IN = '1') then
          valid_frame_bits(3) <= NX_TIMESTAMP_IN(31);
          valid_frame_bits(2) <= NX_TIMESTAMP_IN(23);
          valid_frame_bits(1) <= NX_TIMESTAMP_IN(15);
          valid_frame_bits(0) <= NX_TIMESTAMP_IN(7);
          status_bits         <= NX_TIMESTAMP_IN(2 downto 1);
          parity_bit          <= NX_TIMESTAMP_IN(0);
          parity              <= xor_all(parity_bits);
          adc_data            <= ADC_DATA_IN;
          new_timestamp       <= '1';
        end if;
      end if;
    end if;
  end process PROC_TIMESTAMP_BITS;    

  -----------------------------------------------------------------------------
  -- Filter only valid events
  -----------------------------------------------------------------------------

  PROC_VALIDATE_TIMESTAMP: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        timestamp_o          <= (others => '0');
        channel_o            <= (others => '0');
        timestamp_status_o   <= (others => '0');
        adc_data_o           <= (others => '0');
        data_valid_o         <= '0';
        nx_token_return_o    <= '0';
        nx_nomore_data_o     <= '0';
        trigger_rate_inc     <= '0';
        frame_rate_inc       <= '0';

        invalid_frame_ctr    <= (others => '0');
        overflow_ctr         <= (others => '0');
        pileup_ctr           <= (others => '0');
        parity_error_ctr     <= (others => '0');
      else
        timestamp_o          <= (others => '0');
        channel_o            <= (others => '0');
        timestamp_status_o   <= (others => '0');
        adc_data_o           <= (others => '0');
        data_valid_o         <= '0';
        trigger_rate_inc     <= '0';
        frame_rate_inc       <= '0';
        invalid_adc          <= '0';

        if (new_timestamp = '1') then
          case valid_frame_bits is
            
            -- Data Frame
            when "1000" =>
              ---- Check Overflow
              if ((status_bits(0) = '1') and (clear_counters = '0')) then
                overflow_ctr                 <= overflow_ctr + 1;
              end if;
              
              ---- Check Parity
              if ((parity_bit /= parity) and (clear_counters = '0')) then
                timestamp_status_o(2)        <= '1';
                parity_error_ctr             <= parity_error_ctr + 1;
              else
                timestamp_status_o(2)        <= '0';
              end if;

              -- Check PileUp
              if ((status_bits(1) = '1') and (clear_counters = '0')) then
                pileup_ctr                   <= pileup_ctr + 1;
              end if;
              
              -- Take Timestamp
              timestamp_o                    <= nx_timestamp;
              channel_o                      <= nx_channel_id;
              timestamp_status_o(1 downto 0) <= status_bits;
              adc_data_o                     <= adc_data;
              data_valid_o                   <= '1';
              
              if (adc_data = x"aff") then
                invalid_adc                  <= '1';
              end if;

              nx_token_return_o              <= '0';
              nx_nomore_data_o               <= '0';
              trigger_rate_inc               <= '1';
                                          
            -- Token return and nomore_data
            when "0000" =>
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

          frame_rate_inc                     <= '1';
        
        else
          nx_token_return_o                  <= nx_token_return_o;
          nx_nomore_data_o                   <= nx_nomore_data_o;
        end if;  

        -- Reset Counters
        if (clear_counters = '1') then
          invalid_frame_ctr                  <= (others => '0');
          overflow_ctr                       <= (others => '0');
          pileup_ctr                         <= (others => '0');
          parity_error_ctr                   <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_VALIDATE_TIMESTAMP;

  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        nx_trigger_ctr_t     <= (others => '0');
        nx_frame_ctr_t       <= (others => '0');
        nx_rate_timer        <= (others => '0');
        nx_hit_rate          <= (others => '0');
        nx_frame_rate        <= (others => '0');
      else
        if (nx_rate_timer < x"5f5e100") then
          if (trigger_rate_inc = '1') then
            nx_trigger_ctr_t   <= nx_trigger_ctr_t + 1;
          end if;
          if (frame_rate_inc = '1') then
            nx_frame_ctr_t     <= nx_frame_ctr_t + 1;
          end if;
          nx_rate_timer        <= nx_rate_timer + 1;
        else
          nx_hit_rate          <= nx_trigger_ctr_t;
          nx_frame_rate        <= nx_frame_ctr_t;
          if (trigger_rate_inc = '0') then
            nx_trigger_ctr_t   <= (others => '0');
          else
            nx_trigger_ctr_t   <= x"000_0001";
          end if;
          if (frame_rate_inc = '0') then
            nx_frame_ctr_t     <= (others => '0');
          else
            nx_frame_ctr_t     <= x"000_0001";
          end if;
          nx_rate_timer        <= (others => '0');
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
        adc_data_last      <= (others => '0');
        adc_av             <= '0';
      else
        adc_av             <= '0';
        if ((adc_average_ctr srl to_integer(adc_average_divisor)) > 0) then
          adc_average      <= (adc_average_sum srl
                               to_integer(adc_average_divisor))(11 downto 0);
          adc_average_sum  <= (others => '0');
          adc_average_ctr  <= (others => '0');
          adc_av           <= '1';
        elsif (data_valid_o = '1') then
          adc_average_sum  <= adc_average_sum + unsigned(adc_data_o);
          adc_average_ctr  <= adc_average_ctr + 1;
        end if;

        if (data_valid_o = '1') then
          adc_data_last    <= adc_data_o;
        end if;
      end if;
    end if;
  end process PROC_ADC_AVERAGE;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o         <= (others => '0');
        slv_ack_o              <= '0';
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';
        adc_average_divisor    <= x"3";
      else
        slv_data_out_o         <= (others => '0');
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        clear_counters         <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(invalid_frame_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0001" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(overflow_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(pileup_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0003" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(parity_error_ctr);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0004" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(nx_hit_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0005" =>
              slv_data_out_o(27 downto 0)  <=
                std_logic_vector(nx_frame_rate);
              slv_data_out_o(31 downto 28) <= (others => '0');
              slv_ack_o                    <= '1';

            when x"0006" =>
              slv_data_out_o(11 downto 0)   <= adc_data_last;
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0007" =>
              slv_data_out_o(11 downto 0)   <= std_logic_vector(adc_average);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';
 
            when x"0008" =>
              slv_data_out_o(3 downto 0)    <=
                std_logic_vector(adc_average_divisor);
              slv_data_out_o(31 downto 4)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              clear_counters               <= '1';
              slv_ack_o                    <= '1';

            when x"0008" =>
              adc_average_divisor           <= SLV_DATA_IN(3 downto 0);
              slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;                
        else
          slv_ack_o                        <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMESTAMP_OUT         <= timestamp_o;
  CHANNEL_OUT           <= channel_o;
  TIMESTAMP_STATUS_OUT  <= timestamp_status_o;
  ADC_DATA_OUT          <= adc_data_o;
  DATA_VALID_OUT        <= data_valid_o;
  NX_TOKEN_RETURN_OUT   <= nx_token_return_o;
  NX_NOMORE_DATA_OUT    <= nx_nomore_data_o;
  
  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
end Behavioral;
