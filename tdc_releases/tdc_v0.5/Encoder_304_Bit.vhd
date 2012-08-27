-------------------------------------------------------------------------------
-- Title      : Encoder 304 bits
-------------------------------------------------------------------------------
-- File       : Encoder_304_Bit.vhd
-- Author     : Cahit Ugur
-- Created    : 2011-11-28
-- Last update: 2012-08-22
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
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity Encoder_304_Bit is
  port (
    RESET           : in  std_logic;    -- system reset
    CLK             : in  std_logic;    -- system clock
    START_IN        : in  std_logic;
    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
    FINISHED_OUT    : out std_logic;
    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
    ENCODER_DEBUG   : out std_logic_vector(31 downto 0)
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
  signal P_lut                 : std_logic_vector(37 downto 0);
  signal P_one                 : std_logic_vector(37 downto 0);
  signal mux_control           : std_logic_vector(5 downto 0);
  signal mux_control_reg       : std_logic_vector(5 downto 0);
  signal mux_control_2reg      : std_logic_vector(5 downto 0);
  signal mux_control_3reg      : std_logic_vector(5 downto 0);
  signal mux_control_4reg      : std_logic_vector(5 downto 0);
  signal interval_reg          : std_logic_vector(8 downto 0);
  signal interval_binary       : std_logic_vector(2 downto 0);
  signal binary_code_f         : std_logic_vector(8 downto 0);
  signal binary_code_r         : std_logic_vector(8 downto 0);
  signal start_reg             : std_logic;
  signal start_2reg            : std_logic;
  signal start_3reg            : std_logic;
  signal rom_done_i            : std_logic;  -- indicates that the encoding of rising edge is done
  signal rom_done_reg          : std_logic;  -- indicates that the encoding of rising edge is done
  signal interval_detected_i   : std_logic;
  signal address_i             : std_logic_vector(9 downto 0);
  signal q_reg                 : std_logic_vector(7 downto 0);
  signal q_2reg                : std_logic_vector(7 downto 0);
-- FSM signals
  type   FSM is (IDLE, START_CNT_2, START_CNT_3, START_CNT_4);
  signal FSM_CURRENT, FSM_NEXT : FSM;

  signal start_cnt_1_fsm : std_logic;
  signal start_cnt_2_fsm : std_logic;
  signal start_cnt_3_fsm : std_logic;
  signal start_cnt_4_fsm : std_logic;
  signal start_cnt_1_i   : std_logic;
  signal start_cnt_2_i   : std_logic;
  signal start_cnt_3_i   : std_logic;
  signal start_cnt_4_i   : std_logic;
--
  signal proc_cnt_1      : std_logic_vector(3 downto 0);
  signal proc_cnt_2      : std_logic_vector(3 downto 0);
  signal proc_cnt_3      : std_logic_vector(3 downto 0);
  signal proc_cnt_4      : std_logic_vector(3 downto 0);
  signal proc_finished_1 : std_logic;
  signal proc_finished_2 : std_logic;
  signal proc_finished_3 : std_logic;
  signal proc_finished_4 : std_logic;
  signal conv_finished_i : std_logic;

  attribute syn_keep                     : boolean;
  attribute syn_keep of mux_control      : signal is true;
  attribute syn_keep of mux_control_reg  : signal is true;
  attribute syn_keep of mux_control_2reg : signal is true;
  attribute syn_keep of mux_control_3reg : signal is true;
  attribute syn_keep of mux_control_4reg : signal is true;
-------------------------------------------------------------------------------
begin

  --purpose : Register signals
  Register_Signals : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        start_reg           <= '0';
        start_2reg          <= '0';
        start_3reg          <= '0';
        mux_control_reg     <= (others => '0');
        mux_control_2reg    <= (others => '0');
        mux_control_3reg    <= (others => '0');
        mux_control_4reg    <= (others => '0');
        q_2reg              <= (others => '0');
        rom_done_reg        <= '0';
        interval_detected_i <= '0';
      else
        start_reg           <= START_IN;
        start_2reg          <= start_reg;
        start_3reg          <= start_2reg;
        mux_control_reg     <= mux_control;
        mux_control_2reg    <= mux_control_reg;
        mux_control_3reg    <= mux_control_2reg;
        mux_control_4reg    <= mux_control_3reg;
        q_2reg              <= q_reg;
        rom_done_reg        <= rom_done_i;
        interval_detected_i <= rom_done_i and rom_done_reg;
      end if;
    end if;
  end process Register_Signals;

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

  P_one_assign : process (CLK, START_IN, P_lut)
  begin
    if rising_edge(CLK) then
      if RESET = '1' or START_IN = '0' then
        P_one(37) <= '0';
      else
        P_one(37) <= P_lut(37);
      end if;
    end if;
  end process P_one_assign;

  Interval_Number_to_Binary : process (CLK, RESET)
  begin  -- The interval number with the 0-1 transition is converted from 1-of-N code to binary
    -- code for the control of the MUX.
    if rising_edge(CLK) then
      if RESET = '1' then
        mux_control <= (others => '0');
      elsif START_IN = '1' or start_reg = '1' then
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

  Interval_Selection : process (CLK, RESET)
  begin  -- The interval with the 0-1 transition is selected.
    if rising_edge(CLK) then
      if RESET = '1' then
        interval_reg  <= (others => '0');
      else
        case mux_control is
          when "000001" => interval_reg <= THERMOCODE_IN(7 downto 0) & '1';
          when "000010" => interval_reg <= THERMOCODE_IN(15 downto 7);
          when "000011" => interval_reg <= THERMOCODE_IN(23 downto 15);
          when "000100" => interval_reg <= THERMOCODE_IN(31 downto 23);
          when "000101" => interval_reg <= THERMOCODE_IN(39 downto 31);
          when "000110" => interval_reg <= THERMOCODE_IN(47 downto 39);
          when "000111" => interval_reg <= THERMOCODE_IN(55 downto 47);
          when "001000" => interval_reg <= THERMOCODE_IN(63 downto 55);
          when "001001" => interval_reg <= THERMOCODE_IN(71 downto 63);
          when "001010" => interval_reg <= THERMOCODE_IN(79 downto 71);
          when "001011" => interval_reg <= THERMOCODE_IN(87 downto 79);
          when "001100" => interval_reg <= THERMOCODE_IN(95 downto 87);
          when "001101" => interval_reg <= THERMOCODE_IN(103 downto 95);
          when "001110" => interval_reg <= THERMOCODE_IN(111 downto 103);
          when "001111" => interval_reg <= THERMOCODE_IN(119 downto 111);
          when "010000" => interval_reg <= THERMOCODE_IN(127 downto 119);
          when "010001" => interval_reg <= THERMOCODE_IN(135 downto 127);
          when "010010" => interval_reg <= THERMOCODE_IN(143 downto 135);
          when "010011" => interval_reg <= THERMOCODE_IN(151 downto 143);
          when "010100" => interval_reg <= THERMOCODE_IN(159 downto 151);
          when "010101" => interval_reg <= THERMOCODE_IN(167 downto 159);
          when "010110" => interval_reg <= THERMOCODE_IN(175 downto 167);
          when "010111" => interval_reg <= THERMOCODE_IN(183 downto 175);
          when "011000" => interval_reg <= THERMOCODE_IN(191 downto 183);
          when "011001" => interval_reg <= THERMOCODE_IN(199 downto 191);
          when "011010" => interval_reg <= THERMOCODE_IN(207 downto 199);
          when "011011" => interval_reg <= THERMOCODE_IN(215 downto 207);
          when "011100" => interval_reg <= THERMOCODE_IN(223 downto 215);
          when "011101" => interval_reg <= THERMOCODE_IN(231 downto 223);
          when "011110" => interval_reg <= THERMOCODE_IN(239 downto 231);
          when "011111" => interval_reg <= THERMOCODE_IN(247 downto 239);
          when "100000" => interval_reg <= THERMOCODE_IN(255 downto 247);
          when "100001" => interval_reg <= THERMOCODE_IN(263 downto 255);
          when "100010" => interval_reg <= THERMOCODE_IN(271 downto 263);
          when "100011" => interval_reg <= THERMOCODE_IN(279 downto 271);
          when "100100" => interval_reg <= THERMOCODE_IN(287 downto 279);
          when "100101" => interval_reg <= THERMOCODE_IN(295 downto 287);
          when "100110" => interval_reg <= THERMOCODE_IN(303 downto 295);
          when others   => interval_reg <= (others => '0');
        end case;
      end if;
    end if;
  end process Interval_Selection;

  ROM_Encoder_1 : ROM_Encoder
    port map (
      Address    => address_i,
      OutClock   => CLK,
      OutClockEn => '1',
      Reset      => RESET,
      Q          => q_reg);
  address_i       <= start_3reg & interval_reg;
  rom_done_i      <= q_2reg(7);
  interval_binary <= q_2reg(2 downto 0);

  Binary_Code_Calculation_rf : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        binary_code_f <= (others => '0');
        binary_code_r <= (others => '0');
      elsif rom_done_i = '1' then
        binary_code_r <= (mux_control_4reg - 1) & interval_binary;
        binary_code_f <= binary_code_r;
      end if;
    end if;
  end process Binary_Code_Calculation_rf;

  --purpose: FSMs the encoder
  FSM_CLK : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        FSM_CURRENT   <= IDLE;
        start_cnt_1_i <= '0';
        start_cnt_2_i <= '0';
        start_cnt_3_i <= '0';
        start_cnt_4_i <= '0';
      else
        FSM_CURRENT   <= FSM_NEXT;
        start_cnt_1_i <= start_cnt_1_fsm;
        start_cnt_2_i <= start_cnt_2_fsm;
        start_cnt_3_i <= start_cnt_3_fsm;
        start_cnt_4_i <= start_cnt_4_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, START_IN)
  begin

    FSM_NEXT        <= IDLE;
    start_cnt_1_fsm <= '0';
    start_cnt_2_fsm <= '0';
    start_cnt_3_fsm <= '0';
    start_cnt_4_fsm <= '0';

    case (FSM_CURRENT) is
      when IDLE =>
        if START_IN = '1' then
          FSM_NEXT        <= START_CNT_2;
          start_cnt_1_fsm <= '1';
        end if;

      when START_CNT_2 =>
        if START_IN = '1' then
          FSM_NEXT        <= START_CNT_3;
          start_cnt_2_fsm <= '1';
        else
          FSM_NEXT <= START_CNT_2;
        end if;

      when START_CNT_3 =>
        if START_IN = '1' then
          FSM_NEXT        <= START_CNT_4;
          start_cnt_3_fsm <= '1';
        else
          FSM_NEXT <= START_CNT_3;
        end if;

      when START_CNT_4 =>
        if START_IN = '1' then
          FSM_NEXT        <= IDLE;
          start_cnt_4_fsm <= '1';
        else
          FSM_NEXT <= START_CNT_4;
        end if;

      when others =>
        FSM_NEXT <= IDLE;
    end case;
  end process FSM_PROC;

  --purpose : Conversion number 1
  Conv_1 : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        proc_cnt_1      <= x"6";
        proc_finished_1 <= '0';
      elsif start_cnt_1_i = '1' then
        proc_cnt_1      <= x"1";
        proc_finished_1 <= '0';
      elsif proc_cnt_1 = x"5" then
        proc_cnt_1      <= proc_cnt_1 + 1;
        proc_finished_1 <= '1';
      elsif proc_cnt_1 = x"6" then
        proc_cnt_1      <= x"6";
        proc_finished_1 <= '0';
      else
        proc_cnt_1      <= proc_cnt_1 + 1;
        proc_finished_1 <= '0';
      end if;
    end if;
  end process Conv_1;

  --purpose : Conversion number 2
  Conv_2 : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        proc_cnt_2      <= x"6";
        proc_finished_2 <= '0';
      elsif start_cnt_2_i = '1' then
        proc_cnt_2      <= x"1";
        proc_finished_2 <= '0';
      elsif proc_cnt_2 = x"5" then
        proc_cnt_2      <= proc_cnt_2 + 1;
        proc_finished_2 <= '1';
      elsif proc_cnt_2 = x"6" then
        proc_cnt_2      <= x"6";
        proc_finished_2 <= '0';
      else
        proc_cnt_2      <= proc_cnt_2 + 1;
        proc_finished_2 <= '0';
      end if;
    end if;
  end process Conv_2;

  --purpose : Conversion number 3
  Conv_3 : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        proc_cnt_3      <= x"6";
        proc_finished_3 <= '0';
      elsif start_cnt_3_i = '1' then
        proc_cnt_3      <= x"1";
        proc_finished_3 <= '0';
      elsif proc_cnt_3 = x"5" then
        proc_cnt_3      <= proc_cnt_3 + 1;
        proc_finished_3 <= '1';
      elsif proc_cnt_3 = x"6" then
        proc_cnt_3      <= x"6";
        proc_finished_3 <= '0';
      else
        proc_cnt_3      <= proc_cnt_3 + 1;
        proc_finished_3 <= '0';
      end if;
    end if;
  end process Conv_3;

  --purpose : Conversion number 4
  Conv_4 : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        proc_cnt_4      <= x"6";
        proc_finished_4 <= '0';
      elsif start_cnt_4_i = '1' then
        proc_cnt_4      <= x"1";
        proc_finished_4 <= '0';
      elsif proc_cnt_4 = x"5" then
        proc_cnt_4      <= proc_cnt_4 + 1;
        proc_finished_4 <= '1';
      elsif proc_cnt_4 = x"6" then
        proc_cnt_4      <= x"6";
        proc_finished_4 <= '0';
      else
        proc_cnt_4      <= proc_cnt_4 + 1;
        proc_finished_4 <= '0';
      end if;
    end if;
  end process Conv_4;

  Binary_Code_Calculation : process (CLK, RESET)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        BINARY_CODE_OUT <= (others => '0');
        FINISHED_OUT    <= '0';
      elsif conv_finished_i = '1' and interval_detected_i = '1' then
        BINARY_CODE_OUT <= ('0' & binary_code_r) + ('0' & binary_code_f);
        FINISHED_OUT    <= '1';
      else
        BINARY_CODE_OUT <= (others => '0');
        FINISHED_OUT    <= '0';
      end if;
    end if;
  end process Binary_Code_Calculation;

  conv_finished_i <= proc_finished_1 or proc_finished_2 or proc_finished_3 or proc_finished_4;


