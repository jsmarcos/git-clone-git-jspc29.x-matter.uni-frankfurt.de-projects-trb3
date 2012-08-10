library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

-- synopsys translate_off
-- library ecp2m;
-- use ecp2m.components.all;
-- synopsys translate_on

entity TDC is
  generic (
    CHANNEL_NUMBER : integer range 2 to 65;
    STATUS_REG_NR  : integer range 0 to 6;
    CONTROL_REG_NR : integer range 0 to 6);
  port (
    RESET                 : in  std_logic;
    CLK_TDC               : in  std_logic;
    CLK_READOUT           : in  std_logic;
    REFERENCE_TIME        : in  std_logic;
    HIT_IN                : in  std_logic_vector(CHANNEL_NUMBER-1 downto 1);
    TRG_WIN_PRE           : in  std_logic_vector(10 downto 0);
    TRG_WIN_POST          : in  std_logic_vector(10 downto 0);
--
    -- Trigger signals from handler
    TRG_DATA_VALID_IN     : in  std_logic;
    VALID_TIMING_TRG_IN   : in  std_logic;
    VALID_NOTIMING_TRG_IN : in  std_logic;
    INVALID_TRG_IN        : in  std_logic;
    TMGTRG_TIMEOUT_IN     : in  std_logic;
    SPIKE_DETECTED_IN     : in  std_logic;
    MULTI_TMG_TRG_IN      : in  std_logic;
    SPURIOUS_TRG_IN       : in  std_logic;
--
    TRG_NUMBER_IN         : in  std_logic_vector(15 downto 0);
    TRG_CODE_IN           : in  std_logic_vector(7 downto 0);
    TRG_INFORMATION_IN    : in  std_logic_vector(23 downto 0);
    TRG_TYPE_IN           : in  std_logic_vector(3 downto 0);
--
    --Response to handler
    TRG_RELEASE_OUT       : out std_logic;
    TRG_STATUSBIT_OUT     : out std_logic_vector(31 downto 0);
    DATA_OUT              : out std_logic_vector(31 downto 0);
    DATA_WRITE_OUT        : out std_logic;
    DATA_FINISHED_OUT     : out std_logic;
--
    TDC_DEBUG             : out std_logic_vector(32*2**STATUS_REG_NR-1 downto 0);
    LOGIC_ANALYSER_OUT    : out std_logic_vector(15 downto 0);
    CONTROL_REG_IN        : in  std_logic_vector(32*2**CONTROL_REG_NR-1 downto 0)
    );
end TDC;

architecture TDC of TDC is

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- Output registers
  signal trg_release_reg     : std_logic;
  signal trg_statusbit_reg   : std_logic_vector(31 downto 0);
  signal data_out_reg        : std_logic_vector(31 downto 0);
  signal data_wr_reg         : std_logic;
  signal data_finished_reg   : std_logic;
  signal fsm_debug_reg       : std_logic_vector(7 downto 0);
  signal logic_analyser_reg  : std_logic_vector(15 downto 0);
  signal logic_analyser_2reg : std_logic_vector(15 downto 0);

-- Clock - Reset Signals
  signal reset_tdc : std_logic := '1';

-- ReadOut Signals
  signal trigger_time_i             : std_logic_vector(10 downto 0);
  signal ref_time_coarse            : std_logic_vector(10 downto 0);
  signal trg_win_cnt                : std_logic_vector(15 downto 0);
  signal trg_win_cnt_up_i           : std_logic;
  signal trg_win_end_i              : std_logic;
  signal header_error_bits          : std_logic_vector(15 downto 0);
  signal trailer_error_bits         : std_logic_vector(15 downto 0);
  signal valid_timing_trg_200       : std_logic;
  signal valid_timing_trg_pulse_200 : std_logic;
-- FSM Signals
  type FSM is (IDLE, WAIT_FOR_TRG_WIND_END,
               WAIT_FOR_LVL1_TRG_A, WAIT_FOR_LVL1_TRG_B, WAIT_FOR_LVL1_TRG_C,
               SEND_STATUS, SEND_TRG_RELEASE_A, SEND_TRG_RELEASE_B,
               WAIT_FOR_FIFO_NR_A, WAIT_FOR_FIFO_NR_B, WAIT_FOR_FIFO_NR_C,
               WR_HEADER, APPLY_MASK,
               RD_CHANNEL_A, RD_CHANNEL_B, RD_CHANNEL_C);
  signal FSM_CURRENT, FSM_NEXT : FSM;
  signal fsm_debug_fsm         : std_logic_vector(7 downto 0);
  signal start_trg_win_cnt_i   : std_logic;
  signal start_trg_win_cnt_fsm : std_logic;
  signal updt_index_fsm        : std_logic;
  signal updt_index_i          : std_logic;
  signal updt_mask_fsm         : std_logic;
  signal updt_mask_i           : std_logic;
  signal rd_en_fsm             : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal rd_en_i               : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal data_finished_fsm     : std_logic;
  signal data_finished_i       : std_logic;
  signal trg_release_fsm       : std_logic;
  signal wr_header_fsm         : std_logic;
  signal wr_header_i           : std_logic;
  signal wr_ch_data_fsm        : std_logic;
  signal wr_ch_data_i          : std_logic;
  signal wr_ch_data_reg        : std_logic;
  signal wr_status_fsm         : std_logic;
  signal wr_status_i           : std_logic;
  signal wrong_readout_fsm     : std_logic;
  signal wrong_readout_i       : std_logic;
  signal wr_trailer_fsm        : std_logic;
  signal wr_trailer_i          : std_logic;

