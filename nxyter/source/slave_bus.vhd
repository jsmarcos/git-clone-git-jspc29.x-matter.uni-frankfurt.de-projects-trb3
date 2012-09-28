library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.adcmv3_components.all;


entity slave_bus is
  port(
    CLK_IN                  : in    std_logic;
    RESET_IN                : in    std_logic;

    -- RegIO signals
    REGIO_ADDR_IN           : in    std_logic_vector(15 downto 0); -- address bus
    REGIO_DATA_IN           : in    std_logic_vector(31 downto 0); -- data from TRB endpoint
    REGIO_DATA_OUT          : out   std_logic_vector(31 downto 0); -- data to TRB endpoint
    REGIO_READ_ENABLE_IN    : in    std_logic; -- read pulse
    REGIO_WRITE_ENABLE_IN   : in    std_logic; -- write pulse
    REGIO_TIMEOUT_IN        : in    std_logic; -- access timed out
    REGIO_DATAREADY_OUT     : out   std_logic; -- your data, master, as requested
    REGIO_WRITE_ACK_OUT     : out   std_logic; -- data accepted
    REGIO_NO_MORE_DATA_OUT  : out   std_logic; -- don't disturb me now
    REGIO_UNKNOWN_ADDR_OUT  : out   std_logic; -- noone here to answer your request

    -- I2C connections
    SDA_IN                  : in    std_logic;
    SDA_OUT                 : out   std_logic;
    SCL_IN                  : in    std_logic;
    SCL_OUT                 : out   std_logic;
   
    -- SPI connections
    SPI_CS_OUT              : out   std_logic;
    SPI_SCK_OUT             : out   std_logic;
    SPI_SDI_IN              : in    std_logic;
    SPI_SDO_OUT             : out   std_logic
    );
end entity;

architecture Behavioral of slave_bus is

-- Signals
  signal slv_read             : std_logic_vector(18-1 downto 0);
  signal slv_write            : std_logic_vector(18-1 downto 0);
  signal slv_busy             : std_logic_vector(18-1 downto 0);
  signal slv_ack              : std_logic_vector(18-1 downto 0);
  signal slv_addr             : std_logic_vector(18*16-1 downto 0);
  signal slv_data_rd          : std_logic_vector(18*32-1 downto 0);
  signal slv_data_wr          : std_logic_vector(18*32-1 downto 0);

-- SPI controller BRAM lines
  signal spi_bram_addr        : std_logic_vector(7 downto 0);
  signal spi_bram_wr_d        : std_logic_vector(7 downto 0);
  signal spi_bram_rd_d        : std_logic_vector(7 downto 0);
  signal spi_bram_we          : std_logic;

  signal spi_cs               : std_logic;
  signal spi_sck              : std_logic;
  signal spi_sdi              : std_logic;
  signal spi_sdo              : std_logic;
  signal spi_debug            : std_logic_vector(31 downto 0);

  signal ctrl_lvl             : std_logic_vector(31 downto 0);
  signal ctrl_trg             : std_logic_vector(31 downto 0);
  signal ctrl_pll             : std_logic_vector(15 downto 0);

  signal debug                : std_logic_vector(63 downto 0);
  signal onewire_debug        : std_logic_vector(63 downto 0);
  
  -- do not know at the moment, have no backplanes, needed by Slave-Bus
  signal bp_module_qq             : std_logic_vector(3 downto 0);

  -- Pedestal and threshold stuff
  type reg_18bit_t is array (0 to 15) of std_logic_vector(17 downto 0);

  signal buf_addr                 : std_logic_vector(6 downto 0);
  signal thr_addr                 : std_logic_vector(6 downto 0);
  signal thr_data                 : reg_18bit_t;
  signal ped_data                 : reg_18bit_t;

begin

