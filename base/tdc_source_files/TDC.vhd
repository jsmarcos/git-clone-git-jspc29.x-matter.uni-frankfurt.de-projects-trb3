library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.NUMERIC_STD.all;
use STD.TEXTIO.all;
use IEEE.STD_LOGIC_TEXTIO.all;

-- synopsys translate_off
library ecp2m;
use ecp2m.components.all;
-- synopsys translate_on

entity TDC is
  generic (
    CHANNEL_NUMBER :     integer range 0 to 64 := 8);
  port (
    RESET          : in  std_logic;
    CLK_CHANNEL    : in  std_logic;
    CLK_READOUT    : in  std_logic;
    HIT_IN         : in  std_logic_vector(CHANNEL_NUMBER-1 downto 0);
    TRIGGER_IN     : in  std_logic;
    TRIGGER_WIN    : in  std_logic_vector(31 downto 0);
    DATA_OUT       : out std_logic_vector(31 downto 0);
    TRB_WR_CLK_OUT : out std_logic;
    DATA_VALID     : out std_logic;
    DATA_READY     : out std_logic;
    TDC_DEBUG_00   : out std_logic_vector(31 downto 0)
    );
end TDC;

architecture TDC of TDC is

-------------------------------------------------------------------------------
-- Component Declarations
-------------------------------------------------------------------------------

  component Channel
    generic (
      CHANNEL_ID        :     integer range 0 to 15);
    port (
      RESET             : in  std_logic;
      CLK               : in  std_logic;
      HIT_IN            : in  std_logic;
      READ_EN_IN        : in  std_logic;
      FIFO_DATA_OUT     : out std_logic_vector(31 downto 0);
      FIFO_EMPTY_OUT    : out std_logic;
      FIFO_FULL_OUT     : out std_logic;
      COARSE_COUNTER_IN : in  std_logic_vector(15 downto 0)
      );
  end component;
--
  component ROM_FIFO
    port (
      Address           : in  std_logic_vector(7 downto 0);
      OutClock          : in  std_logic;
      OutClockEn        : in  std_logic;
      Reset             : in  std_logic;
      Q                 : out std_logic_vector(3 downto 0));
  end component;
--
  component up_counter
    generic (
      NUMBER_OF_BITS    :     positive);
    port (
      CLK               : in  std_logic;
      RESET             : in  std_logic;
      COUNT_OUT         : out std_logic_vector(NUMBER_OF_BITS-1 downto 0);
      UP_IN             : in  std_logic);
  end component;
--
  component edge_to_pulse_fast
    port (
      RESET             : in  std_logic;
      CLK               : in  std_logic;
      SIGNAL_IN         : in  std_logic;
      PULSE_OUT         : out std_logic);
  end component;
--
  component bit_sync
    generic (
      DEPTH             :     integer);
    port (
      RESET             : in  std_logic;
      CLK0              : in  std_logic;
      CLK1              : in  std_logic;
      D_IN              : in  std_logic;
      D_OUT             : out std_logic);
  end component;
--
  component ddr_off
    port (
      Clk               : in  std_logic;
      Data              : in  std_logic_vector(1 downto 0);
      Q                 : out std_logic_vector(0 downto 0));
  end component;

-------------------------------------------------------------------------------
-- Signal Declarations
-------------------------------------------------------------------------------
-- Input Output signals
  signal clk_i        : std_logic;
  signal clk_100_i    : std_logic;
  signal lock_100_i   : std_logic;
  signal reset_i      : std_logic;
  signal hit_in_i     : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal trigger_in_i : std_logic;
  signal trig_pulse_i : std_logic;
  signal trig_sync_i  : std_logic;
  signal data_out_i   : std_logic_vector(31 downto 0);
  signal data_valid_i : std_logic;
  signal data_ready_i : std_logic;

-- Other signals
  type FSM is (IDLE, WR_HEADER, WR_ERROR, WR_TRAILOR, WAIT_FOR_FIFO_NR,
               APPLY_MASK, RD_CHANNEL_1, RD_CHANNEL_2, RD_CHANNEL_3,
               RD_CHANNEL_4, RD_CHANNEL_5, RD_CHANNEL_6, RD_CHANNEL, FINISH);
  signal FSM_CURRENT, FSM_NEXT : FSM;
