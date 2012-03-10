library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;
--use ieee.std_logic_arith.all;
--use ieee.numeric_std.all;

-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

--library synplify;
--use synplify.attributes.all;


entity Encoder_304_ROMsuz is
  port (
    RESET           : in  std_logic;
    CLK             : in  std_logic;
    START_IN        : in  std_logic;
    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
    FINISHED_OUT    : out std_logic;
    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
    ENCODER_DEBUG   : out std_logic_vector(31 downto 0)
    );
end Encoder_304_ROMsuz;

architecture Encoder_304_ROMsuz of Encoder_304_ROMsuz is

  -- component definitions
  component up_counter
    generic (
      NUMBER_OF_BITS : positive);
    port (
      CLK       : in  std_logic;
      RESET     : in  std_logic;
      COUNT_OUT : out std_logic_vector(NUMBER_OF_BITS-1 downto 0);
      UP_IN     : in  std_logic);
  end component;
--
  component LUT4
    generic(
      INIT : std_logic_vector);
    port (
      A, B, C, D : in  std_ulogic;
      Z          : out std_ulogic);
  end component;

  -- signal declerations
  signal clk_i            : std_logic;
  signal rst_i            : std_logic;
  signal start_in_i       : std_logic;
  signal thermocode_i     : std_logic_vector(303 downto 0) := x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
  signal P_lut            : std_logic_vector(18 downto 0);
  signal P_one            : std_logic_vector(18 downto 0);
  signal mux_control      : std_logic_vector(4 downto 0);
  signal interval_tmp     : std_logic_vector(17 downto 0);
  signal interval_i       : std_logic_vector(17 downto 0);
  signal interval_bc      : std_logic_vector(14 downto 0);
  signal interval_bc_norm : std_logic_vector(14 downto 0);
  signal interval_bc_bbl  : std_logic_vector(14 downto 0);
  signal interval_binary  : std_logic_vector(3 downto 0);
  signal counter_reset_i  : std_logic;
  signal counter_up_i     : std_logic;
  signal counter_out_i    : std_logic_vector(2 downto 0);
  signal binary_code_f    : std_logic_vector(8 downto 0);
  signal binary_code_r    : std_logic_vector(8 downto 0);
  signal edge_type_i      : std_logic;  -- 0 => 0-1 edge, 1 => 1-0 edge

begin

  clk_i        <= CLK;
  rst_i        <= RESET;
  start_in_i   <= START_IN;
  thermocode_i <= THERMOCODE_IN;

  ENCODER_DEBUG <= (others => '0');

  --Component instantiations

  Process_Counter : up_counter
    generic map (
      NUMBER_OF_BITS => 3)
    port map (
      CLK       => clk_i,
      RESET     => counter_reset_i,
      COUNT_OUT => counter_out_i,
      UP_IN     => counter_up_i);

  Interval_Determination_First : LUT4
    generic map (INIT => X"A815")
    port map (A => '1', B => '1', C => thermocode_i(0), D => edge_type_i,
              Z => P_lut(0));
--
  Interval_Determination : for i in 1 to 18 generate
    U : LUT4
      generic map (INIT => X"A815")
      port map (A => thermocode_i(16*i-2), B => thermocode_i(16*i-1), C => thermocode_i(16*i), D => edge_type_i,
                Z => P_lut(i));
  end generate Interval_Determination;