-- Bus handler: acts as bridge between RegIO and the FPGA internal slave bus
  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => 3,
      PORT_ADDRESSES      => ( 0 => x"a000", -- pedestal memories
                               1 => x"a800", -- threshold memories
                               2 => x"8040", -- I2C master
                               -- 3 => x"c000", -- 1Wire master + memory
                               -- 4 => x"d000", -- SPI master
                               -- 5 => x"d100", -- SPI data memory
                               -- 6 => x"d010", -- ADC0 SPI
                               -- 7 => x"d020", -- ADC1 SPI
                               -- 8 => x"b000", -- APV control / status
                               -- 9 => x"b010", -- ADC level settings
                               -- 10 => x"b020", -- trigger settings
                               -- 11 => x"b030", -- PLL settings
                               -- 12 => x"f000", -- ADC 0 snooper
                               -- 13 => x"f800", -- ADC 1 snooper
                               -- 14 => x"8000", -- test register (busy)
                               -- 15 => x"7100", -- data buffer status registers
                               -- 16 => x"7200", -- LVL1 release status register
                               -- 17 => x"7202", -- IPU handler status register
                               others => x"0000"),
      PORT_ADDR_MASK      => ( 0 => 16, -- pedestal memories
                               1 => 16, -- threshold memories
                               2 => 0,  -- I2C master
                               -- 3 => 6,  -- 1Wire master + memory
                               -- 4 => 1,  -- SPI master
                               -- 5 => 6,  -- SPI data memory
                               -- 6 => 0,  -- ADC0 SPI
                               -- 7 => 0,  -- ADC1 SPI
                               -- 8 => 4,  -- APV control / status
                               -- 9 => 0,  -- ADC level settings
                               -- 10 => 0,  -- trigger settings
                               -- 11 => 0,  -- PLL settings
                               -- 12 => 10, -- ADC 0 snooper
                               -- 13 => 10, -- ADC 1 snooper
                               -- 14 => 0,  -- test register (normal)
                               -- 15 => 4,  -- FIFO status registers
                               -- 16 => 0,  -- LVL1 release status register
                               -- 17 => 0,  -- IPU handler status register
                               others => 0)
      )
    port map(
      CLK                                 => CLK_IN,
      RESET                               => RESET_IN,
      DAT_ADDR_IN                         => REGIO_ADDR_IN,
      DAT_DATA_IN                         => REGIO_DATA_IN,
      DAT_DATA_OUT                        => REGIO_DATA_OUT,
      DAT_READ_ENABLE_IN                  => REGIO_READ_ENABLE_IN,
      DAT_WRITE_ENABLE_IN                 => REGIO_WRITE_ENABLE_IN,
      DAT_TIMEOUT_IN                      => REGIO_TIMEOUT_IN,
      DAT_DATAREADY_OUT                   => REGIO_DATAREADY_OUT,
      DAT_WRITE_ACK_OUT                   => REGIO_WRITE_ACK_OUT,
      DAT_NO_MORE_DATA_OUT                => REGIO_NO_MORE_DATA_OUT,
      DAT_UNKNOWN_ADDR_OUT                => REGIO_UNKNOWN_ADDR_OUT,
      -- pedestal memories
      BUS_READ_ENABLE_OUT(0)              => slv_read(0),
      BUS_WRITE_ENABLE_OUT(0)             => slv_write(0),
      BUS_DATA_OUT(0*32+31 downto 0*32)   => slv_data_wr(0*32+31 downto 0*32),
      BUS_DATA_IN(0*32+31 downto 0*32)    => slv_data_rd(0*32+31 downto 0*32),
      BUS_ADDR_OUT(0*16+15 downto 0*16)   => slv_addr(0*16+15 downto 0*16),
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATAREADY_IN(0)                 => slv_ack(0),
      BUS_WRITE_ACK_IN(0)                 => slv_ack(0),
      BUS_NO_MORE_DATA_IN(0)              => slv_busy(0),
      BUS_UNKNOWN_ADDR_IN(0)              => '0',
      -- threshold memories
      BUS_READ_ENABLE_OUT(1)              => slv_read(1),
      BUS_WRITE_ENABLE_OUT(1)             => slv_write(1),
      BUS_DATA_OUT(1*32+31 downto 1*32)   => slv_data_wr(1*32+31 downto 1*32),
      BUS_DATA_IN(1*32+31 downto 1*32)    => slv_data_rd(1*32+31 downto 1*32),
      BUS_ADDR_OUT(1*16+15 downto 1*16)   => slv_addr(1*16+15 downto 1*16),
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATAREADY_IN(1)                 => slv_ack(1),
      BUS_WRITE_ACK_IN(1)                 => slv_ack(1),
      BUS_NO_MORE_DATA_IN(1)              => slv_busy(1),
      BUS_UNKNOWN_ADDR_IN(1)              => '0',
      -- I2C master
      BUS_READ_ENABLE_OUT(2)              => slv_read(2),
      BUS_WRITE_ENABLE_OUT(2)             => slv_write(2),
      BUS_DATA_OUT(2*32+31 downto 2*32)   => slv_data_wr(2*32+31 downto 2*32),
      BUS_DATA_IN(2*32+31 downto 2*32)    => slv_data_rd(2*32+31 downto 2*32),
      BUS_ADDR_OUT(2*16+15 downto 2*16)   => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATAREADY_IN(2)                 => slv_ack(2),
      BUS_WRITE_ACK_IN(2)                 => slv_ack(2),
      BUS_NO_MORE_DATA_IN(2)              => slv_busy(2),
      BUS_UNKNOWN_ADDR_IN(2)              => '0',

      -- OneWire master
      --BUS_READ_ENABLE_OUT(3)              => slv_read(3),
      --BUS_WRITE_ENABLE_OUT(3)             => slv_write(3),
      --BUS_DATA_OUT(3*32+31 downto 3*32)   => slv_data_wr(3*32+31 downto 3*32),
      --BUS_DATA_IN(3*32+31 downto 3*32)    => slv_data_rd(3*32+31 downto 3*32),
      --BUS_ADDR_OUT(3*16+15 downto 3*16)   => slv_addr(3*16+15 downto 3*16),
      --BUS_TIMEOUT_OUT(3)                  => open,
      --BUS_DATAREADY_IN(3)                 => slv_ack(3),
      --BUS_WRITE_ACK_IN(3)                 => slv_ack(3),
      --BUS_NO_MORE_DATA_IN(3)              => slv_busy(3),
      --BUS_UNKNOWN_ADDR_IN(3)              => '0',
      ---- SPI control registers
      --BUS_READ_ENABLE_OUT(4)              => slv_read(4),
      --BUS_WRITE_ENABLE_OUT(4)             => slv_write(4),
      --BUS_DATA_OUT(4*32+31 downto 4*32)   => slv_data_wr(4*32+31 downto 4*32),
      --BUS_DATA_IN(4*32+31 downto 4*32)    => slv_data_rd(4*32+31 downto 4*32),
      --BUS_ADDR_OUT(4*16+15 downto 4*16)   => slv_addr(4*16+15 downto 4*16),
      --BUS_TIMEOUT_OUT(4)                  => open,
      --BUS_DATAREADY_IN(4)                 => slv_ack(4),
      --BUS_WRITE_ACK_IN(4)                 => slv_ack(4),
      --BUS_NO_MORE_DATA_IN(4)              => slv_busy(4),
      --BUS_UNKNOWN_ADDR_IN(4)              => '0',
      ---- SPI data memory
      --BUS_READ_ENABLE_OUT(5)              => slv_read(5),
      --BUS_WRITE_ENABLE_OUT(5)             => slv_write(5),
      --BUS_DATA_OUT(5*32+31 downto 5*32)   => slv_data_wr(5*32+31 downto 5*32),
      --BUS_DATA_IN(5*32+31 downto 5*32)    => slv_data_rd(5*32+31 downto 5*32),
      --BUS_ADDR_OUT(5*16+15 downto 5*16)   => slv_addr(5*16+15 downto 5*16),
      --BUS_TIMEOUT_OUT(5)                  => open,
      --BUS_DATAREADY_IN(5)                 => slv_ack(5),
      --BUS_WRITE_ACK_IN(5)                 => slv_ack(5),
      --BUS_NO_MORE_DATA_IN(5)              => slv_busy(5),
      --BUS_UNKNOWN_ADDR_IN(5)              => '0',
      ---- ADC 0 SPI control registers
      --BUS_READ_ENABLE_OUT(6)              => slv_read(6),
      --BUS_WRITE_ENABLE_OUT(6)             => slv_write(6),
      --BUS_DATA_OUT(6*32+31 downto 6*32)   => slv_data_wr(6*32+31 downto 6*32),
      --BUS_DATA_IN(6*32+31 downto 6*32)    => slv_data_rd(6*32+31 downto 6*32),
      --BUS_ADDR_OUT(6*16+15 downto 6*16)   => open,
      --BUS_TIMEOUT_OUT(6)                  => open,
      --BUS_DATAREADY_IN(6)                 => slv_ack(6),
      --BUS_WRITE_ACK_IN(6)                 => slv_ack(6),
      --BUS_NO_MORE_DATA_IN(6)              => slv_busy(6),
      --BUS_UNKNOWN_ADDR_IN(6)              => '0',
      ---- ADC 1 SPI control registers
      --BUS_READ_ENABLE_OUT(7)              => slv_read(7),
      --BUS_WRITE_ENABLE_OUT(7)             => slv_write(7),
      --BUS_DATA_OUT(7*32+31 downto 7*32)   => slv_data_wr(7*32+31 downto 7*32),
      --BUS_DATA_IN(7*32+31 downto 7*32)    => slv_data_rd(7*32+31 downto 7*32),
      --BUS_ADDR_OUT(7*16+15 downto 7*16)   => open,
      --BUS_TIMEOUT_OUT(7)                  => open,
      --BUS_DATAREADY_IN(7)                 => slv_ack(7),
      --BUS_WRITE_ACK_IN(7)                 => slv_ack(7),
      --BUS_NO_MORE_DATA_IN(7)              => slv_busy(7),
      --BUS_UNKNOWN_ADDR_IN(7)              => '0',
      ---- APV control / status registers
      --BUS_READ_ENABLE_OUT(8)              => slv_read(8),
      --BUS_WRITE_ENABLE_OUT(8)             => slv_write(8),
      --BUS_DATA_OUT(8*32+31 downto 8*32)   => slv_data_wr(8*32+31 downto 8*32),
      --BUS_DATA_IN(8*32+31 downto 8*32)    => slv_data_rd(8*32+31 downto 8*32),
      --BUS_ADDR_OUT(8*16+15 downto 8*16)   => slv_addr(8*16+15 downto 8*16),
      --BUS_TIMEOUT_OUT(8)                  => open,
      --BUS_DATAREADY_IN(8)                 => slv_ack(8),
      --BUS_WRITE_ACK_IN(8)                 => slv_ack(8),
      --BUS_NO_MORE_DATA_IN(8)              => slv_busy(8),
      --BUS_UNKNOWN_ADDR_IN(8)              => '0',
      ---- ADC / PLL / trigger ctrl register
      --BUS_READ_ENABLE_OUT(11 downto 9)    => slv_read(11 downto 9),
      --BUS_WRITE_ENABLE_OUT(11 downto 9)   => slv_write(11 downto 9),
      --BUS_DATA_OUT(11*32+31 downto 9*32)  => slv_data_wr(11*32+31 downto 9*32),
      --BUS_DATA_IN(11*32+31 downto 9*32)   => slv_data_rd(11*32+31 downto 9*32),
      --BUS_ADDR_OUT(11*16+15 downto 9*16)  => open,
      --BUS_TIMEOUT_OUT(11 downto 9)        => open,
      --BUS_DATAREADY_IN(11 downto 9)       => slv_ack(11 downto 9),
      --BUS_WRITE_ACK_IN(11 downto 9)       => slv_ack(11 downto 9),
      --BUS_NO_MORE_DATA_IN(11 downto 9)    => slv_busy(11 downto 9),
      --BUS_UNKNOWN_ADDR_IN(11 downto 9)    => (others => '0'),
      ---- ADC0 snooper
      --BUS_READ_ENABLE_OUT(12)             => slv_read(12),
      --BUS_WRITE_ENABLE_OUT(12)            => slv_write(12),
      --BUS_DATA_OUT(12*32+31 downto 12*32) => slv_data_wr(12*32+31 downto 12*32),
      --BUS_DATA_IN(12*32+31 downto 12*32)  => slv_data_rd(12*32+31 downto 12*32),
      --BUS_ADDR_OUT(12*16+15 downto 12*16) => slv_addr(12*16+15 downto 12*16),
      --BUS_TIMEOUT_OUT(12)                 => open,
      --BUS_DATAREADY_IN(12)                => slv_ack(12),
      --BUS_WRITE_ACK_IN(12)                => slv_ack(12),
      --BUS_NO_MORE_DATA_IN(12)             => slv_busy(12),
      --BUS_UNKNOWN_ADDR_IN(12)             => '0',
      ---- ADC1 snooper
      --BUS_READ_ENABLE_OUT(13)             => slv_read(13),
      --BUS_WRITE_ENABLE_OUT(13)            => slv_write(13),
      --BUS_DATA_OUT(13*32+31 downto 13*32) => slv_data_wr(13*32+31 downto 13*32),
      --BUS_DATA_IN(13*32+31 downto 13*32)  => slv_data_rd(13*32+31 downto 13*32),
      --BUS_ADDR_OUT(13*16+15 downto 13*16) => slv_addr(13*16+15 downto 13*16),
      --BUS_TIMEOUT_OUT(13)                 => open,
      --BUS_DATAREADY_IN(13)                => slv_ack(13),
      --BUS_WRITE_ACK_IN(13)                => slv_ack(13),
      --BUS_NO_MORE_DATA_IN(13)             => slv_busy(13),
      --BUS_UNKNOWN_ADDR_IN(13)             => '0',
      ---- Test register
      --BUS_READ_ENABLE_OUT(14)             => slv_read(14),
      --BUS_WRITE_ENABLE_OUT(14)            => slv_write(14),
      --BUS_DATA_OUT(14*32+31 downto 14*32) => slv_data_wr(14*32+31 downto 14*32),
      --BUS_DATA_IN(14*32+31 downto 14*32)  => slv_data_rd(14*32+31 downto 14*32),
      --BUS_ADDR_OUT(14*16+15 downto 14*16) => open,
      --BUS_TIMEOUT_OUT(14)                 => open,
      --BUS_DATAREADY_IN(14)                => slv_ack(14),
      --BUS_WRITE_ACK_IN(14)                => slv_ack(14),
      --BUS_NO_MORE_DATA_IN(14)             => slv_busy(14),
      --BUS_UNKNOWN_ADDR_IN(14)             => '0',
      ---- data buffer status registers
      --BUS_READ_ENABLE_OUT(15)             => slv_read(15),
      --BUS_WRITE_ENABLE_OUT(15)            => slv_write(15),
      --BUS_DATA_OUT(15*32+31 downto 15*32) => slv_data_wr(15*32+31 downto 15*32),
      --BUS_DATA_IN(15*32+31 downto 15*32)  => slv_data_rd(15*32+31 downto 15*32),
      --BUS_ADDR_OUT(15*16+15 downto 15*16) => slv_addr(15*16+15 downto 15*16),
      --BUS_TIMEOUT_OUT(15)                 => open,
      --BUS_DATAREADY_IN(15)                => slv_ack(15),
      --BUS_WRITE_ACK_IN(15)                => slv_ack(15),
      --BUS_NO_MORE_DATA_IN(15)             => slv_busy(15),
      --BUS_UNKNOWN_ADDR_IN(15)             => '0',
      ---- LVL1 release status register
      --BUS_READ_ENABLE_OUT(16)             => slv_read(16),
      --BUS_WRITE_ENABLE_OUT(16)            => slv_write(16),
      --BUS_DATA_OUT(16*32+31 downto 16*32) => slv_data_wr(16*32+31 downto 16*32),
      --BUS_DATA_IN(16*32+31 downto 16*32)  => slv_data_rd(16*32+31 downto 16*32),
      --BUS_ADDR_OUT(16*16+15 downto 16*16) => slv_addr(16*16+15 downto 16*16),
      --BUS_TIMEOUT_OUT(16)                 => open,
      --BUS_DATAREADY_IN(16)                => slv_ack(16),
      --BUS_WRITE_ACK_IN(16)                => slv_ack(16),
      --BUS_NO_MORE_DATA_IN(16)             => slv_busy(16),
      --BUS_UNKNOWN_ADDR_IN(16)             => '0',
      ---- IPU handler status register
      --BUS_READ_ENABLE_OUT(17)             => slv_read(17),
      --BUS_WRITE_ENABLE_OUT(17)            => slv_write(17),
      --BUS_DATA_OUT(17*32+31 downto 17*32) => slv_data_wr(17*32+31 downto 17*32),
      --BUS_DATA_IN(17*32+31 downto 17*32)  => slv_data_rd(17*32+31 downto 17*32),
      --BUS_ADDR_OUT(17*16+15 downto 17*16) => slv_addr(17*16+15 downto 17*16),
      --BUS_TIMEOUT_OUT(17)                 => open,
      --BUS_DATAREADY_IN(17)                => slv_ack(17),
      --BUS_WRITE_ACK_IN(17)                => slv_ack(17),
      --BUS_NO_MORE_DATA_IN(17)             => slv_busy(17),
      --BUS_UNKNOWN_ADDR_IN(17)             => '0',
      ---- debug
      --STAT_DEBUG          => stat
      STAT_DEBUG          => open
      );


