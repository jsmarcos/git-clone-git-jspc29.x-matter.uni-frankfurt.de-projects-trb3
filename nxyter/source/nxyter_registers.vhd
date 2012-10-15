library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;

entity nxyter_registers is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    
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
end entity;

architecture Behavioral of nxyter_registers is

  signal slv_data_out_o     : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o : std_logic;
  signal slv_unknown_addr_o : std_logic;
  signal slv_ack_o          : std_logic;

  type reg_32bit_t is array (0 to 7) of std_logic_vector(31 downto 0);
  signal reg_data   : reg_32bit_t;
  
begin

  PROC_NX_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        reg_data(0) <= x"babe_0000";
        reg_data(1) <= x"babe_0001";
        reg_data(2) <= x"babe_0002";
        reg_data(3) <= x"babe_0003";
        reg_data(4) <= x"babe_0004";
        reg_data(5) <= x"babe_0005";
        reg_data(6) <= x"babe_0006";
        reg_data(7) <= x"babe_0007";

        slv_data_out_o     <= (others => '0');
        slv_no_more_data_o <= '0';
        slv_unknown_addr_o <= '0';
        slv_ack_o          <= '0';
      else
        slv_ack_o <= '1';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        slv_data_out_o     <= (others => '0');    

        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" => reg_data(0) <= SLV_DATA_IN;
            when x"0001" => reg_data(1) <= SLV_DATA_IN;
            when x"0002" => reg_data(2) <= SLV_DATA_IN;
            when x"0003" => reg_data(3) <= SLV_DATA_IN;
            when x"0004" => reg_data(4) <= SLV_DATA_IN;
            when x"0005" => reg_data(5) <= SLV_DATA_IN;
            when x"0006" => reg_data(6) <= SLV_DATA_IN;
            when x"0007" => reg_data(7) <= SLV_DATA_IN;
            when others => slv_unknown_addr_o <= '1';
                           slv_ack_o <= '0';
          end case;
          
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>  slv_data_out_o <= reg_data(0);
            when x"0001" =>  slv_data_out_o <= reg_data(1);
            when x"0002" =>  slv_data_out_o <= reg_data(2);
            when x"0003" =>  slv_data_out_o <= reg_data(3);
            when x"0004" =>  slv_data_out_o <= reg_data(4);
            when x"0005" =>  slv_data_out_o <= reg_data(5);
            when x"0006" =>  slv_data_out_o <= reg_data(6);
            when x"0007" =>  slv_data_out_o <= reg_data(7);
            when others => slv_unknown_addr_o <= '1';
                           slv_ack_o <= '0';
          end case;

        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;           
  end process PROC_NX_REGISTERS;

-- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;          

end Behavioral;