--
  signal clk_to_TRB_i          : std_logic_vector(0 downto 0);
  signal start_rdout_i         : std_logic;
  signal rdout_busy_fsm        : std_logic;
  signal rdout_busy_i          : std_logic;
  signal send_ready_fsm        : std_logic;
  signal send_ready_i          : std_logic;
  signal wr_header_fsm         : std_logic;
  signal wr_header_i           : std_logic;
  signal wr_ch_data_fsm        : std_logic;
  signal wr_ch_data_i          : std_logic;
  signal wr_error_fsm          : std_logic;
  signal wr_error_i            : std_logic;
  signal wr_trailor_fsm        : std_logic;
  signal wr_trailor_i          : std_logic;
  signal fsm_debug_fsm         : std_logic_vector(3 downto 0);
  signal fsm_debug_i           : std_logic_vector(3 downto 0);
  signal mask_i                : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal updt_mask_i           : std_logic;
  signal updt_mask_fsm         : std_logic;
  signal fifo_nr_int           : integer range 0 to 16 := 0;
  signal fifo_nr               : integer range 0 to 15 := 0;
  signal updt_index_i          : std_logic;
  signal updt_index_fsm        : std_logic;
  signal rd_en_fsm             : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal rd_en_i               : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal trig_time_i           : std_logic_vector(15 downto 0);
  signal TW_pre                : std_logic_vector(15 downto 0);
  signal TW_post               : std_logic_vector(15 downto 0);
  signal channel_hit_time      : std_logic_vector(15 downto 0);
  signal trig_win_l            : std_logic;
  signal trig_win_r            : std_logic;
  signal ctwe_cntr_i           : std_logic_vector(15 downto 0);
  signal ctwe_up_i             : std_logic;
  signal ctwe_reset_i          : std_logic;
  signal trig_win_end_i        : std_logic;
--
  type Std_Logic_8_array is array (0 to 1) of std_logic_vector(3 downto 0);
  signal fifo_nr_hex           : Std_Logic_8_array;
--
  signal coarse_counter_i      : std_logic_vector(15 downto 0);
  signal trig_win_pre          : std_logic_vector(15 downto 0);
  signal trig_win_post         : std_logic_vector(15 downto 0);
  signal channel_full_i        : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_i       : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_reg     : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_2reg    : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_3reg    : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal channel_empty_4reg    : std_logic_vector(CHANNEL_NUMBER-1 downto 0);
  signal LE_cntr_up            : std_logic;
  signal LE_cntr_i             : std_logic_vector(15 downto 0);
--
  type channel_data_array is array (0 to CHANNEL_NUMBER) of std_logic_vector(31 downto 0);
  signal channel_data_i        : channel_data_array;
  signal channel_data_reg      : channel_data_array;
  signal channel_data_2reg     : channel_data_array;
  signal channel_data_3reg     : channel_data_array;
  signal channel_data_4reg     : channel_data_array;

-------------------------------------------------------------------------------
-- test signals
-------------------------------------------------------------------------------
  signal tdc_debug_i     : std_logic_vector(31 downto 0);
  signal tdc_debug_out_i : std_logic_vector(31 downto 0);

-------------------------------------------------------------------------------

begin

  reset_i       <= RESET;
  clk_i         <= CLK_CHANNEL;
  clk_100_i     <= CLK_READOUT;
  trigger_in_i  <= TRIGGER_IN;
  hit_in_i      <= HIT_IN;
  trig_win_pre  <= TRIGGER_WIN(15 downto 0);
  trig_win_post <= TRIGGER_WIN(31 downto 16);

-------------------------------------------------------------------------------
-- COMPONENT INSTANTINIATIONS
-------------------------------------------------------------------------------
-- Channels
  GEN_Channels : for i in 0 to CHANNEL_NUMBER - 1 generate
    Channels   : Channel
      generic map (
        CHANNEL_ID        => i)
      port map (
        RESET             => reset_i,
        CLK               => clk_i,
        HIT_IN            => hit_in_i(i),
        READ_EN_IN        => rd_en_i(i),
        FIFO_DATA_OUT     => channel_data_i(i),
        FIFO_EMPTY_OUT    => channel_empty_i(i),
        FIFO_FULL_OUT     => channel_full_i(i),
        COARSE_COUNTER_IN => coarse_counter_i
        );
  end generate GEN_Channels;
  channel_data_i(CHANNEL_NUMBER) <= x"FFFFFFFF";

