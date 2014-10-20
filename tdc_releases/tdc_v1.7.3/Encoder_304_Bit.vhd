-------------------------------------------------------------------------------
-- Title      : Encoder 304 bits
-------------------------------------------------------------------------------
-- File       : Encoder_304_Bit.vhd
-- Author     : Cahit Ugur
-- Created    : 2011-11-28
-- Last update: 2014-06-24
-------------------------------------------------------------------------------
-- Description: Encoder for 304 bits
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2011-11-28  1.0      ugur    Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.tdc_components.all;

-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity Encoder_304_Bit is
  port (
    RESET            : in  std_logic;   -- system reset
    CLK              : in  std_logic;   -- system clock
    START_IN         : in  std_logic;
    THERMOCODE_IN    : in  std_logic_vector(303 downto 0);
    FINISHED_OUT     : out std_logic;
    BINARY_CODE_OUT  : out std_logic_vector(9 downto 0);
    ENCODER_INFO_OUT : out std_logic_vector(1 downto 0);
    ENCODER_DEBUG    : out std_logic_vector(31 downto 0)
    );
end Encoder_304_Bit;

architecture behavioral of Encoder_304_Bit is

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------
  component LUT4
    generic (
      INIT : std_logic_vector);
    port (
      A, B, C, D : in  std_ulogic;
      Z          : out std_ulogic);
  end component;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
  signal P_lut            : std_logic_vector(37 downto 0);
  signal P_one            : std_logic_vector(37 downto 0);
  signal mux_control      : std_logic_vector(5 downto 0);
  signal mux_control_reg  : std_logic_vector(5 downto 0);
  signal mux_control_2reg : std_logic_vector(5 downto 0);
  signal mux_control_3reg : std_logic_vector(5 downto 0);
  signal interval_reg     : std_logic_vector(8 downto 0);
  signal interval_binary  : std_logic_vector(2 downto 0);
  signal binary_code_f    : std_logic_vector(8 downto 0);
  signal binary_code_r    : std_logic_vector(8 downto 0);
  signal start_reg        : std_logic;
  signal start_2reg       : std_logic;
  signal address_i        : std_logic_vector(9 downto 0);
  signal q_reg            : std_logic_vector(7 downto 0);
  signal info             : std_logic_vector(1 downto 0);
  signal info_reg         : std_logic_vector(1 downto 0);
  signal info_2reg        : std_logic_vector(1 downto 0);
--
  signal conv_finished_i  : std_logic;
  signal thermocode_i     : std_logic_vector(304 downto 0);
  signal start_pipeline   : std_logic_vector(6 downto 0) := (others => '0');

  attribute syn_keep                     : boolean;
  attribute syn_keep of mux_control      : signal is true;
  attribute syn_keep of mux_control_reg  : signal is true;
  attribute syn_keep of mux_control_2reg : signal is true;
  attribute syn_keep of mux_control_3reg : signal is true;
-------------------------------------------------------------------------------
begin


  thermocode_i(304 downto 1) <= THERMOCODE_IN;
  thermocode_i(0)            <= '1';
  start_reg                  <= START_IN         when rising_edge(CLK);
  start_2reg                 <= start_reg        when rising_edge(CLK);
  mux_control_reg            <= mux_control      when rising_edge(CLK);
  mux_control_2reg           <= mux_control_reg  when rising_edge(CLK);
  mux_control_3reg           <= mux_control_2reg when rising_edge(CLK);

  Interval_Determination_First : LUT4
    generic map (INIT => X"15A8")
    port map (A => '1', B => '1', C => THERMOCODE_IN(0), D => START_IN,
              Z => P_lut(0));

  Interval_Determination : for i in 1 to 37 generate
    U : LUT4
      generic map (INIT => X"15A8")
      port map (A => THERMOCODE_IN(8*i-2), B => THERMOCODE_IN(8*i-1), C => THERMOCODE_IN(8*i), D => START_IN,
                Z => P_lut(i));
  end generate Interval_Determination;
