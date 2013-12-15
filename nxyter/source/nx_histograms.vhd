library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_histograms is
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    
    RESET_HISTS_IN       : in  std_logic;

    CHANNEL_STAT_FILL_IN : in  std_logic;
    CHANNEL_ID_IN        : in  std_logic_vector(6 downto 0);
    CHANNEL_ADC_IN       : in  std_logic_vector(11 downto 0);
    
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

architecture nx_histograms of nx_histograms is

-- Histograms
  signal hist_write_busy      : std_logic;
  signal hist_read_busy       : std_logic;
  
  signal hist_write_id        : std_logic_vector(6 downto 0);
  signal hist_write_data      : std_logic_vector(31 downto 0);
  signal hist_write           : std_logic;
  signal hist_add             : std_logic;

  signal hist_read_id         : std_logic_vector(6 downto 0);
  signal hist_read            : std_logic;
  signal hist_read_data       : std_logic_vector(31 downto 0);
  signal hist_read_data_valid : std_logic;

  signal write_ctr            : unsigned(11 downto 0);
  
  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal reset_hists_r        : std_logic;
  
begin
  
  ---------------------------------------------------------------------------

  nx_histogram_1: nx_histogram
    generic map (
      BUS_WIDTH  => 7,
      DATA_WIDTH => 32
      )
    port map (
      CLK_IN                 => CLK_IN,
      RESET_IN               => RESET_IN,

      CHANNEL_ID_IN          => hist_write_id,
      CHANNEL_DATA_IN        => hist_write_data,
      CHANNEL_ADD_IN         => hist_add,
      CHANNEL_WRITE_IN       => hist_write,
      CHANNEL_WRITE_BUSY_OUT => hist_write_busy,

      CHANNEL_ID_READ_IN     => hist_read_id,
      CHANNEL_READ_IN        => hist_read,
      CHANNEL_DATA_OUT       => hist_read_data,
      CHANNEL_DATA_VALID_OUT => hist_read_data_valid,
      CHANNEL_READ_BUSY_OUT  => hist_read_busy,

      DEBUG_OUT              => DEBUG_OUT
      );

  -----------------------------------------------------------------------------
  -- Fill Histograms
  -----------------------------------------------------------------------------

  PROC_FILL_HISTOGRAMS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        hist_write_id                   <= CHANNEL_ID_IN;
        hist_write_data                 <= (others => '0');
        hist_write                      <= '0';
        hist_add                        <= '0';
        write_ctr                       <= (others => '0');
      else
        hist_write_id                   <= (others => '0');
        hist_write_data                 <= (others => '0');
        hist_write                      <= '0';
        hist_add                        <= '0';

        if (CHANNEL_STAT_FILL_IN = '1' and  hist_write_busy = '0') then
          hist_write_id                 <= CHANNEL_ID_IN;
          hist_write_data(11 downto 0)  <= x"001"; --CHANNEL_ADC_IN;
          hist_write_data(31 downto 12) <= (others => '0');
          hist_add                      <= '1';

          write_ctr                     <= write_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_FILL_HISTOGRAMS;
  
  ---------------------------------------------------------------------------
  -- TRBNet Slave Bus
  ---------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_HISTOGRAMS_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o       <= (others => '0');
        slv_no_more_data_o   <= '0';
        slv_unknown_addr_o   <= '0';
        slv_ack_o            <= '0';

        hist_read_id         <= (others => '0');
        hist_read            <= '0';
      else
        slv_data_out_o       <= (others => '0');
        slv_unknown_addr_o   <= '0';
        slv_no_more_data_o   <= '0';

        hist_read_id         <= (others => '0');
        hist_read            <= '0';
        
        if (hist_read_busy = '1') then
          if (hist_read_data_valid = '1') then
            slv_data_out_o   <= hist_read_data;
            slv_ack_o        <= '1';
          else
            slv_ack_o        <= '0';
          end if;
          
        elsif (SLV_READ_IN  = '1') then
          if (unsigned(SLV_ADDR_IN) >= x"0000" and
              unsigned(SLV_ADDR_IN) <= x"007f") then
            hist_read_id                  <= SLV_ADDR_IN(6 downto 0);
            hist_read                     <= '1';
            slv_ack_o                     <= '0';
          else
            slv_unknown_addr_o            <= '1';
            slv_ack_o                     <= '0';
          end if;
          
        elsif (SLV_WRITE_IN  = '1') then

          case SLV_ADDR_IN is

            when others =>
              slv_unknown_addr_o          <= '1';
              slv_ack_o                   <= '0';

          end case;
        else
          slv_ack_o                       <= '0';
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

end nx_histograms;
