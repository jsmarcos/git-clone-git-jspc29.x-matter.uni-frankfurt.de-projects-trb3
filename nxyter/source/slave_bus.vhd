library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.adcmv3_components.all;
use work.nxyter_components.all;

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
    SPI_SDO_OUT             : out   std_logic;

    -- Timestamp Read
    NX_CLK128_IN            : in std_logic;
    NX_TIMESTAMP_IN         : in std_logic_vector(7 downto 0)
    );
end entity;

architecture Behavioral of slave_bus is

-- Signals
  signal slv_read             : std_logic_vector(8-1 downto 0);
  signal slv_write            : std_logic_vector(8-1 downto 0);
  signal slv_busy             : std_logic_vector(8-1 downto 0);
  signal slv_ack              : std_logic_vector(8-1 downto 0);
  signal slv_addr             : std_logic_vector(8*16-1 downto 0);
  signal slv_data_rd          : std_logic_vector(8*32-1 downto 0);
  signal slv_data_wr          : std_logic_vector(8*32-1 downto 0);
  signal slv_unknown_addr     : std_logic_vector(8-1 downto 0);
    
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
  
  -- Register Stuff
  -- type reg_18bit_t is array (0 to 15) of std_logic_vector(17 downto 0);

  signal reg_data             : std_logic_vector(31 downto 0);
  
  
begin

-- Bus handler: acts as bridge between RegIO and the FPGA internal slave bus
  THE_BUS_HANDLER: trb_net16_regio_bus_handler
    generic map(
      PORT_NUMBER         => 3,
      PORT_ADDRESSES      => ( 0 => x"0000", -- Control Register Handler
                               1 => x"0040", -- I2C master
                               2 => x"0100", -- Timestamp Fifo
                               -- 3 => x"d100", -- SPI data memory
                               others => x"0000"),
      PORT_ADDR_MASK      => ( 0 => 3, -- Control Register Handler
                               1 => 0, -- I2C master
                               2 => 2, -- Timestamp Fifo
                               -- 3 => 6,  -- SPI data memory
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

      -- Control Registers
      BUS_READ_ENABLE_OUT(0)              => slv_read(0),
      BUS_WRITE_ENABLE_OUT(0)             => slv_write(0),
      BUS_DATA_OUT(0*32+31 downto 0*32)   => slv_data_wr(0*32+31 downto 0*32),
      BUS_DATA_IN(0*32+31 downto 0*32)    => slv_data_rd(0*32+31 downto 0*32),
      BUS_ADDR_OUT(0*16+2 downto 0*16)    => slv_addr(0*16+2 downto 0*16),
      BUS_ADDR_OUT(0*16+15 downto 0*16+3) => open,
      BUS_TIMEOUT_OUT(0)                  => open,
      BUS_DATAREADY_IN(0)                 => slv_ack(0),
      BUS_WRITE_ACK_IN(0)                 => slv_ack(0),
      BUS_NO_MORE_DATA_IN(0)              => slv_busy(0),
      BUS_UNKNOWN_ADDR_IN(0)              => slv_unknown_addr(0),

      -- I2C master
      BUS_READ_ENABLE_OUT(1)              => slv_read(1),
      BUS_WRITE_ENABLE_OUT(1)             => slv_write(1),
      BUS_DATA_OUT(1*32+31 downto 1*32)   => slv_data_wr(1*32+31 downto 1*32),
      BUS_DATA_IN(1*32+31 downto 1*32)    => slv_data_rd(1*32+31 downto 1*32),
      BUS_ADDR_OUT(1*16+15 downto 1*16)   => open,
      BUS_TIMEOUT_OUT(1)                  => open,
      BUS_DATAREADY_IN(1)                 => slv_ack(1),
      BUS_WRITE_ACK_IN(1)                 => slv_ack(1),
      BUS_NO_MORE_DATA_IN(1)              => slv_busy(1),
      BUS_UNKNOWN_ADDR_IN(1)              => '0',

      -- Timestamp Fifo
      BUS_READ_ENABLE_OUT(2)              => slv_read(2),
      BUS_WRITE_ENABLE_OUT(2)             => slv_write(2),
      BUS_DATA_OUT(2*32+31 downto 2*32)   => slv_data_wr(2*32+31 downto 2*32),
      BUS_DATA_IN(2*32+31 downto 2*32)    => slv_data_rd(2*32+31 downto 2*32),
      BUS_ADDR_OUT(2*16+1 downto 2*16)    => slv_addr(2*16+1 downto 2*16),
      BUS_ADDR_OUT(2*16+15 downto 2*16+2) => open,
      BUS_TIMEOUT_OUT(2)                  => open,
      BUS_DATAREADY_IN(2)                 => slv_ack(2),
      BUS_WRITE_ACK_IN(2)                 => slv_ack(2),
      BUS_NO_MORE_DATA_IN(2)              => slv_busy(2),
      BUS_UNKNOWN_ADDR_IN(2)              => slv_unknown_addr(2),

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

      ---- debug
      --STAT_DEBUG          => stat
      STAT_DEBUG          => open
      );

-------------------------------------------------------------------------------
-- Registers
-------------------------------------------------------------------------------
  nxyter_registers_1: nxyter_registers
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,

      SLV_READ_IN          => slv_read(0),
      SLV_WRITE_IN         => slv_write(0),
      SLV_DATA_OUT         => slv_data_rd(0*32+31 downto 0*32),
      SLV_DATA_IN          => slv_data_wr(0*32+31 downto 0*32),
      SLV_ADDR_IN          => slv_addr(0*16+15 downto 0*16),
      SLV_ACK_OUT          => slv_ack(0),
      SLV_NO_MORE_DATA_OUT => slv_busy(0),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(0)
      );
    
