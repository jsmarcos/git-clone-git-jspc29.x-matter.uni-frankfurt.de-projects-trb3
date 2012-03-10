library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

entity Channel is

  generic (
    CHANNEL_ID : integer range 0 to 64);
  port (
    RESET_WR             : in  std_logic;
    RESET_RD             : in  std_logic;
    CLK_WR               : in  std_logic;
    CLK_RD               : in  std_logic;
--
    HIT_IN               : in  std_logic;
    READ_EN_IN           : in  std_logic;
    FIFO_DATA_OUT        : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT       : out std_logic;
    FIFO_FULL_OUT        : out std_logic;
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
--
    LOST_HIT_NUMBER      : out std_logic_vector(23 downto 0);
    MEASUREMENT_NUMBER   : out std_logic_vector(23 downto 0);
    ENCODER_START_NUMBER : out std_logic_vector(23 downto 0);
--
    Channel_DEBUG_01     : out std_logic_vector(31 downto 0)
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

  component Adder_304
    port (
      CLK    : in  std_logic;
      RESET  : in  std_logic;
      DataA  : in  std_logic_vector(303 downto 0);
      DataB  : in  std_logic_vector(303 downto 0);
      ClkEn  : in  std_logic;
      Result : out std_logic_vector(303 downto 0));
  end component;
--
  component Encoder_304_Bit
    port (
      RESET           : in  std_logic;
      CLK             : in  std_logic;
      START_IN        : in  std_logic;
      THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
      FINISHED_OUT    : out std_logic;
      BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
      BUSY_OUT        : out std_logic;
      ENCODER_DEBUG   : out std_logic_vector(31 downto 0));
  end component;
--
  --component Encoder_304_ROMsuz
  --  port (
  --    RESET           : in  std_logic;
  --    CLK             : in  std_logic;
  --    START_IN        : in  std_logic;
  --    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
  --    FINISHED_OUT    : out std_logic;
  --    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
  --    ENCODER_DEBUG   : out std_logic_vector(31 downto 0));
  --end component;
--
  --component Encoder_304_Sngl_ROMsuz
  --  port (
  --    RESET           : in  std_logic;
  --    CLK             : in  std_logic;
  --    START_IN        : in  std_logic;
  --    THERMOCODE_IN   : in  std_logic_vector(303 downto 0);
  --    FINISHED_OUT    : out std_logic;
  --    BINARY_CODE_OUT : out std_logic_vector(9 downto 0);
  --    ENCODER_DEBUG   : out std_logic_vector(31 downto 0));
  --end component;
--
  component FIFO_32x512_OutReg
    port (
      Data    : in  std_logic_vector(31 downto 0);
      WrClock : in  std_logic;
      RdClock : in  std_logic;
      WrEn    : in  std_logic;
      RdEn    : in  std_logic;
      Reset   : in  std_logic;
      RPReset : in  std_logic;
      Q       : out std_logic_vector(31 downto 0);
      Empty   : out std_logic;
      Full    : out std_logic);
  end component;
--
  component edge_to_pulse
    port (
      clock     : in  std_logic;
      en_clk    : in  std_logic;
      signal_in : in  std_logic;
      pulse     : out std_logic);
  end component;
--
  component signal_sync
    generic (
      WIDTH : integer;
      DEPTH : integer);
    port (
      RESET : in  std_logic;
      CLK0  : in  std_logic;
      CLK1  : in  std_logic;
      D_IN  : in  std_logic_vector(WIDTH-1 downto 0);
      D_OUT : out std_logic_vector(WIDTH-1 downto 0));
  end component;
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  signal data_a_i            : std_logic_vector(303 downto 0);
  signal data_b_i            : std_logic_vector(303 downto 0);
  signal result_i            : std_logic_vector(303 downto 0);
  signal result_reg          : std_logic_vector(303 downto 0);
  signal hit_in_i            : std_logic;
  signal hit_detect_i        : std_logic;
  signal result_2_reg        : std_logic;
  signal coarse_cntr_i       : std_logic_vector(10 downto 0);
  signal hit_time_stamp_i    : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg  : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg2 : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg3 : std_logic_vector(10 downto 0);
  signal fine_counter_i      : std_logic_vector(9 downto 0);
  signal encoder_start_i     : std_logic;
  signal encoder_busy_i      : std_logic;
  signal fifo_data_out_i     : std_logic_vector(31 downto 0);
  signal fifo_data_in_i      : std_logic_vector(31 downto 0);
  signal fifo_empty_i        : std_logic;
  signal fifo_full_i         : std_logic;
  signal fifo_wr_en_i        : std_logic;
  signal fifo_rd_en_i        : std_logic;
  signal sync_q              : std_logic_vector(3 downto 0);
  signal hit_pulse           : std_logic;
  signal lost_hit_cntr       : std_logic_vector(23 downto 0);
  signal lost_hit_number_reg : std_logic_vector(23 downto 0);
  signal hit_buf             : std_logic;
  signal ff_array_en_i       : std_logic := '1';

-------------------------------------------------------------------------------
-- Debug Signals
-------------------------------------------------------------------------------
  signal measurement_cntr       : std_logic_vector(23 downto 0);
  signal measurement_reg        : std_logic_vector(23 downto 0);
  signal encoder_start_cntr     : std_logic_vector(23 downto 0);
  signal encoder_start_cntr_reg : std_logic_vector(23 downto 0);
  signal encoder_debug_i        : std_logic_vector(31 downto 0);
-------------------------------------------------------------------------------

  attribute syn_keep                  : boolean;
  attribute syn_keep of hit_buf       : signal is true;
  attribute syn_keep of hit_in_i      : signal is true;
  attribute syn_keep of ff_array_en_i : signal is true;
  attribute NOMERGE                   : string;
  attribute NOMERGE of hit_buf        : signal is "true";
  attribute NOMERGE of ff_array_en_i  : signal is "true";
  
-------------------------------------------------------------------------------

begin

  fifo_rd_en_i  <= READ_EN_IN;
  coarse_cntr_i <= COARSE_COUNTER_IN;
  hit_in_i      <= HIT_IN;
  hit_buf       <= not hit_in_i;

  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) double transition
  FC : Adder_304
    port map (
      CLK    => CLK_WR,
      RESET  => RESET_WR,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => '1', -- ff_array_en_i, -- '1',
      Result => result_i);
  data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" & x"7FFFFFF";
  data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000" & not(hit_buf) & x"000000" & "00" & hit_buf;

  --FF_Array_Enable : process (hit_detect_i, encoder_busy_i)
  --begin
  --  if hit_detect_i = '1' then
  --    ff_array_en_i <= '0';
  --  elsif encoder_busy_i = '1' then
  --    ff_array_en_i <= '1';
  --  end if;
  --end process FF_Array_Enable;
  
  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) single transition
  --FC : Adder_304
  --  port map (
  --    CLK    => CLK_WR,
  --    RESET  => RESET_WR,
  --    DataA  => data_a_i,
  --    DataB  => data_b_i,
  --    ClkEn  => '1',
  --    Result => result_i);
  --data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
  --data_b_i <= x"000000000000000000000000000000000000000000000000000000000000000000000000000" & "000" & hit_in_i;

  --purpose: Tapped Delay Line 288 (Carry Chain) single transition
