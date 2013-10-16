library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.nxyter_components.all;

entity nx_data_receiver is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_MAIN_CLK_IN       : in  std_logic;
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

    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_data_receiver is

  -----------------------------------------------------------------------------
  -- NX_MAIN_CLK Domain
  -----------------------------------------------------------------------------

  -- Check Nxyter Data Clock
  signal nx_data_clock_t           : std_logic;
  signal nx_data_clock             : std_logic;
  signal nx_data_clock_last        : std_logic;
  signal nx_data_clock_nok         : std_logic;

  -- CLK_IN Domain
  signal nx_data_clock_invalid     : std_logic;
  
  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK Domain
  -----------------------------------------------------------------------------

  -- FIFO DC Input Handler
  signal nx_timestamp_reg_t        : std_logic_vector(7 downto 0);
  signal nx_timestamp_reg          : std_logic_vector(7 downto 0);
  signal nx_fifo_full              : std_logic;
  signal nx_fifo_reset             : std_logic;
                                   
  -- NX_TIMESTAMP_IN Process       
  signal frame_byte_ctr            : unsigned(1 downto 0);
  signal nx_frame_word             : std_logic_vector(31 downto 0);
  signal nx_new_frame              : std_logic;
                                   
  -- Frame Sync Process                  
  signal frame_byte_pos            : unsigned(1 downto 0);
                                   
  -- RS Sync FlipFlop              
  signal nx_frame_synced           : std_logic;
  signal rs_sync_set               : std_logic;
  signal rs_sync_reset             : std_logic;
                                   
  -- Parity Check                  
  signal parity_error              : std_logic;
                                   
  -- Write to FIFO Handler         
  signal nx_fifo_data_input        : std_logic_vector(31 downto 0);
  signal nx_fifo_write_enable      : std_logic;
                                   
  -- NX Clock Active               
  signal nx_clk_active_ff_0        : std_logic;
  signal nx_clk_active_ff_1        : std_logic;
  signal nx_clk_active_ff_2        : std_logic;
                                   
  -- ADC Ckl Generator             
  signal adc_clk_skip              : std_logic;
  signal adc_sample_clk            : std_logic;
  signal johnson_ff_0              : std_logic;
  signal johnson_ff_1              : std_logic;
  signal adc_clk_inv               : std_logic;
  signal adc_clk_delay             : std_logic_vector(2 downto 0);
  signal adc_clk_ok                : std_logic;
                                   
  -- ADC RESET                     
  signal adc_clk_ok_last           : std_logic;
  signal adc_reset_s               : std_logic;
  signal adc_reset_ctr             : unsigned(11 downto 0);
  
  -----------------------------------------------------------------------------
  -- CLK_IN Domain
  -----------------------------------------------------------------------------

  -- NX FIFO READ ENABLE
  signal nx_fifo_read_enable       : std_logic;
  signal nx_fifo_empty             : std_logic;
  signal nx_read_enable            : std_logic;
  signal nx_fifo_data_valid_t      : std_logic;
  signal nx_fifo_data_valid        : std_logic;
                                   
  -- NX FIFO READ                  
  signal nx_timestamp_t            : std_logic_vector(31 downto 0);
  signal nx_new_timestamp          : std_logic;
  signal nx_new_timestamp_ctr      : unsigned(3 downto 0);
  signal nx_fifo_data              : std_logic_vector(31 downto 0);
                                   
  -- Resync Counter Process                  
  signal resync_counter            : unsigned(11 downto 0);
  signal resync_ctr_inc            : std_logic;
  signal nx_clk_active             : std_logic;
                                   
  -- Parity Error Counter Process                  
  signal parity_error_counter      : unsigned(11 downto 0);
  signal parity_error_ctr_inc      : std_logic;
                                   
  signal reg_nx_frame_synced_t     : std_logic;
  signal reg_nx_frame_synced       : std_logic;

  -----------------------------------------------------------------------------
  -- ADC Data Handler
  -----------------------------------------------------------------------------

  -- ADC Handler
  signal adc_reset_r               : std_logic;
  signal adc_reset_l               : std_logic;
  signal adc_reset                 : std_logic;
                                   
  signal adc_data                  : std_logic_vector(11 downto 0);
  signal test_adc_data             : std_logic_vector(11 downto 0);
  signal adc_data_valid            : std_logic;
                                   
  signal adc_data_t                : std_logic_vector(11 downto 0);
  signal adc_new_data              : std_logic;
  signal adc_new_data_ctr          : unsigned(3 downto 0);
                                   
  -- ADC TEST INPUT DATA           
  signal adc_input_error_enable    : std_logic;
  signal adc_input_error_ctr       : unsigned(15 downto 0);
  
  
  -- Data Output Handler
  type STATES is (IDLE,
                  WAIT_ADC,
                  WAIT_TIMESTAMP
                  );
  signal STATE : STATES;
  signal STATE_d                   : std_logic_vector(1 downto 0);
                                   
  signal nx_timestamp_o            : std_logic_vector(31 downto 0);
  signal adc_data_o                : std_logic_vector(11 downto 0);
  signal new_data_o                : std_logic;
                                   
  -- Slave Bus                     
  signal slv_data_out_o            : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o        : std_logic;
  signal slv_unknown_addr_o        : std_logic;
  signal slv_ack_o                 : std_logic;
                                   
  signal reset_resync_ctr          : std_logic;
  signal reset_parity_error_ctr    : std_logic;
  signal fifo_reset_r              : std_logic;
  signal debug_adc                 : std_logic_vector(1 downto 0);

