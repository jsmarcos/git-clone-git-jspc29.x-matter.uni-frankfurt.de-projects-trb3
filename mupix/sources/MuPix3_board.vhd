-------------------------------------------------------------------------------
--MuPix Block for readout/controll of MuPix3 Sensorboard
--T. Weber, University Mainz
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use work.mupix_components.all;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;


entity MuPix3_Board is
  port(
    --Clock signal
    clk                  : in  std_logic;
    reset                : in  std_logic;
    --signals to and from MuPix 3 chip/board DACS
    timestamp_from_mupix : in  std_logic_vector(7 downto 0);
    rowaddr_from_mupix   : in  std_logic_vector(5 downto 0);
    coladdr_from_mupix   : in  std_logic_vector(5 downto 0);
    priout_from_mupix    : in  std_logic;
    sout_c_from_mupix    : in  std_logic;
    sout_d_from_mupix    : in  std_logic;
    hbus_form_mupix      : in  std_logic;
    fpga_aux_from_board  : in  std_logic_vector(9 downto 0);
    ldpix_to_mupix       : out std_logic;
    ldcol_to_mupix       : out std_logic;
    timestamp_to_mupix   : out std_logic_vector(7 downto 0);
    rdcol_to_mupix       : out std_logic;
    pulldown_to_mupix    : out std_logic;
    sin_to_mupix         : out std_logic;
    ck_d_to_mupix        : out std_logic;
    ck_c_to_mupix        : out std_logic;
    ld_c_to_mupix        : out std_logic;
    testpulse1_to_board  : out std_logic;
    testpulse2_to_board  : out std_logic;
    spi_din_to_board     : out std_logic;
    spi_clk_to_board     : out std_logic;
    spi_ld_to_board      : out std_logic;
    fpga_led_to_board    : out std_logic_vector(3 downto 0);
    fpga_aux_to_board    : out std_logic_vector(9 downto 0);

    --TRBv3 connections
    TIMING_TRG_IN              : in std_logic;
    LVL1_TRG_DATA_VALID_IN     : in std_logic;
    LVL1_VALID_TIMING_TRG_IN   : in std_logic;
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic;
    LVL1_INVALID_TRG_IN        : in std_logic;
    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    FEE_TRG_RELEASE_OUT     : out std_logic;
    FEE_TRG_STATUSBITS_OUT  : out std_logic_vector(31 downto 0);
    FEE_DATA_OUT            : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT      : out std_logic;
    FEE_DATA_FINISHED_OUT   : out std_logic;
    FEE_DATA_ALMOST_FULL_IN : in  std_logic;

    REGIO_ADDR_IN          : in  std_logic_vector(15 downto 0);
    REGIO_DATA_IN          : in  std_logic_vector(31 downto 0);
    REGIO_DATA_OUT         : out std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN   : in  std_logic;
    REGIO_WRITE_ENABLE_IN  : in  std_logic;
    REGIO_TIMEOUT_IN       : in  std_logic;
    REGIO_DATAREADY_OUT    : out std_logic;
    REGIO_WRITE_ACK_OUT    : out std_logic;
    REGIO_NO_MORE_DATA_OUT : out std_logic;
    REGIO_UNKNOWN_ADDR_OUT : out std_logic
    );
end MuPix3_Board;


architecture Behavioral of MuPix3_Board is

--signal declarations
-- Bus Handler
  constant NUM_PORTS : integer := 8;

  signal slv_read         : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_write        : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_no_more_data : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_ack          : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_addr         : std_logic_vector(NUM_PORTS*16-1 downto 0);
  signal slv_data_rd      : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_data_wr      : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_unknown_addr : std_logic_vector(NUM_PORTS-1 downto 0);

  --data from mupix interface
  signal memdata : std_logic_vector(31 downto 0);
  signal memwren : std_logic;
  signal ro_mupix_busy : std_logic;

  --data from event buffer
  signal buffer_data : std_logic_vector(31 downto 0);
  signal buffer_data_valid : std_logic;

  --signals from trigger handler
  signal valid_trigger_int : std_logic;
  signal timing_trigger : std_logic;
  signal status_trigger : std_logic;
  signal buffer_fast_clear : std_logic;
  signal flush_buffer : std_logic;
  signal trigger_busy_mupix_data_int : std_logic;

  -- synced signals from board interface
  signal timestamp_from_mupix_sync : std_logic_vector(7 downto 0);
  signal rowaddr_from_mupix_sync   : std_logic_vector(5 downto 0);
  signal coladdr_from_mupix_sync   : std_logic_vector(5 downto 0);
  signal priout_from_mupix_sync    : std_logic;
  signal sout_c_from_mupix_sync    : std_logic;
  signal sout_d_from_mupix_sync    : std_logic;
  signal hbus_form_mupix_sync      : std_logic;
  signal fpga_aux_from_board_sync  : std_logic_vector(9 downto 0);
  
  

