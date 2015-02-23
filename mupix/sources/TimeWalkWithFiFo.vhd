-----------------------------------------------------------
--Measurement of Time-Walk (latency vs.  energy deposition)
--readout of data usng fifo which is read by
--slow control interface.
--T. Weber, Mainz University
-----------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.mupix_components.all;

entity TimeWalkWithFiFo is
  
  port (
    trb_slv_clock        : in  std_logic;
    fast_clk             : in  std_logic;  -- fast clock samples hitbus and szintilator
    reset                : in  std_logic;
    hitbus               : in  std_logic;
    szintillator_trigger : in  std_logic;
    -- trb slowcontrol
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic);

end entity TimeWalkWithFiFo;

architecture TimeWalk_arch of TimeWalkWithFiFo is

  constant bitsBeforeWriteCounter : integer := 2;
  signal hitbus_timeout            : std_logic_vector(31 downto 0)        := (others => '0');
  
  signal hitbusEdgeCounter : unsigned(31 downto 0) := (others => '0');
  signal szintilatorEdgeCounter : unsigned(31 downto 0) := (others => '0');
  signal hitbusRisingEdge : std_logic_vector(1 downto 0) := (others => '0');
  signal szintilatorRisingEdge : std_logic_vector(1 downto 0) := (others => '0');
  
  signal FiFo_Wren         : std_logic                     := '0';
  signal FiFo_Rden         : std_logic                     := '0';
  signal FiFo_data_in      : std_logic_vector(31 downto 0) := (others => '0');
  signal FiFo_data_out     : std_logic_vector(31 downto 0) := (others => '0');
  signal FiFo_writecounter : std_logic_vector(12 downto 0) := (others => '0');
  signal FiFo_empty        : std_logic                     := '0';
  signal FiFo_full         : std_logic                     := '0';
  signal fifo_status       : std_logic_vector(31 downto 0) := (others => '0');

  --fifo readout via slv_bus
  type fifo_read_s_states is (idle, wait1, wait2, done);
  signal fifo_read_s_fsm      : fifo_read_s_states := idle;
  signal fifo_start_read      : std_logic          := '0';
  signal fifo_read_s          : std_logic          := '0';
  signal fifo_read_wasempty_s : std_logic          := '0';
  signal fifo_reading_s       : std_logic          := '0';
  signal fifo_read_done_s     : std_logic          := '0';
  signal fifo_read_busy_s     : std_logic          := '0';
  signal slv_fifo_reset       : std_logic          := '0';

  component fifo_4k32_async is
    port (
      Data    : in  std_logic_vector(31 downto 0);
      WrClock : in  std_logic;
      RdClock : in  std_logic;
      WrEn    : in  std_logic;
      RdEn    : in  std_logic;
      Reset   : in  std_logic;
      RPReset : in  std_logic;
      Q       : out std_logic_vector(31 downto 0);
      WCNT    : out std_logic_vector(12 downto 0);
      Empty   : out std_logic;
      Full    : out std_logic);
  end component fifo_4k32_async;
  
