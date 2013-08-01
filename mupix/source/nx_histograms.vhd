library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity nx_histograms is
  generic (
    NUM_BINS : integer   := 7
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
                         
    RESET_HISTS_IN       : in  std_logic;
                         
    CHANNEL_STAT_FILL_IN : in  std_logic;
    CHANNEL_ID_IN        : in  std_logic_vector(NUM_BINS - 1 downto 0);

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

  type histogram_t is array(0 to 127) of unsigned(31 downto 0);
  signal hist_channel_stat    : histogram_t;

  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal reset_hists_r        : std_logic;
  
begin
  
  PROC_CHANNEL_HIST : process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_hists_r = '1' or RESET_HISTS_IN = '1') then
        for I in (NUM_BINS - 1) downto 0 loop
         hist_channel_stat(I) <= (others => '0');
        end loop;
      else
        if (CHANNEL_STAT_FILL_IN = '1') then
          hist_channel_stat(to_integer(unsigned(CHANNEL_ID_IN))) <=
            hist_channel_stat(to_integer(unsigned(CHANNEL_ID_IN))) + 1;
        end if;
      end if;
    end if;
  end process PROC_CHANNEL_HIST;  


  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
 -- Give status info to the TRB Slow Control Channel
  PROC_HISTOGRAMS_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o       <= (others => '0');
        slv_no_more_data_o   <= '0';
        slv_unknown_addr_o   <= '0';
        slv_ack_o            <= '0';
        reset_hists_r        <= '0';
      else
        slv_data_out_o       <= (others => '0');
        slv_unknown_addr_o   <= '0';
        slv_no_more_data_o   <= '0';
        slv_ack_o            <= '0';

        reset_hists_r        <= '0';
        
        if (SLV_READ_IN  = '1') then
          if (unsigned(SLV_ADDR_IN) >= x"0000" and
              unsigned(SLV_ADDR_IN) <  x"0080") then
            slv_data_out_o           <= std_logic_vector(
              hist_channel_stat(to_integer(unsigned(SLV_ADDR_IN(7 downto 0))))
              );
            slv_ack_o                <= '1';
          else
            slv_unknown_addr_o       <= '1';
          end if;
                    
        elsif (SLV_WRITE_IN  = '1') then

          case SLV_ADDR_IN is

            when x"0000" =>
              reset_hists_r          <= '1';
              slv_ack_o              <= '1';

            when others =>
              slv_unknown_addr_o     <= '1';

          end case;
        end if;
      end if;
    end if;     
  end process PROC_HISTOGRAMS_READ;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;

  end nx_histograms;