------------------------------------------------------------------------------------
-- pedestal memories (16x128 = 2048, 18bit)
------------------------------------------------------------------------------------
  THE_PED_MEM: slv_ped_thr_mem
    port map(
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      -- Slave bus
      SLV_ADDR_IN     => slv_addr(0*16+10 downto 0*16),
      SLV_READ_IN     => slv_read(0),
      SLV_WRITE_IN    => slv_write(0),
      SLV_ACK_OUT     => slv_ack(0),
      SLV_DATA_IN     => slv_data_wr(0*32+31 downto 0*32),
      SLV_DATA_OUT    => slv_data_rd(0*32+31 downto 0*32),
      -- backplane identifier
      BACKPLANE_IN    => bp_module_qq,
      -- I/O to the backend
      MEM_CLK_IN      => CLK_IN,
      MEM_ADDR_IN     => buf_addr,
      MEM_0_D_OUT     => ped_data(0),
      MEM_1_D_OUT     => ped_data(1),
      MEM_2_D_OUT     => ped_data(2),
      MEM_3_D_OUT     => ped_data(3),
      MEM_4_D_OUT     => ped_data(4),
      MEM_5_D_OUT     => ped_data(5),
      MEM_6_D_OUT     => ped_data(6),
      MEM_7_D_OUT     => ped_data(7),
      MEM_8_D_OUT     => ped_data(8),
      MEM_9_D_OUT     => ped_data(9),
      MEM_10_D_OUT    => ped_data(10),
      MEM_11_D_OUT    => ped_data(11),
      MEM_12_D_OUT    => ped_data(12),
      MEM_13_D_OUT    => ped_data(13),
      MEM_14_D_OUT    => ped_data(14),
      MEM_15_D_OUT    => ped_data(15),
      -- Status lines
      STAT            => open
      );
  slv_busy(0) <= '0';