begin  -- architecture TimeWalk_arch

  fifo_4k32_async_1 : entity work.fifo_4k32_async
    port map (
      Data    => FiFo_data_in,
      WrClock => fast_clk,
      RdClock => trb_slv_clock,
      WrEn    => FiFo_Wren,
      RdEn    => FiFo_Rden,
      Reset   => Reset,
      RPReset => Reset,
      Q       => FiFo_data_out,
      WCNT    => FiFo_writecounter,
      Empty   => FiFo_empty,
      Full    => FiFo_full);

  TimeWalk_1: entity work.TimeWalk
    port map (
      clk                  => fast_clk,
      reset                => reset,
      hitbus               => hitbus,
      hitbus_timeout       => hitbus_timeout,
      szintillator_trigger => szintillator_trigger,
      readyToWrite         => not FiFo_full,
      measurementFinished  => FiFo_Wren,
      measurementData      => FiFo_data_in);

  ------------------------------------------------------------
  --count number of rising edges on szintilator and hitbus
  ------------------------------------------------------------
  edge_counter: process (trb_slv_clock) is
  begin  -- process edge_counter
    if rising_edge(trb_slv_clock) then
      hitbusRisingEdge <= hitbusRisingEdge(0) & hitbus;
      szintilatorRisingEdge <= szintilatorRisingEdge & szintillator_trigger;
      if szintilatorRisingEdge = "01" then
        szintilatorEdgeCounter <= szintilatorEdgeCounter + 1;
      end if;
      if hitbusRisingEdge = "01" then
        hitbusEdgeCounter <= hitbusEdgeCounter + 1;
      end if;
    end if;
  end process edge_counter;
  
  ------------------------------------------------------------
  --fifo readout using trb slow control channel
  ------------------------------------------------------------
  fifo_data_read_s : process(trb_slv_clock)
  begin
    if rising_edge(trb_slv_clock) then
      fifo_read_done_s     <= '0';
      fifo_read_s          <= '0';
      fifo_read_busy_s     <= '0';
      fifo_read_wasempty_s <= '0';
      case fifo_read_s_fsm is
        when idle =>
          if fifo_start_read = '1' then
            if fifo_empty = '0' then
              fifo_read_s      <= '1';
              fifo_read_busy_s <= '1';
              fifo_read_s_fsm  <= wait1;
            else
              fifo_read_done_s     <= '1';
              fifo_read_wasempty_s <= '1';
              fifo_read_s_fsm      <= idle;
            end if;
          end if;
        when wait1 =>
          fifo_read_busy_s <= '1';
          fifo_read_s_fsm  <= done;
        when wait2 =>
          fifo_read_busy_s <= '1';
          fifo_read_s_fsm  <= done;
        when done =>
          fifo_read_busy_s <= '0';
          fifo_read_done_s <= '1';
          fifo_read_s_fsm  <= idle;
      end case;
    end if;
  end process fifo_data_read_s;

  -----------------------------------------------------------------------------
  --trb slave bus
  --0x0400: read fifo status
  --0x0401: read fifo write counter
  --0x0402: read fifo data
  --0x0403: timeout after szintilator trigger signal
  --0x0404: number of rising edges on szintilator
  --0x0405: number of rising edges on hitbus
  -----------------------------------------------------------------------------
  fifo_status((bitsBeforeWriteCounter - 1) downto 0) <= fifo_empty & FiFo_full;
  fifo_status(12 + bitsBeforeWriteCounter downto bitsBeforeWriteCounter) <= FiFo_writecounter;
  fifo_status(31 downto 13 + bitsBeforeWriteCounter) <= (others => '0');

   slv_bus_handler : process(trb_slv_clock)
  begin
    if rising_edge(trb_slv_clock) then
      slv_data_out         <= (others => '0');
      slv_ack_out          <= '0';
      slv_no_more_data_out <= '0';
      slv_unknown_addr_out <= '0';
      fifo_start_read      <= '0';
      slv_fifo_reset       <= '0';

      if fifo_reading_s = '1' then
        if (fifo_read_done_s = '0') then
          fifo_reading_s <= '1';
        else
          if (fifo_read_wasempty_s = '0') then
            slv_data_out <= FiFo_data_out;
            slv_ack_out  <= '1';
          else
            slv_no_more_data_out <= '1';
            slv_ack_out          <= '0';
          end if;
          fifo_reading_s <= '0';
        end if;
        
      elsif slv_write_in = '1' then
        case SLV_ADDR_IN is
          when x"0403" =>
            hitbus_timeout   <= slv_data_in;
            slv_ack_out <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;
        
      elsif slv_read_in = '1' then
        case slv_addr_in is
          when x"0400" =>
            slv_data_out <= fifo_status;
            slv_ack_out  <= '1';
          when x"0401" =>
            slv_data_out(12 downto 0) <= FiFo_writecounter;
            slv_ack_out               <= '1';
          when x"0402" =>
            fifo_start_read <= '1';
            fifo_reading_s  <= '1';
          when x"0403" =>
            slv_data_out <= hitbus_timeout;
            slv_ack_out <= '1';
          when x"0404"
            slv_data_out <= szintilatorEdgeCounter;
            slv_ack_out <= '1';
          when x"0405"
            slv_data_out <= hitbusEdgeCounter;
            slv_ack_out <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;

      end if;
    end if;
  end process slv_bus_handler;
  

end architecture TimeWalk_arch;
