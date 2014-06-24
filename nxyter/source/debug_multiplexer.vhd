library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity debug_multiplexer is
  generic (
    NUM_PORTS : integer range 1 to 32 := 1
    );
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    DEBUG_LINE_IN        : in  debug_array_t(0 to NUM_PORTS-1);
    DEBUG_LINE_OUT       : out std_logic_vector(15 downto 0);

    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic

    );
end entity;

architecture Behavioral of debug_multiplexer is

  -- Multiplexer
  signal port_select        : std_logic_vector(7 downto 0);
  signal debug_line_o       : std_logic_vector(15 downto 0);

  -- Checkerboard
  signal checker_counter    : unsigned(15 downto 0);

  -- Slave Bus
  signal slv_data_out_o     : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o : std_logic;
  signal slv_unknown_addr_o : std_logic;
  signal slv_ack_o          : std_logic;
  
begin
  
  PROC_MULTIPLEXER: process(port_select,
                            DEBUG_LINE_IN)
  begin
    if (unsigned(port_select) < NUM_PORTS) then
      debug_line_o             <=
        DEBUG_LINE_IN(to_integer(unsigned(port_select)));
    elsif (unsigned(port_select) = NUM_PORTS) then
      -- Checkerboard
      debug_line_o             <= checker_counter;
    else
      debug_line_o             <= (others => '1');
    end if;
  end process PROC_MULTIPLEXER;

  PROC_CHECKERBOARD: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        checker_counter <= (others => '0');
      else
        checker_counter <= checker_counter + 1;
      end if;
    end if;
  end process PROC_CHECKERBOARD;
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o      <= (others => '0');
        slv_no_more_data_o  <= '0';
        slv_unknown_addr_o  <= '0';
        slv_ack_o           <= '0';
        port_select         <= (others => '0');
      else
        slv_ack_o           <= '1';
        slv_unknown_addr_o  <= '0';
        slv_no_more_data_o  <= '0';
        slv_data_out_o      <= (others => '0');    
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              if (unsigned(SLV_DATA_IN(7 downto 0)) < NUM_PORTS + 1) then
                port_select               <= SLV_DATA_IN(7 downto 0);
              end if;
              slv_ack_o                   <= '1';

            when others =>                
              slv_unknown_addr_o          <= '1';
              slv_ack_o                   <= '0';
          end case;
          
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(7 downto 0)  <= port_select;
              slv_data_out_o(31 downto 8) <= (others => '0');

            when others =>
              slv_unknown_addr_o          <= '1';
              slv_ack_o                   <= '0';
          end case;

        else
          slv_ack_o                       <= '0';
        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;
  
  DEBUG_LINE_OUT       <= debug_line_o;

end Behavioral;