-- Other Signals
  signal fifo_full_i           : std_logic;
  signal fifo_almost_full_i    : std_logic;
  signal mask_i                : std_logic_vector(71 downto 0);
  signal fifo_nr               : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal fifo_nr_next          : integer range 0 to CHANNEL_NUMBER := CHANNEL_NUMBER;
  signal TW_pre                : std_logic_vector(10 downto 0);
  signal TW_post               : std_logic_vector(10 downto 0);
  signal channel_hit_time      : std_logic_vector(10 downto 0);
  signal trg_win_l             : std_logic;
  signal trg_win_r             : std_logic;
  type   Std_Logic_8_array is array (0 to 8) of std_logic_vector(3 downto 0);
  signal fifo_nr_hex           : Std_Logic_8_array;
  signal coarse_cnt            : std_logic_vector(10 downto 0);
  signal reset_coarse_cnt      : std_logic;
  signal channel_full_i        : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_almost_full_i : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_i       : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_reg     : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  type   channel_data_array is array (0 to CHANNEL_NUMBER) of std_logic_vector(31 downto 0);
  signal channel_data_i        : channel_data_array;
  signal channel_data_reg      : channel_data_array;
  signal hit_in_i              : std_logic_vector(CHANNEL_NUMBER-1 downto 1);

-- Slow Control Signals
  signal ch_en_i                  : std_logic_vector(63 downto 0);
  signal trigger_win_en           : std_logic;
  signal readout_trigger_mode     : std_logic := '1';  -- readout trigger
                                                       -- 1: with trigger
                                                       -- 0: triggerless
  signal readout_trigger_mode_200 : std_logic := '1';  -- trigger mode signal synchronised to the coarse counter clk
  signal logic_anal_control       : std_logic_vector(3 downto 0);
  signal debug_mode_en_i          : std_logic;

-- Statistics Signals
  type   statistics_array_12 is array (1 to CHANNEL_NUMBER-1) of std_logic_vector(11 downto 0);
  type   statistics_array_24 is array (1 to CHANNEL_NUMBER-1) of std_logic_vector(23 downto 0);
  signal trig_number                  : std_logic_vector(23 downto 0);
  signal release_number               : std_logic_vector(23 downto 0);
  signal valid_tmg_trig_number        : std_logic_vector(23 downto 0);
  signal valid_timing_trg_pulse       : std_logic;
  signal valid_NOtmg_trig_number      : std_logic_vector(23 downto 0);
  signal valid_notiming_trg_pulse     : std_logic;
  signal invalid_trig_number          : std_logic_vector(23 downto 0);
  signal invalid_trg_pulse            : std_logic;
  signal multi_tmg_trig_number        : std_logic_vector(23 downto 0);
  signal multi_tmg_trg_pulse          : std_logic;
  signal spurious_trig_number         : std_logic_vector(23 downto 0);
  signal spurious_trg_pulse           : std_logic;
  signal wrong_readout_number         : std_logic_vector(23 downto 0);
  signal spike_number                 : std_logic_vector(23 downto 0);
  signal spike_detected_pulse         : std_logic;
  signal idle_i                       : std_logic;
  signal idle_fsm                     : std_logic;
  signal idle_time                    : std_logic_vector(23 downto 0);
  signal readout_i                    : std_logic;
  signal readout_fsm                  : std_logic;
  signal readout_time                 : std_logic_vector(23 downto 0);
  signal wait_i                       : std_logic;
  signal wait_fsm                     : std_logic;
  signal wait_time                    : std_logic_vector(23 downto 0);
  signal empty_channels               : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal total_empty_channel          : std_logic_vector(23 downto 0);
  signal channel_lost_hit_number      : statistics_array_24;
  signal channel_hit_detect_number    : statistics_array_24;
  signal channel_encoder_start_number : statistics_array_24;
  signal channel_fifo_wr_number       : statistics_array_24;
  signal stop_status_i                : std_logic;

-- Test signals
  signal ref_debug_i     : std_logic_vector(31 downto 0);
  type   channel_debug_array is array (1 to CHANNEL_NUMBER-1) of std_logic_vector(31 downto 0);
  signal channel_debug_i : channel_debug_array;
-------------------------------------------------------------------------------
  
begin
-------------------------------------------------------------------------------
-- Slow control signals
-------------------------------------------------------------------------------
  logic_anal_control   <= CONTROL_REG_IN(3 downto 0) when rising_edge(CLK_READOUT);
  debug_mode_en_i      <= CONTROL_REG_IN(4);
  readout_trigger_mode <= CONTROL_REG_IN(12);

  trigger_win_en       <= CONTROL_REG_IN(1*32+31);

  ch_en_i              <= CONTROL_REG_IN(3*32+31 downto 2*32+0);
    
-------------------------------------------------------------------------------
-- The Reset Signal Genaration (Synchronous with the fine time clock)
-------------------------------------------------------------------------------
  Reset_Generator_200 : process (CLK_TDC)
  begin
    if rising_edge(CLK_TDC) then
      reset_tdc <= RESET;
    end if;
  end process Reset_Generator_200;

