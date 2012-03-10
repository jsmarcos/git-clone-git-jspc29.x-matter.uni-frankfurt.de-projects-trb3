-------------------------------------------------------------------------------
-- Title      : Reset Generator
-- Project    : 
-------------------------------------------------------------------------------
-- File       : reset_generator.vhd
-- Author     : Cahit Ugur
-- Company    : 
-- Created    : 2011-11-09
-- Last update: 2011-11-28
-- Platform   : 
-- Standard   : VHDL'87
-------------------------------------------------------------------------------
-- Description: Generates a synchronous reset signal.
-------------------------------------------------------------------------------
-- Copyright (c) 2011 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-11-09  1.0      ugur    Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;

entity Reset_Generator is
  
  generic (
    RESET_SIGNAL_WIDTH : std_logic_vector(3 downto 0) := x"F");  -- The length of the reset signal

  port (
    CLK_IN    : in  std_logic;  -- System clock, that the reset will be synchronous with.
    RESET_OUT : out std_logic);         -- Synchronous reset signal

end Reset_Generator;

architecture Behavioral of Reset_Generator is

  signal reset_cnt : std_logic_vector(3 downto 0) := x"0";  -- initial value of the reset counter
  signal reset_i   : std_logic                    := '0';
  
begin  -- Behavioral

  RESET_PROC : process (CLK_IN)
  begin  -- process RESET_PROC
    if (rising_edge(CLK_IN)) then       -- rising clock edge
      reset_cnt <= reset_cnt + 1;
      reset_i   <= '1';
      if reset_cnt = RESET_SIGNAL_WIDTH then
        reset_cnt <= RESET_SIGNAL_WIDTH;
        reset_i   <= '0';
      end if;
    end if;
  end process RESET_PROC;

  RESET_OUT <= reset_i when rising_edge(CLK_IN);

end Behavioral;