begin
  
  PROC_DEBUG_MULT: process(debug_adc,
                           adc_data,
                           adc_data_valid,
                           test_adc_data,
                           adc_clk_ok,
                           adc_clk_ok_last,
                           adc_clk_skip,
                           adc_reset_s,
                           adc_reset,
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
      when "01" =>
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= NX_TIMESTAMP_CLK_IN;
        DEBUG_OUT(2)            <= TRIGGER_IN;
        DEBUG_OUT(3)            <= adc_data_valid;
        DEBUG_OUT(15 downto 4)  <= adc_data;
        
      when "10" =>
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= NX_TIMESTAMP_CLK_IN;
        DEBUG_OUT(2)            <= TRIGGER_IN;
        DEBUG_OUT(3)            <= adc_data_valid;
        DEBUG_OUT(15 downto 4)  <= test_adc_data;

      when "11" =>
        DEBUG_OUT(0)            <= NX_TIMESTAMP_CLK_IN;
        DEBUG_OUT(1)            <= CLK_IN;
        DEBUG_OUT(2)            <= TRIGGER_IN;
        DEBUG_OUT(3)            <= adc_clk_ok;
        DEBUG_OUT(4)            <= adc_clk_ok_last;
        DEBUG_OUT(5)            <= adc_clk_skip;
        DEBUG_OUT(6)            <= adc_reset_r;
        DEBUG_OUT(7)            <= adc_reset_l;
        DEBUG_OUT(8)            <= adc_reset_s;
        DEBUG_OUT(9)            <= adc_reset;
        DEBUG_OUT(10)           <= nx_new_frame;
        DEBUG_OUT(11)           <= nx_data_clock;
        DEBUG_OUT(12)           <= nx_data_clock_last;
        DEBUG_OUT(13)           <= nx_data_clock_nok;
        DEBUG_OUT(14)           <= nx_data_clock_invalid;
        DEBUG_OUT(15)           <= '0';
        
        --DEBUG_OUT(15 downto 11) <= adc_reset_ctr(4 downto 0) ;
        
      when others => 
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= NX_TIMESTAMP_CLK_IN;
        DEBUG_OUT(2)            <= TRIGGER_IN;
        DEBUG_OUT(3)            <= nx_fifo_full;
        DEBUG_OUT(4)            <= nx_fifo_write_enable;
        DEBUG_OUT(5)            <= nx_fifo_empty;
        DEBUG_OUT(6)            <= nx_fifo_read_enable;
        DEBUG_OUT(7)            <= nx_fifo_data_valid;

        DEBUG_OUT(8)            <= adc_data_valid;
        
        DEBUG_OUT(9)            <= nx_new_timestamp;
        DEBUG_OUT(10)           <= adc_new_data;

        DEBUG_OUT(12 downto 11) <= STATE_d;
        DEBUG_OUT(13)           <= new_data_o;
        
        DEBUG_OUT(14)           <= nx_frame_synced;
        DEBUG_OUT(15)           <= rs_sync_reset;
    end case;

  end process PROC_DEBUG_MULT;
  
  -----------------------------------------------------------------------------
  -- NX_MAIN_CLK Domain
  -----------------------------------------------------------------------------
  PROC_CHECK_NX_DATA_CLOCK: process(NX_MAIN_CLK_IN)
  begin
    if (rising_edge(NX_MAIN_CLK_IN)) then
      if( RESET_IN = '1' ) then
        nx_data_clock_t        <= '0';
        nx_data_clock          <= '0';
        nx_data_clock_last     <= '0';
        nx_data_clock_nok      <= '0';
      else
        if (nx_data_clock /= nx_data_clock_last) then
          nx_data_clock_nok     <= '0';
        else
          nx_data_clock_nok     <= '1';
        end if;

        nx_data_clock_t        <= NX_TIMESTAMP_CLK_IN;
        nx_data_clock          <= nx_data_clock_t;
        nx_data_clock_last     <= nx_data_clock;
      end if;
    end if;
  end process PROC_CHECK_NX_DATA_CLOCK;

  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 3
      )
    port map (
      CLK_A_IN    => NX_MAIN_CLK_IN,
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => nx_data_clock_nok,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => nx_data_clock_invalid
      );

  
  -----------------------------------------------------------------------------
  -- ADC CLK DOMAIN
  -----------------------------------------------------------------------------

  adc_ad9222_1: entity work.adc_ad9222
    generic map (
      CHANNELS => 4,
      DEVICES  => 2,
      RESOLUTION => 12
      )
    port map (
      CLK                        => CLK_IN,
      CLK_ADCREF                 => adc_sample_clk,
      CLK_ADCDAT                 => ADC_CLK_DAT_IN,
      RESTART_IN                 => adc_reset,
      ADCCLK_OUT                 => ADC_SAMPLE_CLK_OUT,

      ADC_DATA(0)                => ADC_NX_IN(0), 
      ADC_DATA(1)                => ADC_B_IN(0),
      ADC_DATA(2)                => ADC_A_IN(0), 
      ADC_DATA(3)                => ADC_D_IN(0), 

      ADC_DATA(4)                => ADC_NX_IN(1), 
      ADC_DATA(5)                => ADC_A_IN(1), 
      ADC_DATA(6)                => ADC_B_IN(1), 
      ADC_DATA(7)                => ADC_D_IN(1),

      ADC_DCO                    => ADC_DCLK_IN,
      ADC_FCO                    => ADC_FCLK_IN,

      DATA_OUT(11 downto  0)     => adc_data,
      DATA_OUT(23 downto 12)     => test_adc_data,
      DATA_OUT(95 downto 24)     => open,

      FCO_OUT                    => open,
      DATA_VALID_OUT(0)          => adc_data_valid,
      DATA_VALID_OUT(1)          => open,
      DEBUG                      => open
      );

  adc_reset <= adc_reset_s or adc_reset_l or RESET_IN;

  pulse_to_level_1: pulse_to_level
    generic map (
      NUM_CYCLES => 7
      )
    port map (
      CLK_IN     => CLK_IN,
      RESET_IN   => RESET_IN,
      PULSE_IN   => adc_reset_r,
      LEVEL_OUT  => adc_reset_l
      );
  
  -----------------------------------------------------------------------------
  -- NX_TIMESTAMP_CLK_IN Domain
  -----------------------------------------------------------------------------

  nx_timestamp_reg   <= NX_TIMESTAMP_IN when rising_edge(NX_TIMESTAMP_CLK_IN);

  -- Transfer 8 to 32Bit 
  PROC_8_TO_32_BIT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if( RESET_IN = '1' ) then
        frame_byte_ctr   <= (others => '0');
        nx_frame_word    <= (others => '0');
        nx_new_frame     <= '0';
      else
        nx_new_frame     <= '0';
        
        case frame_byte_pos is
          when "11" => nx_frame_word(31 downto 24) <= nx_timestamp_reg;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "10" => nx_frame_word(23 downto 16) <= nx_timestamp_reg;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "01" => nx_frame_word(15 downto  8) <= nx_timestamp_reg;
                       frame_byte_ctr              <= frame_byte_ctr + 1;
                       
          when "00" => nx_frame_word( 7 downto  0) <= nx_timestamp_reg;
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
      if( RESET_IN = '1' ) then
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
      if (RESET_IN = '1' or rs_sync_reset = '1') then
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
      if (RESET_IN = '1') then
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

  -- Write to FIFO
  PROC_WRITE_TO_FIFO: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN) ) then
      if (RESET_IN = '1') then
        nx_fifo_data_input      <= (others => '0');
        nx_fifo_write_enable    <= '0';
      else
        nx_fifo_data_input      <= x"deadbeef";
        nx_fifo_write_enable    <= '0';
        if (nx_new_frame    = '1' and
            nx_frame_synced = '1' and
            nx_fifo_full    = '0') then
          nx_fifo_data_input    <= nx_frame_word; 
          nx_fifo_write_enable  <= '1';
        end if;
      end if;
    end if;
  end process PROC_WRITE_TO_FIFO;

  fifo_ts_32to32_dc_1: fifo_ts_32to32_dc
    port map (
      Data          => nx_fifo_data_input,
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
  
  nx_fifo_reset     <= RESET_IN or fifo_reset_r;

  PROC_NX_CLK_ACT: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if(RESET_IN = '1' ) then
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

  -- Johnson Counter
  PROC_ADC_CLK_GENERATOR: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_IN = '1') then
        johnson_ff_0  <= '0';
        johnson_ff_1  <= '0';
      else
        if (adc_clk_skip = '0') then
          johnson_ff_0 <= not johnson_ff_1;
          johnson_ff_1 <= johnson_ff_0;
        end if;
      end if;
    end if;
  end process PROC_ADC_CLK_GENERATOR;

  PROC_ADC_CLK_DELAY_4NS: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (falling_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_IN = '1') then
        adc_clk_inv <= '0';
      else
        adc_clk_inv <= johnson_ff_0;
      end if;
    end if;
  end process PROC_ADC_CLK_DELAY_4NS;
  
  adc_sample_clk <= adc_clk_inv when adc_clk_delay(0) = '1' else johnson_ff_0;
  
  PROC_ADC_CLK_DELAY: process(NX_TIMESTAMP_CLK_IN)
    variable adc_clk_state : std_logic_vector(1 downto 0);
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_IN = '1') then
        adc_clk_skip       <= '0';
        adc_clk_ok         <= '0';
      else
        adc_clk_state      := johnson_ff_1 & johnson_ff_0;
        adc_clk_skip       <= '0';
        if (nx_new_frame = '1') then
          if (adc_clk_state /= adc_clk_delay(2 downto 1)) then
            adc_clk_skip   <= '1';
            adc_clk_ok     <= '0';
          else
            adc_clk_ok     <= '1';        
          end if;
        end if;
      end if;
    end if;
  end process PROC_ADC_CLK_DELAY;

  PROC_ADC_RESET: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_IN = '1') then
        adc_clk_ok_last  <= '0';
        adc_reset_s      <= '0';
      else
        adc_reset_s      <= '0';
        adc_clk_ok_last  <= adc_clk_ok;
        if (adc_clk_ok_last = '0' and adc_clk_ok = '1') then
          adc_reset_s    <= '1';
        end if;
      end if;
    end if;
  end process PROC_ADC_RESET;
  
  PROC_RESET_CTR: process(NX_TIMESTAMP_CLK_IN)
  begin
    if (rising_edge(NX_TIMESTAMP_CLK_IN)) then
      if (RESET_IN = '1') then
        adc_reset_ctr        <= (others => '0');
      else
        if (adc_reset = '1') then
          adc_reset_ctr      <= adc_reset_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_RESET_CTR;

  -- PROC_CAL_RATES: process (CLK_IN)
  -- begin 
  --   if( rising_edge(CLK_IN) ) then
  --     if (RESET_IN = '1') then
  --       nx_trigger_ctr_t     <= (others => '0');
  --       nx_hit_rate          <= (others => '0');
  --       nx_frame_rate        <= (others => '0');
  --     else
  --     end if;
  --   end if;
  -- end process PROC_CAL_RATES;
  
  -----------------------------------------------------------------------------
  -- NX CLK_IN Domain
  -----------------------------------------------------------------------------

  -- FIFO Read Handler
  nx_fifo_read_enable     <= not nx_fifo_empty;

  PROC_NX_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' or fifo_reset_r = '1') then
        nx_fifo_data_valid_t      <= '0';
        nx_fifo_data_valid        <= '0';
      else
        -- Delay read signal by one CLK
        nx_fifo_data_valid_t      <= nx_fifo_read_enable;
        nx_fifo_data_valid        <= nx_fifo_data_valid_t;
      end if;
    end if;
  end process PROC_NX_FIFO_READ_ENABLE;

  PROC_NX_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or fifo_reset_r = '1') then
        nx_timestamp_t         <= (others => '0');
        nx_new_timestamp       <= '0';
        nx_new_timestamp_ctr   <= (others => '0');
      else
        if (nx_fifo_data_valid = '1') then
          nx_timestamp_t       <= nx_fifo_data;
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
      RESET_A_IN  => RESET_IN,
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
      RESET_A_IN  => RESET_IN,
      PULSE_A_IN  => parity_error,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => parity_error_ctr_inc
      );
  
  PROC_SYNC_FRAME_SYNC: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if(RESET_IN = '1' ) then
        reg_nx_frame_synced_t <= '0';
        reg_nx_frame_synced   <= '0';
      else
        reg_nx_frame_synced_t <= nx_frame_synced;
        reg_nx_frame_synced   <= reg_nx_frame_synced_t; 
      end if;
    end if;
  end process PROC_SYNC_FRAME_SYNC;

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
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or fifo_reset_r = '1') then
        adc_data_t         <= (others => '0');
        adc_new_data       <= '0';
        adc_new_data_ctr   <= (others => '0');
      else
        if (adc_data_valid = '1') then
          adc_data_t       <= adc_data;
          adc_new_data     <= '1';
          adc_new_data_ctr <= adc_new_data_ctr + 1;
        else
          adc_data_t       <= x"aff";
          adc_new_data     <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC_DATA_READ; 

  PROC_ADC_TEST_INPUT_DATA: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        adc_input_error_ctr      <= (others => '0');
      else
        if (adc_input_error_enable = '1') then
          if (adc_new_data = '1' and
              adc_data_t /= x"fff" and
              adc_data_t /= x"000") then
            adc_input_error_ctr  <= adc_input_error_ctr + 1;
          end if;
        else
          adc_input_error_ctr    <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_ADC_TEST_INPUT_DATA;
  
  -----------------------------------------------------------------------------
  -- Output handler
  -----------------------------------------------------------------------------
  PROC_OUTPUT_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or fifo_reset_r = '1') then
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
        fifo_reset_r                  <= '0';
        adc_clk_delay                 <= "111";
        adc_reset_r                   <= '0';
        debug_adc                     <= (others => '0');
        adc_input_error_enable        <= '0';
        -- pll_adc_sample_clk_reset      <= '1';
        -- pll_adc_sample_clk_dphase     <= (others => '0');
        -- pll_adc_sample_clk_finedelb   <= (others => '0');
      else                      
        slv_data_out_o                <= (others => '0');
        slv_ack_o                     <= '0';
        slv_unknown_addr_o            <= '0';
        slv_no_more_data_o            <= '0';
        reset_resync_ctr              <= '0';
        reset_parity_error_ctr        <= '0';
        fifo_reset_r                  <= '0';
        adc_reset_r                   <= '0';
        -- pll_adc_sample_clk_reset      <= '0';
        -- pll_adc_sample_clk_dphase     <= (others => '0');
        -- pll_adc_sample_clk_finedelb   <= (others => '0');
        
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
              slv_data_out_o(11 downto  0)  <= std_logic_vector(resync_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0003" =>
              slv_data_out_o(11 downto  0)  <=
                std_logic_vector(parity_error_counter);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1'; 

            when x"0005" =>
              case adc_clk_delay is
                when "010" => slv_data_out_o(2 downto 0) <= "000";
                when "011" => slv_data_out_o(2 downto 0) <= "001";
                when "000" => slv_data_out_o(2 downto 0) <= "010";
                when "001" => slv_data_out_o(2 downto 0) <= "011";
                when "100" => slv_data_out_o(2 downto 0) <= "100";
                when "101" => slv_data_out_o(2 downto 0) <= "101";
                when "110" => slv_data_out_o(2 downto 0) <= "110";
                when "111" => slv_data_out_o(2 downto 0) <= "111";
              end case;

              slv_data_out_o(31 downto 3)   <= (others => '0');
              slv_ack_o                     <= '1';   

            when x"0006" =>
              slv_data_out_o(11 downto  0)  <= std_logic_vector(adc_reset_ctr);
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0007" =>
              slv_data_out_o(1 downto 0)    <= debug_adc;
              slv_data_out_o(31 downto 2)   <= (others => '0');
              slv_ack_o                     <= '1';
              
            when x"0008" =>
              slv_data_out_o(11 downto 0)   <= adc_data_t;
              slv_data_out_o(31 downto 12)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0009" =>
              slv_data_out_o(0)             <= adc_input_error_enable;
              slv_data_out_o(31 downto 1)   <= (others => '0');
              slv_ack_o                     <= '1';

            when x"000a" =>
              slv_data_out_o(15 downto  0)  <= adc_input_error_ctr;
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';

            -- when x"000b" =>
            --   slv_data_out_o(0)             <= pll_adc_sample_clk_lock;
            --   slv_data_out_o(31 downto 1)   <= (others => '0');
            --   slv_ack_o                     <= '1';  
            -- 
            -- when x"000c" =>
            --   slv_data_out_o(3 downto 0)    <= pll_adc_sample_clk_dphase;
            --   slv_data_out_o(31 downto 4)   <= (others => '0');
            --   slv_ack_o                     <= '1';
            -- 
            -- when x"000d" =>
            --   slv_data_out_o(3 downto 0)    <= pll_adc_sample_clk_finedelb;
            --   slv_data_out_o(31 downto 4)   <= (others => '0');
            --   slv_ack_o                     <= '1';
              
            when others  =>
              slv_unknown_addr_o            <= '1';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" => 
              adc_reset_r                   <= '1';
              slv_ack_o                     <= '1';
              
            when x"0002" => 
              reset_resync_ctr              <= '1';
              slv_ack_o                     <= '1'; 

            when x"0003" => 
              reset_parity_error_ctr        <= '1';
              slv_ack_o                     <= '1'; 

            when x"0005" =>
              if (SLV_DATA_IN  < x"0000_0008") then
                case SLV_DATA_IN(2 downto 0) is
                  when "000" => adc_clk_delay <= "010";
                  when "001" => adc_clk_delay <= "011";
                  when "010" => adc_clk_delay <= "000";
                  when "011" => adc_clk_delay <= "001";
                  when "100" => adc_clk_delay <= "100";
                  when "101" => adc_clk_delay <= "101";
                  when "110" => adc_clk_delay <= "110";
                  when "111" => adc_clk_delay <= "111";
                end case;
              end if;
              slv_ack_o                     <= '1';

            when x"0007" =>
              debug_adc                     <= SLV_DATA_IN(1 downto 0);
              slv_ack_o                     <= '1';

            when x"0009" =>
              adc_input_error_enable        <= SLV_DATA_IN(0);
              slv_ack_o                     <= '1';

            -- when x"000b" =>
            --   pll_adc_sample_clk_reset      <= '1';
            --   slv_ack_o                     <= '1'; 
            -- 
            -- when x"000c" =>
            --   pll_adc_sample_clk_dphase     <= SLV_DATA_IN(3 downto 0);
            --   slv_ack_o                     <= '1'; 
            -- 
            -- when x"000d" =>
            --   pll_adc_sample_clk_finedelb   <= SLV_DATA_IN(3 downto 0);
            --   slv_ack_o                     <= '1'; 
              
            when others  =>
              slv_unknown_addr_o            <= '1';
              
          end case;                
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  -- Output Signals

  NX_TIMESTAMP_OUT      <= nx_timestamp_o;
  ADC_DATA_OUT          <= adc_data_o;
  NEW_DATA_OUT          <= new_data_o;
  
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
  
end Behavioral;