-------------------------------------------------------------------------------
-- I2C master block for accessing APVs
-------------------------------------------------------------------------------
  THE_I2C_MASTER: i2c_master
    port map(
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      -- Slave bus
      SLV_READ_IN     => slv_read(1),
      SLV_WRITE_IN    => slv_write(1),
      SLV_BUSY_OUT    => slv_busy(1),
      SLV_ACK_OUT     => slv_ack(1),
      SLV_DATA_IN     => slv_data_wr(1*32+31 downto 1*32),
      SLV_DATA_OUT    => slv_data_rd(1*32+31 downto 1*32),
      -- I2C connections
      SDA_IN          => SDA_IN,
      SDA_OUT         => SDA_OUT,
      SCL_IN          => SCL_IN,
      SCL_OUT         => SCL_OUT,
      -- Status lines
      STAT            => open
      );
-------------------------------------------------------------------------------
-- TimeStamp Read
-------------------------------------------------------------------------------
  nx_timestamp_read_1: nx_timestamp_read
    port map (
      CLK_IN               => CLK_IN,
      RESET_IN             => RESET_IN,
      NX_CLK128_IN         => NX_CLK128_IN,
      NX_TIMESTAMP_IN      => NX_TIMESTAMP_IN,

      SLV_READ_IN          => slv_read(2),
      SLV_WRITE_IN         => slv_write(2),
      SLV_DATA_OUT         => slv_data_rd(2*32+31 downto 2*32),
      SLV_DATA_IN          => slv_data_wr(2*32+31 downto 2*32),
      SLV_ADDR_IN          => slv_addr(2*16+15 downto 2*16),
      SLV_ACK_OUT          => slv_ack(2),
      SLV_NO_MORE_DATA_OUT => slv_busy(2),
      SLV_UNKNOWN_ADDR_OUT => slv_unknown_addr(2)
      );

-----------------------------------------------------------------------------
-- Test Register
-----------------------------------------------------------------------------
--   slv_register_1: slv_register
--     generic map (
--       RESET_VALUE  => x"dead_beef"
--       )
--     port map (
--       CLK_IN       => CLK_IN,
--       RESET_IN     => RESET_IN,
--       BUSY_IN      => '0',
--       
--       SLV_READ_IN  => slv_read(0),
--       SLV_WRITE_IN => slv_write(0),
--       SLV_BUSY_OUT => slv_busy(0),
--       SLV_ACK_OUT  => slv_ack(0),
--       SLV_DATA_IN  => slv_data_wr(0*32+31 downto 0*32),
--       SLV_DATA_OUT => slv_data_rd(0*32+31 downto 0*32),
-- 
--       REG_DATA_IN  => reg_data_in,
--       REG_DATA_OUT => reg_data_out,
--       STAT         => open
--     );
--   slv_busy(0) <= '0';
  
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

end Behavioral;
