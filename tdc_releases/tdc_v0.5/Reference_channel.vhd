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

entity Reference_Channel is

  generic (
    CHANNEL_ID : integer range 0 to 0);
  port (
    RESET_200              : in  std_logic;
    RESET_100              : in  std_logic;
    CLK_200                : in  std_logic;
    CLK_100                : in  std_logic;
--
    HIT_IN                 : in  std_logic;
    READ_EN_IN             : in  std_logic;
    VALID_TMG_TRG_IN       : in  std_logic;
    SPIKE_DETECTED_IN      : in  std_logic;
    MULTI_TMG_TRG_IN       : in  std_logic;
    FIFO_DATA_OUT          : out std_logic_vector(31 downto 0);
    FIFO_EMPTY_OUT         : out std_logic;
    FIFO_FULL_OUT          : out std_logic;
    FIFO_ALMOST_FULL_OUT   : out std_logic;
    COARSE_COUNTER_IN      : in  std_logic_vector(10 downto 0);
    TRIGGER_TIME_STAMP_OUT : out std_logic_vector(10 downto 0);  -- coarse time of the timing trigger
    REF_DEBUG_OUT          : out std_logic_vector(31 downto 0)
    );

end Reference_Channel;

architecture Reference_Channel of Reference_Channel is
-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------

  signal data_a_i           : std_logic_vector(303 downto 0);
  signal data_b_i           : std_logic_vector(303 downto 0);
  signal result_i           : std_logic_vector(303 downto 0);
  signal result_reg         : std_logic_vector(303 downto 0);
  signal hit_in_i           : std_logic;
  signal hit_buf            : std_logic;
  signal hit_detect_i       : std_logic;
  signal hit_detect_reg     : std_logic;
  signal hit_detect_2reg    : std_logic;
  signal result_2_reg       : std_logic;
  signal hit_time_stamp_i   : std_logic_vector(10 downto 0);
  signal hit_time_stamp_reg : std_logic_vector(10 downto 0);
  signal fine_counter_i     : std_logic_vector(9 downto 0);
  signal fine_counter_reg   : std_logic_vector(9 downto 0);
  signal encoder_start_i    : std_logic;
  signal encoder_finished_i : std_logic;
  signal encoder_debug_i    : std_logic_vector(31 downto 0);
  signal fifo_data_out_i    : std_logic_vector(31 downto 0);
  signal fifo_data_in_i     : std_logic_vector(31 downto 0);
  signal fifo_empty_i       : std_logic;
  signal fifo_full_i        : std_logic;
  signal fifo_almost_full_i : std_logic;
  signal fifo_wr_en_i       : std_logic;
  signal valid_tmg_trg_i    : std_logic;
  signal multi_tmg_trg_i    : std_logic;
  signal spike_detected_i   : std_logic;
  signal ff_array_en_i      : std_logic;

  type   FSM is (IDLE, LOOK_FOR_VALIDITY, ENCODER_FINISHED, WAIT_FOR_FALLING_EDGE);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal fifo_wr_en_fsm        : std_logic;
  signal fsm_debug_i           : std_logic_vector(3 downto 0);
  signal fsm_debug_fsm         : std_logic_vector(3 downto 0);

  attribute syn_keep                  : boolean;
  attribute syn_keep of hit_buf       : signal is true;
  attribute syn_keep of ff_array_en_i : signal is true;
  attribute NOMERGE                   : string;
  attribute NOMERGE of hit_buf        : signal is "true";
-------------------------------------------------------------------------------