-------------------------------------------------------------------------------
-- COMPONENT INSTANTINIATIONS
-------------------------------------------------------------------------------
  --Reference time measurement
  The_Reference_Time : Reference_Channel
    generic map (
      CHANNEL_ID => 0)
    port map (
      RESET_WR             => reset_tdc,
      RESET_RD             => RESET,
      CLK_WR               => CLK_TDC,
      CLK_RD               => CLK_READOUT,
      HIT_IN               => REFERENCE_TIME,
      READ_EN_IN           => rd_en_i(0),
      VALID_TMG_TRG_IN     => VALID_TIMING_TRG_IN,
      SPIKE_DETECTED_IN    => SPIKE_DETECTED_IN,
      MULTI_TMG_TRG_IN     => MULTI_TMG_TRG_IN,
      FIFO_DATA_OUT        => channel_data_i(0),
      FIFO_EMPTY_OUT       => channel_empty_i(0),
      FIFO_FULL_OUT        => channel_full_i(0),
      FIFO_ALMOST_FULL_OUT => channel_almost_full_i(0),
      COARSE_COUNTER_IN    => coarse_cnt,
      TRIGGER_TIME_OUT     => trigger_time_i,
      REF_DEBUG_OUT        => ref_debug_i);

  -- Channel enable signals
  GEN_Channel_Enable : for i in 1 to CHANNEL_NUMBER-1 generate
    hit_in_i(i) <= HIT_IN(i) and ch_en_i(i-1);
  end generate GEN_Channel_Enable;

  -- Channels
  GEN_Channels : for i in 1 to CHANNEL_NUMBER - 1 generate
    Channels : Channel
      generic map (
        CHANNEL_ID => i)
      port map (
        RESET_WR             => reset_tdc,
        RESET_RD             => RESET,
        CLK_WR               => CLK_TDC,
        CLK_RD               => CLK_READOUT,
        HIT_IN               => hit_in_i(i),
        READ_EN_IN           => rd_en_i(i),
        FIFO_DATA_OUT        => channel_data_i(i),
        FIFO_EMPTY_OUT       => channel_empty_i(i),
        FIFO_FULL_OUT        => channel_full_i(i),
        FIFO_ALMOST_FULL_OUT => channel_almost_full_i(i),
        COARSE_COUNTER_IN    => coarse_cnt,
        LOST_HIT_NUMBER      => channel_lost_hit_number(i),
        HIT_DETECT_NUMBER    => channel_hit_detect_number(i),
        ENCODER_START_NUMBER => channel_encoder_start_number(i),
        FIFO_WR_NUMBER       => channel_fifo_wr_number(i),
        Channel_DEBUG        => channel_debug_i(i));
  end generate GEN_Channels;
  channel_data_i(CHANNEL_NUMBER) <= x"FFFFFFFF";

  -- Common Coarse counter
  The_Coarse_Counter : up_counter
    generic map (
      NUMBER_OF_BITS => 11)
    port map (
      CLK       => CLK_TDC,
      RESET     => reset_coarse_cnt,
      COUNT_OUT => coarse_cnt,
      UP_IN     => '1');

  -- Trigger mode control register synchronised to the coarse counter clk
  Readout_trigger_mode_sync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => reset_tdc,
      CLK0  => CLK_READOUT,
      CLK1  => CLK_TDC,
      D_IN  => readout_trigger_mode,
      D_OUT => readout_trigger_mode_200);

  Valid_timing_trigger_sync : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => reset_tdc,
      CLK0  => CLK_READOUT,
      CLK1  => CLK_TDC,
      D_IN  => VALID_TIMING_TRG_IN,
      D_OUT => valid_timing_trg_200);

  Valid_timing_trigger_pulse : edge_to_pulse
    port map (
      clock     => CLK_TDC,
      en_clk    => '1',
      signal_in => valid_timing_trg_200,
      pulse     => valid_timing_trg_pulse_200);



-------------------------------------------------------------------------------
-- READOUT
-------------------------------------------------------------------------------

-- Coarse counter reset
  -- purpose: If the timing trigger is valid, the coarse time of the reference

  Coarse_Counter_Reset : process (CLK_TDC, reset_tdc)
  begin
    if rising_edge(CLK_TDC) then
      if reset_tdc = '1' then
        reset_coarse_cnt <= '1';
      elsif readout_trigger_mode_200 = '1' then
        reset_coarse_cnt <= '0';
      elsif valid_timing_trg_pulse_200 = '1' then
        reset_coarse_cnt <= '1';
      else
        reset_coarse_cnt <= '0';
      end if;
    end if;
  end process Coarse_Counter_Reset;

-- Reference Time (Coarse)

  -- purpose: If the timing trigger is valid, the coarse time of the reference
  -- time is registered in order to be used in trigger window calculations
  Reference_Coarse_Time : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        ref_time_coarse <= (others => '0');
      elsif VALID_TIMING_TRG_IN = '1' then
        ref_time_coarse <= trigger_time_i;
      end if;
    end if;
  end process Reference_Coarse_Time;
-------------------------------------------------------------------------------

