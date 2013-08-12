--type definitions and components for MuPix readout
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package mupix_components is

  --MuPix Board entity with regio to trbv3
  component MuPix3_Board
    port (
      clk                        : in  std_logic;
      fastclk                    : in  std_logic;
      reset                      : in  std_logic;
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
      LVL1_TRG_DATA_VALID_IN     : in  std_logic;
      LVL1_VALID_TIMING_TRG_IN   : in  std_logic;
      LVL1_VALID_NOTIMING_TRG_IN : in  std_logic;
      LVL1_INVALID_TRG_IN        : in  std_logic;
      LVL1_TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
      LVL1_TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
      LVL1_TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
      LVL1_TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
      LVL1_INT_TRG_NUMBER_IN     : in  std_logic_vector(15 downto 0);
      FEE_TRG_RELEASE_OUT        : out std_logic;
      FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
      FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
      FEE_DATA_WRITE_OUT         : out std_logic;
      FEE_DATA_FINISHED_OUT      : out std_logic;
      FEE_DATA_ALMOST_FULL_IN    : in  std_logic;
      REGIO_ADDR_IN              : in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN              : in  std_logic_vector(31 downto 0);
      REGIO_DATA_OUT             : out std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN       : in  std_logic;
      REGIO_WRITE_ENABLE_IN      : in  std_logic;
      REGIO_TIMEOUT_IN           : in  std_logic;
      REGIO_DATAREADY_OUT        : out std_logic;
      REGIO_WRITE_ACK_OUT        : out std_logic;
      REGIO_NO_MORE_DATA_OUT     : out std_logic;
      REGIO_UNKNOWN_ADDR_OUT     : out std_logic);
  end component;

end mupix_components;
