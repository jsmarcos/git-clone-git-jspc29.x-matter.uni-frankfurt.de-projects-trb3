library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

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
  signal counter         : unsigned(1 downto 0);
  signal counter2        : unsigned(3 downto 0);
  signal counter3        : unsigned(1 downto 0);

begin

  PROC_NX_TIMESTAMP: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        timestamp_n <= (others => '0');
        counter     <= (others => '0');
        counter2    <= (others => '0');
        counter3    <= (others => '0');

      else

        if (counter3 /= 0) then
          case counter is
            when "11" => timestamp_n <= x"06";
                         counter3 <= counter3 + 1;

            when "10" => timestamp_n <= x"7f";

            when "01" => timestamp_n <= x"7f";

            when "00" => timestamp_n <= x"7f";
          end case;

        else
          case counter is
            when "11" =>
              timestamp_n(7)           <= '0';
              timestamp_n(6 downto 4)  <= (others => '0');
              timestamp_n(3 downto 0)  <= counter2;
              counter3 <= counter3 + 1;
              
            when "10" =>
              timestamp_n(7)           <= '0';
              timestamp_n(6 downto 4)  <= (others => '0');
              timestamp_n(3 downto 0)  <= counter2;
            
            when "01" =>
              timestamp_n(7)           <= '0';
              timestamp_n(6 downto 4)  <= (others => '0');
              timestamp_n(3 downto 0)  <= counter2;

            when "00" =>
              timestamp_n(7)           <= '0';
              timestamp_n(6 downto 4)  <= (others => '0');
              timestamp_n(3 downto 0)  <= counter2;

          end case;
          counter2 <= counter2 + 1;
        end if;

        counter  <= counter + 1;
      end if;
    end if;           
  end process PROC_NX_TIMESTAMP;

--   gray_Encoder_1: gray_Encoder
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
--  timestamp_g <= timestamp_n;
  
  
-- Output Signals
  TIMESTAMP_OUT <= timestamp_n;
  CLK128_OUT    <= CLK_IN;
  
end Behavioral;
