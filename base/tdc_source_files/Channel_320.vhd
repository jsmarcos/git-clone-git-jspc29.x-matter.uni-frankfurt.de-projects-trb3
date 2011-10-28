library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

library synplify;
use synplify.attributes.all;

entity Channel is

  generic (
    CHANNEL_ID        :     integer range 0 to 15);
  port (
    RESET             : in  std_logic;
    CLK               : in  std_logic;
--
    HIT_IN            : in  std_logic;
    READ_EN_IN        : in  std_logic;
    FIFO_DATA_OUT     : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT    : out std_logic;
    FIFO_FULL_OUT     : out std_logic;
    COARSE_COUNTER_IN : in  std_logic_vector(15 downto 0)
--
-- Channel_DEBUG_01 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_02 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_03 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_04 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_05 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_06 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_07 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_08 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_09 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_10 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_11 : out std_logic_vector(31 downto 0);
-- Channel_DEBUG_12 : out std_logic_vector(31 downto 0)
    );

end Channel;

architecture Channel of Channel is

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

  component Adder_320
    port (
      CLK    : in  std_logic;
      RESET  : in  std_logic;
      DataA  : in  std_logic_vector(319 downto 0);
      DataB  : in  std_logic_vector(319 downto 0);
      ClkEn  : in  std_logic;
      Result : out std_logic_vector(319 downto 0));
  end component;

-- component Adder_288
-- port (
-- CLK : in std_logic;
-- RESET : in std_logic;
-- DataA : in std_logic_vector(287 downto 0);
-- DataB : in std_logic_vector(287 downto 0);
-- ClkEn : in std_logic;
-- Result : out std_logic_vector(287 downto 0));
-- end component;
--
  component Encoder_320_Bit
    port (
      RESET              : in  std_logic;
      CLK                : in  std_logic;
      START_INPUT        : in  std_logic;
      THERMO_CODE_INPUT  : in  std_logic_vector(319 downto 0);
      FINISHED_OUTPUT    : out std_logic;
      BINARY_CODE_OUTPUT : out std_logic_vector(9 downto 0));
  end component;

-- component Encoder_288_Bit
-- port (
-- RESET : in std_logic;
-- CLK : in std_logic;
-- START_INPUT : in std_logic;
-- THERMO_CODE_INPUT : in std_logic_vector(287 downto 0);
-- FINISHED_OUTPUT : out std_logic;
-- BINARY_CODE_OUTPUT : out std_logic_vector(9 downto 0));
-- end component;
--
  component FIFO_32x512_Oreg
    port (
      Data       : in  std_logic_vector(31 downto 0);
      WrClock    : in  std_logic;
      RdClock    : in  std_logic;
      WrEn       : in  std_logic;
      RdEn       : in  std_logic;
      Reset      : in  std_logic;
      RPReset    : in  std_logic;
      Q          : out std_logic_vector(31 downto 0);
      Empty      : out std_logic;
      Full       : out std_logic);
  end component;
--
  component ORCALUT4
    generic(
      INIT       :     bit_vector);
    port (
      A, B, C, D : in  std_logic;
      Z          : out std_logic);
  end component;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  signal clk_i               : std_logic;
  signal rst_i               : std_logic;
  signal data_a_i            : std_logic_vector(319 downto 0);
  signal data_b_i            : std_logic_vector(319 downto 0);
  signal result_i            : std_logic_vector(319 downto 0);
  signal result_reg          : std_logic_vector(319 downto 0);
  signal thermo_code_i       : std_logic_vector(319 downto 0);
  signal hit_in_i            : std_logic;
  signal hit_detect_i        : std_logic;
  signal result_2_reg        : std_logic;
  signal coarse_cntr_i       : std_logic_vector(15 downto 0);
  signal hit_time_stamp_i    : std_logic_vector(15 downto 0);
  signal hit_time_stamp_reg  : std_logic_vector(15 downto 0);
  signal hit_time_stamp_reg2 : std_logic_vector(15 downto 0);
  signal hit_time_stamp_reg3 : std_logic_vector(15 downto 0);
  signal fine_counter_i      : std_logic_vector(9 downto 0);
  signal encoder_start_i     : std_logic;
  signal fifo_data_out_i     : std_logic_vector(31 downto 0);
  signal fifo_data_in_i      : std_logic_vector(31 downto 0);
  signal fifo_empty_i        : std_logic;
  signal fifo_full_i         : std_logic;
  signal fifo_wr_en_i        : std_logic;
  signal fifo_rd_en_i        : std_logic;

  signal                                  hit_buf : std_logic;
  attribute syn_keep of hit_buf                   : signal  is true;
  attribute syn_keep of hit_in_i                  : signal is true;
  attribute NOMERGE                               : string;
  attribute NOMERGE of hit_buf                    : signal   is "true";