begin  -- Behavioral

-------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  THE_BUS_HANDLER : trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER => NUM_PORTS,

      PORT_ADDRESSES
                 => (0 => x"0020",      -- MuPix Interface Control
          1      => x"0040",            -- Sensorboard DACs
          2      => x"0060",            -- Injection Control
          3      => x"0080",            -- MuPix DACs
          4      => x"0800",            -- Hitbus Histograms
          5      => x"0300",            -- Event Buffer
          6      => x"0100",            -- Trigger Handler
          7      => x"0200",            -- Board Interface
          others => x"0000"),

      PORT_ADDR_MASK
                 => (0 => 4,            -- MuPix Interface Control
          1      => 4,                  -- Sensorboard DACs
          2      => 4,                  -- Injection Control
          3      => 4,                  -- MuPix DACs
          4      => 8,                  -- HitBus Histograms
          5      => 8,                  -- Event Buffer
          6      => 8,                  -- Trigger Handler
          7      => 8,                  -- Board Interface 
          others => 0)

      --PORT_MASK_ENABLE => 1
      )
    port map(
      CLK   => CLK,
      RESET => RESET,

      DAT_ADDR_IN          => REGIO_ADDR_IN,
      DAT_DATA_IN          => REGIO_DATA_IN,
      DAT_DATA_OUT         => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN   => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN  => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN       => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT    => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT    => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT => REGIO_UNKNOWN_ADDR_OUT,

      -- Control Registers       
      BUS_READ_ENABLE_OUT  => slv_read,
      BUS_WRITE_ENABLE_OUT => slv_write,
      BUS_DATA_OUT         => slv_data_wr,
      BUS_DATA_IN          => slv_data_rd,
      BUS_ADDR_OUT         => slv_addr,
      BUS_TIMEOUT_OUT      => open,
      BUS_DATAREADY_IN     => slv_ack,
      BUS_WRITE_ACK_IN     => slv_ack,
      BUS_NO_MORE_DATA_IN  => slv_no_more_data,
      BUS_UNKNOWN_ADDR_IN  => slv_unknown_addr,

      -- DEBUG
      STAT_DEBUG => open
      );


  board_interface_1: entity work.board_interface
    port map (
      clk_in                    => clk,
      timestamp_from_mupix      => timestamp_from_mupix,
      rowaddr_from_mupix        => rowaddr_from_mupix,
      coladdr_from_mupix        => coladdr_from_mupix,
      priout_from_mupix         => priout_from_mupix,
      sout_c_from_mupix         => sout_c_from_mupix,
      sout_d_from_mupix         => sout_d_from_mupix,
      hbus_form_mupix           => hbus_form_mupix,
      fpga_aux_from_board       => fpga_aux_from_board,
      timestamp_from_mupix_sync => timestamp_from_mupix_sync,
      rowaddr_from_mupix_sync   => rowaddr_from_mupix_sync,
      coladdr_from_mupix_sync   => coladdr_from_mupix_sync,
      priout_from_mupix_sync    => priout_from_mupix_sync,
      sout_c_from_mupix_sync    => sout_c_from_mupix_sync,
      sout_d_from_mupix_sync    => sout_d_from_mupix_sync,
      hbus_form_mupix_sync      => hbus_form_mupix_sync,
      fpga_aux_from_board_sync  => fpga_aux_from_board_sync,
      SLV_READ_IN               => slv_read(7),
      SLV_WRITE_IN              => slv_write(7),
      SLV_DATA_OUT              => slv_data_rd(7*32+31 downto 7*32),
      SLV_DATA_IN               => slv_data_wr(7*32+31 downto 7*32),
      SLV_ADDR_IN               => slv_addr(7*16+15 downto 7*16),
      SLV_ACK_OUT               => slv_ack(7),
      SLV_NO_MORE_DATA_OUT      => slv_no_more_data(7),
      SLV_UNKNOWN_ADDR_OUT      => slv_unknown_addr(7));

  --Mupix 3 Chip Interface
  mupix_interface_1 : mupix_interface
    port map (
      rstn                 => not Reset,
      clk                  => clk,
      ldpix                => ldpix_to_mupix,
      ldcol                => ldcol_to_mupix,
      rdcol                => rdcol_to_mupix,
      pulldown             => pulldown_to_mupix,
      timestamps           => timestamp_to_mupix,
      priout               => priout_from_mupix_sync,
      hit_col              => coladdr_from_mupix_sync,
      hit_row              => rowaddr_from_mupix_sync,
      hit_time             => timestamp_from_mupix_sync,
      memdata              => memdata,
      memwren              => memwren,
      trigger_ext          => valid_trigger_int,
      ro_busy              => ro_mupix_busy,
      SLV_READ_IN          => slv_read(0),
      SLV_WRITE_IN         => slv_write(0),
      SLV_DATA_OUT         => slv_data_rd(0*32+31 downto 0*32),
      SLV_DATA_IN          => slv_data_wr(0*32+31 downto 0*32),
      SLV_ADDR_IN          => slv_addr(0*16+15 downto 0*16),
      SLV_ACK_OUT          => slv_ack(0),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(0),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(0));

  --SPI-Interface to Board DACs
  spi_if_1 : spi_if
    port map (
      clk                  => clk,
      reset_n              => not Reset,
      SLV_READ_IN          => slv_read(1),
      SLV_WRITE_IN         => slv_write(1),
      SLV_DATA_OUT         => slv_data_rd(1*32+31 downto 1*32),
      SLV_DATA_IN          => slv_data_wr(1*32+31 downto 1*32),
      SLV_ADDR_IN          => slv_addr(1*16+15 downto 1*16),
      SLV_ACK_OUT          => slv_ack(1),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(1),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(1),
      spi_data             => spi_din_to_board,
      spi_clk              => spi_clk_to_board,
      spi_ld               => spi_ld_to_board);

  inj_gen : injection_generator
    port map(
      rstn                 => not reset,
      clk                  => clk,
      SLV_READ_IN          => slv_read(2),
      SLV_WRITE_IN         => slv_write(2),
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT          => slv_ack(2),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(2),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2),
      testpulse1           => testpulse1_to_board,
      testpulse2           => testpulse2_to_board
      );


  PixCtr_1: PixCtr
    port map (
      clk                  => clk,
      sout_c_from_mupix    => sout_c_from_mupix_sync,
      sout_d_from_mupix    => sout_d_from_mupix_sync,
      ck_d_to_mupix        => ck_d_to_mupix,
      ck_c_to_mupix        => ck_c_to_mupix,
      ld_c_to_mupix        => ld_c_to_mupix,
      sin_to_mupix         => sin_to_mupix,
      SLV_READ_IN          => slv_read(3),
      SLV_WRITE_IN         => slv_write(3),
      SLV_DATA_OUT         => slv_data_rd(3*32+31 downto 3*32),
      SLV_DATA_IN          => slv_data_wr(3*32+31 downto 3*32),
      SLV_ADDR_IN          => slv_addr(3*16+15 downto 3*16),
      SLV_ACK_OUT          => slv_ack(3),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(3),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(3));


  HitbusHistogram_1 : HitbusHistogram
    generic map (
      HistogramRange => 8)
    port map (
      clk                  => clk,
      trigger              => fpga_aux_to_board(0),
      hitbus               => hbus_form_mupix_sync,
      SLV_READ_IN          => slv_read(4),
      SLV_WRITE_IN         => slv_write(4),
      SLV_DATA_OUT         => slv_data_rd(4*32+31 downto 4*32),
      SLV_DATA_IN          => slv_data_wr(4*32+31 downto 4*32),
      SLV_ADDR_IN          => slv_addr(4*16+15 downto 4*16),
      SLV_ACK_OUT          => slv_ack(4),
      SLV_NO_MORE_DATA_OUT => slv_no_more_data(4),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(4));


  
  EventBuffer_1 : EventBuffer
    port map (
      CLK                     => clk,
      Reset                   => reset,
      MuPixData_in            => memdata,
      MuPixDataWr_in          => memwren,
      MuPixEndOfEvent_in      => ro_mupix_busy,
      FEE_DATA_OUT            => buffer_data,
      FEE_DATA_WRITE_OUT      => buffer_data_valid,
      FEE_DATA_FINISHED_OUT   => open,
      FEE_DATA_ALMOST_FULL_IN => FEE_DATA_ALMOST_FULL_IN,
      valid_trigger_in        => flush_buffer,
      clear_buffer_in         => buffer_fast_clear,
      SLV_READ_IN             => slv_read(5),
      SLV_WRITE_IN            => slv_write(5),
      SLV_DATA_IN             => slv_data_wr(5*32+31 downto 5*32),
      SLV_ADDR_IN             => slv_addr(5*16+15 downto 5*16),
      SLV_DATA_OUT            => slv_data_rd(5*32+31 downto 5*32),
      SLV_ACK_OUT             => slv_ack(5),
      SLV_NO_MORE_DATA_OUT    => slv_no_more_data(5),
      SLV_UNKNOWN_ADDR_OUT    => slv_unknown_addr(5));

  
  TriggerHandler_1: entity work.TriggerHandler
    port map (
      CLK_IN                     => clk,
      RESET_IN                   => reset,
      TIMING_TRIGGER_IN          => TIMING_TRG_IN,
      LVL1_TRG_DATA_VALID_IN     => LVL1_TRG_DATA_VALID_IN,
      LVL1_VALID_TIMING_TRG_IN   => LVL1_VALID_TIMING_TRG_IN,
      LVL1_VALID_NOTIMING_TRG_IN => LVL1_VALID_NOTIMING_TRG_IN,
      LVL1_INVALID_TRG_IN        => LVL1_INVALID_TRG_IN,
      LVL1_TRG_TYPE_IN           => LVL1_TRG_TYPE_IN,
      LVL1_TRG_NUMBER_IN         => LVL1_TRG_NUMBER_IN,
      LVL1_TRG_CODE_IN           => LVL1_TRG_CODE_IN,
      LVL1_TRG_INFORMATION_IN    => LVL1_TRG_INFORMATION_IN,
      LVL1_INT_TRG_NUMBER_IN     => LVL1_INT_TRG_NUMBER_IN,
      FEE_DATA_OUT               => FEE_DATA_OUT,
      FEE_DATA_WRITE_OUT         => FEE_DATA_WRITE_OUT,
      FEE_DATA_FINISHED_OUT      => FEE_DATA_FINISHED_OUT,
      FEE_TRG_RELEASE_OUT        => FEE_TRG_RELEASE_OUT,
      FEE_TRG_STATUSBITS_OUT     => FEE_TRG_STATUSBITS_OUT,
      FEE_DATA_0_IN              => buffer_data,
      FEE_DATA_WRITE_0_IN        => buffer_data_valid,
      TRIGGER_BUSY_MUPIX_READ_IN => ro_mupix_busy,
      TRIGGER_BUSY_FIFO_READ_IN  => buffer_data_valid,
      VALID_TRIGGER_OUT          => valid_trigger_int,
      TRIGGER_TIMING_OUT         => timing_trigger,
      TRIGGER_STATUS_OUT         => status_trigger,
      FAST_CLEAR_OUT             => buffer_fast_clear,
      FLUSH_BUFFER_OUT           => flush_buffer,
      SLV_READ_IN                => slv_read(6),
      SLV_WRITE_IN               => slv_write(6),
      SLV_DATA_OUT               => slv_data_rd(6*32+31 downto 6*32),
      SLV_DATA_IN                => slv_data_wr(6*32+31 downto 6*32),
      SLV_ADDR_IN                => slv_addr(6*16+15 downto 6*16),
      SLV_ACK_OUT                => slv_ack(6),
      SLV_NO_MORE_DATA_OUT       => slv_no_more_data(6),
      SLV_UNKNOWN_ADDR_OUT       => slv_unknown_addr(6));


end Behavioral;
