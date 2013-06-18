-------------------------------------------------------------------------------
-- Title      : Channel 200 MHz Part
-- Project    : 
-------------------------------------------------------------------------------
-- File       : Channel_200.vhd
-- Author     : c.ugur@gsi.de
-- Created    : 2012-08-28
-- Last update: 2013-05-06
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;
use work.version.all;

entity Channel_200 is

  generic (
    CHANNEL_ID : integer range 0 to 64);  
  port (
    CLK_200              : in  std_logic;  -- 200 MHz clk
    RESET_200            : in  std_logic;  -- reset sync with 200Mhz clk
    CLK_100              : in  std_logic;  -- 100 MHz clk
    RESET_100            : in  std_logic;  -- reset sync with 100Mhz clk
--
    HIT_IN               : in  std_logic;  -- hit in
    TRIGGER_WIN_END_IN   : in  std_logic;  -- trigger in
    EPOCH_COUNTER_IN     : in  std_logic_vector(27 downto 0);  -- system coarse counter
--    DATA_FINISHED_IN     : in  std_logic;
    COARSE_COUNTER_IN    : in  std_logic_vector(10 downto 0);
    READ_EN_IN           : in  std_logic;  -- read en signal
    FIFO_DATA_OUT        : out std_logic_vector(35 downto 0);  -- fifo data out
    FIFO_WCNT_OUT        : out unsigned(7 downto 0);  -- fifo write counter out
    FIFO_EMPTY_OUT       : out std_logic;  -- fifo empty signal
    FIFO_FULL_OUT        : out std_logic;  -- fifo full signal
    FIFO_ALMOST_FULL_OUT : out std_logic;
--
    ENCODER_START_OUT    : out std_logic;
    ENCODER_FINISHED_OUT : out std_logic);


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
  signal time_stamp_i    : std_logic_vector(10 downto 0);
  signal coarse_cntr_reg : std_logic_vector(10 downto 0);

  -- encoder
  signal encoder_start_i    : std_logic;
  signal encoder_finished_i : std_logic;
  signal encoder_data_out_i : std_logic_vector(9 downto 0);
  signal encoder_info_i     : std_logic_vector(1 downto 0);
  signal encoder_debug_i    : std_logic_vector(31 downto 0);

  -- epoch counter
  signal epoch_cntr         : std_logic_vector(27 downto 0);
  signal epoch_cntr_updated : std_logic := '0';
  signal epoch_capture_time : std_logic_vector(10 downto 0);

  -- fifo
  signal fifo_data_out_i    : std_logic_vector(35 downto 0);
  signal fifo_data_in_i     : std_logic_vector(35 downto 0);
  signal fifo_wcnt_i        : std_logic_vector(7 downto 0);
  signal fifo_empty_i       : std_logic;
  signal fifo_full_i        : std_logic;
  signal fifo_almost_full_i : std_logic := '0';
  signal fifo_wr_en_i       : std_logic;
  signal fifo_rd_en_i       : std_logic;

  -- fsm
  type   FSM is (WRITE_EPOCH, WRITE_DATA, WAIT_FOR_HIT);
  signal FSM_CURRENT     : FSM := WRITE_EPOCH;
  signal FSM_NEXT        : FSM;
  signal write_epoch_fsm : std_logic;
  signal write_epoch_i   : std_logic;
  signal write_data_fsm  : std_logic;
  signal write_data_i    : std_logic;
  signal fsm_debug_fsm   : std_logic_vector(1 downto 0);
  signal fsm_debug_i     : std_logic_vector(1 downto 0);

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
  ff_array_en_i <= not(hit_detect_i or hit_detect_reg);  -- or hit_detect_2reg);

  result_2_reg      <= result_i(2)       when rising_edge(CLK_200);
  hit_detect_i      <= (not result_2_reg) and result_i(2);  -- detects the hit by
                                                            -- comparing the
                                        -- previous state of the
                                        -- hit detection bit
  hit_detect_reg    <= hit_detect_i      when rising_edge(CLK_200);
  hit_detect_2reg   <= hit_detect_reg    when rising_edge(CLK_200);
  coarse_cntr_reg   <= COARSE_COUNTER_IN when rising_edge(CLK_200);
  encoder_start_i   <= hit_detect_i;
  ENCODER_START_OUT <= encoder_start_i;

  TimeStampCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if hit_detect_reg = '1' then
        time_stamp_i <= coarse_cntr_reg;
      end if;
    end if;
  end process TimeStampCapture;

  epoch_capture_time <= "00000000111";

  EpochCounterCapture : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if coarse_cntr_reg = epoch_capture_time or TRIGGER_WIN_END_IN = '1' then  --DATA_FINISHED_IN = '1' then
        epoch_cntr         <= EPOCH_COUNTER_IN;
        epoch_cntr_updated <= '1';
      elsif write_epoch_i = '1' then
        epoch_cntr_updated <= '0';
      end if;
    end if;
  end process EpochCounterCapture;

  --purpose: Encoder
  Encoder : Encoder_304_Bit
    port map (
      RESET            => RESET_200,
      CLK              => CLK_200,
      START_IN         => encoder_start_i,
      THERMOCODE_IN    => result_i,
      FINISHED_OUT     => encoder_finished_i,
      BINARY_CODE_OUT  => encoder_data_out_i,
      ENCODER_INFO_OUT => encoder_info_i,
      ENCODER_DEBUG    => encoder_debug_i);

  FIFO : FIFO_36x128_OutReg_Counter
    port map (
      Data    => fifo_data_in_i,
      WrClock => CLK_200,
      RdClock => CLK_100,
      WrEn    => fifo_wr_en_i,
      RdEn    => fifo_rd_en_i,
      Reset   => RESET_100,
      RPReset => RESET_200,
      Q       => fifo_data_out_i,
      WCNT    => fifo_wcnt_i,
      Empty   => fifo_empty_i,
      Full    => fifo_full_i);

  fifo_rd_en_i <= READ_EN_IN or fifo_full_i;

  -- Readout fsm
  FSM_CLK : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      FSM_CURRENT   <= FSM_NEXT;
      write_epoch_i <= write_epoch_fsm;
      write_data_i  <= write_data_fsm;
      fsm_debug_i   <= fsm_debug_fsm;
    end if;
  end process FSM_CLK;

  FSM_PROC : process (FSM_CURRENT, encoder_finished_i, epoch_cntr_updated)  --, TRIGGER_IN)
  begin

    FSM_NEXT        <= WAIT_FOR_HIT;
    write_epoch_fsm <= '0';
    write_data_fsm  <= '0';
    fsm_debug_fsm   <= "00";

    case (FSM_CURRENT) is
      when WRITE_EPOCH =>
        if encoder_finished_i = '1' then
          write_epoch_fsm <= '1';
          FSM_NEXT        <= WRITE_DATA;
        else
          write_epoch_fsm <= '0';
          FSM_NEXT        <= WRITE_EPOCH;
        end if;
        fsm_debug_fsm <= "01";

      when WRITE_DATA =>
        write_data_fsm <= '1';
        FSM_NEXT       <= WAIT_FOR_HIT;
        fsm_debug_fsm  <= "10";

      when WAIT_FOR_HIT =>
        if epoch_cntr_updated = '1' then  -- or TRIGGER_IN = '1' then
          FSM_NEXT <= WRITE_EPOCH;
        else
          if encoder_finished_i = '1' and epoch_cntr_updated = '1' then
            write_epoch_fsm <= '1';
            FSM_NEXT        <= WRITE_DATA;
          elsif encoder_finished_i = '1' and epoch_cntr_updated = '0' then
            write_data_fsm <= '1';
            FSM_NEXT       <= WAIT_FOR_HIT;
          else
            write_data_fsm <= '0';
            FSM_NEXT       <= WAIT_FOR_HIT;
          end if;
        end if;
        fsm_debug_fsm <= "11";

      when others =>
        FSM_NEXT      <= WRITE_EPOCH;
        fsm_debug_fsm <= "00";
    end case;
  end process FSM_PROC;

  -- purpose: Generate Fifo Wr Signal
  FifoWriteSignal : process (CLK_200)
  begin
    if rising_edge(CLK_200) then
      if write_epoch_i = '1' then
        fifo_data_in_i(31 downto 29) <= "011";
        fifo_data_in_i(28)           <= '0';
        fifo_data_in_i(27 downto 0)  <= epoch_cntr;
        fifo_wr_en_i                 <= '1';
      elsif write_data_i = '1' then
        fifo_data_in_i(31)           <= '1';                -- data marker
        fifo_data_in_i(30)           <= '0';                -- reserved bits
        fifo_data_in_i(29)           <= encoder_info_i(0);  -- low resolution info bit
        fifo_data_in_i(28 downto 22) <= std_logic_vector(to_unsigned(CHANNEL_ID, 7));  -- channel number
        fifo_data_in_i(21 downto 12) <= encoder_data_out_i;  -- fine time from the encoder
        fifo_data_in_i(11)           <= '1';  --edge_type_i;  -- rising '1' or falling '0' edge
        fifo_data_in_i(10 downto 0)  <= time_stamp_i;       -- hit time stamp
        fifo_wr_en_i                 <= '1';
      else
        fifo_data_in_i <= (others => '0');
        fifo_wr_en_i   <= '0';
      end if;
    end if;
  end process FifoWriteSignal;

  ENCODER_FINISHED_OUT <= encoder_finished_i;

  RegisterOutputs : process (CLK_100)
  begin
    if rising_edge(CLK_100) then
      FIFO_DATA_OUT        <= fifo_data_out_i;
      FIFO_WCNT_OUT        <= unsigned(fifo_wcnt_i);
      FIFO_EMPTY_OUT       <= fifo_empty_i;
      FIFO_FULL_OUT        <= fifo_full_i;
      FIFO_ALMOST_FULL_OUT <= fifo_almost_full_i;
    end if;
  end process RegisterOutputs;

end Channel_200;
