----------------------------------------------------------------------------------
-- Company: University Mainz, AG Fritsch
-- Engineer: Tobias Weber
-- 
-- Create Date:    20:13:03 07/03/2015 
-- Design Name: 
-- Module Name:    MupixDigiConverter - Behavioral 
-- Project Name: 
-- Target Devices: Hades Trigger and Readout Board v3
-- Tool versions: 
-- Description: Module to transform column and row address from 
--              chip representation to physical column and row.
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity MupixDigiConverter is
  generic (
    address_width : integer := 6);
  port (
    mupixVersionSel_in : in  std_logic;
    chipColumn_in      : in  std_logic_vector(address_width - 1 downto 0);
    chipRow_in         : in  std_logic_vector(address_width - 1 downto 0);
    physicalColumn_out : out std_logic_vector(address_width - 1 downto 0);
    physicalRow_out    : out std_logic_vector(address_width - 1 downto 0)); 
end MupixDigiConverter;

architecture Behavioral of MupixDigiConverter is

signal column_Mupix4_i : unsigned(address_width - 1 downto 0) := (others => '0');
signal row_Mupix4_i : unsigned(address_width - 1 downto 0) := ( others => '0');
signal row_tmp_Mupix4_i : unsigned(address_width - 1 downto 0) := (others => '0');

signal column_Mupix6_i : unsigned(address_width - 1 downto 0) := (others => '0');
signal row_Mupix6_i : unsigned(address_width - 1 downto 0) := ( others => '0');
signal row_tmp_Mupix6_i : unsigned(address_width - 1 downto 0) := (others => '0');


begin

  -- purpose: conversion of addresses for Mupix 4 digital part
  -- type   : combinational
  -- inputs : chipColumn_in, chipRow_in
  Mupix4Convert: process (chipColumn_in, chipRow_in, row_tmp_Mupix4_i) is
  begin  -- process Mupix4Convert
    row_tmp_Mupix4_i <= shift_left(unsigned(chipRow_in),1);
    case chipColumn_in(0) is
      when '0' =>
        row_Mupix4_i <= row_tmp_Mupix4_i;
        column_Mupix4_i <= shift_right(unsigned(chipColumn_in),1);
      when '1' =>
        row_Mupix4_i <= row_tmp_Mupix4_i + 1;
        column_Mupix4_i <= shift_right((unsigned(chipColumn_in) - 1 ),1);
      when others => null;
    end case;
  end process Mupix4Convert;

  -- purpose: conversion of addresses for Mupix 6 digital part
  -- type   : combinational
  -- inputs : chipColumn_in, chipRow_in, row_tmp_mupix6_i
  Mupix6Convert: process (chipColumn_in, chipRow_in, row_tmp_mupix6_i) is
  begin  -- process Mupix6Convert
    row_tmp_mupix6_i <= shift_left(unsigned(chipRow_in),1);
    case chipColumn_in(0) is
      when '0' =>
        column_Mupix6_i <= shift_right(unsigned(chipColumn_in),1);
        if chipRow_in(0) = '1' then
          row_Mupix6_i <= row_tmp_Mupix6_i - 2;
        else
          row_Mupix6_i <= row_tmp_Mupix6_i + 2;
        end if;
      when '1' =>
        row_Mupix6_i <= row_tmp_Mupix6_i + 1;
        column_Mupix6_i <= shift_right((unsigned(chipColumn_in) - 1 ),1);
      when others => null;
    end case;
  end process Mupix6Convert;

  --Multiplexing of output depending on version
  with mupixVersionSel_in select
    physicalRow_out <=
    std_logic_vector(row_Mupix4_i) when '1',
    std_logic_vector(row_Mupix6_i) when '0';

  with mupixVersionSel_in select
    physicalColumn_out <=
    std_logic_vector(column_Mupix4_i) when '1',
    std_logic_vector(column_Mupix6_i) when '0';
  
  
end Behavioral;

