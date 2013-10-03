library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_histograms is
  generic (
    BUS_WIDTH    : integer   := 7;
    ENABLE       : integer   := 1
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
                         
    RESET_HISTS_IN       : in  std_logic;

    CHANNEL_STAT_FILL_IN : in  std_logic;
    CHANNEL_ID_IN        : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
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

  type histogram_t is array(0 to 2**BUS_WIDTH - 1) of unsigned(31 downto 0);

  -- PROC_CHANNEL_HIST
  signal hist_channel_stat    : histogram_t;
  signal hist_channel_freq    : histogram_t;

  signal wait_timer_init      : unsigned(27 downto 0);
  signal wait_timer_done      : std_logic;

  -- PROC_CHANNEL_HIST
  signal hist_channel_adc     : histogram_t;
  
  -- Slave Bus                    
  signal slv_data_out_o       : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o   : std_logic;
  signal slv_unknown_addr_o   : std_logic;
  signal slv_ack_o            : std_logic;
  signal reset_hists_r        : std_logic;
  
begin

hist_enable_1: if ENABLE = 1 generate
  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= RESET_IN;  
  DEBUG_OUT(2)           <= RESET_HISTS_IN; 
  DEBUG_OUT(3)           <= reset_hists_r;
  DEBUG_OUT(4)           <= CHANNEL_STAT_FILL_IN;
  DEBUG_OUT(5)           <= slv_ack_o;
  DEBUG_OUT(6)           <= SLV_READ_IN;
  DEBUG_OUT(7)           <= SLV_WRITE_IN;
  DEBUG_OUT(8)           <= wait_timer_done;
  DEBUG_OUT(15 downto 9) <= CHANNEL_ID_IN;
  
  -----------------------------------------------------------------------------
  
  PROC_CHANNEL_HIST : process (CLK_IN)
    variable value : unsigned(31 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or reset_hists_r = '1' or RESET_HISTS_IN = '1') then
        for I in 0 to (2**BUS_WIDTH - 1) loop
         hist_channel_stat(I) <= (others => '0');
         hist_channel_freq(I) <= (others => '0');
         hist_channel_adc(I) <= (others => '0');
        end loop;
        wait_timer_init       <= x"000_0001";
      else
        wait_timer_init <= (others => '0');
        if (wait_timer_done = '1') then
          for I in 0 to (2**BUS_WIDTH - 1) loop
            hist_channel_stat(I) <= (others => '0');
            hist_channel_freq(I) <=
              (hist_channel_freq(I) + hist_channel_stat(I)) / 2;
          end loop;
          wait_timer_init <= x"5f5_e100";
        else
          if (CHANNEL_STAT_FILL_IN = '1') then
            hist_channel_stat(to_integer(unsigned(CHANNEL_ID_IN))) <=
              hist_channel_stat(to_integer(unsigned(CHANNEL_ID_IN))) + 1;
            
            value := (hist_channel_adc(to_integer(unsigned(CHANNEL_ID_IN)))
                      + unsigned(CHANNEL_ADC_IN)) / 2;
            hist_channel_adc(to_integer(unsigned(CHANNEL_ID_IN))) <= value;
          end if;
        end if;
      end if;
    end if;
  end process PROC_CHANNEL_HIST;  
  
  -- Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 28
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

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

        reset_hists_r        <= '0';
        
        if (SLV_READ_IN  = '1') then
          if (unsigned(SLV_ADDR_IN) >= x"0000" and
              unsigned(SLV_ADDR_IN) <= x"007f") then
            slv_data_out_o(31 downto 0)  <= std_logic_vector(
              hist_channel_stat(to_integer(unsigned(SLV_ADDR_IN(7 downto 0))))
              );
            slv_ack_o                    <= '1';
          elsif (unsigned(SLV_ADDR_IN) >= x"0080" and
                 unsigned(SLV_ADDR_IN) <= x"00ff") then
            slv_data_out_o(31 downto 0)  <= std_logic_vector(
              hist_channel_freq(to_integer(unsigned(SLV_ADDR_IN(7 downto 0))))
              );
            slv_ack_o                    <= '1';
          elsif (unsigned(SLV_ADDR_IN) >= x"0100" and
                 unsigned(SLV_ADDR_IN) <= x"017f") then
            slv_data_out_o(31 downto 0)  <= std_logic_vector(
              hist_channel_adc(to_integer(unsigned(SLV_ADDR_IN(7 downto 0))))
              );
            slv_ack_o                    <= '1';
          else
            slv_ack_o                    <= '0';
          end if;        

        elsif (SLV_WRITE_IN  = '1') then

          case SLV_ADDR_IN is

            when x"0000" =>
              reset_hists_r          <= '1';
              slv_ack_o              <= '1';

            when others =>
              slv_unknown_addr_o     <= '1';
              slv_ack_o              <= '0';
          end case;
        else
          slv_ack_o                  <= '0';
        end if;
      end if;
    end if;     
  end process PROC_HISTOGRAMS_READ;

end generate hist_enable_1;
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- Slave 
  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;

  end nx_histograms;