-------------------------------------------------------------------------------

  Gen_P_one : for i in 0 to 36 generate
    P_one(i) <= P_lut(i) and (not P_lut(i+1)) when rising_edge(CLK);
  end generate Gen_P_one;

  P_one_assign : process (CLK)
  begin
    if rising_edge(CLK) then
      if START_IN = '0' then
        P_one(37) <= '0';
      else
        P_one(37) <= P_lut(37);
      end if;
    end if;
  end process P_one_assign;

  Interval_Number_to_Binary : process (CLK)
  begin  -- The interval number with the 0-1 transition is converted from 1-of-N code to binary
    -- code for the control of the MUX.
    if rising_edge(CLK) then
      if start_2reg = '1' or start_reg = '1' then
        mux_control(0) <= P_one(0) or P_one(2) or P_one(4) or P_one(6) or P_one(8) or P_one(10) or
                          P_one(12) or P_one(14) or P_one(16) or P_one(18) or P_one(20) or P_one(22) or
                          P_one(24) or P_one(26) or P_one(28) or P_one(30) or P_one(32) or P_one(34) or
                          P_one(36);
        mux_control(1) <= P_one(1) or P_one(2) or P_one(5) or P_one(6) or P_one(9) or P_one(10) or
                          P_one(13) or P_one(14) or P_one(17) or P_one(18) or P_one(21) or P_one(22) or
                          P_one(25) or P_one(26) or P_one(29) or P_one(30) or P_one(33) or P_one(34) or
                          P_one(37);
        mux_control(2) <= P_one(3) or P_one(4) or P_one(5) or P_one(6) or P_one(11) or P_one(12) or
                          P_one(13) or P_one(14) or P_one(19) or P_one(20) or P_one(21) or P_one(22) or
                          P_one(27) or P_one(28) or P_one(29) or P_one(30) or P_one(35) or P_one(36) or
                          P_one(37);
        mux_control(3) <= P_one(7) or P_one(8) or P_one(9) or P_one(10) or P_one(11) or P_one(12) or
                          P_one(13) or P_one(14) or P_one(23) or P_one(24) or P_one(25) or P_one(26) or
                          P_one(27) or P_one(28) or P_one(29) or P_one(30);
        mux_control(4) <= P_one(15) or P_one(16) or P_one(17) or P_one(18) or P_one(19) or P_one(20) or
                          P_one(21) or P_one(22) or P_one(23) or P_one(24) or P_one(25) or P_one(26) or
                          P_one(27) or P_one(28) or P_one(29) or P_one(30);
        mux_control(5) <= P_one(31) or P_one(32) or P_one(33) or P_one(34) or P_one(35) or P_one(36) or
                          P_one(37);
      else
        mux_control <= (others => '0');
      end if;
    end if;
  end process Interval_Number_to_Binary;

  Interval_Selection : process (CLK)
    variable tmp : std_logic_vector(9 downto 1);
  begin  -- The interval with the 0-1 transition is selected.
    if rising_edge(CLK) then
      tmp := (others => '0');
      make_mux : for i in 0 to 37 loop
        make_mux_2 : for j in 1 to 9 loop
          tmp(j) := tmp(j) or (thermocode_i(i*8-1+j) and P_one(i));
        end loop;
      end loop;
      interval_reg <= tmp;
    end if;
  end process Interval_Selection;

  ROM_Encoder_1 : ROM_encoder_3
    port map (
      Address    => address_i,
      OutClock   => CLK,
      OutClockEn => '1',
      Reset      => RESET,
      Q          => q_reg);

  address_i       <= start_2reg & interval_reg;
  interval_binary <= q_reg(2 downto 0) when rising_edge(CLK);
  info            <= q_reg(7 downto 6) when rising_edge(CLK);
  info_reg        <= info              when rising_edge(CLK);
  info_2reg       <= info_reg          when rising_edge(CLK);

  Binary_Code_Calculation_rf : process (CLK)
  begin
    if rising_edge(CLK) then
      binary_code_r <= (mux_control_3reg - 1) & interval_binary;
      binary_code_f <= binary_code_r;
    end if;
  end process Binary_Code_Calculation_rf;

  Binary_Code_Calculation : process (CLK)
  begin
    if rising_edge(CLK) then
      if conv_finished_i = '1' then
        if info_reg(1) = '1' and info_2reg(1) = '1' then
          BINARY_CODE_OUT <= ('0' & binary_code_r) + ('0' & binary_code_f);
        else
          BINARY_CODE_OUT <= (others => '1');
        end if;
        ENCODER_INFO_OUT <= (others => '0'); --info_reg or info_2reg;
        FINISHED_OUT     <= '1';
      else
        FINISHED_OUT <= '0';
      end if;
    end if;
  end process Binary_Code_Calculation;

  StartSignalPipeLine : process (CLK)
  begin
    if rising_edge(CLK) then
      start_pipeline <= start_pipeline(5 downto 0) & START_IN;
    end if;
  end process StartSignalPipeLine;
  conv_finished_i <= start_pipeline(6);

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------

  --Binary_Code_Calculation : process (CLK, RESET)
  --begin
  -- if rising_edge(CLK) then
  --   if RESET = '1' then
  --     BINARY_CODE_OUT <= (others => '0');
  --     FINISHED_OUT    <= '0';
  --   elsif proc_finished_1 = '1' then
  --     BINARY_CODE_OUT <= address_i; --'0' & interval_reg;
  --     FINISHED_OUT    <= '1';
  --   else
  --     BINARY_CODE_OUT <= (others => '0');
  --     FINISHED_OUT    <= '0';
  --   end if;
  -- end if;
  --end process Binary_Code_Calculation;

  --ENCODER_DEBUG(8 downto 0) <= interval_reg;

end behavioral;