--   FC : Adder_288
--     port map (
--       CLK    => CLK_WR,
--       RESET  => RESET_WR,
--       DataA  => data_a_i,
--       DataB  => data_b_i,
--       ClkEn  => '1',
--       Result => result_i);
--   data_a_i <= x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF";
--   data_b_i <= x"00000000000000000000000000000000000000000000000000000000000000000000000" & "000" & hit_in_i;

  --purpose: Registers the hit detection bit
  Hit_Register : process (CLK_WR, RESET_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        result_2_reg <= '0';
      else
        result_2_reg <= result_i(2);
      end if;
    end if;
  end process Hit_Register;

  --purpose: Detects the hit
  Hit_Detect : process (result_2_reg, result_i)
  begin
    hit_detect_i <= (not result_2_reg) and result_i(2);  -- result_2_reg and (not result_i(2));
  end process Hit_Detect;

  --purpose: Double Synchroniser
  Double_Syncroniser : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        result_reg <= (others => '1');
      elsif hit_detect_i = '1' then
        result_reg <= result_i;
      end if;
    end if;
  end process Double_Syncroniser;

  --purpose: Start Encoder and captures the time stamp of the hit
  Start_Encoder : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        encoder_start_i     <= '0';
        hit_time_stamp_i    <= (others => '0');
        hit_time_stamp_reg  <= (others => '0');
        hit_time_stamp_reg2 <= (others => '0');
        hit_time_stamp_reg3 <= (others => '0');
      elsif hit_detect_i = '1' then
        encoder_start_i    <= '1';
        hit_time_stamp_i   <= coarse_cntr_i-1;
      else
        encoder_start_i     <= '0';
        hit_time_stamp_reg  <= hit_time_stamp_i;
        hit_time_stamp_reg2 <= hit_time_stamp_reg;
        hit_time_stamp_reg3 <= hit_time_stamp_reg2;
      end if;
    end if;
  end process Start_Encoder;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_WR,
      CLK             => CLK_WR,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_reg,
      FINISHED_OUT    => fifo_wr_en_i,
      BINARY_CODE_OUT => fine_counter_i,
      BUSY_OUT        => encoder_busy_i,
      ENCODER_DEBUG   => encoder_debug_i);

  ----purpose: Encoder
  --Encoder : Encoder_304_ROMsuz
  --  port map (
  --    RESET           => RESET_WR,
  --    CLK             => CLK_WR,
  --    START_IN        => encoder_start_i,
  --    THERMOCODE_IN   => result_reg,
  --    FINISHED_OUT    => fifo_wr_en_i,
  --    BINARY_CODE_OUT => fine_counter_i,
  --    ENCODER_DEBUG   => encoder_debug_i);

  --purpose: Encoder
  --Encoder : Encoder_304_Sngl_ROMsuz
  --  port map (
  --    RESET           => RESET_WR,
  --    CLK             => CLK_WR,
  --    START_IN        => encoder_start_i,
  --    THERMOCODE_IN   => result_reg,
  --    FINISHED_OUT    => fifo_wr_en_i,
  --    BINARY_CODE_OUT => fine_counter_i,
  --    ENCODER_DEBUG   => encoder_debug_i);

  FIFO : FIFO_32x512_OutReg
    port map (
      Data    => fifo_data_in_i,
      WrClock => CLK_WR,
      RdClock => CLK_RD,
      WrEn    => fifo_wr_en_i,
      RdEn    => fifo_rd_en_i,
      Reset   => RESET_RD,
      RPReset => RESET_RD,
      Q       => fifo_data_out_i,
      Empty   => fifo_empty_i,
      Full    => fifo_full_i);
  fifo_data_in_i(31)           <= '1';  -- data marker
  fifo_data_in_i(30 downto 28) <= "000";           -- reserved bits
  fifo_data_in_i(27 downto 22) <= conv_std_logic_vector(CHANNEL_ID, 6);  -- channel number
  fifo_data_in_i(21 downto 12) <= fine_counter_i;  -- fine time from the encoder
  fifo_data_in_i(11)           <= '1';  -- rising '1' or falling '0' edge
  fifo_data_in_i(10 downto 0)  <= hit_time_stamp_reg3;  -- hit time stamp

  Register_Outputs : process (CLK_RD, RESET_RD)
  begin
    if rising_edge(CLK_RD) then
      if RESET_RD = '1' then
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