-- Trigger Window

  --purpose: Generates trigger window end signal
  Check_Trg_Win_End_Conrollers : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        trg_win_cnt      <= x"0000";
        trg_win_end_i    <= '0';
        trg_win_cnt_up_i <= '0';
      elsif start_trg_win_cnt_i = '1' then
        trg_win_cnt      <= x"0001";
        trg_win_cnt_up_i <= '1';
      elsif trg_win_cnt = TRG_WIN_POST then
        trg_win_cnt      <= x"0000";
        trg_win_end_i    <= '1';
        trg_win_cnt_up_i <= '0';
      elsif trg_win_cnt_up_i = '1' then
        trg_win_cnt <= trg_win_cnt + 1;
      else
        trg_win_end_i <= '0';
      end if;
    end if;
  end process Check_Trg_Win_End_Conrollers;

  --purpose: Calculates the position of the trigger window edges
  Trg_Win_Calculation : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        TW_pre  <= (others => '0');
        TW_post <= (others => '0');
      else
        TW_pre  <= ref_time_coarse - TRG_WIN_PRE;
        TW_post <= ref_time_coarse + TRG_WIN_POST;
      end if;
    end if;
  end process Trg_Win_Calculation;

  channel_hit_time <= channel_data_i(fifo_nr)(10 downto 0);

  --purpose: Controls if the data coming from the channel is greater than the
  --trigger window pre-edge
  Check_Trg_Win_Left : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        trg_win_l <= '0';
      elsif TW_pre <= channel_hit_time then
        trg_win_l <= '1';
      else
        trg_win_l <= '0';
      end if;
    end if;
  end process Check_Trg_Win_Left;

  --purpose: Controls if the data coming from the channel is smaller than the
  --trigger window post-edge
  Check_Trg_Win_Right : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        trg_win_r <= '0';
      elsif channel_hit_time <= TW_post then
        trg_win_r <= '1';
      else
        trg_win_r <= '0';
      end if;
    end if;
  end process Check_Trg_Win_Right;
-------------------------------------------------------------------------------
-- Creating mask and Generating the fifo nr to be read

  -- purpose: Creats and updates the mask to determine the non-empty FIFOs
  CREAT_MASK : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        mask_i         <= (others => '1');
        empty_channels <= (others => '1');
      elsif trg_win_end_i = '1' then
        mask_i(CHANNEL_NUMBER-1 downto 0)         <= channel_empty_i;
        empty_channels(CHANNEL_NUMBER-1 downto 0) <= channel_empty_i;
      elsif updt_mask_i = '1' then
        mask_i(fifo_nr) <= '1';
      end if;
    end if;
  end process CREAT_MASK;

  GEN : for i in 0 to (CHANNEL_NUMBER/8-1) generate
    ROM : ROM_FIFO
      port map (
        Address    => mask_i(8*(i+1)-1 downto 8*i),
        OutClock   => CLK_READOUT,
        OutClockEn => '1',
        Reset      => RESET,
        Q          => fifo_nr_hex(i));
  end generate GEN;

  -- purpose: Generates number of the FIFO, to be read, in integer
  CON_FIFO_NR_HEX_TO_INT : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        fifo_nr_next <= CHANNEL_NUMBER;
      elsif fifo_nr_hex(0)(3) /= '1' then
        fifo_nr_next <= conv_integer("00000" & fifo_nr_hex(0)(2 downto 0));
      elsif fifo_nr_hex(1)(3) /= '1' then
        fifo_nr_next <= conv_integer("00001" & fifo_nr_hex(1)(2 downto 0));
      elsif fifo_nr_hex(2)(3) /= '1' then
        fifo_nr_next <= conv_integer("00010" & fifo_nr_hex(2)(2 downto 0));
      elsif fifo_nr_hex(3)(3) /= '1' then
        fifo_nr_next <= conv_integer("00011" & fifo_nr_hex(3)(2 downto 0));
      elsif fifo_nr_hex(4)(3) /= '1' then
        fifo_nr_next <= conv_integer("00100" & fifo_nr_hex(4)(2 downto 0));
      elsif fifo_nr_hex(5)(3) /= '1' then
        fifo_nr_next <= conv_integer("00101" & fifo_nr_hex(5)(2 downto 0));
      elsif fifo_nr_hex(6)(3) /= '1' then
        fifo_nr_next <= conv_integer("00110" & fifo_nr_hex(6)(2 downto 0));
      elsif fifo_nr_hex(7)(3) /= '1' then
        fifo_nr_next <= conv_integer("00111" & fifo_nr_hex(7)(2 downto 0));
      else
        fifo_nr_next <= CHANNEL_NUMBER;
      end if;
    end if;
  end process CON_FIFO_NR_HEX_TO_INT;

  --purpose: Updates the index number for the array signals
  UPDATE_INDEX_NR : process (CLK_READOUT)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        fifo_nr <= CHANNEL_NUMBER;
      elsif updt_index_i = '1' then
        fifo_nr <= fifo_nr_next;
      end if;
    end if;
  end process UPDATE_INDEX_NR;
