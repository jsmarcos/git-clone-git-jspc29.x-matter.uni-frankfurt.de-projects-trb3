library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.nxyter_components.all;

entity nx_data_delay is
  port(
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
                           
    -- Signals             
    NX_FRAME_IN            : in  std_logic_vector(31 downto 0);
    ADC_DATA_IN            : in  std_logic_vector(11 downto 0);
    DATA_CLK_IN            : in  std_logic;
                           
    NX_FRAME_OUT           : out std_logic_vector(31 downto 0);
    ADC_DATA_OUT           : out std_logic_vector(11 downto 0);
    DATA_CLK_OUT           : out std_logic;

    FIFO_DELAY_IN          : in  std_logic_vector(7 downto 0);
    
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

architecture Behavioral of nx_data_delay is

  -- FIFO Write Handler
  signal fifo_data_in          : std_logic_vector(43 downto 0);
  signal fifo_full             : std_logic;
  signal fifo_write_enable     : std_logic;
  signal fifo_reset            : std_logic;

  -- FIFO READ
  signal fifo_data_out         : std_logic_vector(43 downto 0);
  signal fifo_read_enable      : std_logic;
  signal fifo_empty            : std_logic;
  signal fifo_almost_empty     : std_logic;

  signal fifo_read_enable_t    : std_logic;
  signal fifo_read_enable_tt   : std_logic;
  signal nx_frame_o            : std_logic_vector(31 downto 0);
  signal adc_data_o            : std_logic_vector(11 downto 0);
  signal data_clk_o            : std_logic;

  -- Fifo Delay
  signal fifo_delay            : std_logic_vector(7 downto 0);
  signal fifo_delay_reset      : std_logic;
  
  -- Slave Bus                 
  signal slv_data_o            : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;
  signal fifo_reset_r          : std_logic;
  signal debug_r               : std_logic;

  -- Misc
  signal fifo_select           : std_logic;
  signal debug_fifo            : std_logic_vector(15 downto 0);

begin

  -- Debug
  PROC_DEBUG_MULTIPLEXER: process(debug_r)
  begin
    if (debug_r = '0') then
    DEBUG_OUT(0)            <= CLK_IN;
    DEBUG_OUT(1)            <= DATA_CLK_IN;
    DEBUG_OUT(2)            <= fifo_reset;
    DEBUG_OUT(3)            <= fifo_full;
    DEBUG_OUT(4)            <= fifo_write_enable;
    DEBUG_OUT(5)            <= fifo_empty;
    DEBUG_OUT(6)            <= fifo_almost_empty;
    DEBUG_OUT(7)            <= fifo_read_enable;
    DEBUG_OUT(8)            <= fifo_read_enable_t;
    DEBUG_OUT(9)            <= fifo_read_enable_tt;
    DEBUG_OUT(10)           <= data_clk_o;
    --DEBUG_OUT(15 downto 11) <= NX_FRAME_OUT(14 downto 10);
    else
      DEBUG_OUT             <= debug_fifo;
    end if;
  end process PROC_DEBUG_MULTIPLEXER;
    
  -----------------------------------------------------------------------------
  -- FIFO Delay Handler
  -----------------------------------------------------------------------------
  
  fifo_44_data_delay_my_1: fifo_44_data_delay_my
    port map (
      Data          => fifo_data_in,
      Clock         => CLK_IN,
      WrEn          => fifo_write_enable,
      RdEn          => fifo_read_enable,  --LOOP?? 
      Reset         => fifo_reset,
      AmEmptyThresh => fifo_delay,
      Q             => fifo_data_out,      --fifo_data_out_0, 
      Empty         => fifo_empty,         -- fifo_empty_0,
      Full          => fifo_full,          --fifo_full_0,
      AlmostEmpty   => fifo_almost_empty,  -- fifo_almost_empty_0,
      DEBUG_OUT     => debug_fifo
      );        

  fifo_read_enable             <= not fifo_almost_empty;
  fifo_reset                   <= RESET_IN or fifo_reset_r or fifo_delay_reset;
  fifo_data_in(31 downto 0)    <= NX_FRAME_IN;
  fifo_data_in(43 downto 32)   <= ADC_DATA_IN;
  fifo_write_enable            <= DATA_CLK_IN and not fifo_full;
    
  -- FIFO Read Handler
  PROC_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1' or fifo_delay_reset = '1') then
        fifo_read_enable_t   <= '0';
        fifo_read_enable_tt  <= '0';

        nx_frame_o           <= (others => '0');
        adc_data_o           <= (others => '0');
        data_clk_o           <= '0';
      else
        -- Read enable
        fifo_read_enable_t   <= fifo_read_enable;
        fifo_read_enable_tt  <= fifo_read_enable_t;

        if (fifo_read_enable_tt = '1') then
          nx_frame_o         <= fifo_data_out(31 downto 0);
          adc_data_o         <= fifo_data_out(43 downto 32);
          data_clk_o         <= '1'; 
        else
          nx_frame_o         <= x"ffff_ffff";
          adc_data_o         <= x"fff";
          data_clk_o         <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_READ;

  PROC_FIFO_DELAY: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_delay             <= x"02";
        fifo_delay_reset       <= '0';
      else
        fifo_delay_reset       <= '0';
        if ((FIFO_DELAY_IN /= fifo_delay)) then
            fifo_delay         <= FIFO_DELAY_IN;
            fifo_delay_reset   <= '1';
        else
          fifo_delay_reset     <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_DELAY;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------

  -- Give status info to the TRB Slow Control Channel
  PROC_FIFO_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_o              <= (others => '0');
        slv_ack_o               <= '0';
        slv_unknown_addr_o      <= '0';
        slv_no_more_data_o      <= '0';
        fifo_reset_r            <= '0';
        debug_r                 <= '0';
        fifo_select             <= '0';
      else                      
        slv_data_o              <= (others => '0');
        slv_unknown_addr_o      <= '0';
        slv_no_more_data_o      <= '0';
        fifo_reset_r            <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_o( 7 downto 0)  <= fifo_delay;
              slv_data_o(31 downto 8)  <= (others => '0');
              slv_ack_o                <= '1';

            when x"0001" =>
              slv_data_o(0)            <= debug_r;
              slv_data_o(31 downto 1)  <= (others => '0');
              slv_ack_o                <= '1';

            when x"0002" =>
              slv_data_o(0)            <= fifo_select;
              slv_data_o(31 downto 1)  <= (others => '0');
              slv_ack_o                <= '1';
              
            when others =>
              slv_unknown_addr_o       <= '1';
              slv_ack_o                <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              fifo_reset_r             <= '1';
              slv_ack_o                <= '1';

            when x"0001" =>
              debug_r                  <= SLV_DATA_IN(0);
              slv_ack_o                <= '1';

            when x"0002" =>
              fifo_select              <= SLV_DATA_IN(0);
              slv_ack_o                <= '1';
              
            when others =>
              slv_unknown_addr_o       <= '1';
              slv_ack_o                <= '0';

          end case;
        else
          slv_ack_o                    <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  -- Output Signals
  NX_FRAME_OUT          <= nx_frame_o;
  ADC_DATA_OUT          <= adc_data_o;
  DATA_CLK_OUT          <= data_clk_o;
                           
  SLV_DATA_OUT          <= slv_data_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
  
end Behavioral;
