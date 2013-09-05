-------------------------------------------------------------------------------
--Event Buffer FiFo for MuPix Readout
--FiFo can be read via SlowControl Bus or transferred into FEE-FiFo on TRB
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.mupix_components.all;


entity EventBuffer is
  port (
    CLK   : in std_logic;
    Reset : in std_logic;

    --Data from MuPix Interface
    MuPixData_in       : in std_logic_vector(31 downto 0);
    MuPixDataWr_in     : in std_logic;
    MuPixEndOfEvent_in : in std_logic;

    --Response from FEE (to TRB FiFo)       
    FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT      : out std_logic;
    FEE_DATA_FINISHED_OUT   : out std_logic;
    FEE_DATA_ALMOST_FULL_IN : in  std_logic;

    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic);
end EventBuffer;


architecture Behavioral of EventBuffer is

  --FiFo Signals
  signal fifo_reset       : std_logic;
  signal fifo_full        : std_logic;
  signal fifo_empty       : std_logic;
  signal fifo_write       : std_logic;
  signal fifo_status      : std_logic_vector(31 downto 0);
  signal fifo_write_ctr   : std_logic_vector(10 downto 0);
  signal fifo_data_in     : std_logic_vector(31 downto 0);
  signal fifo_data_out    : std_logic_vector(31 downto 0);
  signal fifo_read_enable : std_logic;

  --FiFo Readout via SLV_BUS
  type   FiFo_Read_S_States is (idle, wait1, wait2, done);
  signal FiFo_Read_S_fsm  : FiFo_Read_S_States := idle;
  signal fifo_start_read  : std_logic;
  signal fifo_read_s      : std_logic;
  signal fifo_reading_s   : std_logic := '0';
  signal fifo_read_done_s : std_logic;
  signal fifo_read_busy_s : std_logic;
  

begin  -- Behavioral

  -- Send data to FIFO (TODO: generate FiFo Core in Cores-Directory!!)
  fifo_32_data_1 : fifo_32_data
    port map (
      Data  => MuPixData_in,            --Data In
      Clock => CLK,
      WrEn  => fifo_write,
      RdEn  => fifo_read_enable,
      Reset => fifo_reset,
      Q     => fifo_data_out,           --Data Out
      WCNT  => fifo_write_ctr,
      Empty => fifo_empty,
      Full  => fifo_full
      );

  fifo_read_enable <= fifo_read_s;

  FiFo_Write_Handler : process(clk)
  begin  -- process FiFo_Write_Handler
    if rising_edge(clk) then
      fifo_write   <= '0';
      fifo_data_in <= (others => '0');
      if MuPixDataWr_in = '1' and fifo_full = '0' then
        fifo_write   <= '1';
        fifo_data_in <= MuPixData_in;
      end if;
    end if;
  end process FiFo_Write_Handler;

  --TODO: Transfer Data to TRB FiFo in case of valid trigger


  FiFo_Data_Read : process(clk)
  begin
    if rising_edge(clk) then
      fifo_read_done_s <= '0';
      fifo_read_s      <= '0';
      fifo_read_busy_s <= '0';
      case FiFo_Read_S_fsm is
        when idle =>
          if fifo_start_read = '1' then
            if fifo_empty = '0' then
              fifo_read_s      <= '1';
              fifo_read_busy_s <= '1';
              FiFo_Read_S_fsm  <= wait1;
            else
              fifo_read_done_s <= '1';
              FiFo_Read_S_fsm  <= idle;
            end if;
          end if;
        when wait1 =>
          fifo_read_busy_s <= '1';
          FiFo_Read_S_fsm  <= wait2;
        when wait2 =>
          fifo_read_busy_s <= '1';
          FiFo_Read_S_fsm  <= done;
        when done =>
          fifo_read_busy_s <= '0';
          fifo_read_done_s <= '1';
          FiFo_Read_S_fsm  <= idle;
      end case;
    end if;
  end process FiFo_Data_Read;


  -----------------------------------------------------------------------------
  --TRB Slave Bus
  --0x0300: Read FiFo Status
  --0x0301: Read FiFo Write Counter
  --0x0302: Read FiFo Data
  ----------------------------------------------------------------------------- 

  fifo_status(1 downto 0)   <= fifo_empty & fifo_full;
  fifo_status(12 downto 2)  <= fifo_write_ctr;
  fifo_status(31 downto 13) <= (others => '0');
  
  SLV_BUS_HANDLER : process(clk)
  begin
    if rising_edge(clk) then
      SLV_DATA_OUT         <= (others => '0');
      SLV_ACK_OUT          <= '0';
      SLV_NO_MORE_DATA_OUT <= '0';
      SLV_UNKNOWN_ADDR_OUT <= '0';
      fifo_start_read      <= '0';

      if fifo_reading_s = '1' then
        if (fifo_read_done_s = '0') then
          fifo_reading_s <= '1';
        else
          if (fifo_empty = '0') then
            slv_data_out <= fifo_data_out;
            SLV_ACK_OUT  <= '1';
          else
            SLV_NO_MORE_DATA_OUT <= '1';
            SLV_ACK_OUT          <= '0';
          end if;
          fifo_reading_s <= '0';
        end if;
        
      elsif SLV_WRITE_IN = '1' then
        SLV_UNKNOWN_ADDR_OUT <= '1';
      elsif SLV_READ_IN = '1' then
        case SLV_ADDR_IN is
          when x"0300" =>
            SLV_DATA_OUT <= fifo_status;
            SLV_ACK_OUT  <= '1';
          when x"0301" =>
            SLV_DATA_OUT(10 downto 0) <= fifo_write_ctr;
            SLV_ACK_OUT               <= '1';
          when x"0302" =>
            fifo_start_read <= '1';
            fifo_reading_s  <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;

      end if;
    end if;
  end process SLV_BUS_HANDLER;
  
  
end Behavioral;