-------------------------------------------------------------------------------

  Change_Edge_Type : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' or counter_out_i = "111" then
        edge_type_i <= '0';
      elsif counter_out_i = "001" then
        edge_type_i <= '1';
      end if;
    end if;
  end process Change_Edge_Type;

  Gen_P_one : for i in 0 to 17 generate
    P_one(i) <= P_lut(i) and (not P_lut(i+1));
  end generate Gen_P_one;

  P_one_assign : process (edge_type_i, P_lut)
  begin
    if edge_type_i = '0' then
      P_one(18) <= P_lut(18);
    else
      P_one(18) <= '0';
    end if;
  end process P_one_assign;

  Interval_Number_to_Binary : process (clk_i, rst_i)
  begin  -- The interval number with the 0-1 transition is converted from 1-of-N code to binary
    -- code for the control of the MUX.
    if rising_edge(clk_i) then
      if rst_i = '1' then
        mux_control <= (others => '0');
      else
        mux_control(0) <= P_one(0) or P_one(2) or P_one(4) or P_one(6) or P_one(8) or P_one(10) or
                          P_one(12) or P_one(14) or P_one(16) or P_one(18);
        mux_control(1) <= P_one(1) or P_one(2) or P_one(5) or P_one(6) or P_one(9) or P_one(10) or
                          P_one(13) or P_one(14) or P_one(17) or P_one(18);
        mux_control(2) <= P_one(3) or P_one(4) or P_one(5) or P_one(6) or P_one(11) or P_one(12) or
                          P_one(13) or P_one(14);
        mux_control(3) <= P_one(7) or P_one(8) or P_one(9) or P_one(10) or P_one(11) or P_one(12) or
                          P_one(13) or P_one(14);
        mux_control(4) <= P_one(15) or P_one(16) or P_one(17) or P_one(18);
      end if;
    end if;
  end process Interval_Number_to_Binary;

  Interval_Selection : process (mux_control, thermocode_i, edge_type_i)
  begin  -- The interval with the 0-1 transition is selected.
    case mux_control is
      when "00001" => interval_tmp <= thermocode_i(16 downto 0) & edge_type_i;
      when "00010" => interval_tmp <= thermocode_i(32 downto 15);
      when "00011" => interval_tmp <= thermocode_i(48 downto 31);
      when "00100" => interval_tmp <= thermocode_i(64 downto 47);
      when "00101" => interval_tmp <= thermocode_i(80 downto 63);
      when "00110" => interval_tmp <= thermocode_i(96 downto 79);
      when "00111" => interval_tmp <= thermocode_i(112 downto 95);
      when "01000" => interval_tmp <= thermocode_i(128 downto 111);
      when "01001" => interval_tmp <= thermocode_i(144 downto 127);
      when "01010" => interval_tmp <= thermocode_i(160 downto 143);
      when "01011" => interval_tmp <= thermocode_i(176 downto 159);
      when "01100" => interval_tmp <= thermocode_i(192 downto 175);
      when "01101" => interval_tmp <= thermocode_i(208 downto 191);
      when "01110" => interval_tmp <= thermocode_i(224 downto 207);
      when "01111" => interval_tmp <= thermocode_i(240 downto 223);
      when "10000" => interval_tmp <= thermocode_i(256 downto 239);
      when "10001" => interval_tmp <= thermocode_i(272 downto 255);
      when "10010" => interval_tmp <= thermocode_i(288 downto 271);
      when "10011" => interval_tmp <= (not edge_type_i) & thermocode_i(303 downto 287);
      when others  => interval_tmp <= (others => '1');
    end case;
  end process Interval_Selection;

  Assign_Interval : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        interval_i <= (others => '1');
      elsif edge_type_i = '0' then
        interval_i <= interval_tmp;
      else
        interval_i <= not interval_tmp;
      end if;
    end if;
  end process Assign_Interval;

  Bubble_Correction_Normal : process (interval_bc_norm, interval_i)
  begin  -- The bubble correction is done by detecting the "1100" code pattern
    interval_bc_norm(0)  <= interval_i(3) and interval_i(2) and not(interval_i(1)) and not(interval_i(0));
    interval_bc_norm(1)  <= interval_i(4) and interval_i(3) and not(interval_i(2)) and not(interval_i(1));
    interval_bc_norm(2)  <= interval_i(5) and interval_i(4) and not(interval_i(3)) and not(interval_i(2));
    interval_bc_norm(3)  <= interval_i(6) and interval_i(5) and not(interval_i(4)) and not(interval_i(3));
    interval_bc_norm(4)  <= interval_i(7) and interval_i(6) and not(interval_i(5)) and not(interval_i(4));
    interval_bc_norm(5)  <= interval_i(8) and interval_i(7) and not(interval_i(6)) and not(interval_i(5));
    interval_bc_norm(6)  <= interval_i(9) and interval_i(8) and not(interval_i(7)) and not(interval_i(6));
    interval_bc_norm(7)  <= interval_i(10) and interval_i(9) and not(interval_i(8)) and not(interval_i(7));
    interval_bc_norm(8)  <= interval_i(11) and interval_i(10) and not(interval_i(9)) and not(interval_i(8));
    interval_bc_norm(9)  <= interval_i(12) and interval_i(11) and not(interval_i(10)) and not(interval_i(9));
    interval_bc_norm(10) <= interval_i(13) and interval_i(12) and not(interval_i(11)) and not(interval_i(10));
    interval_bc_norm(11) <= interval_i(14) and interval_i(13) and not(interval_i(12)) and not(interval_i(11));
    interval_bc_norm(12) <= interval_i(15) and interval_i(14) and not(interval_i(13)) and not(interval_i(12));
    interval_bc_norm(13) <= interval_i(16) and interval_i(15) and not(interval_i(14)) and not(interval_i(13));
    interval_bc_norm(14) <= interval_i(17) and interval_i(16) and not(interval_i(15)) and not(interval_i(14));
  end process Bubble_Correction_Normal;

  Bubble_Correction_Bubble : process (interval_bc_bbl, interval_i)
  begin  -- The bubble correction is done by detecting the "1010" code pattern
    interval_bc_bbl(0)  <= interval_i(3) and not(interval_i(2)) and interval_i(1) and not(interval_i(0));
    interval_bc_bbl(1)  <= interval_i(4) and not(interval_i(3)) and interval_i(2) and not(interval_i(1));
    interval_bc_bbl(2)  <= interval_i(5) and not(interval_i(4)) and interval_i(3) and not(interval_i(2));
    interval_bc_bbl(3)  <= interval_i(6) and not(interval_i(5)) and interval_i(4) and not(interval_i(3));
    interval_bc_bbl(4)  <= interval_i(7) and not(interval_i(6)) and interval_i(5) and not(interval_i(4));
    interval_bc_bbl(5)  <= interval_i(8) and not(interval_i(7)) and interval_i(6) and not(interval_i(5));
    interval_bc_bbl(6)  <= interval_i(9) and not(interval_i(8)) and interval_i(7) and not(interval_i(6));
    interval_bc_bbl(7)  <= interval_i(10) and not(interval_i(9)) and interval_i(8) and not(interval_i(7));
    interval_bc_bbl(8)  <= interval_i(11) and not(interval_i(10)) and interval_i(9) and not(interval_i(8));
    interval_bc_bbl(9)  <= interval_i(12) and not(interval_i(11)) and interval_i(10) and not(interval_i(9));
    interval_bc_bbl(10) <= interval_i(13) and not(interval_i(12)) and interval_i(11) and not(interval_i(10));
    interval_bc_bbl(11) <= interval_i(14) and not(interval_i(13)) and interval_i(12) and not(interval_i(11));
    interval_bc_bbl(12) <= interval_i(15) and not(interval_i(14)) and interval_i(13) and not(interval_i(12));
    interval_bc_bbl(13) <= interval_i(16) and not(interval_i(15)) and interval_i(14) and not(interval_i(13));
    interval_bc_bbl(14) <= interval_i(17) and not(interval_i(16)) and interval_i(15) and not(interval_i(14));
  end process Bubble_Correction_Bubble;

  interval_bc <= interval_bc_bbl or interval_bc_norm;

  Interval_Decoding : process (clk_i, rst_i)
  begin  -- The decoding of the bubble corrected 1-of-N code is done by the OR gates
    if rising_edge(clk_i) then
      if rst_i = '1' then
        interval_binary <= (others => '0');
      else
        interval_binary(0) <= interval_bc(0) or interval_bc(2) or interval_bc(4) or interval_bc(6) or
                              interval_bc(8) or interval_bc(10) or interval_bc(12) or interval_bc(14);
        interval_binary(1) <= interval_bc(1) or interval_bc(2) or interval_bc(5) or interval_bc(6) or
                              interval_bc(9) or interval_bc(10) or interval_bc(13) or interval_bc(14);
        interval_binary(2) <= interval_bc(3) or interval_bc(4) or interval_bc(5) or interval_bc(6) or
                              interval_bc(11) or interval_bc(12) or interval_bc(13) or interval_bc(14);
        interval_binary(3) <= interval_bc(7) or interval_bc(8) or interval_bc(9) or interval_bc(10) or
                              interval_bc(11) or interval_bc(12) or interval_bc(13) or interval_bc(14);
      end if;
    end if;
  end process Interval_Decoding;

  Binary_Code_Calculation : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        binary_code_f   <= (others => '0');
        binary_code_r   <= (others => '0');
        BINARY_CODE_OUT <= (others => '0');
        FINISHED_OUT    <= '0';
      elsif counter_out_i = "010" then
        binary_code_f <= (mux_control-1) & interval_binary;
      elsif counter_out_i = "101" then
        binary_code_r <= (mux_control-1) & interval_binary;
      elsif counter_out_i = "110" then
        BINARY_CODE_OUT <= std_logic_vector(to_unsigned((to_integer(unsigned(binary_code_r)) + to_integer(unsigned(binary_code_f))), 10));
        FINISHED_OUT    <= '1';
      else
        BINARY_CODE_OUT <= (others => '0');
        FINISHED_OUT    <= '0';
      end if;
    end if;
  end process Binary_Code_Calculation;

  Counter_Countrol : process (clk_i, rst_i)
  begin  -- The control of the "counter_up_i" signal
    if rising_edge(clk_i) then
      if rst_i = '1' then
        counter_up_i    <= '0';
        counter_reset_i <= '1';
      elsif start_in_i = '1' then
        counter_up_i <= '1';
      elsif counter_out_i = "110" then
        counter_up_i    <= '0';
        counter_reset_i <= '1';
      else
        counter_reset_i <= '0';
      end if;
    end if;
  end process Counter_Countrol;

end Encoder_304_ROMsuz;
