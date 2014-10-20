-------------------------------------------------------------------------------
-- Title      : Stretcher
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Stretcher.vhd
-- Author     : cugur@gsi.de
-- Created    : 2012-11-07
-- Last update: 2014-08-27
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

  signal pulse_d1 : std_logic;
  signal pulse_d2 : std_logic;
  signal pulse_d3 : std_logic;
  signal pulse_d4 : std_logic;

  attribute syn_keep                 : boolean;
  attribute syn_keep of pulse_d1     : signal is true;
  attribute syn_keep of pulse_d2     : signal is true;
  attribute syn_keep of pulse_d3     : signal is true;
  attribute syn_keep of pulse_d4     : signal is true;
  attribute syn_preserve             : boolean;
  attribute syn_preserve of pulse_d1 : signal is true;
  attribute syn_preserve of pulse_d2 : signal is true;
  attribute syn_preserve of pulse_d3 : signal is true;
  attribute syn_preserve of pulse_d4 : signal is true;
  attribute NOMERGE                  : string;
  attribute NOMERGE of pulse_d1      : signal is "KEEP";
  attribute NOMERGE of pulse_d2      : signal is "KEEP";
  attribute NOMERGE of pulse_d3      : signal is "KEEP";
  attribute NOMERGE of pulse_d4      : signal is "KEEP";
  
begin  -- behavioral

  pulse_d1 <= not PULSE_IN;
  pulse_d2 <= not pulse_d1;
  pulse_d3 <= not pulse_d2;
  pulse_d4 <= not pulse_d3;

  PULSE_OUT <= transport pulse_d4 after 30 ns;

end behavioral;
