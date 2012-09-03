-------------------------------------------------------------------------------
-- Title      : Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-08-28
-- Last update: 2012-09-03
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2012-08-28  1.0      cugur   Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity Channel_200 is

  generic (
    CHANNEL_ID : integer range 0 to 64);  
  port (
    CLK_200              : in  std_logic;   -- 200 MHz clk
    RESET_200            : in  std_logic;   -- reset sync with 200Mhz clk
    CLK_100              : in  std_logic;   -- 100 MHz clk
    RESET_100            : in  std_logic;   -- reset sync with 100Mhz clk
--
    HIT_IN               : in  std_logic;   -- hit in
    HIT_DETECT_OUT       : out std_logic;   -- hit detect reg out
--    COARSE_CNTR_IN       : in  std_logic_vector(10 downto 0);  -- coarse counter in
    TIME_STAMP_IN        : in  std_logic_vector(10 downto 0);  -- time stamp in 
    READ_EN_IN           : in  std_logic;   -- read en signal
    FIFO_DATA_OUT        : out std_logic_vector(31 downto 0);  -- fifo data out
    FIFO_EMPTY_OUT       : out std_logic;   -- fifo empty signal
    FIFO_FULL_OUT        : out std_logic;   -- fifo full signal
    FIFO_ALMOST_FULL_OUT : out std_logic;   -- fifo almost full signal
    FIFO_WR_OUT          : out std_logic;   -- fifo wr en signal
    ENCODER_START_OUT    : out std_logic);  -- encoder start signal

end Channel_200;

architecture Channel_200 of Channel_200 is

  -- carry chain
  signal data_a_i      : std_logic_vector(303 downto 0);
  signal data_b_i      : std_logic_vector(303 downto 0);
  signal result_i      : std_logic_vector(303 downto 0);
  signal ff_array_en_i : std_logic;

  -- hit detection
  signal result_2_reg    : std_logic;
  signal hit_detect_i    : std_logic;
  signal hit_detect_reg  : std_logic;
  signal hit_detect_2reg : std_logic;

  -- time stamp
  signal time_stamp_i   : std_logic_vector(10 downto 0);
  signal time_stamp_reg : std_logic_vector(10 downto 0);

  -- encoder
  signal encoder_start_i    : std_logic;
  signal encoder_data_out_i : std_logic_vector(9 downto 0);
  signal encoder_debug_i    : std_logic_vector(31 downto 0);

  -- fifo
  signal fifo_data_out_i    : std_logic_vector(31 downto 0);
  signal fifo_data_in_i     : std_logic_vector(31 downto 0);
  signal fifo_empty_i       : std_logic;
  signal fifo_full_i        : std_logic;
  signal fifo_almost_full_i : std_logic;
  signal fifo_wr_en_i       : std_logic;

  attribute syn_keep                  : boolean;
  attribute syn_keep of ff_array_en_i : signal is true;

begin  -- Channel_200

  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
  FC : Adder_304
    port map (
      CLK    => CLK_200,
      RESET  => RESET_200,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => ff_array_en_i,
      Result => result_i);
  data_a_i      <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFFFF";
  data_b_i      <= x"000000000000000000000000000000000000000000000000000000000000000000000" & not(HIT_IN) & x"000000" & "00" & HIT_IN;
  ff_array_en_i <= not(hit_detect_i or hit_detect_reg or hit_detect_2reg);

  result_2_reg    <= result_i(2)    when rising_edge(CLK_200);
  hit_detect_i    <= (not result_2_reg) and result_i(2);  -- detects the hit by
                                                          -- comparing the
                                                          -- previous state of the
                                                          -- hit detection bit
  hit_detect_reg  <= hit_detect_i   when rising_edge(CLK_200);
  hit_detect_2reg <= hit_detect_reg when rising_edge(CLK_200);
  time_stamp_reg  <= TIME_STAMP_IN  when rising_edge(CLK_200);
  HIT_DETECT_OUT  <= hit_detect_reg;
  encoder_start_i <= hit_detect_reg;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_200,
      CLK             => CLK_200,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_i,
      FINISHED_OUT    => fifo_wr_en_i,
      BINARY_CODE_OUT => encoder_data_out_i,
      ENCODER_DEBUG   => encoder_debug_i);

  FIFO : FIFO_32x32_OutReg
    port map (
      Data       => fifo_data_in_i,
      WrClock    => CLK_200,
      RdClock    => CLK_100,
      WrEn       => fifo_wr_en_i,
      RdEn       => READ_EN_IN,
      Reset      => RESET_100,
      RPReset    => RESET_200,
      Q          => fifo_data_out_i,
      Empty      => fifo_empty_i,
      Full       => fifo_full_i,
      AlmostFull => fifo_almost_full_i);
  fifo_data_in_i(31)           <= '1';  -- data marker
  fifo_data_in_i(30 downto 29) <= "00";                -- reserved bits
  fifo_data_in_i(28 downto 22) <= conv_std_logic_vector(CHANNEL_ID, 7);  -- channel number
  fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
  fifo_data_in_i(10 downto 0)  <= time_stamp_reg;      -- hit time stamp

  RegisterOutputs : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      if RESET_100 = '1' then
        FIFO_DATA_OUT        <= (others => '1');
        FIFO_EMPTY_OUT       <= '0';
        FIFO_FULL_OUT        <= '0';
        FIFO_ALMOST_FULL_OUT <= '0';
      else
        FIFO_DATA_OUT        <= fifo_data_out_i;
        FIFO_EMPTY_OUT       <= fifo_empty_i;
        FIFO_FULL_OUT        <= fifo_full_i;
        FIFO_ALMOST_FULL_OUT <= fifo_almost_full_i;
      end if;
    end if;
  end process RegisterOutputs;

  ENCODER_START_OUT <= encoder_start_i;
  FIFO_WR_OUT       <= fifo_wr_en_i;

end Channel_200;