-------------------------------------------------------------------------------
-- Data Out, Data Write and Data Finished assigning according to the control
-- signals from the readout final-state-machine.

  Data_Out_MUX : process (CLK_READOUT, RESET)
    variable i : integer := 0;
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        data_out_reg  <= (others => '1');
        data_wr_reg   <= '0';
        stop_status_i <= '0';
      else
        if wr_header_i = '1' then
          data_out_reg  <= "001" & "00000" & TRG_CODE_IN & header_error_bits;
          data_wr_reg   <= '1';
          stop_status_i <= '0';
        elsif wr_ch_data_reg = '1' and trigger_win_en = '1' then
          if (TW_pre(10) = '1' and ref_time_coarse(10) = '0') or (TW_post(10) = '0' and ref_time_coarse(10) = '1') then
            if (trg_win_l = '0' and trg_win_r = '1') or (trg_win_l = '1' and trg_win_r = '0') then
              data_out_reg <= channel_data_reg(fifo_nr);
              data_wr_reg  <= '1';
            else
              data_wr_reg <= '0';
            end if;
          else
            if (trg_win_l = '1' and trg_win_r = '1') then
              data_out_reg <= channel_data_reg(fifo_nr);
              data_wr_reg  <= '1';
            else
              data_wr_reg <= '0';
            end if;
          end if;
          stop_status_i <= '0';
        elsif wr_ch_data_reg = '1' and trigger_win_en = '0' then
          data_out_reg  <= channel_data_reg(fifo_nr);
          data_wr_reg   <= '1';
          stop_status_i <= '0';
        elsif wr_status_i = '1' then
          case i is
            when 0  => data_out_reg <= "010" & "00000" & trig_number;
            when 1  => data_out_reg <= "010" & "00001" & release_number;
            when 2  => data_out_reg <= "010" & "00010" & valid_tmg_trig_number;
            when 3  => data_out_reg <= "010" & "00011" & valid_NOtmg_trig_number;
            when 4  => data_out_reg <= "010" & "00100" & invalid_trig_number;
            when 5  => data_out_reg <= "010" & "00101" & multi_tmg_trig_number;
            when 6  => data_out_reg <= "010" & "00110" & spurious_trig_number;
            when 7  => data_out_reg <= "010" & "00111" & wrong_readout_number;
            when 8  => data_out_reg <= "010" & "01000" & spike_number;
            when 9  => data_out_reg <= "010" & "01001" & idle_time;
            when 10 => data_out_reg <= "010" & "01010" & wait_time;
                       stop_status_i <= '1';
            when 11     => data_out_reg <= "010" & "01011" & total_empty_channel;
                           i := -1;
            when others => null;
          end case;
          data_wr_reg <= '1';
          i           := i+1;
        elsif wr_trailer_i = '1' then
          data_out_reg  <= "011" & "0000000000000" & trailer_error_bits;
          data_wr_reg   <= '1';
          stop_status_i <= '0';
        else
--          data_out_reg <= (others => '1');
          data_wr_reg   <= '0';
          stop_status_i <= '0';
        end if;
      end if;
    end if;
  end process Data_Out_MUX;

  DATA_OUT          <= data_out_reg;
  DATA_WRITE_OUT    <= data_wr_reg;
  DATA_FINISHED_OUT <= data_finished_reg;
  TRG_RELEASE_OUT   <= trg_release_reg;
  TRG_STATUSBIT_OUT <= trg_statusbit_reg;

-----------------------------------------------------------------------------
-- Data delay

  Delay_Channel_Data : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        channel_data_reg   <= (others => x"00000000");
        channel_empty_reg  <= (others => '0');
      else
        channel_data_reg   <= channel_data_i;
        channel_empty_reg  <= channel_empty_i;
      end if;
    end if;
  end process Delay_Channel_Data;

-------------------------------------------------------------------------------
-- Readout Final-State-Machine
-------------------------------------------------------------------------------

  --purpose: FSM for writing data
  FSM_CLK : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        FSM_CURRENT         <= IDLE;
        fsm_debug_reg       <= x"00";
        start_trg_win_cnt_i <= '0';
        updt_index_i        <= '0';
        updt_mask_i         <= '0';
        rd_en_i             <= (others => '0');
        wr_ch_data_i        <= '0';
        wr_ch_data_reg      <= '0';
        wr_header_i         <= '0';
        wr_status_i         <= '0';
        data_finished_i     <= '0';
        data_finished_reg   <= '0';
        trg_release_reg     <= '0';
        wrong_readout_i     <= '0';
        idle_i              <= '0';
        readout_i           <= '0';
        wait_i              <= '0';
      else
        FSM_CURRENT         <= FSM_NEXT;
        fsm_debug_reg       <= fsm_debug_fsm;
        start_trg_win_cnt_i <= start_trg_win_cnt_fsm;
        updt_index_i        <= updt_index_fsm;
        updt_mask_i         <= updt_mask_fsm;
        rd_en_i             <= rd_en_fsm;
        wr_ch_data_i        <= wr_ch_data_fsm;
        wr_ch_data_reg      <= wr_ch_data_i;
        wr_header_i         <= wr_header_fsm;
        wr_status_i         <= wr_status_fsm;
        data_finished_i     <= data_finished_fsm;
        data_finished_reg   <= data_finished_i;
        trg_release_reg     <= trg_release_fsm;
        wrong_readout_i     <= wrong_readout_fsm;
        idle_i              <= idle_fsm;
        readout_i           <= readout_fsm;
        wait_i              <= wait_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, VALID_TIMING_TRG_IN, VALID_NOTIMING_TRG_IN, trg_win_end_i, fifo_nr_next,
                      fifo_nr, channel_empty_reg, TRG_DATA_VALID_IN, INVALID_TRG_IN, TMGTRG_TIMEOUT_IN,
                      TRG_TYPE_IN, SPURIOUS_TRG_IN, stop_status_i, debug_mode_en_i)
  begin

    start_trg_win_cnt_fsm <= '0';
    updt_index_fsm        <= '0';
    updt_mask_fsm         <= '0';
    rd_en_fsm             <= (others => '0');
    wr_ch_data_fsm        <= '0';
    wr_header_fsm         <= '0';
    data_finished_fsm     <= '0';
    trg_release_fsm       <= '0';
    wrong_readout_fsm     <= '0';
    idle_fsm              <= '0';
    readout_fsm           <= '0';
    wait_fsm              <= '0';
    wr_status_fsm         <= '0';
    fsm_debug_fsm         <= x"00";
    FSM_NEXT              <= IDLE;

    case (FSM_CURRENT) is
      when IDLE =>
        if VALID_TIMING_TRG_IN = '1' then
          FSM_NEXT              <= WAIT_FOR_TRG_WIND_END;
          start_trg_win_cnt_fsm <= '1';
        elsif VALID_NOTIMING_TRG_IN = '1' then
          if TRG_TYPE_IN = x"E" then
            FSM_NEXT <= SEND_STATUS;
          else
            FSM_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          wr_header_fsm <= '1';
        elsif INVALID_TRG_IN = '1' then
          FSM_NEXT          <= SEND_TRG_RELEASE_A;
          data_finished_fsm <= '1';
        else
          FSM_NEXT <= IDLE;
        end if;
        idle_fsm      <= '1';
        fsm_debug_fsm <= x"01";