------------------------------------------------------------------------------------
-- threshold memories (16x128 = 2048, 18bit)
------------------------------------------------------------------------------------
  THE_THR_MEM: slv_ped_thr_mem
    port map(
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      -- Slave bus
      SLV_ADDR_IN     => slv_addr(1*16+10 downto 1*16),
      SLV_READ_IN     => slv_read(1),
      SLV_WRITE_IN    => slv_write(1),
      SLV_ACK_OUT     => slv_ack(1),
      SLV_DATA_IN     => slv_data_wr(1*32+31 downto 1*32),
      SLV_DATA_OUT    => slv_data_rd(1*32+31 downto 1*32),
      -- backplane identifier
      BACKPLANE_IN    => bp_module_qq,
      -- I/O to the backend
      MEM_CLK_IN      => CLK_IN,
      MEM_ADDR_IN     => thr_addr,
      MEM_0_D_OUT     => thr_data(0),
      MEM_1_D_OUT     => thr_data(1),
      MEM_2_D_OUT     => thr_data(2),
      MEM_3_D_OUT     => thr_data(3),
      MEM_4_D_OUT     => thr_data(4),
      MEM_5_D_OUT     => thr_data(5),
      MEM_6_D_OUT     => thr_data(6),
      MEM_7_D_OUT     => thr_data(7),
      MEM_8_D_OUT     => thr_data(8),
      MEM_9_D_OUT     => thr_data(9),
      MEM_10_D_OUT    => thr_data(10),
      MEM_11_D_OUT    => thr_data(11),
      MEM_12_D_OUT    => thr_data(12),
      MEM_13_D_OUT    => thr_data(13),
      MEM_14_D_OUT    => thr_data(14),
      MEM_15_D_OUT    => thr_data(15),
      -- Status lines
      STAT            => open
      );
  slv_busy(1) <= '0';