-------------------------------------------------------------------------------

begin

  clk_i         <= CLK;
  rst_i         <= RESET;
  fifo_rd_en_i  <= READ_EN_IN;
  coarse_cntr_i <= COARSE_COUNTER_IN;

--  -- purpose: Generates a pulse out of the hit signal on order to prevent second transition in the hit signal
--   Hit_Trigger : process (HIT_IN, hit_trig_reset_i, rst_i)
--   begin
--     if rst_i = '1' or hit_trig_reset_i = '1' then
--       hit_in_i <= '0';
--     elsif rising_edge(HIT_IN) then
--       hit_in_i <= '1';
--     end if;
--   end process Hit_Trigger;

  hit_in_i <= HIT_IN;
  hit_buf <= not hit_in_i;

  --purpose: Tapped Delay Line 320 (Carry Chain) with wave launcher (21)
  FC : Adder_320
    port map (
      CLK    => clk_i,
      RESET  => rst_i,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => '1',
      Result => result_i);
  data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFF";
  data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000000000" & not(hit_buf) & x"0000" & "00" & hit_buf;

--  --purpose: Tapped Delay Line 288 (Carry Chain) with wave launcher (21)
--   FC : Adder_288
--     port map (
--       CLK    => clk_i,
--       RESET  => rst_i,
--       DataA  => data_a_i,
--       DataB  => data_b_i,
--       ClkEn  => '1',
--       Result => result_i);
--   data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFF";
--   data_b_i <= x"0000000000000000000000000000000000000000000000000000000000000000000" & not(hit_buf) & x"0000" & "00" & hit_buf;

  --purpose: Tapped Delay Line 288 (Carry Chain)
--   FC : Adder_288
--     port map (
--       CLK    => clk_i,
--       RESET  => rst_i,
--       DataA  => data_a_i,
--       DataB  => data_b_i,
--       ClkEn  => '1',
--       Result => result_i);
--   data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
--   data_b_i <= x"00000000000000000000000000000000000000000000000000000000000000000000000" & "000" & hit_in_i;

  --purpose: Registers the hit detection bit
  Hit_Register : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        result_2_reg <= '0';
      else
        result_2_reg <= result_i(2);
      end if;
    end if;
  end process Hit_Register;

  --purpose: Detects the hit
  Hit_Detect : process (result_2_reg, result_i)
  begin
    hit_detect_i <= (not result_2_reg) and result_i(2);
  end process Hit_Detect;

  --purpose: Double Synchroniser
  Double_Syncroniser : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        result_reg <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
      elsif hit_detect_i = '1' then     --or hit_trig_reset_i = '1' then
        result_reg <= result_i;
      end if;
    end if;
  end process Double_Syncroniser;

