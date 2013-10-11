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
    NEW_DATA_IN            : in  std_logic;
                           
    NX_FRAME_OUT           : out std_logic_vector(31 downto 0);
    ADC_DATA_OUT           : out std_logic_vector(11 downto 0);
    NEW_DATA_OUT           : out std_logic;

    FIFO_DELAY_IN          : in  std_logic_vector(6 downto 0);
    
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
  
  -- FIFO READ ENABLE
  signal fifo_data_out         : std_logic_vector(43 downto 0);
  signal fifo_read_enable      : std_logic;
  signal fifo_empty            : std_logic;
  signal fifo_almost_empty     : std_logic;

  signal fifo_data_valid_t     : std_logic;
  signal fifo_data_valid       : std_logic;
  
  -- FIFO READ
  signal nx_frame_o            : std_logic_vector(31 downto 0);
  signal adc_data_o            : std_logic_vector(11 downto 0);
  signal new_data_o            : std_logic;
  
  -- Slave Bus                 
  signal slv_data_o            : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;
  signal fifo_delay            : std_logic_vector(6 downto 0);
  signal fifo_delay_reset      : std_logic;
  
begin

  -- Debug Signals
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= fifo_reset;
  DEBUG_OUT(2)            <= fifo_full;
  DEBUG_OUT(3)            <= fifo_write_enable;
  DEBUG_OUT(4)            <= fifo_empty;
  DEBUG_OUT(5)            <= fifo_almost_empty;
  DEBUG_OUT(6)            <= fifo_read_enable;
  DEBUG_OUT(7)            <= fifo_data_valid;
  DEBUG_OUT(8)            <= new_data_o;
  DEBUG_OUT(15 downto 9)  <= fifo_delay;

  -----------------------------------------------------------------------------
  -- FIFO Delay Handler
  -----------------------------------------------------------------------------
  
  fifo_44_data_delay_1: fifo_44_data_delay
    port map (
      Data          => fifo_data_in,
      Clock         => CLK_IN,
      WrEn          => fifo_write_enable,
      RdEn          => fifo_read_enable,
      Reset         => fifo_reset,
      AmEmptyThresh => fifo_delay,
      Q             => fifo_data_out, 
      Empty         => fifo_empty,
      Full          => fifo_full,
      AlmostEmpty   => fifo_almost_empty
      );

  -----------------------------------------------------------------------------
  -- FIFO Handler
  -----------------------------------------------------------------------------
  
  -- Write to FIFO
  PROC_WRITE_TO_FIFO: process(NEW_DATA_IN,
                              NX_FRAME_IN,
                              ADC_DATA_IN)
  begin
    if ( NEW_DATA_IN = '1' and fifo_full = '0') then
      fifo_data_in(31 downto 0)  <= NX_FRAME_IN;
      fifo_data_in(43 downto 32) <= ADC_DATA_IN;
      fifo_write_enable          <= '1';
    else
      fifo_data_in               <= x"fff_ffff_ffff";
      fifo_write_enable          <= '0';
    end if;

  end process PROC_WRITE_TO_FIFO;

  fifo_reset     <= RESET_IN or fifo_delay_reset;

  -- FIFO Read Handler
  fifo_read_enable     <= not fifo_almost_empty;

  PROC_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' or fifo_reset = '1') then
        fifo_data_valid_t        <= '0';
        fifo_data_valid          <= '0';
      else
        -- Delay read signal by one CLK
        fifo_data_valid_t        <= fifo_read_enable;
        fifo_data_valid          <= fifo_data_valid_t;
      end if;
    end if;
  end process PROC_FIFO_READ_ENABLE;

  PROC_NX_FIFO_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1' or fifo_reset = '1') then
        nx_frame_o               <= (others => '0');
        adc_data_o               <= (others => '0');
        new_data_o               <= '0';
      else
        if (fifo_data_valid = '1') then
          nx_frame_o             <= fifo_data_out(31 downto 0);
          adc_data_o             <= fifo_data_out(43 downto 32);
          new_data_o             <= '1';
        else
          nx_frame_o             <= x"ffff_ffff";
          adc_data_o             <= x"fff";
          new_data_o             <= '0';
        end if;
      end if;
    end if;
  end process PROC_NX_FIFO_READ;

  PROC_FIFO_DELAY: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        fifo_delay             <= "0000001";
        fifo_delay_reset       <= '0';
      else
        fifo_delay_reset       <= '0';
        if (fifo_delay /= FIFO_DELAY_IN) then
          if (unsigned(FIFO_DELAY_IN) >= 1 and
              unsigned(FIFO_DELAY_IN) <= 120) then
            fifo_delay         <= FIFO_DELAY_IN;
            fifo_delay_reset   <= '1';
          end if;
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
      else                      
        slv_data_o              <= (others => '0');
        slv_unknown_addr_o      <= '0';
        slv_no_more_data_o      <= '0';

        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_o( 6 downto 0)  <= fifo_delay;
              slv_data_o(31 downto 7)  <= (others => '0');
              slv_ack_o                <= '1';
              
            when others =>
              slv_unknown_addr_o       <= '1';
              slv_ack_o                <= '0';
          end case;
          
        elsif (SLV_WRITE_IN  = '1') then
          slv_unknown_addr_o           <= '1';
          slv_ack_o                    <= '0';
        else
          slv_ack_o                    <= '0';
        end if;
      end if;
    end if;
  end process PROC_FIFO_REGISTERS;

  -- Output Signals
  NX_FRAME_OUT          <= nx_frame_o;
  ADC_DATA_OUT          <= adc_data_o;
  NEW_DATA_OUT          <= new_data_o;
                           
  SLV_DATA_OUT          <= slv_data_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;
  
end Behavioral;
