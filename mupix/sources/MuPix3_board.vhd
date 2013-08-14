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
    clk                        : in  std_logic;  
    reset                      : in  std_logic;
    --signals to and from MuPix 3 chip/board DACS
    timestamp_from_mupix       : in  std_logic_vector(7 downto 0);
    rowaddr_from_mupix         : in  std_logic_vector(5 downto 0);
    coladdr_from_mupix         : in  std_logic_vector(5 downto 0);
    priout_from_mupix          : in  std_logic;
    sout_c_from_mupix          : in  std_logic;
    sout_d_from_mupix          : in  std_logic;
    hbus_form_mupix            : in  std_logic;
    fpga_aux_from_board        : in  std_logic_vector(9 downto 0);
    ldpix_to_mupix             : out std_logic;
    ldcol_to_mupix             : out std_logic;
    timestamp_to_mupix         : out std_logic_vector(7 downto 0);
    rdcol_to_mupix             : out std_logic;
    pulldown_to_mupix          : out std_logic;
    sin_to_mupix               : out std_logic;
    ck_d_to_mupix              : out std_logic;
    ck_c_to_mupix              : out std_logic;
    ld_c_to_mupix              : out std_logic;
    testpulse1_to_board        : out std_logic;
    testpulse2_to_board        : out std_logic;
    spi_din_to_board           : out std_logic;
    spi_clk_to_board           : out std_logic;
    spi_ld_to_board            : out std_logic;
    fpga_led_to_board          : out std_logic_vector(3 downto 0);
    fpga_aux_to_board          : out std_logic_vector(9 downto 0);
    
    --TRBv3 connections
    LVL1_TRG_DATA_VALID_IN     : in  std_logic;
    LVL1_VALID_TIMING_TRG_IN   : in  std_logic;
    LVL1_VALID_NOTIMING_TRG_IN : in  std_logic;
    LVL1_INVALID_TRG_IN        : in  std_logic;
    LVL1_TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in  std_logic_vector(15 downto 0);

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
  constant NUM_PORTS : integer := 11;

  signal slv_read              : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_write             : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_no_more_data      : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_ack               : std_logic_vector(NUM_PORTS-1 downto 0);
  signal slv_addr              : std_logic_vector(NUM_PORTS*16-1 downto 0);
  signal slv_data_rd           : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_data_wr           : std_logic_vector(NUM_PORTS*32-1 downto 0);
  signal slv_unknown_addr      : std_logic_vector(NUM_PORTS-1 downto 0);
 

begin  -- Behavioral

  -------------------------------------------------------------------------------
-- Port Maps
-------------------------------------------------------------------------------

  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => NUM_PORTS,

      PORT_ADDRESSES      => ( 0 => x"0100",    -- Readout Control
                               1 => x"0040",    -- Sensorboard DACs
                               2 => x"0600",    -- Injection Control
                               3 => x"0060",    -- MuPix DACs
                               4 => x"0120",    -- TimeStamp Control
                               5 => x"0160",    -- Hit Generator
                               6 => x"0180",    -- Manual Readout
                               7 => x"0200",    -- MuPix SlowControl Out
                               8 => x"0800",    -- Hitbus Histograms
                               others => x"0000"),

      PORT_ADDR_MASK      => ( 0 => 8,          -- Readout Control
                               1 => 4,          -- Sensorboard DACs
                               2 => 8,          -- Injection Control
                               3 => 4,          -- MuPix DACs
                               4 => 4,          -- TimeStamp Control
                               5 => 4,          -- Hit Generator
                               6 => 4,          -- Manual Readout
                               7 => 8,          -- MuPix SlowControl Out
                               8 => 8,          -- HitBus Histograms
                               others => 0),

      PORT_MASK_ENABLE           => 1
      )
    port map(
      CLK                        => CLK_IN,
      RESET                      => RESET_IN,
                                 
      DAT_ADDR_IN                => REGIO_ADDR_IN,
      DAT_DATA_IN                => REGIO_DATA_IN,
      DAT_DATA_OUT               => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN         => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN        => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN             => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT          => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT          => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT       => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT       => REGIO_UNKNOWN_ADDR_OUT,
                                 
      -- Control Registers       
      BUS_READ_ENABLE_OUT        => slv_read,
      BUS_WRITE_ENABLE_OUT       => slv_write,
      BUS_DATA_OUT               => slv_data_wr,
      BUS_DATA_IN                => slv_data_rd,
      BUS_ADDR_OUT               => slv_addr,
      BUS_TIMEOUT_OUT            => open,
      BUS_DATAREADY_IN           => slv_ack,
      BUS_WRITE_ACK_IN           => slv_ack,
      BUS_NO_MORE_DATA_IN        => slv_no_more_data,
      BUS_UNKNOWN_ADDR_IN        => slv_unknown_addr,

      -- DEBUG
      STAT_DEBUG          => open
      );


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
      priout               => priout_from_mupix,
      hit_col              => coladdr_from_mupix,
      hit_row              => rowaddr_from_mupix,
      hit_time             => timestamp_from_mupix,
      memdata              => memdata,
      memwren              => memwren,
      ro_busy              => ro_busy,
      --add signal to indicate readout still in progress
      roregister           => writeregs(1),
      roregwritten         => regwritten(1),
      rocontrolbits        => writeregs(6),
      timestampcontrolbits => writeregs(7),
      generatehitswait     => writeregs(8));

  --SPI-Interface to Board DACs
  spi_if_1 : spi_if
    port map (
      clk            => clk,
      reset_n        => not Reset,
      threshold_reg  => writeregs(2)(15 downto 0),
      injection1_reg => writeregs(3)(15 downto 0),
      injection2_reg => writeregs(3)(31 downto 16),
      wren           => spi_wren,
      spi_data       => spi_din_to_board,
      spi_clk        => spi_clk_to_board,
      spi_ld         => spi_ld_to_board);

  spi_wren <= '1' when regwritten(2) = '1' else '0';  --maybe add regwritten(3)

  inj_gen : injection_generator
    port map(
      rstn               => not reset,
      clk                => clk,
      injection_register => writeregs(4),
      reg_written        => regwritten(4),
      testpulse1         => testpulse1_to_board,
      testpulse2         => testpulse2_to_board
      );


  sync_historeg : process
  begin
    wait until rising_edge(fastclk);
    historegwriten_sync <= regwritten(9);
    historegwriten_last <= historegwriten_sync;
    if historegwriten_sync = '0' and historegwriten_last = '1' then
      historeg <= writeregs(9);
    end if;
  end process sync_historeg;


  HitbusHistogram_1 : HitbusHistogram
    generic map (
      HistogramRange => 10)
    port map (
      clk       => clk,
      Control   => historeg,
      trigger   => fpga_aux_to_board(0),
      hitbus    => hbus_form_mupix,
      DataValid => DataValidToFormatterFiFo,
      BinHeight => BinHeightToFormatterFiFo);


  write_mupix_dac : process
  begin
    wait until rising_edge(clk);
    sin_to_mupix  <= writeregs(5)(0);
    ck_c_to_mupix <= writeregs(5)(1);
    ck_d_to_mupix <= writeregs(5)(2);
    ld_c_to_mupix <= writeregs(5)(3);
  end process write_mupix_dac;
  

end Behavioral;
