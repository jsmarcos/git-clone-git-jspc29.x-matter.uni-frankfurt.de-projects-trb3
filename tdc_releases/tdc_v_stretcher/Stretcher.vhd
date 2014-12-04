-------------------------------------------------------------------------------
-- Title      : Stretcher
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Stretcher.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-11-07
-- Last update: 2014-08-26
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
use work.version.all;

entity Stretcher is
  
  port (
    PULSE_IN  : in  std_logic;
    PULSE_OUT : out std_logic);

end Stretcher;

architecture behavioral of Stretcher is

  signal pulse_inverse1 : std_logic;
  signal pulse_inverse2 : std_logic;
  signal pulse_inverse3 : std_logic;
  signal pulse_latch    : std_logic;

  attribute syn_keep                       : boolean;
  attribute syn_keep of pulse_inverse1     : signal is true;
  attribute syn_keep of pulse_inverse2     : signal is true;
  attribute syn_keep of pulse_inverse3     : signal is true;
  attribute syn_keep of pulse_latch        : signal is true;
  attribute syn_preserve                   : boolean;
  attribute syn_preserve of pulse_inverse1 : signal is true;
  attribute syn_preserve of pulse_inverse2 : signal is true;
  attribute syn_preserve of pulse_inverse3 : signal is true;
  attribute syn_preserve of pulse_latch    : signal is true;
  attribute NOMERGE                        : string;
  attribute NOMERGE of pulse_inverse1      : signal is "KEEP";
  attribute NOMERGE of pulse_inverse2      : signal is "KEEP";
  attribute NOMERGE of pulse_inverse3      : signal is "KEEP";
  attribute NOMERGE of pulse_latch         : signal is "KEEP";
  
begin  -- behavioral

  pulse_inverse1 <= not PULSE_IN;
  pulse_inverse2 <= not pulse_inverse1;
  pulse_inverse3 <= not pulse_inverse2;

  TheStretcher : process (PULSE_IN, pulse_inverse3)
  begin
    if PULSE_IN = '1' then
      pulse_latch <= '1';
    elsif rising_edge(pulse_inverse3) then
      pulse_latch <= '0';
    end if;
  end process TheStretcher;

  PULSE_OUT <= pulse_latch after 30 ns;

end behavioral;