--
      when WAIT_FOR_TRG_WIND_END =>
        if trg_win_end_i = '1' then
          FSM_NEXT <= WR_HEADER;
        else
          FSM_NEXT <= WAIT_FOR_TRG_WIND_END;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"02";
-------------------------------------------------------------------------------
-- Readout process starts
      when WR_HEADER =>
        FSM_NEXT      <= WAIT_FOR_FIFO_NR_A;
        wr_header_fsm <= '1';
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"03";

      when WAIT_FOR_FIFO_NR_A =>
        FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
        updt_index_fsm <= '1';
        wait_fsm       <= '1';
        fsm_debug_fsm  <= x"04";

      when WAIT_FOR_FIFO_NR_B =>
        FSM_NEXT      <= APPLY_MASK;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"05";

      when APPLY_MASK =>
        if fifo_nr_next = CHANNEL_NUMBER then
          if debug_mode_en_i = '1' then
            FSM_NEXT          <= SEND_STATUS;
          else
            FSM_NEXT          <= WAIT_FOR_LVL1_TRG_A;
            data_finished_fsm <= '1';
          end if;
        else
          FSM_NEXT           <= RD_CHANNEL_A;
          rd_en_fsm(fifo_nr) <= '1';
          updt_mask_fsm      <= '1';
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"06";

      when RD_CHANNEL_A =>
        FSM_NEXT           <= RD_CHANNEL_B;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"07";
        
      when RD_CHANNEL_B =>
        FSM_NEXT           <= RD_CHANNEL_C;
        rd_en_fsm(fifo_nr) <= '1';
        readout_fsm        <= '1';
        fsm_debug_fsm      <= x"08";
        
      when RD_CHANNEL_C =>
        if channel_empty_reg(fifo_nr) = '1' then
          FSM_NEXT       <= WAIT_FOR_FIFO_NR_B;
          wr_ch_data_fsm <= '0';
          updt_index_fsm <= '1';
        else
          FSM_NEXT           <= RD_CHANNEL_C;
          wr_ch_data_fsm     <= '1';
          rd_en_fsm(fifo_nr) <= '1';
        end if;
        readout_fsm   <= '1';
        fsm_debug_fsm <= x"09";
-------------------------------------------------------------------------------
      when WAIT_FOR_LVL1_TRG_A =>
        if TRG_DATA_VALID_IN = '1' then
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_B;
        elsif TMGTRG_TIMEOUT_IN = '1' then
          FSM_NEXT <= IDLE;
        else
          FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
        end if;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0A";
--
      when WAIT_FOR_LVL1_TRG_B =>
        FSM_NEXT      <= WAIT_FOR_LVL1_TRG_C;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0B";
--
      when WAIT_FOR_LVL1_TRG_C =>
        if SPURIOUS_TRG_IN = '1' then
          wrong_readout_fsm <= '1';
        end if;
        FSM_NEXT      <= SEND_TRG_RELEASE_A;
        wait_fsm      <= '1';
        fsm_debug_fsm <= x"0C";
--
      when SEND_STATUS =>  -- here the status of the TDC should be sent
        if stop_status_i = '1' then
          if debug_mode_en_i = '1' then
            FSM_NEXT <= WAIT_FOR_LVL1_TRG_A;
          else
            FSM_NEXT <= SEND_TRG_RELEASE_A;
          end if;
          data_finished_fsm <= '1';
        else
          FSM_NEXT      <= SEND_STATUS;
          wr_status_fsm <= '1';
        end if;
        fsm_debug_fsm <= x"0D";
--
      when SEND_TRG_RELEASE_A =>
        FSM_NEXT        <= SEND_TRG_RELEASE_B;
        trg_release_fsm <= '1';
        fsm_debug_fsm   <= x"0E";
--
      when SEND_TRG_RELEASE_B =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"0F";
--
      when others =>
        FSM_NEXT      <= IDLE;
        fsm_debug_fsm <= x"FF";
    end case;
  end process FSM_PROC;

-------------------------------------------------------------------------------
-- Header-Trailor Error & Warning Bits
-------------------------------------------------------------------------------
  -- Error, warning bits set in the header
  header_error_bits(15 downto 3) <= (others => '0');
  header_error_bits(0)           <= '0';
  --header_error_bits(0) <= lost_hit_i;  -- if there is at least one lost hit (can be more if the FIFO is full).
  header_error_bits(1)           <= fifo_full_i;  -- if the channel FIFO is full.
  header_error_bits(2)           <= fifo_almost_full_i;  -- if the channel FIFO is almost full.

  -- Error, warning bits set in the trailer
  trailer_error_bits <= (others => '0');
  -- trailer_error_bits (0) <= wrong_readout_i;  -- if there is a wrong readout because of a spurious timing trigger.

  fifo_full_i        <= or_all(channel_full_i);
  fifo_almost_full_i <= or_all(channel_almost_full_i);

