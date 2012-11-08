library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.nxyter_components.all;

entity nxyter_timestamp_sim is
  port(
    CLK_IN               : in  std_logic;  -- Clock 128MHz
    RESET_IN             : in  std_logic;
    
    TIMESTAMP_OUT        : out std_logic_vector(7 downto 0);
    CLK128_OUT           : out std_logic
    );
end entity;

architecture Behavioral of nxyter_timestamp_sim is
  
  signal timestamp_n     : std_logic_vector(7 downto 0);
  signal timestamp_g     : std_logic_vector(7 downto 0);
  signal timestamp       : unsigned(31 downto 0);
  signal counter         : unsigned(1 downto 0);
  
begin

  timestamp <= x"7f7f7f06";

  PROC_NX_TIMESTAMP: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_n <= (others => '0');
--        timestamp   <= (others => '0');
        counter     <= (others => '0');
      else
        case counter is
         --  when "00" => timestamp_n <= timestamp(7 downto 0);
         --  when "01" => timestamp_n <= timestamp(15 downto 8);
         --  when "10" => timestamp_n <= timestamp(23 downto 16);
         --  when "11" => timestamp_n <= timestamp(31 downto 24);
         --               timestamp   <= timestamp + 1;
          when "00" => timestamp_n <= timestamp(7 downto 0);
          when "01" => timestamp_n <= timestamp(15 downto 8);
          when "10" => timestamp_n <= timestamp(23 downto 16);
          when "11" => timestamp_n <= timestamp(31 downto 24);

          when others => null; 
        end case;

        counter <= counter + 1;
      end if;
    end if;           
  end process PROC_NX_TIMESTAMP;

--   Gray_Encoder_1: Gray_Encoder
--     generic map (
--       WIDTH => 8
--       )
--     port map (
--       CLK_IN    => CLK_IN,
--       RESET_IN  => RESET_IN,
--       BINARY_IN => timestamp_n,
--       GRAY_OUT  => timestamp_g 
--       );
-- 
  timestamp_g <= timestamp_n;
  
  
-- Output Signals
  TIMESTAMP_OUT <= timestamp_g;
  CLK128_OUT    <= CLK_IN;
  
end Behavioral;
