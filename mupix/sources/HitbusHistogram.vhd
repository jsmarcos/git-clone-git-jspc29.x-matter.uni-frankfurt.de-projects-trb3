-------------------------------------------------------------------------------
--Histogramming of Hitbus for Time over Threshold and Latency Measurement
--Readout by TRB Slave Bus
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;


entity HitbusHistogram is
  generic (
    HistogramRange : integer := 8);
  port (
    clk                  : in  std_logic;
    hitbus               : in  std_logic;
    Trigger              : out std_logic;  --Trigger to Laser/LED
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic
    );
end HitbusHistogram;

architecture Behavioral of HitbusHistogram is

  component Histogram
    generic (
      HistogramHeight : integer;
      HistogramRange  : integer);
    port (
      clk       : in  std_logic;
      reset     : in  std_logic;
      StartRun  : in  std_logic;
      StartRd   : in  std_logic;
      ReadAddr  : in  std_logic_vector(HistogramRange - 1 downto 0);
      Wr        : in  std_logic;
      BinSelect : in  std_logic_vector(HistogramRange - 1 downto 0);
      DataValid : out std_logic;
      BinHeight : out std_logic_vector(HistogramHeight - 1 downto 0));
  end component;


  signal hitbus_i : std_logic_vector(1 downto 0);

  --ToT Histogram
  type   hithisto_fsm_type is (idle, hitbus_high);
  signal hithisto_fsm       : hithisto_fsm_type := idle;
  signal hitbus_counter     : unsigned(HistogramRange - 1 downto 0);  --duration of hitbus high
  signal hitbus_HistoWrAddr : std_logic_vector(HistogramRange - 1 downto 0);
  signal hitbus_WriteBin    : std_logic;
  signal hitbus_BinValue    : std_logic_vector(15 downto 0);


  --Latency Histogram
  type   latency_fsm_type is (idle, waittime, generatetrigger, waitforhitbus);
  signal latency_fsm         : latency_fsm_type      := idle;
  signal trigger_counter     : unsigned(2 downto 0)  := (others => '0');
  signal wait_counter        : unsigned(15 downto 0) := (others => '0');
  signal latency_counter     : unsigned(HistogramRange - 1 downto 0);  --duration of hitbus high
  signal latency_HistoWrAddr : std_logic_vector(HistogramRange - 1 downto 0);
  signal latency_WriteBin    : std_logic;
  signal latency_BinValue    : std_logic_vector(15 downto 0);


  --Histogram Ctrl
  signal histo_ctrl        : std_logic_vector(31 downto 0)         := (others => '0');
  signal histvalue         : std_logic_vector(31 downto 0);
  signal histvalue_valid   : std_logic;
  signal ReadAddr_i        : std_logic_vector(HistogramRange - 1 downto 0);
  signal ReadHisto         : std_logic                             := '0';
  signal reading_histo_mem : std_logic                             := '0';  --read in progress
  signal readcounter       : unsigned(HistogramRange - 1 downto 0) := (others => '0');
  
  

  
