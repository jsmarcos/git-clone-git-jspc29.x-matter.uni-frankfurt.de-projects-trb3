------------------------------------------------------------
--Module to Broadcast a Reset Signal to several frontends
--entities on an peripherial FPGA.
--T. Weber, University Mainz
------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
--use work.trb_net_std.all;
--use work.trb_net_components.all;
--use work.trb3_components.all;
--use work.version.all;

entity resethandler is
  
  port (
    CLK_IN                : in  std_logic;
    RESET_IN              : in  std_logic;
    TimestampReset_OUT    : out std_logic;
    EventCounterReset_OUT : out std_logic;
    -- Slave bus               
    SLV_READ_IN           : in  std_logic;
    SLV_WRITE_IN          : in  std_logic;
    SLV_DATA_OUT          : out std_logic_vector(31 downto 0);
    SLV_DATA_IN           : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN           : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT           : out std_logic;
    SLV_NO_MORE_DATA_OUT  : out std_logic;
    SLV_UNKNOWN_ADDR_OUT  : out std_logic);
end entity resethandler;

architecture behavioral of resethandler is

  signal timestampreset_i       : std_logic                    := '0';
  signal eventcounterreset_i    : std_logic                    := '0';
  signal timestampreset_edge    : std_logic_vector(1 downto 0) := (others => '0');
  signal eventcounterreset_edge : std_logic_vector(1 downto 0) := (others => '0');
  
begin  -- architecture behavioral


  timestamp_edge_detect : process (CLK_IN) is
  begin  -- process timestamp_edge_detect
    if rising_edge(CLK_IN) then
      timestampreset_edge <= timestampreset_edge(0) & timestampreset_i;
      if timestampreset_edge = "01" then
        TimestampReset_OUT <= '1';
      else
        TimestampReset_OUT <= '0';
      end if;
    end if;
  end process timestamp_edge_detect;

  eventcounter_edge_detect : process (CLK_IN) is
  begin  -- process eventcounter_edge_detect
    if rising_edge(CLK_IN) then
      eventcounterreset_edge <= eventcounterreset_edge(0) & eventcounterreset_i;
      if eventcounterreset_edge = "01" then
        EventCounterReset_OUT <= '1';
      else
        EventCounterReset_OUT <= '0';
      end if;
    end if;
  end process eventcounter_edge_detect;

  ------------------------------------------------------------
  --TRB SLV-BUS Hanlder
  ------------------------------------------------------------
  --0x0001: reset timestamps
  --0x0002: reset eventcounter
  slv_bus_handler : process (CLK_IN) is
  begin  -- process slv_bus_handler
    if rising_edge(CLK_IN) then
      slv_data_out         <= (others => '0');
      slv_ack_out          <= '0';
      slv_no_more_data_out <= '0';
      slv_unknown_addr_out <= '0';

      if SLV_WRITE_IN = '1' then
        case SLV_ADDR_IN is
          when x"0001" =>
            timestampreset_i <= SLV_DATA_IN(0);
            slv_ack_out      <= '1';
          when x"0002" =>
            eventcounterreset_i <= SLV_DATA_IN(0);
            slv_ack_out         <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;
      end if;

      if SLV_READ_IN = '1' then
        case SLV_ADDR_IN is
          when x"0001" =>
            slv_data_out(0) <= timestampreset_i;
            slv_ack_out     <= '1';
          when x"0002" =>
            slv_data_out(0) <= eventcounterreset_i;
            slv_ack_out  <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;
      end if;
    end if;
  end process slv_bus_handler;
  

end architecture behavioral;
