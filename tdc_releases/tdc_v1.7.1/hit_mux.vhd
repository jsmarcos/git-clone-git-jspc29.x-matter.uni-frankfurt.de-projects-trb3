-------------------------------------------------------------------------------
-- Title      : Hit Multiplexer
-- Project    : FPGA TDC
-------------------------------------------------------------------------------
-- File       : hit_mux.vhd
-- Author     : Cahit Ugur  <c.ugur@gsi.de>
-- Created    : 2014-03-26
-- Last update: 2014-03-27
-------------------------------------------------------------------------------
-- Description: Entity to decide the hit for the channels between physical or
-- calibration hits.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2014-03-26  1.0      cugur   Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity hit_mux is
  
  port (
    CH_EN_IN           : in  std_logic;  -- channel enable signal
    CALIBRATION_EN_IN  : in  std_logic;  -- calibration enable signal
    HIT_CALIBRATION_IN : in  std_logic;  -- hit signal for calibration purposes
    HIT_PHYSICAL_IN    : in  std_logic;  -- physical hit signal
    HIT_OUT            : out std_logic);  -- hit signal to the delay lines
end entity hit_mux;

architecture behavioral of hit_mux is

  signal ch_en_i           : std_logic;
  signal calibration_en_i  : std_logic;
  signal hit_calibration_i : std_logic;
  signal hit_physical_i    : std_logic;
  signal hit_i             : std_logic;

  attribute syn_keep                      : boolean;
  attribute syn_keep of ch_en_i           : signal is true;
  attribute syn_keep of calibration_en_i  : signal is true;
  attribute syn_keep of hit_calibration_i : signal is true;
  attribute syn_keep of hit_physical_i    : signal is true;
  attribute syn_keep of hit_i             : signal is true;
  --attribute syn_preserve                        : boolean;
  --attribute syn_preserve of coarse_cntr         : signal is true;
  attribute nomerge                       : string;
  attribute nomerge of ch_en_i            : signal is "true";
  attribute nomerge of calibration_en_i   : signal is "true";
  attribute nomerge of hit_calibration_i  : signal is "true";
  attribute nomerge of hit_physical_i     : signal is "true";
  attribute nomerge of hit_i              : signal is "true";

  
begin  -- architecture behavioral

  ch_en_i           <= CH_EN_IN;
  calibration_en_i  <= CALIBRATION_EN_IN;
  hit_calibration_i <= HIT_CALIBRATION_IN;
  hit_physical_i    <= HIT_PHYSICAL_IN;
  
  process (ch_en_i, calibration_en_i, hit_calibration_i, hit_physical_i)
  begin
    if ch_en_i = '1' then
      if calibration_en_i = '1' then
        hit_i <= hit_calibration_i;
      else
        hit_i <= hit_physical_i;
      end if;
    else
      hit_i <= '0';
    end if;
  end process;

  HIT_OUT <= hit_i;

end architecture behavioral;