begin

  Histogram_1 : Histogram
    generic map (
      HistogramHeight => 16,  --change Max Height of Histogrambin here
      HistogramRange  => HistogramRange)
    port map (
      clk       => clk,
      reset     => histo_ctrl(2),
      StartRun  => histo_ctrl(1),
      StartRd   => ReadHisto,
      ReadAddr  => ReadAddr_i,
      Wr        => hitbus_WriteBin,
      BinSelect => hitbus_HistoWrAddr,
      DataValid => histvalue_valid,
      BinHeight => hitbus_BinValue);

  Histogram_2 : Histogram
    generic map (
      HistogramHeight => 16,
      HistogramRange  => HistogramRange)
    port map (
      clk       => clk,
      reset     => histo_ctrl(2),
      StartRun  => histo_ctrl(1),
      StartRd   => ReadHisto,
      ReadAddr  => ReadAddr_i,
      Wr        => latency_WriteBin,
      BinSelect => latency_HistoWrAddr,
      DataValid => open,
      BinHeight => latency_BinValue);


  -----------------------------------------------------------------------------
  --Time over Threshold histogram
  -----------------------------------------------------------------------------
  
  HitBusHisto : process(clk)
  begin  -- process HitBusHisto
    if rising_edge(clk) then
      hitbus_i <= hitbus_i(0) & hitbus;
      case hithisto_fsm is
        when idle =>
          --hitbus_counter  <= (others => '0');
          hitbus_WriteBin <= '0';
          if hitbus_i = "01" then       --rising edge
            hitbus_counter <= to_unsigned(0, HistogramRange);
            hithisto_fsm   <= hitbus_high;
          end if;
        when hitbus_high =>
          hitbus_counter <= hitbus_counter + 1;
          if hitbus_i = "10" then       --falling edge
            hitbus_WriteBin    <= '1';
            hitbus_HistoWrAddr <= std_logic_vector(hitbus_counter);
            hithisto_fsm       <= idle;
          end if;
      end case;
    end if;
  end process HitBusHisto;

  -----------------------------------------------------------------------------
  --Latency Histogram
  -----------------------------------------------------------------------------

  LatencyHisto : process(clk)
  begin  -- process LatencyHisto
    if rising_edge(clk) then
      case latency_fsm is
        when idle =>
          trigger_counter  <= (others => '0');
          --latency_histoaddr <= (others => '0');
          latency_counter  <= (others => '0');
          latency_WriteBin <= '0';
          if histo_ctrl(3) = '1' then
            latency_fsm  <= waittime;
            wait_counter <= wait_counter + 1;
          end if;
        when waittime =>
          wait_counter <= wait_counter + 1;
          if std_logic_vector(wait_counter) = histo_ctrl(31 downto 16) then
            trigger     <= '1';
            latency_fsm <= generatetrigger;
          end if;
        when generatetrigger =>         --necessary width of triggersignal in
                                        --function generator?
          trigger_counter <= trigger_counter + 1;
          if trigger_counter = "111" then
            latency_fsm <= waitforhitbus;
          else
            latency_fsm <= generatetrigger;
          end if;
          latency_counter <= latency_counter + 1;
          wait_counter    <= (others => '0');
          
        when waitforhitbus =>
          trigger         <= '0';
          latency_counter <= latency_counter + 1;
          if hitbus_i = "01" then
            latency_writebin    <= '1';
            latency_histoWraddr <= std_logic_vector(latency_counter);
            latency_fsm         <= idle;
          elsif latency_counter = x"FFFF" then
            latency_fsm <= idle;
          end if;
      end case;
    end if;
  end process LatencyHisto;

  -----------------------------------------------------------------------------
  --TRB Slave Bus
  --0x0800: Histogram Ctrl
  --0x0801: Last ToT Value
  --0x0802: Last Latency Value
  --0x0803: Read Histograms
  --0x0804: ReadCounter
  --0x0805: snapshot of hitbus
  -----------------------------------------------------------------------------
  SLV_BUS_HANDLER : process(clk)
  begin  -- process SLV_BUS_HANDLER
    if rising_edge(clk) then
      SLV_DATA_OUT         <= (others => '0');
      SLV_ACK_OUT          <= '0';
      SLV_UNKNOWN_ADDR_OUT <= '0';
      SLV_NO_MORE_DATA_OUT <= '0';
      histvalue            <= latency_BinValue & hitbus_BinValue;
      if reading_histo_mem = '1' then
        ReadHisto <= '0';
        if histvalue_valid = '1' then
          SLV_DATA_OUT      <= histvalue;
          SLV_ACK_OUT       <= '1';
          reading_histo_mem <= '0';
          readcounter       <= readcounter + 1;
        else
          reading_histo_mem <= '1';
        end if;

      elsif SLV_READ_IN = '1' then
        case SLV_ADDR_IN is
          when x"0800" =>
            SLV_DATA_OUT <= histo_ctrl;
            SLV_ACK_OUT  <= '1';
          when x"0801" =>
            SLV_DATA_OUT(31 downto 16)                <= (others => '0');
            SLV_DATA_OUT(HistogramRange - 1 downto 0) <= hitbus_HistoWrAddr;
            SLV_ACK_OUT                               <= '1';
          when x"0802" =>
            SLV_DATA_OUT(31 downto 16)                <= (others => '0');
            SLV_DATA_OUT(HistogramRange - 1 downto 0) <= latency_histoWraddr;
            SLV_ACK_OUT                               <= '1';
          when x"0803" =>
            ReadHisto         <= '1';
            ReadAddr_i        <= std_logic_vector(readcounter);
            reading_histo_mem <= '1';
          when x"0804" =>
            SLV_DATA_OUT(HistogramRange - 1 downto 0) <= std_logic_vector(readcounter);
            SLV_ACK_OUT                               <= '1';
          when x"0805" =>
            SLV_DATA_OUT(0) <= hitbus;
            SLV_ACK_OUT <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;

      elsif SLV_WRITE_IN = '1' then
        case SLV_ADDR_IN is
          when x"0800" =>
            histo_ctrl  <= SLV_DATA_IN;
            SLV_ACK_OUT <= '1';
          when x"0804" =>
            readcounter <= unsigned(SLV_DATA_IN(HistogramRange - 1 downto 0));
            SLV_ACK_OUT <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;
        
      end if;
    end if;
    
  end process SLV_BUS_HANDLER;

  

end Behavioral;

