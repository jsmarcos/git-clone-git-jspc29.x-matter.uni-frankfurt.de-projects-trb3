----------------------------------------------------------------------------
-- synchronize signals from mupix board
-- Invert logic levels of some signals from the mupix sensorboard
-- depending if inverters are present on the sensor board
-- Tobias Weber, Mainz Univerity
-----------------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

use work.mupix_components.all;

entity board_interface is
  port(
    clk_in               : in  std_logic;
    -- signals from mupix
    timestamp_from_mupix : in std_logic_vector(7 downto 0);
    rowaddr_from_mupix   : in std_logic_vector(5 downto 0);
    coladdr_from_mupix   : in std_logic_vector(5 downto 0);
    priout_from_mupix    : in std_logic;
    sout_c_from_mupix    : in std_logic;
    sout_d_from_mupix    : in std_logic;
    hbus_from_mupix      : in std_logic;
    fpga_aux_from_board  : in std_logic_vector(9 downto 0);
    --synced (and inverted) signals
    timestamp_from_mupix_sync : out std_logic_vector(7 downto 0);
    rowaddr_from_mupix_sync   : out std_logic_vector(5 downto 0);
    coladdr_from_mupix_sync   : out std_logic_vector(5 downto 0);
    priout_from_mupix_sync    : out std_logic;
    sout_c_from_mupix_sync    : out std_logic;
    sout_d_from_mupix_sync    : out std_logic;
    hbus_from_mupix_sync      : out std_logic;
    fpga_aux_from_board_sync  : out std_logic_vector(9 downto 0);
    --Trb Slv-Bus
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic);          
end entity board_interface;



architecture rtl of board_interface is

  signal invert_signals_int : std_logic := '0';
  
begin


-- Synchronize input signals
  process
  begin
    wait until rising_edge(clk_in);
    if invert_signals_int = '1' then
      timestamp_from_mupix_sync <= not timestamp_from_mupix;
      rowaddr_from_mupix_sync   <= not rowaddr_from_mupix;
      coladdr_from_mupix_sync   <= not coladdr_from_mupix;
      sout_c_from_mupix_sync    <= not sout_c_from_mupix;
      sout_d_from_mupix_sync    <= not sout_d_from_mupix;
      priout_from_mupix_sync    <= priout_from_mupix;  --is inverted on the chip
      hbus_from_mupix_sync      <= hbus_from_mupix;
      fpga_aux_from_board_sync  <= fpga_aux_from_board;
    else
      timestamp_from_mupix_sync <= timestamp_from_mupix;
      rowaddr_from_mupix_sync   <= rowaddr_from_mupix;
      coladdr_from_mupix_sync   <= coladdr_from_mupix;
      sout_c_from_mupix_sync    <= sout_c_from_mupix;
      sout_d_from_mupix_sync    <= sout_d_from_mupix;
      priout_from_mupix_sync    <= not priout_from_mupix;  --is inverted on the chip
      hbus_from_mupix_sync      <= not hbus_from_mupix;
      fpga_aux_from_board_sync  <= not fpga_aux_from_board;
    end if;
  end process;

   slv_bus_handler : process(CLK_IN)
  begin
    if rising_edge(CLK_IN) then
      slv_data_out         <= (others => '0');
      slv_ack_out          <= '0';
      slv_no_more_data_out <= '0';
      slv_unknown_addr_out <= '0';
      
      if slv_write_in = '1' then
       case SLV_ADDR_IN is
         when x"0200" =>
            invert_signals_int <= SLV_DATA_IN(0);
            slv_ack_out <= '1';
         when others =>
           slv_unknown_addr_out <= '1';
       end case;
      elsif slv_read_in = '1' then
        case slv_addr_in is
          when x"0200" =>
            slv_data_out(0) <= invert_signals_int;
            slv_ack_out  <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;

      end if;
    end if;
  end process slv_bus_handler;
  
end architecture rtl;