begin

  hit_in_i <= HIT_IN;
  hit_buf  <= not hit_in_i;

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
  data_b_i      <= x"000000000000000000000000000000000000000000000000000000000000000000000" & not(hit_buf) & x"000000" & "00" & hit_buf;
  ff_array_en_i <= not(hit_detect_i or hit_detect_reg or hit_detect_2reg);

  --purpose: Registers the 2nd bit of the carry chain
  Hit_Detect_Register : process (CLK_200, RESET_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        result_2_reg    <= '0';
        hit_detect_reg  <= '0';
        hit_detect_2reg <= '0';
      else
        result_2_reg    <= result_i(2);
        hit_detect_reg  <= hit_detect_i;
        hit_detect_2reg <= hit_detect_reg;
      end if;
    end if;
  end process Hit_Detect_Register;

  --purpose: Detects the hit
  Hit_Detect : process (result_2_reg, result_i)
  begin
    hit_detect_i <= ((not result_2_reg) and result_i(2));
  end process Hit_Detect;

  --purpose: Start Encoder and captures the time stamp of the hit
  Start_Encoder : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        hit_time_stamp_i <= (others => '0');
      elsif hit_detect_reg = '1' then
        hit_time_stamp_i <= COARSE_COUNTER_IN;
      end if;
    end if;
  end process Start_Encoder;
  encoder_start_i        <= hit_detect_reg;
  hit_time_stamp_reg     <= hit_time_stamp_i when rising_edge(CLK_200);
  TRIGGER_TIME_STAMP_OUT <= hit_time_stamp_reg;  -- coarse time of the timing trigger

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET           => RESET_200,
      CLK             => CLK_200,
      START_IN        => encoder_start_i,
      THERMOCODE_IN   => result_i,
      FINISHED_OUT    => encoder_finished_i,
      BINARY_CODE_OUT => fine_counter_i,
      ENCODER_DEBUG   => encoder_debug_i);

  Register_Binary_Code : process (CLK_200, RESET_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
        fine_counter_reg <= (others => '0');
      elsif encoder_finished_i = '1' then
        fine_counter_reg <= fine_counter_i;
      end if;
    end if;
  end process Register_Binary_Code;

  FIFO : FIFO_32x32_OutReg
    port map (
      Data       => fifo_data_in_i,
      WrClock    => CLK_200,
      RdClock    => CLK_100,
      WrEn       => fifo_wr_en_i,
      RdEn       => READ_EN_IN,
      Reset      => RESET_100,
      RPReset    => RESET_100,
      Q          => fifo_data_out_i,
      Empty      => fifo_empty_i,
      Full       => fifo_full_i,
      AlmostFull => fifo_almost_full_i);
  fifo_data_in_i(31)           <= '1';  -- data marker
  fifo_data_in_i(30 downto 29) <= "00";              -- reserved bits
  fifo_data_in_i(28 downto 22) <= conv_std_logic_vector(CHANNEL_ID, 7);  -- channel number
  fifo_data_in_i(21 downto 12) <= fine_counter_reg;  -- fine time from the encoder
  fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1'  or falling '0' edge
  fifo_data_in_i(10 downto 0)  <= hit_time_stamp_reg;  -- hit time stamp

  Register_Outputs : process (CLK_100, RESET_100)
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
  end process Register_Outputs;

  --purpose: FSM for controlling the validity of the timing signal
  FSM_CLK : process (CLK_200, RESET_200)
  begin
    if rising_edge(CLK_200) then
      if RESET_200 = '1' then
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
          FSM_NEXT <= ENCODER_FINISHED;
        else
          FSM_NEXT <= IDLE;
        end if;
        fsm_debug_fsm <= x"1";

      when ENCODER_FINISHED =>
        if encoder_finished_i = '1' then
          FSM_NEXT <= LOOK_FOR_VALIDITY;
        elsif valid_tmg_trg_i = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= ENCODER_FINISHED;
        end if;
        fsm_debug_fsm <= x"2";
        
      when LOOK_FOR_VALIDITY =>
        if valid_tmg_trg_i = '1' then
          FSM_NEXT       <= IDLE;
          fifo_wr_en_fsm <= '1';
        elsif multi_tmg_trg_i = '1' then
          FSM_NEXT <= IDLE;
        elsif spike_detected_i = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= LOOK_FOR_VALIDITY;
        end if;
        fsm_debug_fsm <= x"3";

      when WAIT_FOR_FALLING_EDGE =>
        if encoder_finished_i = '1' then
          FSM_NEXT       <= IDLE;
          fifo_wr_en_fsm <= '1';
          fsm_debug_fsm  <= x"C";
        else
          FSM_NEXT       <= WAIT_FOR_FALLING_EDGE;
          fifo_wr_en_fsm <= '0';
          fsm_debug_fsm  <= x"D";
        end if;
        
      when others =>
        FSM_NEXT <= IDLE;
    end case;
  end process FSM_PROC;

  bit_sync_1 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => VALID_TMG_TRG_IN,
      D_OUT => valid_tmg_trg_i);
  bit_sync_2 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => SPIKE_DETECTED_IN,
      D_OUT => spike_detected_i);
  bit_sync_3 : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => RESET_200,
      CLK0  => CLK_100,
      CLK1  => CLK_200,
      D_IN  => MULTI_TMG_TRG_IN,
      D_OUT => multi_tmg_trg_i);

-------------------------------------------------------------------------------
-- Debug signals
-------------------------------------------------------------------------------
  --REF_DEBUG_OUT(3 downto 0) <= fsm_debug_i;
  --REF_DEBUG_OUT(4)          <= HIT_IN;
  --REF_DEBUG_OUT(5)          <= result_i(2);
  --REF_DEBUG_OUT(6)          <= result_2_reg;
  --REF_DEBUG_OUT(7)          <= '0';     --hit_detect_i;
  --REF_DEBUG_OUT(8)          <= '0';     --hit_detect_reg;
  --REF_DEBUG_OUT(9)          <= '0';
  --REF_DEBUG_OUT(10)         <= '0';
  --REF_DEBUG_OUT(11)         <= ff_array_en_i;
  --REF_DEBUG_OUT(12)         <= encoder_start_i;
  --REF_DEBUG_OUT(13)         <= encoder_finished_i;
  --REF_DEBUG_OUT(14)         <= fifo_wr_en_i;

  --REF_DEBUG_OUT(15) <= CLK_200;

  REF_DEBUG_OUT(31 downto 0) <= (others => '0');
end Reference_Channel;