------------------------------------------------------------------------------------
-- I2C master block for accessing APVs
------------------------------------------------------------------------------------
  THE_I2C_MASTER: i2c_master
    port map(
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      -- Slave bus
      SLV_READ_IN     => slv_read(2),
      SLV_WRITE_IN    => slv_write(2),
      SLV_BUSY_OUT    => slv_busy(2),
      SLV_ACK_OUT     => slv_ack(2),
      SLV_DATA_IN     => slv_data_wr(2*32+31 downto 2*32),
      SLV_DATA_OUT    => slv_data_rd(2*32+31 downto 2*32),
      -- I2C connections
      SDA_IN          => SDA_IN,
      SDA_OUT         => SDA_OUT,
      SCL_IN          => SCL_IN,
      SCL_OUT         => SCL_OUT,
      -- Status lines
      STAT            => open
      );

-- ------------------------------------------------------------------------------------
-- -- SPI master
-- ------------------------------------------------------------------------------------
--   THE_SPI_MASTER: spi_master
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       BUS_READ_IN     => slv_read(4),
--       BUS_WRITE_IN    => slv_write(4),
--       BUS_BUSY_OUT    => slv_busy(4),
--       BUS_ACK_OUT     => slv_ack(4),
--       BUS_ADDR_IN     => slv_addr(4*16+0 downto 4*16),
--       BUS_DATA_IN     => slv_data_wr(4*32+31 downto 4*32),
--       BUS_DATA_OUT    => slv_data_rd(4*32+31 downto 4*32),
--       -- SPI connections
--       SPI_CS_OUT      => spi_cs,
--       SPI_SDI_IN      => spi_sdi,
--       SPI_SDO_OUT     => spi_sdo,
--       SPI_SCK_OUT     => spi_sck,
--       -- BRAM for read/write data
--       BRAM_A_OUT      => spi_bram_addr,
--       BRAM_WR_D_IN    => spi_bram_wr_d,
--       BRAM_RD_D_OUT   => spi_bram_rd_d,
--       BRAM_WE_OUT     => spi_bram_we,
--       -- Status lines
--       STAT            => spi_debug --open
--       );
-- 
-- ------------------------------------------------------------------------------------
-- -- data memory for SPI accesses
-- ------------------------------------------------------------------------------------
--   THE_SPI_MEMORY: spi_databus_memory
--     port map(
--       CLK_IN              => CLK_IN,
--       RESET_IN            => RESET_IN,
--       -- Slave bus
--       BUS_ADDR_IN         => slv_addr(5*16+5 downto 5*16),
--       BUS_READ_IN         => slv_read(5),
--       BUS_WRITE_IN        => slv_write(5),
--       BUS_ACK_OUT         => slv_ack(5),
--       BUS_DATA_IN         => slv_data_wr(5*32+31 downto 5*32),
--       BUS_DATA_OUT        => slv_data_rd(5*32+31 downto 5*32),
--       -- state machine connections
--       BRAM_ADDR_IN        => spi_bram_addr,
--       BRAM_WR_D_OUT       => spi_bram_wr_d,
--       BRAM_RD_D_IN        => spi_bram_rd_d,
--       BRAM_WE_IN          => spi_bram_we,
--       -- Status lines
--       STAT                => open
--       );
--   slv_busy(5) <= '0';
-- 
-- ------------------------------------------------------------------------------------
-- -- ADC0 SPI master
-- ------------------------------------------------------------------------------------
--   THE_SPI_ADC0_MASTER: spi_adc_master
--     generic map(
--       RESET_VALUE_CTRL    => x"60"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_READ_IN     => slv_read(6),
--       SLV_WRITE_IN    => slv_write(6),
--       SLV_BUSY_OUT    => slv_busy(6),
--       SLV_ACK_OUT     => slv_ack(6),
--       SLV_DATA_IN     => slv_data_wr(6*32+31 downto 6*32),
--       SLV_DATA_OUT    => slv_data_rd(6*32+31 downto 6*32),
--       -- SPI connections
--       SPI_CS_OUT      => SPI_ADC0_CS_OUT,
--       SPI_SDO_OUT     => SPI_ADC0_SDO_OUT,
--       SPI_SCK_OUT     => SPI_ADC0_SCK_OUT,
--       -- ADC connections
--       ADC_LOCKED_IN   => ADC0_PLL_LOCKED_IN,
--       ADC_PD_OUT      => ADC0_PD_OUT,
--       ADC_RST_OUT     => ADC0_RST_OUT,
--       ADC_DEL_OUT     => ADC0_DEL_OUT,
--       -- APV connections
--       APV_RST_OUT     => APV0_RST_OUT,
--       -- Status lines
--       STAT            => open
--       );
-- 
-- ------------------------------------------------------------------------------------
-- -- ADC1 SPI master
-- ------------------------------------------------------------------------------------
--   THE_SPI_ADC1_MASTER: spi_adc_master
--     generic map(
--       RESET_VALUE_CTRL    => x"60"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_READ_IN     => slv_read(7),
--       SLV_WRITE_IN    => slv_write(7),
--       SLV_BUSY_OUT    => slv_busy(7),
--       SLV_ACK_OUT     => slv_ack(7),
--       SLV_DATA_IN     => slv_data_wr(7*32+31 downto 7*32),
--       SLV_DATA_OUT    => slv_data_rd(7*32+31 downto 7*32),
--       -- SPI connections
--       SPI_CS_OUT      => SPI_ADC1_CS_OUT,
--       SPI_SDO_OUT     => SPI_ADC1_SDO_OUT,
--       SPI_SCK_OUT     => SPI_ADC1_SCK_OUT,
--       -- ADC connections
--       ADC_LOCKED_IN   => ADC1_PLL_LOCKED_IN,
--       ADC_PD_OUT      => ADC1_PD_OUT,
--       ADC_RST_OUT     => ADC1_RST_OUT,
--       ADC_DEL_OUT     => ADC1_DEL_OUT,
--       -- APV connections
--       APV_RST_OUT     => APV1_RST_OUT,
--       -- Status lines
--       STAT            => open
--       );
-- 
-- ------------------------------------------------------------------------------------
-- -- APV control / status registers
-- ------------------------------------------------------------------------------------
--   THE_SLV_REGISTER_BANK: slv_register_bank
--     generic map(
--       RESET_VALUE => x"0001"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_ADDR_IN     => slv_addr(8*16+3 downto 8*16),
--       SLV_READ_IN     => slv_read(8),
--       SLV_WRITE_IN    => slv_write(8),
--       SLV_ACK_OUT     => slv_ack(8),
--       SLV_DATA_IN     => slv_data_wr(8*32+31 downto 8*32),
--       SLV_DATA_OUT    => slv_data_rd(8*32+31 downto 8*32),
--       -- I/O to the backend
--       BACKPLANE_IN    => BACKPLANE_IN,
--       CTRL_0_OUT      => CTRL_0_OUT,
--       CTRL_1_OUT      => CTRL_1_OUT,
--       CTRL_2_OUT      => CTRL_2_OUT,
--       CTRL_3_OUT      => CTRL_3_OUT,
--       CTRL_4_OUT      => CTRL_4_OUT,
--       CTRL_5_OUT      => CTRL_5_OUT,
--       CTRL_6_OUT      => CTRL_6_OUT,
--       CTRL_7_OUT      => CTRL_7_OUT,
--       CTRL_8_OUT      => CTRL_8_OUT,
--       CTRL_9_OUT      => CTRL_9_OUT,
--       CTRL_10_OUT     => CTRL_10_OUT,
--       CTRL_11_OUT     => CTRL_11_OUT,
--       CTRL_12_OUT     => CTRL_12_OUT,
--       CTRL_13_OUT     => CTRL_13_OUT,
--       CTRL_14_OUT     => CTRL_14_OUT,
--       CTRL_15_OUT     => CTRL_15_OUT,
--       STAT_0_IN       => STAT_0_IN,
--       STAT_1_IN       => STAT_1_IN,
--       STAT_2_IN       => STAT_2_IN,
--       STAT_3_IN       => STAT_3_IN,
--       STAT_4_IN       => STAT_4_IN,
--       STAT_5_IN       => STAT_5_IN,
--       STAT_6_IN       => STAT_6_IN,
--       STAT_7_IN       => STAT_7_IN,
--       STAT_8_IN       => STAT_8_IN,
--       STAT_9_IN       => STAT_9_IN,
--       STAT_10_IN      => STAT_10_IN,
--       STAT_11_IN      => STAT_11_IN,
--       STAT_12_IN      => STAT_12_IN,
--       STAT_13_IN      => STAT_13_IN,
--       STAT_14_IN      => STAT_14_IN,
--       STAT_15_IN      => STAT_15_IN,
--       -- Status lines
--       STAT            => open
--       );
--   slv_busy(8) <= '0';
-- 
-- ------------------------------------------------------------------------------------
-- -- Data buffer status registers
-- ------------------------------------------------------------------------------------
--   THE_FIFO_STATUS_BANK: slv_status_bank
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_ADDR_IN     => slv_addr(15*16+3 downto 15*16),
--       SLV_READ_IN     => slv_read(15),
--       SLV_WRITE_IN    => slv_write(15),
--       SLV_ACK_OUT     => slv_ack(15),
--       SLV_DATA_OUT    => slv_data_rd(15*32+31 downto 15*32),
--       -- I/O to the backend
--       STAT_0_IN       => FIFO_STATUS_0_IN,
--       STAT_1_IN       => FIFO_STATUS_1_IN,
--       STAT_2_IN       => FIFO_STATUS_2_IN,
--       STAT_3_IN       => FIFO_STATUS_3_IN,
--       STAT_4_IN       => FIFO_STATUS_4_IN,
--       STAT_5_IN       => FIFO_STATUS_5_IN,
--       STAT_6_IN       => FIFO_STATUS_6_IN,
--       STAT_7_IN       => FIFO_STATUS_7_IN,
--       STAT_8_IN       => FIFO_STATUS_8_IN,
--       STAT_9_IN       => FIFO_STATUS_9_IN,
--       STAT_10_IN      => FIFO_STATUS_10_IN,
--       STAT_11_IN      => FIFO_STATUS_11_IN,
--       STAT_12_IN      => FIFO_STATUS_12_IN,
--       STAT_13_IN      => FIFO_STATUS_13_IN,
--       STAT_14_IN      => FIFO_STATUS_14_IN,
--       STAT_15_IN      => FIFO_STATUS_15_IN
--       );
--   slv_busy(15) <= '0';
-- 
-- 
-- ------------------------------------------------------------------------------------
-- -- LVL1 release status
-- ------------------------------------------------------------------------------------
--   THE_LVL1_RELEASE_STATUS: slv_status
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_READ_IN     => slv_read(16),
--       SLV_WRITE_IN    => slv_write(16),
--       SLV_ACK_OUT     => slv_ack(16),
--       SLV_DATA_OUT    => slv_data_rd(16*32+31 downto 16*32),
--       -- I/O to the backend
--       STATUS_IN       => RELEASE_STATUS_IN
--       );
--   slv_busy(16) <= '0';
-- 
-- 
-- ------------------------------------------------------------------------------------
-- -- IPU handler status
-- ------------------------------------------------------------------------------------
--   THE_IPU_HANDLER_STATUS: slv_status
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_READ_IN     => slv_read(17),
--       SLV_WRITE_IN    => slv_write(17),
--       SLV_ACK_OUT     => slv_ack(17),
--       SLV_DATA_OUT    => slv_data_rd(17*32+31 downto 17*32),
--       -- I/O to the backend
--       STATUS_IN       => IPU_STATUS_IN
--       );
--   slv_busy(17) <= '0';
-- 
-- 
-- ------------------------------------------------------------------------------------
-- -- ADC level register
-- ------------------------------------------------------------------------------------
--   THE_ADC_LVL_REG: slv_register
--     generic map(
--       RESET_VALUE => x"d0_20_88_78"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN, -- general reset
--       BUSY_IN         => '0',
--       -- Slave bus
--       SLV_READ_IN     => slv_read(9),
--       SLV_WRITE_IN    => slv_write(9),
--       SLV_BUSY_OUT    => slv_busy(9),
--       SLV_ACK_OUT     => slv_ack(9),
--       SLV_DATA_IN     => slv_data_wr(9*32+31 downto 9*32),
--       SLV_DATA_OUT    => slv_data_rd(9*32+31 downto 9*32),
--       -- I/O to the backend
--       REG_DATA_IN     => ctrl_lvl,
--       REG_DATA_OUT    => ctrl_lvl,
--       -- Status lines
--       STAT            => open
--       );
-- 
-- ------------------------------------------------------------------------------------
-- -- trigger control register
-- ------------------------------------------------------------------------------------
--   THE_TRG_CTRL_REG: slv_register
--     generic map(
--       RESET_VALUE => x"10_10_10_10"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN, -- general reset
--       BUSY_IN         => '0',
--       -- Slave bus
--       SLV_READ_IN     => slv_read(10),
--       SLV_WRITE_IN    => slv_write(10),
--       SLV_BUSY_OUT    => slv_busy(10),
--       SLV_ACK_OUT     => slv_ack(10),
--       SLV_DATA_IN     => slv_data_wr(10*32+31 downto 10*32),
--       SLV_DATA_OUT    => slv_data_rd(10*32+31 downto 10*32),
--       -- I/O to the backend
--       REG_DATA_IN     => ctrl_trg,
--       REG_DATA_OUT    => ctrl_trg,
--       -- Status lines
--       STAT            => open
--       );
-- 
-- ------------------------------------------------------------------------------------
-- -- PLL control register
-- ------------------------------------------------------------------------------------
--   THE_PLL_CTRL_REG: slv_half_register
--     generic map(
--       RESET_VALUE => x"00_02"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN, -- general reset
--       -- Slave bus
--       SLV_READ_IN     => slv_read(11),
--       SLV_WRITE_IN    => slv_write(11),
--       SLV_ACK_OUT     => slv_ack(11),
--       SLV_DATA_IN     => slv_data_wr(11*32+31 downto 11*32),
--       SLV_DATA_OUT    => slv_data_rd(11*32+31 downto 11*32),
--       -- I/O to the backend
--       STATUS_REG_IN   => STATUS_PLL_IN,
--       CTRL_REG_OUT    => ctrl_pll,
--       -- Status lines
--       STAT            => open
--       );
--   slv_busy(11) <= '0';
-- 
-- ------------------------------------------------------------------------------------
-- -- ADC0 snooper
-- ------------------------------------------------------------------------------------
--   THE_ADC0_SNOOPER: slv_adc_snoop
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_ADDR_IN     => slv_addr(12*16+9 downto 12*16),
--       SLV_READ_IN     => slv_read(12),
--       SLV_WRITE_IN    => slv_write(12),
--       SLV_ACK_OUT     => slv_ack(12),
--       SLV_DATA_IN     => slv_data_wr(12*32+31 downto 12*32),
--       SLV_DATA_OUT    => slv_data_rd(12*32+31 downto 12*32),
--       -- I/O to the backend
--       ADC_SEL_OUT     => ADC0_SEL_OUT,
--       ADC_CLK_IN      => ADC0_CLK_IN,
--       ADC_DATA_IN     => ADC0_DATA_IN,
--       -- Status lines
--       STAT            => open
--       );
--   slv_busy(12) <= '0';
-- 
-- 
-- ------------------------------------------------------------------------------------
-- -- ADC1 snooper
-- ------------------------------------------------------------------------------------
--   THE_ADC1_SNOOPER: slv_adc_snoop
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN,
--       -- Slave bus
--       SLV_ADDR_IN     => slv_addr(13*16+9 downto 13*16),
--       SLV_READ_IN     => slv_read(13),
--       SLV_WRITE_IN    => slv_write(13),
--       SLV_ACK_OUT     => slv_ack(13),
--       SLV_DATA_IN     => slv_data_wr(13*32+31 downto 13*32),
--       SLV_DATA_OUT    => slv_data_rd(13*32+31 downto 13*32),
--       -- I/O to the backend
--       ADC_SEL_OUT     => ADC1_SEL_OUT,
--       ADC_CLK_IN      => ADC1_CLK_IN,
--       ADC_DATA_IN     => ADC1_DATA_IN,
--       -- Status lines
--       STAT            => open
--       );
--   slv_busy(13) <= '0';
-- 
-- 
-- ------------------------------------------------------------------------------------
-- -- test register (normal)
-- ------------------------------------------------------------------------------------
--   THE_GOOD_TEST_REG: slv_register
--     generic map(
--       RESET_VALUE => x"dead_beef"
--       )
--     port map(
--       CLK_IN          => CLK_IN,
--       RESET_IN        => RESET_IN, -- general reset
--       BUSY_IN         => '0',
--       -- Slave bus
--       SLV_READ_IN     => slv_read(14),
--       SLV_WRITE_IN    => slv_write(14),
--       SLV_BUSY_OUT    => slv_busy(14),
--       SLV_ACK_OUT     => slv_ack(14),
--       SLV_DATA_IN     => slv_data_wr(14*32+31 downto 14*32),
--       SLV_DATA_OUT    => slv_data_rd(14*32+31 downto 14*32),
--       -- I/O to the backend
--       REG_DATA_IN     => TEST_REG_IN, --x"5a3c_87e1",
--       REG_DATA_OUT    => TEST_REG_OUT,
--       -- Status lines
--       STAT            => open
--       );
-- 
-- 


-- unusable pins
  debug(63 downto 43) <= (others => '0');
-- connected pins
  debug(42 downto 0)  <= (others => '0');

-- input signals
  spi_sdi       <= SPI_SDI_IN;

-- Output signals
  SPI_CS_OUT    <= spi_cs;
  SPI_SCK_OUT   <= spi_sck;
  SPI_SDO_OUT   <= spi_sdo;

  -- CTRL_LVL_OUT  <= ctrl_lvl;
  -- CTRL_TRG_OUT  <= ctrl_trg;
  -- CTRL_PLL_OUT  <= ctrl_pll;

  -- DEBUG_OUT     <= debug;

end Behavioral;
