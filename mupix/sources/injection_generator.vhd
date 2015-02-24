-----------------------------------------------------------------------------
-- MUPIX3 injection generator
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-- Adepted to TRBv3 Readout: Tobias Weber, University Mainz
-----------------------------------------------------------------------------




library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mupix_components.all;

entity injection_generator is
  port (
    rst                  : in  std_logic;
    clk                  : in  std_logic;
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    testpulse1           : out std_logic;
    testpulse2           : out std_logic
    );
end injection_generator;


architecture rtl of injection_generator is

  signal counter1 : unsigned(15 downto 0) := (others => '0');
  signal counter2 : unsigned(15 downto 0) := (others => '0');

  signal counter_from_slv : unsigned(31 downto 0);
  signal slv_written      : std_logic_vector(1 downto 0);


  signal testpulse1_i   : std_logic;
  signal testpulse2_i   : std_logic;
  signal testpulse_busy : std_logic := '0';


begin

  process(clk, rst)
  begin
    if(rst = '1') then

      testpulse1_i <= '0';
      testpulse2_i <= '0';

    elsif rising_edge(clk) then
      if slv_written = "10" then
        counter1 <= counter_from_slv(15 downto 0);
        counter2 <= counter_from_slv(31 downto 16);
      end if;

      if(counter1 > x"0000") then
        testpulse1_i <= '1';
        counter1     <= counter1 - 1;
      else
        testpulse1_i <= '0';
      end if;

      if(counter2 > x"0000") then
        testpulse2_i <= '1';
        counter2     <= counter2 - 1;
      else
        testpulse2_i <= '0';
      end if;

    end if;
  end process;

  testpulse_busy <= '1' when testpulse2_i = '1' or testpulse1_i = '1' else '0';

  SLV_HANDLER : process(clk)
  begin
    if rising_edge(clk) then
      SLV_DATA_OUT         <= (others => '0');
      SLV_UNKNOWN_ADDR_OUT <= '0';
      SLV_NO_MORE_DATA_OUT <= '0';
      SLV_ACK_OUT          <= '0';
      slv_written          <= slv_written(0) & SLV_WRITE_IN;

      if SLV_READ_IN = '1' then
        if SLV_ADDR_IN = x"0060" then
          SLV_DATA_OUT(31 downto 16) <= std_logic_vector(counter2);
          SLV_DATA_OUT(15 downto 0)  <= std_logic_vector(counter1);
          SLV_ACK_OUT                <= '1';
        else
          SLV_UNKNOWN_ADDR_OUT <= '1';
        end if;
      end if;

      if SLV_WRITE_IN = '1' then
        if SLV_ADDR_IN = x"0060" then
          if testpulse_busy = '0' then
            counter_from_slv <= unsigned(SLV_DATA_IN);
            SLV_ACK_OUT      <= '1';
          else
            SLV_ACK_OUT <= '1';
          end if;
          
        else
          SLV_UNKNOWN_ADDR_OUT <= '1';
        end if;
      end if;
    end if;
  end process SLV_HANDLER;

--Output Signals
  testpulse2 <= testpulse2_i;
  testpulse1 <= testpulse1_i;
  
end rtl;