-- Channel_DEBUG_01(0) <= result_reg(319);

  --purpose: Start Encoder and captures the time stamp of the hit
  Start_Encoder : process (clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        encoder_start_i    <= '0';
        hit_time_stamp_i   <= (others => '0');
        hit_time_stamp_reg <= (others => '0');
        hit_time_stamp_reg2 <= (others => '0');
        hit_time_stamp_reg3 <= (others => '0');
      elsif hit_detect_i = '1' then
        encoder_start_i    <= '1';
        hit_time_stamp_i   <= coarse_cntr_i-1;
      else
        encoder_start_i    <= '0';
        hit_time_stamp_reg <= hit_time_stamp_i;
        hit_time_stamp_reg2 <= hit_time_stamp_reg;
        hit_time_stamp_reg3 <= hit_time_stamp_reg2;
      end if;
    end if;
  end process Start_Encoder;

  --purpose: Encoder
  Encoder : Encoder_320_Bit
    port map (
      RESET              => rst_i,
      CLK                => clk_i,
      START_INPUT        => encoder_start_i,
      THERMO_CODE_INPUT  => result_reg,
      FINISHED_OUTPUT    => fifo_wr_en_i,
      BINARY_CODE_OUTPUT => fine_counter_i);

--  --purpose: Encoder
--   Encoder : Encoder_288_Bit
--     port map (
--       RESET              => rst_i,
--       CLK                => clk_i,
--       START_INPUT        => encoder_start_i,
--       THERMO_CODE_INPUT  => result_reg,
--       FINISHED_OUTPUT    => fifo_wr_en_i,
--       BINARY_CODE_OUTPUT => fine_counter_i);

  thermo_code_i <= "11" & result_reg(319 downto 2);
-- hit_trig_reset_i <= fifo_wr_en_i;

  FIFO : FIFO_32x512_Oreg
    port map (
      Data    => fifo_data_in_i,
      WrClock => clk_i,
      RdClock => clk_i,
      WrEn    => fifo_wr_en_i,
      RdEn    => fifo_rd_en_i,
      Reset   => rst_i,
      RPReset => rst_i,
      Q       => fifo_data_out_i,
      Empty   => fifo_empty_i,
      Full    => fifo_full_i);
  fifo_data_in_i(31 downto 26) <= conv_std_logic_vector(CHANNEL_ID, 6);
  fifo_data_in_i(25 downto 10) <= hit_time_stamp_reg3;  --hit_time_stamp_i;
  fifo_data_in_i(9 downto 0)   <= fine_counter_i;

  Register_Outputs : process (clk_i, rst_i)
  begin
    if rising_edge(clk_i) then
      if rst_i = '1' then
        FIFO_DATA_OUT  <= (others => '1');
        FIFO_EMPTY_OUT <= '0';
        FIFO_FULL_OUT  <= '0';
      else
        FIFO_DATA_OUT  <= fifo_data_out_i;
        FIFO_EMPTY_OUT <= fifo_empty_i;
        FIFO_FULL_OUT  <= fifo_full_i;
      end if;
    end if;
  end process Register_Outputs;



-- GEN_TDL_FIFOS : for i in 0 to FIFO_NR-1 generate
--  --purpose: TEST FIFO
--    FIFO : FIFO_DC_32_512             --FIFO_DC_34_512
--      port map (
--        Data    => data_in(i),
--        WrClock => clk_i,
--        RdClock => clk_i,
--        WrEn    => encoder_start_i,
--        RdEn    => fifo_rd_en_i,
--        Reset   => rst_i,
--        RPReset => rst_i,
--        Q       => data_out(i),
--        Empty   => open,
--        Full    => open);
--    data_in(i) <= result_reg(32*(i+1)-1 downto i*32);
--  end generate GEN_TDL_FIFOS;

--  --purpose: TEST FIFO
--  FIFO_36 : FIFO_DC_32_512            --FIFO_DC_34_512
--    port map (
--      Data    => data_in(9),
--      WrClock => clk_i,
--      RdClock => clk_i,
--      WrEn    => encoder_start_i,
--      RdEn    => fifo_rd_en_i,
--      Reset   => rst_i,
--      RPReset => rst_i,
--      Q       => data_out(9),
--      Empty   => open,
--      Full    => open);
----
--  --purpose: TEST FIFO
--  FIFO_37 : FIFO_DC_32_512            --FIFO_DC_34_512
--    port map (
--      Data    => data_in(10),
--      WrClock => clk_i,
--      RdClock => clk_i,
--      WrEn    => wr_en_i,
--      RdEn    => fifo_rd_en_i,
--      Reset   => rst_i,
--      RPReset => rst_i,
--      Q       => data_out(10),
--      Empty   => open,
--      Full    => open);
----
--  --purpose: TEST FIFO
--  FIFO_38 : FIFO_DC_32_512            --FIFO_DC_34_512
--    port map (
--      Data    => data_in(11),
--      WrClock => clk_i,
--      RdClock => clk_i,
--      WrEn    => wr_en_i,
--      RdEn    => fifo_rd_en_i,
--      Reset   => rst_i,
--      RPReset => rst_i,
--      Q       => data_out(11),
--      Empty   => open,
--      Full    => open);
--

  --data_in(9)  <= x"deadface";
  --data_in(10) <= "00" & x"00000" & fine_counter_i(9 downto 0);
  --data_in(11) <= x"facedead";

  --Channel_DEBUG_01 <= data_out(0);
  --Channel_DEBUG_02 <= data_out(1);
  --Channel_DEBUG_03 <= data_out(2);
  --Channel_DEBUG_04 <= data_out(3);
  --Channel_DEBUG_05 <= data_out(4);
  --Channel_DEBUG_06 <= data_out(5);
  --Channel_DEBUG_07 <= data_out(6);
  --Channel_DEBUG_08 <= data_out(7);
  --Channel_DEBUG_09 <= data_out(8);
  --Channel_DEBUG_10 <= data_out(9);
  --Channel_DEBUG_11 <= data_out(10);
  --Channel_DEBUG_12 <= data_out(11);


end Channel;