-- Common Coarse counter
  COARSE_COUNTER : up_counter
    generic map (
      NUMBER_OF_BITS => 16)
    port map (
      CLK            => clk_i,
      RESET          => reset_i,
      COUNT_OUT      => coarse_counter_i,
      UP_IN          => '1');

-------------------------------------------------------------------------------
-- CLOCK SETTINGS
-------------------------------------------------------------------------------

  --purpose: ddr flip-flop generation for the clock output to the TRB board
  DDR_FF_for_TRB_CLK : ddr_off
    port map (
      Clk  => clk_100_i,
      Data => "01",
      Q    => clk_to_TRB_i);
  TRB_WR_CLK_OUT <= clk_to_TRB_i(0);

-------------------------------------------------------------------------------
-- READOUT
-------------------------------------------------------------------------------
-- Trigger Setup, Synchronisation, Accept, Timing and Local Event Counter

  -- purpose: synchronises the trigger signal to 200 MHz clock domain
  TRIGGER_SYNC : bit_sync
    generic map (
      DEPTH => 3)
    port map (
      RESET => '0',
      CLK0  => clk_100_i,
      CLK1  => clk_100_i,
      D_IN  => trigger_in_i,
      D_OUT => trig_sync_i);

  -- purpose: Generates pulse from the trigger signals
  Trigger_Pulse : edge_to_pulse_fast
    port map (
      RESET     => reset_i,
      CLK       => clk_100_i,
      SIGNAL_IN => trig_sync_i,
      PULSE_OUT => trig_pulse_i);

  -- purpose: Accepts the trigger according to the readout process situation
  TRIGGER_ACCEPT : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        start_rdout_i <= '0';
      elsif rdout_busy_i = '0' and trig_pulse_i = '1' then
        start_rdout_i <= '1';
      else
        start_rdout_i <= '0';
      end if;
    end if;
  end process TRIGGER_ACCEPT;

  -- purpose: Counts hardware triggers
  LOCAL_EVENT_COUNTER : up_counter
    generic map (
      NUMBER_OF_BITS => 16)
    port map (
      CLK            => clk_100_i,
      RESET          => reset_i,
      COUNT_OUT      => LE_cntr_i,
      UP_IN          => LE_cntr_up);
  LE_cntr_up <= start_rdout_i;

  -- purpose: Defines the trigger time with respect to the coarse counter
  Define_Trigger_Time : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        trig_time_i <= (others => '0');
      elsif start_rdout_i = '1' then
        trig_time_i <= coarse_counter_i - 6;
      end if;
    end if;
  end process Define_Trigger_Time;
-------------------------------------------------------------------------------
-- Trigger Window

  --purpose: Controls the trigger window end
  Check_Trig_Win_End_Conrollers : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        ctwe_up_i      <= '0';
        ctwe_reset_i   <= '1';
        trig_win_end_i <= '0';
      elsif start_rdout_i = '1' then
        ctwe_up_i      <= '1';
        ctwe_reset_i   <= '0';
        trig_win_end_i <= '0';
      elsif ctwe_cntr_i = (trig_win_post)then
        ctwe_up_i      <= '0';
        ctwe_reset_i   <= '1';
        trig_win_end_i <= '1';
      else
        ctwe_up_i      <= ctwe_up_i;
        ctwe_reset_i   <= ctwe_reset_i;
        trig_win_end_i <= '0';
      end if;
    end if;
  end process Check_Trig_Win_End_Conrollers;

  --purpose: Trigger Window Counter
  Check_Trig_Win_End : up_counter
    generic map (
      NUMBER_OF_BITS => 16)
    port map (
      CLK            => clk_100_i,
      RESET          => ctwe_reset_i,
      COUNT_OUT      => ctwe_cntr_i,
      UP_IN          => ctwe_up_i);

  --purpose: Calculates the position of the trigger window edges
  Trig_Win_Calculation : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        TW_pre           <= (others => '0');
        TW_post          <= (others => '0');
        channel_hit_time <= (others => '0');
      else
        TW_pre           <= trig_time_i - trig_win_pre;
        TW_post          <= trig_time_i + trig_win_post;
        channel_hit_time <= channel_data_2reg(fifo_nr)(25 downto 10);
      end if;
    end if;
  end process Trig_Win_Calculation;

  --purpose: Controls if the data coming from the channel is greater than the
  --trigger window pre-edge
  Check_Trig_Win_Left : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        trig_win_l <= '0';
      elsif TW_pre <= channel_hit_time then
        trig_win_l <= '1';
      else
        trig_win_l <= '0';
      end if;
    end if;
  end process Check_Trig_Win_Left;

  --purpose: Controls if the data coming from the channel is smaller than the
  --trigger window post-edge
  Check_Trig_Win_Right : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        trig_win_r           <= '0';
      elsif channel_hit_time <= TW_post then
        trig_win_r           <= '1';
      else
        trig_win_r           <= '0';
      end if;
    end if;
  end process Check_Trig_Win_Right;