-------------------------------------------------------------------------------
-- Debug and statistics words
-------------------------------------------------------------------------------

  edge_to_pulse_1 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => VALID_TIMING_TRG_IN,
      pulse     => valid_timing_trg_pulse);

  edge_to_pulse_2 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => VALID_NOTIMING_TRG_IN,
      pulse     => valid_notiming_trg_pulse);

  edge_to_pulse_3 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => INVALID_TRG_IN,
      pulse     => invalid_trg_pulse);

  edge_to_pulse_4 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => MULTI_TMG_TRG_IN,
      pulse     => multi_tmg_trg_pulse);

  edge_to_pulse_5 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => SPURIOUS_TRG_IN,
      pulse     => spurious_trg_pulse);

  edge_to_pulse_6 : edge_to_pulse
    port map (
      clock     => CLK_READOUT,
      en_clk    => '1',
      signal_in => SPIKE_DETECTED_IN,
      pulse     => spike_detected_pulse);

  -- purpose: Internal trigger number counter (only valid triggers)
  Statistics_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        trig_number <= (others => '0');
      elsif valid_timing_trg_pulse = '1' or valid_notiming_trg_pulse = '1' then
        trig_number <= trig_number + 1;
      end if;
    end if;
  end process Statistics_Trigger_Number;

  -- purpose: Internal release number counter
  Statistics_Release_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        release_number <= (others => '0');
      elsif trg_release_reg = '1' then
        release_number <= release_number + 1;
      end if;
    end if;
  end process Statistics_Release_Number;
    
  -- purpose: Internal valid timing trigger number counter
  Statistics_Valid_Timing_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        valid_tmg_trig_number <= (others => '0');
      elsif valid_timing_trg_pulse = '1' then
        valid_tmg_trig_number <= valid_tmg_trig_number + 1;
      end if;
    end if;
  end process Statistics_Valid_Timing_Trigger_Number;

  -- purpose: Internal valid NOtiming trigger number counter
  Statistics_Valid_NoTiming_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        valid_NOtmg_trig_number <= (others => '0');
      elsif valid_notiming_trg_pulse = '1' then
        valid_NOtmg_trig_number <= valid_NOtmg_trig_number + 1;
      end if;
    end if;
  end process Statistics_Valid_NoTiming_Trigger_Number;

  -- purpose: Internal invalid trigger number counter
  Statistics_Invalid_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        invalid_trig_number <= (others => '0');
      elsif invalid_trg_pulse = '1' then
        invalid_trig_number <= invalid_trig_number + 1;
      end if;
    end if;
  end process Statistics_Invalid_Trigger_Number;

  -- purpose: Internal multi timing trigger number counter
  Statistics_Multi_Timing_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        multi_tmg_trig_number <= (others => '0');
      elsif multi_tmg_trg_pulse = '1' then
        multi_tmg_trig_number <= multi_tmg_trig_number + 1;
      end if;
    end if;
  end process Statistics_Multi_Timing_Trigger_Number;

  -- purpose: Internal spurious trigger number counter
  Statistics_Spurious_Trigger_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        spurious_trig_number <= (others => '0');
      elsif spurious_trg_pulse = '1' then
        spurious_trig_number <= spurious_trig_number + 1;
      end if;
    end if;
  end process Statistics_Spurious_Trigger_Number;

  -- purpose: Number of wrong readout becasue of spurious trigger
  Statistics_Wrong_Readout_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        wrong_readout_number <= (others => '0');
      elsif wrong_readout_i = '1' then
        wrong_readout_number <= wrong_readout_number + 1;
      end if;
    end if;
  end process Statistics_Wrong_Readout_Number;

  -- purpose: Internal spike number counter
  Statistics_Spike_Number : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        spike_number <= (others => '0');
      elsif spike_detected_pulse = '1' then
        spike_number <= spike_number + 1;
      end if;
    end if;
  end process Statistics_Spike_Number;

  -- purpose: IDLE time of the TDC readout
  Statistics_Idle_Time : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        idle_time <= (others => '0');
      elsif idle_i = '1' then
        idle_time <= idle_time + 1;
      end if;
    end if;
  end process Statistics_Idle_Time;

  -- purpose: Readout and Wait time of the TDC readout
  Statistics_Readout_Wait_Time : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        readout_time <= (others => '0');
        wait_time    <= (others => '0');
      elsif readout_i = '1' then
        readout_time <= readout_time + 1;
      elsif wait_i = '1' then
        wait_time <= wait_time + 1;
      end if;
    end if;
  end process Statistics_Readout_Wait_Time;

  -- purpose: Empty channel number
  Statistics_Empty_Channel_Number : process (CLK_READOUT, RESET)
    variable i : integer := CHANNEL_NUMBER;
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        total_empty_channel <= (others => '0');
        i                   := CHANNEL_NUMBER;
      elsif trg_win_end_i = '1' then
        i := 0;
      elsif i = CHANNEL_NUMBER then
        i := i;
      elsif empty_channels(i) = '1' then
        total_empty_channel <= total_empty_channel + 1;
        i                   := i + 1;
      else
        i := i + 1;
      end if;
    end if;
  end process Statistics_Empty_Channel_Number;


