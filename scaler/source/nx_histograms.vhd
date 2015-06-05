library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity nx_histograms is
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    
    RESET_HISTS_IN       : in  std_logic;

    CHANNEL_FILL_IN      : in  std_logic;
    CHANNEL_ID_IN        : in  std_logic_vector(6 downto 0);
    CHANNEL_ADC_IN       : in  std_logic_vector(11 downto 0);
    CHANNEL_TS_IN        : in  std_logic_vector(8 downto 0);
    CHANNEL_PILEUP_IN    : in  std_logic;
    CHANNEL_OVERFLOW_IN  : in  std_logic;
    
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

architecture Behavioral of nx_histograms is

  -- Hit Histogram
  signal hit_num_averages    : unsigned(2 downto 0);
  signal hit_average_enable  : std_logic;
  signal hit_write_busy      : std_logic;
  signal hit_read_busy       : std_logic;
  
  signal hit_write_id        : std_logic_vector(6 downto 0);
  signal hit_write_data      : std_logic_vector(31 downto 0);
  signal hit_write           : std_logic;
  signal hit_add             : std_logic;

  signal hit_read_id         : std_logic_vector(6 downto 0);
  signal hit_read            : std_logic;
  signal hit_read_data       : std_logic_vector(31 downto 0);
  signal hit_read_data_valid : std_logic;

  -- PileUp Histogram
  signal pileup_num_averages    : unsigned(2 downto 0);
  signal pileup_average_enable  : std_logic;
  signal pileup_write_busy      : std_logic;
  signal pileup_read_busy       : std_logic;
         
  signal pileup_write_id        : std_logic_vector(6 downto 0);
  signal pileup_write_data      : std_logic_vector(31 downto 0);
  signal pileup_write           : std_logic;
  signal pileup_add             : std_logic;
         
  signal pileup_read_id         : std_logic_vector(6 downto 0);
  signal pileup_read            : std_logic;
  signal pileup_read_data       : std_logic_vector(31 downto 0);
  signal pileup_read_data_valid : std_logic;

  -- OverFlow Histogram
  signal ovfl_num_averages    : unsigned(2 downto 0);
  signal ovfl_average_enable  : std_logic;
  signal ovfl_write_busy      : std_logic;
  signal ovfl_read_busy       : std_logic;
         
  signal ovfl_write_id        : std_logic_vector(6 downto 0);
  signal ovfl_write_data      : std_logic_vector(31 downto 0);
  signal ovfl_write           : std_logic;
  signal ovfl_add             : std_logic;
         
  signal ovfl_read_id         : std_logic_vector(6 downto 0);
  signal ovfl_read            : std_logic;
  signal ovfl_read_data       : std_logic_vector(31 downto 0);
  signal ovfl_read_data_valid : std_logic;

  -- ADC Value Histogram
  signal adc_num_averages     : unsigned(2 downto 0);
  signal adc_average_enable   : std_logic;
  signal adc_write_busy       : std_logic;
  signal adc_read_busy        : std_logic;
                              
  signal adc_write_id         : std_logic_vector(6 downto 0);
  signal adc_write_data       : std_logic_vector(31 downto 0);
  signal adc_write            : std_logic;
  signal adc_add              : std_logic;
                              
  signal adc_read_id          : std_logic_vector(6 downto 0);
  signal adc_read             : std_logic;
  signal adc_read_data        : std_logic_vector(31 downto 0);
  signal adc_read_data_valid  : std_logic;

  -- Timestamp Histogram
  signal ts_num_averages      : unsigned(2 downto 0);
  signal ts_average_enable    : std_logic;
  signal ts_write_busy        : std_logic;
  signal ts_read_busy         : std_logic;
                              
  signal ts_write_id          : std_logic_vector(8 downto 0);
  signal ts_write_data        : std_logic_vector(31 downto 0);
  signal ts_write             : std_logic;
  signal ts_add               : std_logic;
                              
  signal ts_read_id           : std_logic_vector(8 downto 0);
  signal ts_read              : std_logic;
  signal ts_read_data         : std_logic_vector(31 downto 0);
  signal ts_read_data_valid   : std_logic;
  
  -- Reset Hists              
  signal RESET_HISTS          : std_logic;
                              
  -- Slave Bus                     
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  
begin
  
  ---------------------------------------------------------------------------


 -- DEBUG_OUT(0)               <= CLK_IN;
 -- DEBUG_OUT(1)               <= CHANNEL_FILL_IN;
 -- DEBUG_OUT(2)               <= hit_write_busy;
 -- DEBUG_OUT(3)               <= pileup_write_busy;
 -- DEBUG_OUT(4)               <= ovfl_write_busy;
 -- DEBUG_OUT(5)               <= adc_write_busy;
 --
 -- DEBUG_OUT(6)               <= hit_read_busy;
 -- DEBUG_OUT(7)               <= pileup_read_busy;
 -- DEBUG_OUT(8)               <= ovfl_read_busy;
 -- DEBUG_OUT(9)               <= adc_read_busy;
 -- DEBUG_OUT(15 downto 10)    <= (others => '0');

  
 -- DEBUG_OUT(15 downto 1)    <= SLV_ADDR_IN(14 downto 0);

  -----------------------------------------------------------------------------

  RESET_HISTS    <= RESET_IN or RESET_HISTS_IN;

  nx_histogram_hits: nx_histogram
    generic map (
      BUS_WIDTH => 7
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_HISTS,

      NUM_AVERAGES_IN        => hit_num_averages,
      AVERAGE_ENABLE_IN      => hit_average_enable,
      CHANNEL_ID_IN          => hit_write_id,
      CHANNEL_DATA_IN        => hit_write_data,
      CHANNEL_ADD_IN         => hit_add,
      CHANNEL_WRITE_IN       => hit_write,
      CHANNEL_WRITE_BUSY_OUT => hit_write_busy,

      CHANNEL_ID_READ_IN     => hit_read_id,
      CHANNEL_READ_IN        => hit_read,
      CHANNEL_DATA_OUT       => hit_read_data,
      CHANNEL_DATA_VALID_OUT => hit_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => hit_read_busy,

      DEBUG_OUT              => open
      );

  nx_histogram_adc: nx_histogram
    generic map (
      BUS_WIDTH => 7
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_HISTS,

      NUM_AVERAGES_IN        => adc_num_averages,
      AVERAGE_ENABLE_IN      => adc_average_enable,
      CHANNEL_ID_IN          => adc_write_id,
      CHANNEL_DATA_IN        => adc_write_data,
      CHANNEL_ADD_IN         => adc_add,
      CHANNEL_WRITE_IN       => adc_write,
      CHANNEL_WRITE_BUSY_OUT => adc_write_busy,

      CHANNEL_ID_READ_IN     => adc_read_id,
      CHANNEL_READ_IN        => adc_read,
      CHANNEL_DATA_OUT       => adc_read_data,
      CHANNEL_DATA_VALID_OUT => adc_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => adc_read_busy,

      DEBUG_OUT              => open
      );
  
  nx_histogram_pileup: nx_histogram
    generic map (
      BUS_WIDTH => 7
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_HISTS,

      NUM_AVERAGES_IN        => pileup_num_averages,
      AVERAGE_ENABLE_IN      => pileup_average_enable,
      CHANNEL_ID_IN          => pileup_write_id,
      CHANNEL_DATA_IN        => pileup_write_data,
      CHANNEL_ADD_IN         => pileup_add,
      CHANNEL_WRITE_IN       => pileup_write,
      CHANNEL_WRITE_BUSY_OUT => pileup_write_busy,
                                
      CHANNEL_ID_READ_IN     => pileup_read_id,
      CHANNEL_READ_IN        => pileup_read,
      CHANNEL_DATA_OUT       => pileup_read_data,
      CHANNEL_DATA_VALID_OUT => pileup_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => pileup_read_busy,

      DEBUG_OUT              => open
      );

  nx_histogram_ovfl: nx_histogram
    generic map (
      BUS_WIDTH => 7
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_HISTS,

      NUM_AVERAGES_IN        => ovfl_num_averages,
      AVERAGE_ENABLE_IN      => ovfl_average_enable,
      CHANNEL_ID_IN          => ovfl_write_id,
      CHANNEL_DATA_IN        => ovfl_write_data,
      CHANNEL_ADD_IN         => ovfl_add,
      CHANNEL_WRITE_IN       => ovfl_write,
      CHANNEL_WRITE_BUSY_OUT => ovfl_write_busy,
                             
      CHANNEL_ID_READ_IN     => ovfl_read_id,
      CHANNEL_READ_IN        => ovfl_read,
      CHANNEL_DATA_OUT       => ovfl_read_data,
      CHANNEL_DATA_VALID_OUT => ovfl_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => ovfl_read_busy,

      DEBUG_OUT              => open
      );
  
  nx_histogram_ts: nx_histogram
    generic map (
      BUS_WIDTH => 9
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_HISTS,

      NUM_AVERAGES_IN        => ts_num_averages,
      AVERAGE_ENABLE_IN      => ts_average_enable,
      CHANNEL_ID_IN          => ts_write_id,
      CHANNEL_DATA_IN        => ts_write_data,
      CHANNEL_ADD_IN         => ts_add,
      CHANNEL_WRITE_IN       => ts_write,
      CHANNEL_WRITE_BUSY_OUT => ts_write_busy,
                             
      CHANNEL_ID_READ_IN     => ts_read_id,
      CHANNEL_READ_IN        => ts_read,
      CHANNEL_DATA_OUT       => ts_read_data,
      CHANNEL_DATA_VALID_OUT => ts_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => ts_read_busy,

      DEBUG_OUT              => DEBUG_OUT 
      );
  
  -----------------------------------------------------------------------------
  -- Fill Histograms
  -----------------------------------------------------------------------------

  PROC_FILL_HISTOGRAMS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_HISTS = '1') then
        hit_write_id                   <= (others => '0');
        hit_write_data                 <= (others => '0');
        hit_write                      <= '0';
        hit_add                        <= '0';

        adc_write_id                   <= (others => '0');
        adc_write_data                 <= (others => '0');
        adc_write                      <= '0';
        adc_add                        <= '0';
        
        pileup_write_id                <= (others => '0');
        pileup_write_data              <= (others => '0');
        pileup_write                   <= '0';
        pileup_add                     <= '0';

        ovfl_write_id                  <= (others => '0');
        ovfl_write_data                <= (others => '0');
        ovfl_write                     <= '0';
        ovfl_add                       <= '0';

        ts_write_id                    <= (others => '0');
        ts_write_data                  <= (others => '0');
        ts_write                       <= '0';
        ts_add                         <= '0';
      else
        hit_write_id                   <= (others => '0');
        hit_write_data                 <= (others => '0');
        hit_write                      <= '0';
        hit_add                        <= '0';

        adc_write_id                   <= (others => '0');
        adc_write_data                 <= (others => '0');
        adc_write                      <= '0';
        adc_add                        <= '0';
        
        pileup_write_id                <= (others => '0');
        pileup_write_data              <= (others => '0');
        pileup_write                   <= '0';
        pileup_add                     <= '0';

        ovfl_write_id                  <= (others => '0');
        ovfl_write_data                <= (others => '0');
        ovfl_write                     <= '0';
        ovfl_add                       <= '0';

        ts_write_id                    <= (others => '0');
        ts_write_data                  <= (others => '0');
        ts_write                       <= '0';
        ts_add                         <= '0';
        
        if (CHANNEL_FILL_IN = '1' and  hit_write_busy = '0') then
          hit_write_id                   <= CHANNEL_ID_IN;
          hit_write_data                 <= x"0000_0001";
          hit_add                        <= '1';
          
          adc_write_id                   <= CHANNEL_ID_IN;
          adc_write_data(11 downto 0)    <= CHANNEL_ADC_IN; 
          adc_write_data(31 downto 12)   <= (others => '0');
          adc_add                        <= '1';
          
          if (CHANNEL_PILEUP_IN = '1') then
            pileup_write_id              <= CHANNEL_ID_IN;
            pileup_write_data            <= x"0000_0001";
            pileup_add                   <= '1';
          end if;
          
          if (CHANNEL_OVERFLOW_IN = '1') then
            ovfl_write_id                <= CHANNEL_ID_IN;
            ovfl_write_data              <= x"0000_0001";
            ovfl_add                     <= '1';
          end if;

          if (unsigned(CHANNEL_TS_IN) > 0) then
            ts_write_id                  <= CHANNEL_TS_IN;
            ts_write_data                <= x"0000_0001";
            ts_add                       <= '1';
          end if;

        end if;
      end if;
    end if;
  end process PROC_FILL_HISTOGRAMS;

  ---------------------------------------------------------------------------
  -- Trbnet Slave Bus
  ---------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_HISTOGRAMS_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_HISTS = '1') then
        slv_data_out_o        <= (others => '0');
        slv_no_more_data_o    <= '0';
        slv_unknown_addr_o    <= '0';
        slv_ack_o             <= '0';
                              
        hit_read_id           <= (others => '0');
        hit_read              <= '0';
        hit_num_averages      <= "000";
        hit_average_enable    <= '0';

        adc_read_id           <= (others => '0');
        adc_read              <= '0';
        adc_num_averages      <= (others => '0');
        adc_average_enable    <= '1';
        
        pileup_read_id        <= (others => '0');
        pileup_read           <= '0';
        pileup_num_averages   <= "000";
        pileup_average_enable <= '0';

        ovfl_read_id          <= (others => '0');
        ovfl_read             <= '0';
        ovfl_num_averages     <= "000";
        ovfl_average_enable   <= '0';

        ts_read_id            <= (others => '0');
        ts_read               <= '0';
        ts_num_averages       <= "000";
        ts_average_enable     <= '0';
      else
        slv_data_out_o        <= (others => '0');
        slv_unknown_addr_o    <= '0';
        slv_no_more_data_o    <= '0';

        hit_read_id           <= (others => '0');
        hit_read              <= '0';

        adc_read_id           <= (others => '0');
        adc_read              <= '0';

        pileup_read_id        <= (others => '0');
        pileup_read           <= '0';

        ovfl_read_id          <= (others => '0');
        ovfl_read             <= '0';

        ts_read_id            <= (others => '0');
        ts_read               <= '0';
        
        if (hit_read_busy    = '1' or
            adc_read_busy    = '1' or
            pileup_read_busy = '1' or
            ovfl_read_busy   = '1' or
            ts_read_busy     = '1') then
          if (hit_read_data_valid = '1') then
            slv_data_out_o                   <= hit_read_data;
            slv_ack_o                        <= '1';
          elsif (adc_read_data_valid = '1') then
            slv_data_out_o                   <= adc_read_data;
            slv_ack_o                        <= '1';
          elsif (pileup_read_data_valid = '1') then
            slv_data_out_o                   <= pileup_read_data;
            slv_ack_o                        <= '1';
          elsif (ovfl_read_data_valid = '1') then
            slv_data_out_o                   <= ovfl_read_data;
            slv_ack_o                        <= '1';
          elsif (ts_read_data_valid = '1') then
            slv_data_out_o                   <= ts_read_data;
            slv_ack_o                        <= '1';
          else
            slv_ack_o                        <= '0';
          end if;
          
        elsif (SLV_READ_IN  = '1') then
          if (unsigned(SLV_ADDR_IN) >= x"0000" and
              unsigned(SLV_ADDR_IN) <= x"007f") then
            hit_read_id                      <= SLV_ADDR_IN(6 downto 0);
            hit_read                         <= '1';
            slv_ack_o                        <= '0';
          elsif (unsigned(SLV_ADDR_IN) >= x"0100" and
                 unsigned(SLV_ADDR_IN) <= x"017f") then
            pileup_read_id                   <= SLV_ADDR_IN(6 downto 0);
            pileup_read                      <= '1';            
            slv_ack_o                        <= '0';
          elsif (unsigned(SLV_ADDR_IN) >= x"0200" and
                 unsigned(SLV_ADDR_IN) <= x"027f") then
            ovfl_read_id                     <= SLV_ADDR_IN(6 downto 0);
            ovfl_read                        <= '1';
            slv_ack_o                        <= '0';
          elsif (unsigned(SLV_ADDR_IN) >= x"0300" and
                 unsigned(SLV_ADDR_IN) <= x"037f") then
            adc_read_id                      <= SLV_ADDR_IN(6 downto 0);
            adc_read                         <= '1';
            slv_ack_o                        <= '0';
          elsif (unsigned(SLV_ADDR_IN) >= x"0400" and
                 unsigned(SLV_ADDR_IN) <= x"05ff") then
            ts_read_id                       <= SLV_ADDR_IN(8 downto 0);
            ts_read                          <= '1';
            slv_ack_o                        <= '0';
          else
            case SLV_ADDR_IN is
              when x"0080" =>
                slv_data_out_o(2 downto 0)   <=
                  std_logic_vector(hit_num_averages);
                slv_data_out_o(31 downto 3)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0081" =>
                slv_data_out_o(0)            <= hit_average_enable;
                slv_data_out_o(31 downto 1)  <= (others => '0');
                slv_ack_o                    <= '1';
              
              when x"0180" =>
                slv_data_out_o(2 downto 0)   <=
                  std_logic_vector(pileup_num_averages);
                slv_data_out_o(31 downto 3)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0181" =>
                slv_data_out_o(0)            <= pileup_average_enable;
                slv_data_out_o(31 downto 1)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0280" =>
                slv_data_out_o(2 downto 0)   <=
                  std_logic_vector(ovfl_num_averages);
                slv_data_out_o(31 downto 3)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0281" =>
                slv_data_out_o(0)            <= ovfl_average_enable;
                slv_data_out_o(31 downto 1)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0380" =>
                slv_data_out_o(2 downto 0)   <=
                  std_logic_vector(adc_num_averages);
                slv_data_out_o(31 downto 3)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0381" =>
                slv_data_out_o(0)            <= adc_average_enable;
                slv_data_out_o(31 downto 1)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0600" =>
                slv_data_out_o(2 downto 0)   <=
                  std_logic_vector(ts_num_averages);
                slv_data_out_o(31 downto 3)  <= (others => '0');
                slv_ack_o                    <= '1';

              when x"0601" =>
                slv_data_out_o(0)            <= ts_average_enable;
                slv_data_out_o(31 downto 1)  <= (others => '0');
                slv_ack_o                    <= '1';
                
              when others =>
                slv_unknown_addr_o           <= '1';
                slv_ack_o                    <= '0';

            end case;
          end if;
          
        elsif (SLV_WRITE_IN  = '1') then

          case SLV_ADDR_IN is
            when x"0080" =>
              hit_num_averages               <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                      <= '1';

            when x"0081" =>
              hit_average_enable             <= SLV_DATA_IN(0);
              slv_ack_o                      <= '1';
           
            when x"0180" =>
              pileup_num_averages            <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                      <= '1';

            when x"0181" =>
              pileup_average_enable          <= SLV_DATA_IN(0);
              slv_ack_o                      <= '1';
              
            when x"0280" =>
              ovfl_num_averages              <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                      <= '1';

            when x"0281" =>
              ovfl_average_enable            <= SLV_DATA_IN(0);
              slv_ack_o                      <= '1';
              
            when x"0380" =>
              adc_num_averages               <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                      <= '1';

            when x"0381" =>
              adc_average_enable             <= SLV_DATA_IN(0);
              slv_ack_o                      <= '1';

            when x"0600" =>
              ts_num_averages                <= SLV_DATA_IN(2 downto 0);
              slv_ack_o                      <= '1';
              
            when x"0601" =>
              ts_average_enable              <= SLV_DATA_IN(0);
              slv_ack_o                      <= '1';

            when others =>
              slv_unknown_addr_o             <= '1';
              slv_ack_o                      <= '0';

          end case;
        else
          slv_ack_o                          <= '0';
        end if;
      end if;
    end if;     
  end process PROC_HISTOGRAMS_READ;
  
  ---------------------------------------------------------------------------
  -- Output Signals
  ---------------------------------------------------------------------------

  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;

end Behavioral;