-------------------------------------------------------------------------------
-- Creating mask and Generating the fifo nr to be read

  -- purpose: Creats and updates the mask to determine the non-empty FIFOs
  CREAT_MASK : process (clk_100_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        mask_i          <= (others => '1');
      elsif trig_win_end_i = '1' then
        mask_i          <= channel_empty_i;
      elsif updt_mask_i = '1' then
        mask_i(fifo_nr) <= '1';
      else
        mask_i          <= mask_i;
      end if;
    end if;
  end process CREAT_MASK;

  ROM0 : ROM_FIFO
    port map (
      Address    => mask_i(7 downto 0),
      OutClock   => clk_100_i,
      OutClockEn => '1',
      Reset      => reset_i,
      Q          => fifo_nr_hex(0));
-- ROM1 : ROM_FIFO
-- port map (
-- Address => mask_i(15 downto 8),
-- OutClock => clk_100_i,
-- OutClockEn => '1',
-- Reset => reset_i,
-- Q => fifo_nr_hex(1));

  -- purpose: Generates number of the FIFO, to be read, in integer
  CON_FIFO_NR_HEX_TO_INT : process (clk_100_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        fifo_nr_int <= CHANNEL_NUMBER;
      elsif fifo_nr_hex(0)(3) /= '1' then
        fifo_nr_int <= conv_integer("00000" & fifo_nr_hex(0)(2 downto 0));
-- elsif fifo_nr_hex(1)(3) /= '1' then
-- fifo_nr_int <= conv_integer("00001" & fifo_nr_hex(1)(2 downto 0));
      else
        fifo_nr_int <= CHANNEL_NUMBER;
      end if;
    end if;
  end process CON_FIFO_NR_HEX_TO_INT;

  --purpose: Updates the index number for the array signals
  UPDATE_INDEX_NR : process (clk_100_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        fifo_nr <= CHANNEL_NUMBER;
      elsif updt_index_i = '1' then
        fifo_nr <= fifo_nr_int;
      else
        fifo_nr <= fifo_nr;
      end if;
    end if;
  end process UPDATE_INDEX_NR;
-------------------------------------------------------------------------------
-- Data Out, Data Valid and Data Ready assigning according to the control
-- signals from the readout final-state-machine.

  Data_Out_MUX : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        data_out_i         <= (others => '1');
        data_valid_i       <= '0';
      else
        if wr_header_i = '1' then
          data_out_i       <= x"aa00" & LE_cntr_i;
          data_valid_i     <= '1';
        elsif wr_ch_data_i = '1' then
          if (TW_pre(15) = '1' and trig_time_i(15) = '0') or (TW_post(15) = '0' and trig_time_i(15) = '1') then
            if (trig_win_l = '0' and trig_win_r = '1') or (trig_win_l = '1' and trig_win_r = '0') then
              --data_out_i   <= channel_data_3reg(fifo_nr);
              data_out_i   <= channel_data_4reg(fifo_nr);
              data_valid_i <= '1';
            else
              data_out_i   <= (others => '1');
              data_valid_i <= '0';
            end if;
          else
            if (trig_win_l = '1' and trig_win_r = '1') then
              --data_out_i   <= channel_data_3reg(fifo_nr);
              data_out_i   <= channel_data_4reg(fifo_nr);
              data_valid_i <= '1';
            else
              data_out_i   <= (others => '1');
              data_valid_i <= '0';
            end if;
          end if;
        elsif wr_error_i = '1' then
          data_out_i       <= x"ee000000";
          data_valid_i     <= '1';
        elsif wr_trailor_i = '1' then
          data_out_i       <= x"bb00" & LE_cntr_i;
          data_valid_i     <= '1';
        else
          data_out_i       <= (others => '1');
          data_valid_i     <= '0';
        end if;
      end if;
    end if;
  end process Data_Out_MUX;

  DATA_OUT   <= data_out_i;
  DATA_VALID <= data_valid_i;

  Send_Ready : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        data_ready_i <= '0';
      elsif send_ready_i = '1' then
        data_ready_i <= '1';
      else
        data_ready_i <= '0';
      end if;
    end if;
  end process Send_Ready;

  DATA_READY <= data_ready_i;
-----------------------------------------------------------------------------
-- Data delay

  Delay_Channel_Data : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        channel_data_reg   <= (others => x"00000000");
        channel_data_2reg  <= (others => x"00000000");
        channel_data_3reg  <= (others => x"00000000");
        channel_data_4reg  <= (others => x"00000000");
        channel_empty_reg  <= (others => '0');
        channel_empty_2reg <= (others => '0');
        channel_empty_3reg <= (others => '0');
        channel_empty_4reg <= (others => '0');
      else
        channel_data_reg   <= channel_data_i;
        channel_data_2reg  <= channel_data_reg;
        channel_data_3reg  <= channel_data_2reg;
        channel_data_4reg  <= channel_data_3reg;
        channel_empty_reg  <= channel_empty_i;
        channel_empty_2reg <= channel_empty_reg;
        channel_empty_3reg <= channel_empty_2reg;
        channel_empty_4reg <= channel_empty_3reg;
      end if;
    end if;
  end process Delay_Channel_Data;

-----------------------------------------------------------------------------
-- Readout Final-State-Machine

  --purpose: FSM for writing data
  FSM_CLK : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        FSM_CURRENT  <= IDLE;
        rdout_busy_i <= '0';
        updt_index_i <= '0';
        updt_mask_i  <= '0';
        wr_header_i  <= '0';
        wr_ch_data_i <= '0';
        wr_error_i   <= '0';
        wr_trailor_i <= '0';
        rd_en_i      <= (others => '0');
        send_ready_i <= '0';
        fsm_debug_i  <= x"0";
      else
        FSM_CURRENT  <= FSM_NEXT;
        rdout_busy_i <= rdout_busy_fsm;
        updt_index_i <= updt_index_fsm;
        updt_mask_i  <= updt_mask_fsm;
        wr_header_i  <= wr_header_fsm;
        wr_ch_data_i <= wr_ch_data_fsm;
        wr_error_i   <= wr_error_fsm;
        wr_trailor_i <= wr_trailor_fsm;
        rd_en_i      <= rd_en_fsm;
        send_ready_i <= send_ready_fsm;
        fsm_debug_i  <= fsm_debug_fsm;
      end if;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, trig_win_end_i, fifo_nr_int, fifo_nr,
                      channel_empty_4reg)
  begin

    rdout_busy_fsm <= '1';
    updt_index_fsm <= '0';
    updt_mask_fsm  <= '0';
    wr_header_fsm  <= '0';
    wr_ch_data_fsm <= '0';
    wr_error_fsm   <= '0';
    wr_trailor_fsm <= '0';
    rd_en_fsm      <= (others => '0');
    send_ready_fsm <= '0';

    case (FSM_CURRENT) is
      when IDLE             =>
        if trig_win_end_i = '1' then
          rdout_busy_fsm         <= '1';
          FSM_NEXT               <= WR_HEADER;
          fsm_debug_fsm          <= x"1";
        else
          rdout_busy_fsm         <= '0';
          FSM_NEXT               <= IDLE;
          fsm_debug_fsm          <= x"2";
        end if;
--
      when WR_HEADER        =>
        FSM_NEXT                 <= WAIT_FOR_FIFO_NR;
        wr_header_fsm            <= '1';
        fsm_debug_fsm            <= x"3";
--
      when WAIT_FOR_FIFO_NR =>
        FSM_NEXT                 <= APPLY_MASK;
        updt_index_fsm           <= '1';
        fsm_debug_fsm            <= x"4";
--
      when APPLY_MASK       =>
        if fifo_nr_int = 8 then
          FSM_NEXT               <= WR_ERROR;
          fsm_debug_fsm          <= x"5";
        else
          FSM_NEXT               <= RD_CHANNEL_1;
          rd_en_fsm(fifo_nr_int) <= '1';
          fsm_debug_fsm          <= x"6";
        end if;
--
      when RD_CHANNEL_1     =>
        FSM_NEXT                 <= RD_CHANNEL_2;
        rd_en_fsm(fifo_nr_int)   <= '1';
        updt_mask_fsm            <= '1';
        fsm_debug_fsm            <= x"7";
--
      when RD_CHANNEL_2     =>
        FSM_NEXT                 <= RD_CHANNEL_3;
        rd_en_fsm(fifo_nr_int)   <= '1';
        fsm_debug_fsm            <= x"7";
--
      when RD_CHANNEL_3     =>
        FSM_NEXT                 <= RD_CHANNEL_4;
        rd_en_fsm(fifo_nr_int)   <= '1';
        fsm_debug_fsm            <= x"7";
--
      when RD_CHANNEL_4     =>
        FSM_NEXT                 <= RD_CHANNEL_5;
        rd_en_fsm(fifo_nr_int)   <= '1';
        fsm_debug_fsm            <= x"7";
--
      when RD_CHANNEL_5     =>
        FSM_NEXT                 <= RD_CHANNEL;
        rd_en_fsm(fifo_nr)       <= '1';
        fsm_debug_fsm            <= x"7";
--
      when RD_CHANNEL       =>
-- if channel_empty_3reg(fifo_nr) = '1' then
        if channel_empty_4reg(fifo_nr) = '1' then
          wr_ch_data_fsm         <= '0';
          updt_index_fsm         <= '1';
          FSM_NEXT               <= APPLY_MASK;
          fsm_debug_fsm          <= x"8";
        else
          wr_ch_data_fsm         <= '1';
          rd_en_fsm(fifo_nr)     <= '1';
          FSM_NEXT               <= RD_CHANNEL;
          fsm_debug_fsm          <= x"9";
        end if;
--
      when WR_ERROR         =>
        wr_error_fsm             <= '1';
        FSM_NEXT                 <= WR_TRAILOR;
        fsm_debug_fsm            <= x"A";
--
      when WR_TRAILOR       =>
        wr_trailor_fsm           <= '1';
        FSM_NEXT                 <= FINISH;
        fsm_debug_fsm            <= x"B";
--
      when FINISH           =>
        send_ready_fsm           <= '1';
        rdout_busy_fsm           <= '0';
        FSM_NEXT                 <= IDLE;
        fsm_debug_fsm            <= x"C";
--
      when others           =>
        FSM_NEXT                 <= IDLE;
        fsm_debug_fsm            <= x"D";
    end case;
  end process FSM_PROC;

-------------------------------------------------------------------------------











-------------------------------------------------------------------------------
-- Logic Analyser and Test Signals

-- tdc_debug_out_i(0) <= start_rdout_i;
-- tdc_debug_out_i(4 downto 1) <= fsm_debug_i;
-- tdc_debug_out_i(5) <= buf1_start_i;
-- tdc_debug_out_i(9 downto 6) <= buf1_fsm_debug_i;
-- tdc_debug_out_i(11 downto 10) <= data_ready_i;              --2
-- tdc_debug_out_i(15 downto 12) <= data_len_0_i(5 downto 2);  --12
-- tdc_debug_out_i(19 downto 16) <= data_len_1_i(5 downto 2);  --12
-- tdc_debug_out_i(25 downto 24) <= clear_in_i;
-- tdc_debug_out_i(26) <=
-- tdc_debug_out_i(27)           <= wr_ch_data_i;
-- tdc_debug_out_i(28)           <= buf1_wr_ch_data_i;
-- tdc_debug_out_i(29)           <= HIT_IN(0);
-- tdc_debug_out_i(31 downto 30) <= trigger_in_i;

  REG_OUTPUTS : process (clk_100_i, reset_i)
  begin
    if rising_edge(clk_100_i) then
      if reset_i = '1' then
        tdc_debug_i <= (others => '0');
      else
        tdc_debug_i <= tdc_debug_out_i;
      end if;
    end if;
  end process REG_OUTPUTS;
  TDC_DEBUG_00      <= tdc_debug_i;

end TDC;