-------------------------------------------------------------------------------
-- Logic Analyser Signals
-------------------------------------------------------------------------------
-- Logic Analyser and Test Signals
  REG_LOGIC_ANALYSER_OUTPUT : process (CLK_READOUT, RESET)
  begin
    if rising_edge(CLK_READOUT) then
      if RESET = '1' then
        logic_analyser_reg <= (others => '0');
      elsif logic_anal_control = x"1" then  -- TRBNET connections debugging
        logic_analyser_reg(7 downto 0) <= fsm_debug_reg;
        logic_analyser_reg(8)          <= REFERENCE_TIME;
        logic_analyser_reg(9)          <= VALID_TIMING_TRG_IN;
        logic_analyser_reg(10)         <= VALID_NOTIMING_TRG_IN;
        logic_analyser_reg(11)         <= INVALID_TRG_IN;
        logic_analyser_reg(12)         <= TRG_DATA_VALID_IN;
        logic_analyser_reg(13)         <= data_wr_reg;
        logic_analyser_reg(14)         <= data_finished_reg;
        logic_analyser_reg(15)         <= trg_release_reg;

      elsif logic_anal_control = x"2" then  -- Reference channel debugging
        logic_analyser_reg <= ref_debug_i(15 downto 0);

      elsif logic_anal_control = x"3" then  -- Data out
        logic_analyser_reg(7 downto 0)   <= fsm_debug_reg;
        logic_analyser_reg(8)            <= REFERENCE_TIME;
        logic_analyser_reg(9)            <= data_wr_reg;
        logic_analyser_reg(15 downto 10) <= data_out_reg(27 downto 22);

      elsif logic_anal_control = x"4" then  -- channel debugging
        logic_analyser_reg <= channel_debug_i(1)(15 downto 0);
      end if;
    end if;
  end process REG_LOGIC_ANALYSER_OUTPUT;

  LOGIC_ANALYSER_OUT <= logic_analyser_reg;
-------------------------------------------------------------------------------
-- STATUS REGISTERS
-------------------------------------------------------------------------------

-- Register 0x80
  TDC_DEBUG(7 downto 0)  <= fsm_debug_reg;
  TDC_DEBUG(15 downto 8) <= std_logic_vector(to_unsigned(CHANNEL_NUMBER-1, 8));
  TDC_DEBUG(16)          <= REFERENCE_TIME when rising_edge(CLK_READOUT);
--
--  TDC_DEBUG(27 downto 24)          <= 
--
--  TDC_DEBUG(31 downto 28)          <= 

  -- Register 0x81 & 0x82
  TDC_DEBUG(1*32+CHANNEL_NUMBER-2 downto 1*32+0) <= channel_empty_i(CHANNEL_NUMBER-1 downto 1);

-- Register 0x83
  TDC_DEBUG(3*32+31 downto 3*32+0) <= "00000" & TRG_WIN_POST & "00000" & TRG_WIN_PRE;

-- Register 0x84
  TDC_DEBUG(4*32+23 downto 4*32+0) <= trig_number;

-- Register 0x85
  TDC_DEBUG(5*32+23 downto 5*32+0) <= valid_tmg_trig_number;

-- Register 0x86
  TDC_DEBUG(6*32+23 downto 6*32+0) <= valid_NOtmg_trig_number;

-- Register 0x87
  TDC_DEBUG(7*32+23 downto 7*32+0) <= invalid_trig_number;

-- Register 0x88
  TDC_DEBUG(8*32+23 downto 8*32+0) <= multi_tmg_trig_number;

-- Register 0x89
  TDC_DEBUG(9*32+23 downto 9*32+0) <= spurious_trig_number;

-- Register 0x8a
  TDC_DEBUG(10*32+23 downto 10*32+0) <= wrong_readout_number;

-- Register 0x8b
  TDC_DEBUG(11*32+23 downto 11*32+0) <= spike_number;

-- Register 0x8c
  TDC_DEBUG(12*32+23 downto 12*32+0) <= idle_time;

-- Register 0x8d
  TDC_DEBUG(13*32+23 downto 13*32+0) <= wait_time;

-- Register 0x8e
  TDC_DEBUG(14*32+23 downto 14*32+0) <= total_empty_channel;

-- Register 0x8f
  TDC_DEBUG(15*32+23 downto 15*32+0) <= release_number;

-- Register 0x90
  TDC_DEBUG(16*32+23 downto 16*32+0) <= channel_lost_hit_number(1);

-- Register 0x91
  TDC_DEBUG(17*32+23 downto 17*32+0) <= channel_hit_detect_number(1);

-- Register 0x92
  TDC_DEBUG(18*32+23 downto 18*32+0) <= channel_encoder_start_number(1);

-- Register 0x93
  TDC_DEBUG(19*32+23 downto 19*32+0) <= channel_fifo_wr_number(1);

---- Register 0x94
--  TDC_DEBUG(20*32+23 downto 20*32+0) <= channel_lost_hit_number(2);

---- Register 0x95
--  TDC_DEBUG(21*32+23 downto 21*32+0) <= channel_hit_detect_number(2);

---- Register 0x96
--  TDC_DEBUG(22*32+23 downto 22*32+0) <= channel_encoder_start_number(2);

---- Register 0x97
--  TDC_DEBUG(23*32+23 downto 23*32+0) <= channel_fifo_wr_number(2);

end TDC;
