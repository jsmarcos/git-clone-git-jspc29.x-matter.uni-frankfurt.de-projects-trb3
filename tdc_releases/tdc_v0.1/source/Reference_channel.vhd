library IEEE;
use IEEE.STD_LOGIC_UNSIGNED.all;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_arith.all;

entity Reference_Channel is

  generic (
    CHANNEL_ID : integer range 0 to 15);
  port (
    RESET_WR          : in  std_logic;
    RESET_RD          : in  std_logic;
    CLK_WR            : in  std_logic;
    CLK_RD            : in  std_logic;
--
    HIT_IN            : in  std_logic;
    READ_EN_IN        : in  std_logic;
    VALID_TMG_TRG_IN  : in  std_logic;
    SPIKE_DETECTED_IN : in  std_logic;
    MULTI_TMG_TRG_IN  : in  std_logic;
    FIFO_DATA_OUT     : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT    : out std_logic;
    FIFO_FULL_OUT     : out std_logic;
    COARSE_COUNTER_IN : in  std_logic_vector(10 downto 0);
    TRIGGER_TIME_OUT  : out std_logic_vector(10 downto 0);  -- coarse time of the timing trigger
    REF_DEBUG_OUT     : out std_logic_vector(31 downto 0)
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

end Reference_Channel;

architecture Reference_Channel of Reference_Channel is

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
  component bit_sync
    generic (
      DEPTH : integer);
    port (
      RESET : in  std_logic;
      CLK0  : in  std_logic;
      CLK1  : in  std_logic;
      D_IN  : in  std_logic;
      D_OUT : out std_logic);
  end component;

-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  signal data_a_i            : std_logic_vector(303 downto 0);
  signal data_b_i            : std_logic_vector(303 downto 0);
  signal result_i            : std_logic_vector(303 downto 0);
  signal result_reg          : std_logic_vector(303 downto 0);
  signal hit_in_i            : std_logic;
  signal hit_detect_i        : std_logic;
  signal hit_detect_reg      : std_logic;
  signal result_2_reg        : std_logic;
  signal coarse_cntr_i       : std_logic_vector(10 downto 0);
  signal hit_time_stamp_i    : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg  : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg2 : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg3 : std_logic_vector(10 downto 0);
  signal fine_counter_i      : std_logic_vector(9 downto 0);
  signal fine_counter_reg    : std_logic_vector(9 downto 0);
  signal encoder_start_i     : std_logic;
  signal encoder_busy_i      : std_logic;
  signal encoder_finished_i  : std_logic;
  signal encoder_debug_i     : std_logic_vector(31 downto 0);
  signal fifo_data_out_i     : std_logic_vector(31 downto 0);
  signal fifo_data_in_i      : std_logic_vector(31 downto 0);
  signal fifo_empty_i        : std_logic;
  signal fifo_full_i         : std_logic;
  signal fifo_wr_en_i        : std_logic;
  signal fifo_rd_en_i        : std_logic;
  signal valid_tmg_trg_i     : std_logic;
  signal multi_tmg_trg_i     : std_logic;
  signal spike_detected_i    : std_logic;
  signal ff_array_en_i       : std_logic := '1';

  type   FSM is (IDLE, LOOK_FOR_VALIDITY, ENCODER_FINISHED, VALID_TMG_TRG_ARRIVED);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal fifo_wr_en_fsm        : std_logic;
  signal fsm_debug_i           : std_logic_vector(3 downto 0);
  signal fsm_debug_fsm         : std_logic_vector(3 downto 0);

  signal hit_buf                 : std_logic;
  attribute syn_keep             : boolean;
  attribute syn_keep of hit_buf  : signal is true;
  attribute syn_keep of hit_in_i : signal is true;
  attribute NOMERGE              : string;
  attribute NOMERGE of hit_buf   : signal is "true";

-------------------------------------------------------------------------------

begin

  fifo_rd_en_i  <= READ_EN_IN;
  coarse_cntr_i <= COARSE_COUNTER_IN;

--  -- purpose: Generates a pulse out of the hit signal on order to prevent second transition in the hit signal
--   Hit_Trigger : process (HIT_IN, hit_trig_reset_i, RESET_WR)
--   begin
--     if RESET_WR = '1' or hit_trig_reset_i = '1' then
--       hit_in_i <= '0';
--     elsif rising_edge(HIT_IN) then
--       hit_in_i <= '1';
--     end if;
--   end process Hit_Trigger;

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

  --purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21)
  FC : Adder_304
    port map (
      CLK    => CLK_WR,
      RESET  => RESET_WR,
      DataA  => data_a_i,
      DataB  => data_b_i,
      ClkEn  => '1', -- ff_array_en_i, --'1',
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

  ----purpose: Tapped Delay Line 304 (Carry Chain) with wave launcher (21) single transition
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

  --purpose: Tapped Delay Line 288 (Carry Chain)
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

  --purpose: Registers the 2nd bit of the carry chain & hit detection bit
  Hit_Register : process (CLK_WR, RESET_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        result_2_reg   <= '0';
        hit_detect_reg <= '0';
      else
        result_2_reg   <= result_i(2);
        hit_detect_reg <= hit_detect_i;
      end if;
    end if;
  end process Hit_Register;

  --purpose: Detects the hit
  Hit_Detect : process (result_2_reg, result_i)
  begin
    hit_detect_i <= (not result_2_reg) and result_i(2);  --result_2_reg and (not result_i(2));
  end process Hit_Detect;

  --purpose: Double Synchroniser
  Double_Syncroniser : process (CLK_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        result_reg <= (others => '1');
      elsif hit_detect_i = '1' then     --or hit_trig_reset_i = '1' then
        result_reg <= result_i;
      end if;
    end if;
  end process Double_Syncroniser;

-- Channel_DEBUG_01(0) <= result_reg(303);

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
        encoder_start_i  <= '1';
        hit_time_stamp_i <= coarse_cntr_i-1;
      else
        encoder_start_i     <= '0';
        hit_time_stamp_reg  <= hit_time_stamp_i;
        hit_time_stamp_reg2 <= hit_time_stamp_reg;
        hit_time_stamp_reg3 <= hit_time_stamp_reg2;
      end if;
    end if;
  end process Start_Encoder;

  TRIGGER_TIME_OUT <= hit_time_stamp_i;  -- coarse time of the timing trigger

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_WR,
      CLK             => CLK_WR,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_reg, -- result_i, -- result_reg,
      FINISHED_OUT    => encoder_finished_i,
      BINARY_CODE_OUT => fine_counter_i,
      BUSY_OUT        => encoder_busy_i,
      ENCODER_DEBUG   => encoder_debug_i);
  
  --Encoder : Encoder_304_ROMsuz
  --  port map (
  --    RESET           => RESET_WR,
  --    CLK             => CLK_WR,
  --    START_IN        => encoder_start_i,
  --    THERMOCODE_IN   => result_reg,
  --    FINISHED_OUT    => encoder_finished_i,
  --    BINARY_CODE_OUT => fine_counter_i,
  --    ENCODER_DEBUG   => encoder_debug_i);

  --Encoder : Encoder_304_Sngl_ROMsuz
  --  port map (
  --    RESET           => RESET_WR,
  --    CLK             => CLK_WR,
  --    START_IN        => encoder_start_i,
  --    THERMOCODE_IN   => result_reg,
  --    FINISHED_OUT    => encoder_finished_i,
  --    BINARY_CODE_OUT => fine_counter_i,
  --    ENCODER_DEBUG   => encoder_debug_i);

  Register_Binary_Code : process (CLK_WR, RESET_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        fine_counter_reg <= (others => '0');
      elsif encoder_finished_i = '1' then
        fine_counter_reg <= fine_counter_i;
      end if;
    end if;
  end process Register_Binary_Code;

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
  fifo_data_in_i(30 downto 28) <= "000";             -- reserved bits
  fifo_data_in_i(27 downto 22) <= conv_std_logic_vector(CHANNEL_ID, 6);  -- channel number
  fifo_data_in_i(21 downto 12) <= fine_counter_reg;  -- fine time from the encoder
  fifo_data_in_i(11)           <= '1';  -- rising '1'  or falling '0' edge
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

  --purpose: FSM for controlling the validity of the timing signal
  FSM_CLK : process (CLK_WR, RESET_WR)
  begin
    if rising_edge(CLK_WR) then
      if RESET_WR = '1' then
        FSM_CURRENT  <= IDLE;
        fifo_wr_en_i <= '0';
        fsm_debug_i  <= (others => '0');
      else
        FSM_CURRENT  <= FSM_NEXT;
        fifo_wr_en_i <= fifo_wr_en_fsm;
        fsm_debug_i  <= fsm_debug_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, hit_detect_i, encoder_finished_i, valid_tmg_trg_i, multi_tmg_trg_i,
                      spike_detected_i)
  begin
    fifo_wr_en_fsm <= '0';
    fsm_debug_fsm  <= (others => '0');

    case (FSM_CURRENT) is
      when IDLE =>
        if hit_detect_i = '1' then
          FSM_NEXT      <= LOOK_FOR_VALIDITY;
          fsm_debug_fsm <= x"1";
        else
          FSM_NEXT      <= IDLE;
          fsm_debug_fsm <= x"2";
        end if;

      when LOOK_FOR_VALIDITY =>
        if encoder_finished_i = '1' then
          FSM_NEXT      <= ENCODER_FINISHED;
          fsm_debug_fsm <= x"3";
        elsif valid_tmg_trg_i = '1' then
          FSM_NEXT      <= VALID_TMG_TRG_ARRIVED;
          fsm_debug_fsm <= x"4";
        elsif multi_tmg_trg_i = '1' then
          FSM_NEXT      <= IDLE;
          fsm_debug_fsm <= x"5";
        elsif spike_detected_i = '1' then
          FSM_NEXT      <= IDLE;
          fsm_debug_fsm <= x"6";
        else
          FSM_NEXT      <= LOOK_FOR_VALIDITY;
          fsm_debug_fsm <= x"7";
        end if;

      when ENCODER_FINISHED =>
        if valid_tmg_trg_i = '1' then
          FSM_NEXT       <= IDLE;
          fifo_wr_en_fsm <= '1';
          fsm_debug_fsm  <= x"8";
        elsif multi_tmg_trg_i = '1' then
          FSM_NEXT      <= IDLE;
          fsm_debug_fsm <= x"9";
        elsif spike_detected_i = '1' then
          FSM_NEXT      <= IDLE;
          fsm_debug_fsm <= x"A";
        else
          FSM_NEXT      <= ENCODER_FINISHED;
          fsm_debug_fsm <= x"B";
        end if;

      when VALID_TMG_TRG_ARRIVED =>
        if encoder_finished_i = '1' then
          FSM_NEXT       <= IDLE;
          fifo_wr_en_fsm <= '1';
          fsm_debug_fsm  <= x"C";
        else
          FSM_NEXT      <= VALID_TMG_TRG_ARRIVED;
          fsm_debug_fsm <= x"D";
        end if;

      when others =>
        FSM_NEXT <= IDLE;
    end case;
  end process FSM_PROC;

  bit_sync_1 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_WR,
      CLK0  => CLK_RD,
      CLK1  => CLK_WR,
      D_IN  => VALID_TMG_TRG_IN,
      D_OUT => valid_tmg_trg_i);
  bit_sync_2 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_WR,
      CLK0  => CLK_RD,
      CLK1  => CLK_WR,
      D_IN  => SPIKE_DETECTED_IN,
      D_OUT => spike_detected_i);
  bit_sync_3 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_WR,
      CLK0  => CLK_RD,
      CLK1  => CLK_WR,
      D_IN  => MULTI_TMG_TRG_IN,
      D_OUT => multi_tmg_trg_i);

-------------------------------------------------------------------------------
-- Debug signals
-------------------------------------------------------------------------------
  REF_DEBUG_OUT(3 downto 0)  <= fsm_debug_i;
  REF_DEBUG_OUT(4)           <= hit_detect_i;
  REF_DEBUG_OUT(5)           <= encoder_start_i;
  REF_DEBUG_OUT(6)           <= encoder_finished_i;
  REF_DEBUG_OUT(7)           <= valid_tmg_trg_i;
  REF_DEBUG_OUT(8)           <= fifo_wr_en_i;
  REF_DEBUG_OUT(15 downto 9) <= fine_counter_reg(6 downto 0);

end Reference_Channel;
