library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.nxyter_components.all;

entity nx_data_buffer is
  port (
    CLK_IN               : in std_logic;  
    RESET_IN             : in std_logic;

    -- Data Buffer FIFO
    FIFO_DATA_IN         : std_logic_vector(31 downto 0);
    FIFO_WRITE_ENABLE_IN : std_logic;
    FIFO_READ_ENABLE_IN  : std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic
    );

end nx_data_buffer;

architecture Behavioral of nx_data_buffer is

-- FIFO Handler
  signal fifo_o            : std_logic_vector(31 downto 0);
  signal fifo_empty        : std_logic;       
  signal fifo_full         : std_logic;
  signal fifo_read_enable  : std_logic;
  signal fifo_write_enable : std_logic;
  
-- Slave Bus
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;

  signal register_fifo_status  : std_logic_vector(31 downto 0);
  signal register_write_enable : std_logic;

begin

-------------------------------------------------------------------------------
-- FIFO Handler
-------------------------------------------------------------------------------
  fifo_32_data_1: fifo_32_data
    port map (
      Data  => FIFO_DATA_IN,
      Clock => CLK_IN,
      WrEn  => fifo_write_enable,
      RdEn  => fifo_read_enable,
      Reset => RESET_IN,
      Q     => fifo_o,
      Empty => fifo_empty,
      Full  => fifo_full
      );

  PROC_FIFO_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_write_enable <= '0';
        fifo_read_enable  <= '0';
      else
        fifo_write_enable <= '1';
        fifo_read_enable  <= '1';
        
        if (fifo_full = '1'
            or FIFO_WRITE_ENABLE_IN = '0'
            or register_write_enable <= '0') then
          fifo_write_enable <= '0';
        end if;

        if (fifo_empty = '1' or FIFO_READ_ENABLE_IN = '0') then
          fifo_read_enable <= '0';
        end if;
        
      end if;
    end if;
  end process PROC_FIFO_HANDLER;
  
-------------------------------------------------------------------------------
-- Slave Bus Slow Control
-------------------------------------------------------------------------------

  register_fifo_status(0)            <= fifo_write_enable;
  register_fifo_status(1)            <= fifo_full;
  register_fifo_status(3 downto 2)   <= (others => '0');
  register_fifo_status(4)            <= fifo_read_enable;
  register_fifo_status(5)            <= fifo_empty;
  register_fifo_status(7 downto 6)   <= (others => '0');
  register_fifo_status(31 downto 8)  <= (others => '0');

  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o        <= (others => '0');
        slv_ack_o             <= '0';
        slv_unknown_addr_o    <= '0';
        slv_no_more_data_o    <= '0';
        register_write_enable <= '0';
      else
        slv_data_out_o     <= (others => '0');
        slv_ack_o          <= '1';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        
        if (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" => if (fifo_empty = '1') then
                              slv_no_more_data_o <= '1';
                            else
                              slv_data_out_o <= fifo_o;
                              slv_ack_o <= '1';
                            end if;
            when x"0001" => slv_data_out_o <= register_fifo_status;
            when others  => slv_unknown_addr_o <= '1';
                            slv_ack_o <= '0';          
          end case;
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0001" => register_write_enable <= SLV_DATA_IN(0);
                            slv_ack_o <= '1';
            when others  => slv_unknown_addr_o <= '1';              
                            slv_ack_o <= '0';
          end case;                
        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;

-- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;

end Behavioral;
