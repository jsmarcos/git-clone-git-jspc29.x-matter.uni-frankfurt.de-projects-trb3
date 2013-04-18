-------------------------------------------------------------------------------
-- Title      : Logic Analyser Signals
-- Project    : 
-------------------------------------------------------------------------------
-- File       : LogicAnalyser.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-10-26
-- Last update: 2013-03-01
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;

entity LogicAnalyser is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65);

  port (
    CLK        : in  std_logic;
    RESET      : in  std_logic;
--
    DATA_IN    : in  std_logic_vector(3*32-1 downto 0);
    CONTROL_IN : in  std_logic_vector(3 downto 0);
    DATA_OUT   : out std_logic_vector(15 downto 0)
    );

end LogicAnalyser;


architecture behavioral of LogicAnalyser is
  
  signal mux_out : std_logic_vector(15 downto 0);

begin  -- behavioral

-------------------------------------------------------------------------------
-- Logic Analyser Signals
-------------------------------------------------------------------------------
  REG_LOGIC_ANALYSER_OUTPUT : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        mux_out <= (others => '0');
      elsif CONTROL_IN = x"1" then      -- TRBNET connections debugging
        mux_out(7 downto 0) <= DATA_IN(7 downto 0);      --fsm_debug;
        mux_out(8)          <= DATA_IN(8);   --REFERENCE_TIME;
        mux_out(9)          <= DATA_IN(9);   --VALID_TIMING_TRG_IN;
        mux_out(10)         <= DATA_IN(10);  --VALID_NOTIMING_TRG_IN;
        mux_out(11)         <= DATA_IN(11);  --INVALID_TRG_IN;
        mux_out(12)         <= DATA_IN(12);  --TRG_DATA_VALID_IN;
        mux_out(13)         <= DATA_IN(13);  --data_wr_reg;
        mux_out(14)         <= DATA_IN(14);  --data_finished_reg;
        mux_out(15)         <= DATA_IN(15);  --trg_release_reg;
      elsif CONTROL_IN = x"2" then      -- Reference channel debugging
        mux_out <= DATA_IN(31 downto 16);    --ref_debug_i(15 downto 0);
      elsif CONTROL_IN = x"3" then      -- Data out
        mux_out(7 downto 0)   <= DATA_IN(7 downto 0);    --fsm_debug;
        mux_out(8)            <= DATA_IN(8);             --REFERENCE_TIME;
        mux_out(9)            <= DATA_IN(13);            --data_wr_reg;
        mux_out(15 downto 10) <= DATA_IN(37 downto 32);  --data_out_reg(27 downto 22);

        --elsif CONTROL_IN = x"4" then  -- channel debugging
        --  mux_out <= DATA_IN();  --ch_debug_i(1)(15 downto 0);
      end if;
    end if;
  end process REG_LOGIC_ANALYSER_OUTPUT;

  DATA_OUT <= mux_out;


end behavioral;