-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  ----purpose : Conversion number 1
  --Conv_1 : process (CLK, RESET)
  --begin
  --  if rising_edge(CLK) then
  --    if RESET = '1' then
  --      proc_cnt_1      <= x"3";
  --      proc_finished_1 <= '0';
  --    elsif START_IN = '1' then
  --      proc_cnt_1      <= x"1";
  --      proc_finished_1 <= '0';
  --    elsif proc_cnt_1 = x"1" or proc_cnt_1 = x"2" then
  --      proc_cnt_1      <= proc_cnt_1 + 1;
  --      proc_finished_1 <= '1';
  --    elsif proc_cnt_1 = x"3" then
  --      proc_cnt_1      <= x"3";
  --      proc_finished_1 <= '0';
  --    else
  --      proc_cnt_1      <= proc_cnt_1 + 1;
  --      proc_finished_1 <= '0';
  --    end if;
  --  end if;
  --end process Conv_1;

  --Binary_Code_Calculation : process (CLK, RESET)
  --begin
  --  if rising_edge(CLK) then
  --    if RESET = '1' then
  --      BINARY_CODE_OUT <= (others => '0');
  --      FINISHED_OUT    <= '0';
  --    elsif proc_finished_1 = '1' then
  --      BINARY_CODE_OUT <= address_i; --'0' & interval_reg;
  --      FINISHED_OUT    <= '1';
  --    else
  --      BINARY_CODE_OUT <= (others => '0');
  --      FINISHED_OUT    <= '0';
  --    end if;
  --  end if;
  --end process Binary_Code_Calculation;

  --ENCODER_DEBUG(8 downto 0) <= interval_reg;

end behavioral;