-------------------------------------------------------------------------------
-- Lost Hit Detection
-------------------------------------------------------------------------------
  --purpose: Hit Signal Synchroniser
  GEN_flipflops : for i in 1 to 3 generate
    Hit_Sync : process (CLK_WR)
    begin
      if rising_edge(CLK_WR) then
        if RESET_WR = '1' then
          sync_q(i) <= '0';
        else
          sync_q(i) <= sync_q(i-1);
        end if;
      end if;
    end process Hit_Sync;
  end generate GEN_flipflops;
  sync_q(0) <= HIT_IN;

  --purpose: Creates a pulse out of the synchronised hit signal
  Edge_To_Pulse_Hit : edge_to_pulse
    port map (
      clock     => CLK_WR,
      en_clk    => '1',
      signal_in => sync_q(3),
      pulse     => hit_pulse);

  --purpose: Counts the detected but unwritten hits
  Lost_Hit_Counter : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        lost_hit_cntr <= (others => '0');
      elsif hit_pulse = '1' then
        lost_hit_cntr <= lost_hit_cntr + 1;
      elsif fifo_wr_en_i = '1' then
        lost_hit_cntr <= lost_hit_cntr - 1;
      end if;
    end if;
  end process Lost_Hit_Counter;

  --purpose: Synchronises the lost hit counter to the slowcontrol clock
  Lost_Hit_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_RD,
      CLK0  => CLK_WR,
      CLK1  => CLK_RD,
      D_IN  => lost_hit_cntr,
      D_OUT => lost_hit_number_reg);

  LOST_HIT_NUMBER <= lost_hit_number_reg;


-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  --purpose: Counts the written hits
  Encoder_Start_Counter : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        encoder_start_cntr <= (others => '0');
      elsif encoder_start_i = '1' then
        encoder_start_cntr <= encoder_start_cntr + 1;
      end if;
    end if;
  end process Encoder_Start_Counter;

  --purpose: Synchronises the measurement counter to the slowcontrol clock
  Encoder_Start_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_RD,
      CLK0  => CLK_WR,
      CLK1  => CLK_RD,
      D_IN  => encoder_start_cntr,
      D_OUT => encoder_start_cntr_reg);

  ENCODER_START_NUMBER <= encoder_start_cntr_reg;

  --purpose: Counts the written hits
  Measurement_Counter : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        measurement_cntr <= (others => '0');
      elsif fifo_wr_en_i = '1' then
        measurement_cntr <= measurement_cntr + 1;
      end if;
    end if;
  end process Measurement_Counter;

  --purpose: Synchronises the measurement counter to the slowcontrol clock
  Measurement_Sync : signal_sync
    generic map (
      WIDTH => 24,
      DEPTH => 3)
    port map (
      RESET => RESET_RD,
      CLK0  => CLK_WR,
      CLK1  => CLK_RD,
      D_IN  => measurement_cntr,
      D_OUT => measurement_reg);

  MEASUREMENT_NUMBER <= measurement_reg;

  Channel_DEBUG_01(0)           <= hit_pulse;
  Channel_DEBUG_01(1)           <= encoder_start_i;
  Channel_DEBUG_01(2)           <= fifo_wr_en_i;
  Channel_DEBUG_01(11 downto 3) <= encoder_debug_i(8 downto 0);
-------------------------------------------------------------------------------

end Channel;
