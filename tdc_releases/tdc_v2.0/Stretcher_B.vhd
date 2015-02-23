-------------------------------------------------------------------------------
-- Title      : Stretcher_B
-- Project    : TRB3
-------------------------------------------------------------------------------
-- File       : Stretcher_B.vhd
-- Author     : Cahit Ugur  <c.ugur@gsi.de>
-- Created    : 2014-11-24
-- Last update: 2014-11-24
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-11-24  1.0      cugur   Created
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Stretcher_B is
  generic (
    CHANNEL : integer range 1 to 64;
    DEPTH   : integer range 1 to 10 := 3);
  port (
    PULSE_IN  : in  std_logic_vector(CHANNEL*DEPTH-1 downto 1);
    PULSE_OUT : out std_logic_vector(CHANNEL*DEPTH-1 downto 1));

end entity Stretcher_B;

architecture behavioral of Stretcher_B is

  signal pulse_i : std_logic_vector(CHANNEL*DEPTH-1 downto 1);

  attribute syn_keep                : boolean;
  attribute syn_keep of pulse_i     : signal is true;
  attribute syn_preserve            : boolean;
  attribute syn_preserve of pulse_i : signal is true;
  attribute NOMERGE                 : string;
  attribute NOMERGE of pulse_i      : signal is "KEEP";

begin  -- architecture behavioral

  pulse_i   <= PULSE_IN;
  PULSE_OUT <= not pulse_i;

end architecture behavioral;
