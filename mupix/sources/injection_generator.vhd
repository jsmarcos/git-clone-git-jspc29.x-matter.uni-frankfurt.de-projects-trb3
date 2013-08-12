-----------------------------------------------------------------------------
-- MUPIX3 injection generator
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-----------------------------------------------------------------------------




library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.mupix_comp.all;

entity injection_generator is
  port (
    rstn               : in  std_logic;
    clk                : in  std_logic;
    injection_register : in  std_logic_vector(31 downto 0);
    reg_written        : in  std_logic;
    testpulse1         : out std_logic;
    testpulse2         : out std_logic
    );
end injection_generator;


architecture rtl of injection_generator is

  signal counter1 : std_logic_vector(15 downto 0);
  signal counter2 : std_logic_vector(15 downto 0);


begin

  process(clk, rstn)
  begin
    if(rstn = '0') then

      testpulse1 <= '0';
      testpulse2 <= '0';

    elsif(clk'event and clk = '1') then

      if(reg_written = '1') then
        counter1 <= injection_register(15 downto 0);
        counter2 <= injection_register(31 downto 16);
      end if;

      if(counter1 > "00000000000000000") then
        testpulse1 <= '1';
        counter1   <= counter1 - '1';
      else
        testpulse1 <= '0';
      end if;

      if(counter2 > "00000000000000000") then
        testpulse2 <= '1';
        counter2   <= counter2 - '1';
      else
        testpulse2 <= '0';
      end if;

    end if;
  end process;
end rtl;
