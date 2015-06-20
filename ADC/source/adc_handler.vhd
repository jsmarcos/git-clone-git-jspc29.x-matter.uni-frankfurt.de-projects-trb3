library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;
use work.config.all;

entity adc_handler is
  port(
    CLK              : in  std_logic;
    CLK_ADCRAW       : in  std_logic;

    --ADC
    ADCCLK_OUT       : out std_logic;
    ADC_DATA         : in  std_logic_vector((DEVICES_1 + DEVICES_2) * (CHANNELS + 1) - 1 downto 0);
    ADC_DCO          : in  std_logic_vector((DEVICES_1 + DEVICES_2) downto 1);
    --Trigger In and Out
    TRIGGER_IN       : in  std_logic;
    TRIGGER_FLAG_OUT : out std_logic;
    --Readout    
    READOUT_RX       : in  READOUT_RX;
    READOUT_TX_CFD   : out READOUT_TX;
    READOUT_TX       : out readout_tx_array_t(0 to (DEVICES_1 + DEVICES_2) - 1);

    --Slow control    
    BUS_RX           : in  CTRLBUS_RX;
    BUS_TX           : out CTRLBUS_TX;

    ADCSPI_CTRL      : out std_logic_vector(7 downto 0);
    
    ADC_CLK_TDC_OUT  : out std_logic
  );
end entity;

architecture adc_handler_arch of adc_handler is
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_hier : string;
  attribute syn_hier of adc_handler_arch : architecture is "hard";

  type psa_data_t is array (0 to DEVICES - 1) of std_logic_vector(8 downto 0);

  signal adc_data_out  : std_logic_vector(DEVICES * CHANNELS * RESOLUTION - 1 downto 0);
  signal adc_fco_out   : std_logic_vector(DEVICES * RESOLUTION - 1 downto 0);
  signal adc_valid_out : std_logic_vector(DEVICES - 1 downto 0);
  signal adc_debug     : std_logic_vector(DEVICES * 32 - 1 downto 0);

  signal ctrl_reg   : std_logic_vector(31 downto 0);
  signal strobe_reg : std_logic_vector(31 downto 0);
  attribute syn_keep of ctrl_reg : signal is true;
  attribute syn_preserve of ctrl_reg : signal is true;
  attribute syn_keep of strobe_reg : signal is true;
  attribute syn_preserve of strobe_reg : signal is true;

  signal buffer_ctrl_reg : std_logic_vector(31 downto 0);
  signal adc_restart     : std_logic;

  signal adc_trigger : std_logic_vector(DEVICES - 1 downto 0);
  signal adc_stop    : std_logic;

  signal config        : cfg_t;
  signal config_cfd    : cfg_cfd_t;
  attribute syn_keep of config : signal is true;
  attribute syn_preserve of config : signal is true;
  attribute syn_keep of config_cfd : signal is true;
  attribute syn_preserve of config_cfd : signal is true;
  signal buffer_addr   : std_logic_vector(4 downto 0);
  signal buffer_data   : buffer_data_t;
  signal buffer_read   : std_logic_vector(15 downto 0);
  signal buffer_ready  : std_logic_vector(DEVICES - 1 downto 0);
  signal buffer_device : integer range 0 to DEVICES - 1;

  signal psa_data     : std_logic_vector(8 downto 0);
  signal psa_data_out : psa_data_t;
  signal psa_write    : std_logic;
  signal psa_addr     : std_logic_vector(7 downto 0);

  type arr_4_32_t is array (0 to 3) of unsigned(31 downto 0);
  signal baseline_reset_value : arr_4_32_t := (others => (others => '0'));

  signal adc_clk                     : std_logic_vector(DEVICES downto 1) := (others => '1');
  signal adc_clk_left, adc_clk_right : std_logic                          := '1';
  
  signal epoch_counter, epoch_counter_save, epoch_counter_save_sys : unsigned(EPOCH_COUNTER_SIZE-1 downto 0) := (others => '0');
  signal trigger_in_i : std_logic;
  type state_cfd_t is (IDLE, DO_RELEASE, RELEASE_DIRECT, WAIT_FOR_END, WRITE_EPOCH);
  signal state_cfd     : state_cfd_t;
  
  signal RDO_CFD_write : std_logic := '0';
  signal RDO_CFD_data  : std_logic_vector(31 downto 0) := (others => '0');

-- 000 - 0ff configuration
--       000 reset, buffer clear strobes
--       001 buffer control reg
--       010 buffer depth  (1-1023)
--       011 number of samples after trigger arrived (0-1023 * 25ns)
--       012 number of blocks to process (1-4)
--       013 trigger generation offset (0-1023 from baseline, polarity)
--       014 read-out threshold (0-1023 from baseline, polarity)
--       015 number of values to sum before storing
--       016 baseline averaging (2**N)
--       017 - 018 trigger generation channel enable
--       019 check words
--       01a - 01b channel disable
--       01c processing mode: 0: normal block mode, 1: pulse shape processing
--       020 - 023 number of values to sum  (1-255)
--       024 - 027 number of sums           (1-255)
--       028 - 02b 2^k scaling factor       (0-8)
--       02c - 02f 
--       080 ADC control: SPI, power
-- 100 - 1ff status
--       100 clock valid (1 bit per ADC)
--       101 fco valid (1 bit per ADC)
--       102 readout state
-- 200 - 2ff pulse shape multiplicators
-- 800 - 83f last ADC values              (local 0x0 - 0x3)
-- 840 - 87f long-term average / baseline (local 0x4 - 0x7)
-- 880 - 8bf fifo access (debugging only) (local 0x8 - 0xb)
-- 8c0 - 8ff invalid word count           (local 0xc - 0xf)
-- 900 - 9ff processor registers          (local 0x10 - 0x1f)


begin
  THE_ADC_LEFT : entity work.adc_ad9219
    generic map(
      NUM_DEVICES => DEVICES_1
    )
    port map(
      CLK                                                                      => CLK,
      CLK_ADCRAW                                                               => CLK_ADCRAW,
      RESTART_IN                                                               => adc_restart,
      ADCCLK_OUT                                                               => adc_clk_left,
      --FCO is another channel for each ADC    
      ADC_DATA(4 downto 0)                                                     => ADC_DATA(4 downto 0),
      ADC_DATA(9 downto 5)                                                     => ADC_DATA(9 downto 5),
      ADC_DATA(14 downto 10)                                                   => ADC_DATA(14 downto 10),
      ADC_DATA(19 downto 15)                                                   => ADC_DATA(19 downto 15),
      ADC_DATA(24 downto 20)                                                   => ADC_DATA(24 downto 20),
      ADC_DATA(29 downto 25)                                                   => ADC_DATA(29 downto 25),
      ADC_DATA(34 downto 30)                                                   => ADC_DATA(39 downto 35),
      ADC_DCO(6 downto 1)                                                      => ADC_DCO(6 downto 1),
      ADC_DCO(7)                                                               => ADC_DCO(8),
      DATA_OUT(6 * CHANNELS * RESOLUTION - 1 downto 0)                         => adc_data_out(6 * CHANNELS * RESOLUTION - 1 downto 0),
      DATA_OUT(7 * CHANNELS * RESOLUTION - 1 downto 6 * CHANNELS * RESOLUTION) => adc_data_out(8 * CHANNELS * RESOLUTION - 1 downto 7 * CHANNELS * RESOLUTION),
      FCO_OUT(6 * RESOLUTION - 1 downto 0)                                     => adc_fco_out(6 * RESOLUTION - 1 downto 0),
      FCO_OUT(7 * RESOLUTION - 1 downto 6 * RESOLUTION)                        => adc_fco_out(8 * RESOLUTION - 1 downto 7 * RESOLUTION),
      DATA_VALID_OUT(5 downto 0)                                               => adc_valid_out(5 downto 0),
      DATA_VALID_OUT(6)                                                        => adc_valid_out(7),
      DEBUG(32 * 6 - 1 downto 0)                                               => adc_debug(32 * 6 - 1 downto 0),
      DEBUG(32 * 7 - 1 downto 32 * 6)                                          => adc_debug(32 * 8 - 1 downto 32 * 7)
    );

  THE_ADC_RIGHT : entity work.adc_ad9219
    generic map(
      NUM_DEVICES => DEVICES_2
    )
    port map(
      CLK                                                                      => CLK,
      CLK_ADCRAW                                                               => CLK_ADCRAW,
      RESTART_IN                                                               => adc_restart,
      ADCCLK_OUT                                                               => adc_clk_right,
      --FCO is another channel for each ADC    
      ADC_DATA(4 downto 0)                                                     => ADC_DATA(34 downto 30),
      ADC_DATA(9 downto 5)                                                     => ADC_DATA(44 downto 40),
      ADC_DATA(14 downto 10)                                                   => ADC_DATA(49 downto 45),
      ADC_DATA(19 downto 15)                                                   => ADC_DATA(54 downto 50),
      ADC_DATA(24 downto 20)                                                   => ADC_DATA(59 downto 55),
      ADC_DCO(1)                                                               => ADC_DCO(7),
      ADC_DCO(5 downto 2)                                                      => ADC_DCO(12 downto 9),
      DATA_OUT(1 * CHANNELS * RESOLUTION - 1 downto 0)                         => adc_data_out(7 * CHANNELS * RESOLUTION - 1 downto 6 * CHANNELS * RESOLUTION),
      DATA_OUT(5 * CHANNELS * RESOLUTION - 1 downto 1 * CHANNELS * RESOLUTION) => adc_data_out(12 * CHANNELS * RESOLUTION - 1 downto 8 * CHANNELS * RESOLUTION),
      FCO_OUT(1 * RESOLUTION - 1 downto 0)                                     => adc_fco_out(7 * RESOLUTION - 1 downto 6 * RESOLUTION),
      FCO_OUT(5 * RESOLUTION - 1 downto 1 * RESOLUTION)                        => adc_fco_out(12 * RESOLUTION - 1 downto 8 * RESOLUTION),
      DATA_VALID_OUT(0)                                                        => adc_valid_out(6),
      DATA_VALID_OUT(4 downto 1)                                               => adc_valid_out(11 downto 8),
      DEBUG(32 * 1 - 1 downto 0)                                               => adc_debug(32 * 7 - 1 downto 32 * 6),
      DEBUG(32 * 5 - 1 downto 32 * 1)                                          => adc_debug(32 * 12 - 1 downto 32 * 8)
    );

  ADCCLK_OUT           <= adc_clk_left;
  adc_clk(6 downto 1)  <= (others => adc_clk_left);
  adc_clk(8)           <= adc_clk_left;
  adc_clk(12 downto 9) <= (others => adc_clk_right);
  adc_clk(7)           <= adc_clk_right;

  --------------------------------------------
  -- For both readout modes
  --------------------------------------------

  TRIGGER_FLAG_OUT <= or_all(adc_trigger);
  ADCSPI_CTRL      <= ctrl_reg(7 downto 0);

  --------------------------------------------
  -- PSA readout mode
  --------------------------------------------
  gen_readout_psa : if READOUT_MODE = READOUT_MODE_PSA generate
    gen_processors : for i in 0 to DEVICES - 1 generate
      THE_ADC_PROC : entity work.adc_processor
        generic map(
          DEVICE => i
        )
        port map(
          CLK                   => CLK,
          ADC_DATA              => adc_data_out((i + 1) * RESOLUTION * CHANNELS - 1 downto i * RESOLUTION * CHANNELS),
          ADC_VALID             => adc_valid_out(i),
          STOP_IN               => adc_stop,
          TRIGGER_OUT           => adc_trigger(i),
          CONTROL(31 downto 0)  => strobe_reg,
          CONTROL(63 downto 32) => buffer_ctrl_reg,
          CONFIG                => config, --trigger offset, zero sup offset, depth, 

          PSA_DATA              => psa_data,
          PSA_DATA_OUT          => psa_data_out(i),
          PSA_ADDR              => psa_addr,
          PSA_WRITE             => psa_write,
          DEBUG_BUFFER_ADDR     => buffer_addr,
          DEBUG_BUFFER_READ     => buffer_read(i),
          DEBUG_BUFFER_DATA     => buffer_data(i),
          DEBUG_BUFFER_READY    => buffer_ready(i),
          READOUT_RX            => READOUT_RX,
          READOUT_TX            => READOUT_TX(i)
        );
    end generate;

    adc_stop                  <= buffer_ctrl_reg(0);
    config.baseline_always_on <= buffer_ctrl_reg(4);

    READOUT_TX_CFD.data_finished <= '1';

    PROC_BUS : process
    begin
      wait until rising_edge(CLK);
      BUS_TX.ack     <= '0';
      BUS_TX.nack    <= '0';
      BUS_TX.unknown <= '0';
      buffer_read    <= (others => '0');
      strobe_reg     <= (others => '0');
      psa_write      <= '0';
      if or_all(buffer_ready) = '1' then
        BUS_TX.data <= buffer_data(buffer_device);
        BUS_TX.ack  <= '1';
      elsif BUS_RX.read = '1' then
        if BUS_RX.addr <= x"000f" then
          BUS_TX.ack <= '1';
          case BUS_RX.addr(3 downto 0) is
            when x"1"   => BUS_TX.data <= buffer_ctrl_reg;
            when others => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr = x"0080" then
          BUS_TX.data <= ctrl_reg;
          BUS_TX.ack  <= '1';
        elsif BUS_RX.addr >= x"0010" and BUS_RX.addr <= x"001f" then --basic config registers
          BUS_TX.ack  <= '1';
          BUS_TX.data <= (others => '0');
          case BUS_RX.addr(7 downto 0) is
            when x"10" => BUS_TX.data(10 downto 0) <= std_logic_vector(config.buffer_depth);
            when x"11" => BUS_TX.data(10 downto 0) <= std_logic_vector(config.samples_after);
            when x"12" => BUS_TX.data(1 downto 0) <= std_logic_vector(config.block_count);
            when x"13" => BUS_TX.data(17 downto 0) <= std_logic_vector(config.trigger_threshold);
            when x"14" => BUS_TX.data(17 downto 0) <= std_logic_vector(config.readout_threshold);
            when x"15" => BUS_TX.data(7 downto 0) <= std_logic_vector(config.presum);
            when x"16" => BUS_TX.data(3 downto 0) <= std_logic_vector(config.averaging);
            when x"17" => BUS_TX.data(31 downto 0) <= config.trigger_enable(31 downto 0);
            when x"18" => BUS_TX.data(15 downto 0) <= config.trigger_enable(47 downto 32);
            when x"19" => BUS_TX.data(RESOLUTION - 1 downto 0) <= config.check_word1;
              BUS_TX.data(RESOLUTION - 1 + 16 downto 16) <= config.check_word2;
              BUS_TX.data(31)                            <= config.check_word_enable;
            when x"1a" => BUS_TX.data(31 downto 0)       <= config.channel_disable(31 downto 0);
            when x"1b" => BUS_TX.data(15 downto 0)       <= config.channel_disable(47 downto 32);
            when x"1c" => BUS_TX.data(1 downto 0)        <= std_logic_vector(to_unsigned(config.processing_mode, 2));
            when x"1d" => BUS_TX.data(7 downto 0)        <= std_logic_vector(config.cfd_window);
              BUS_TX.data(11 downto 8)                   <= std_logic_vector(config.cfd_delay);
            when others => BUS_TX.ack                    <= '0';
              BUS_TX.unknown                             <= '1';
          end case;
        elsif BUS_RX.addr >= x"0020" and BUS_RX.addr <= x"002f" then
          BUS_TX.ack  <= '1';
          BUS_TX.data <= (others => '0');
          case BUS_RX.addr(3 downto 2) is
            when "00" => BUS_TX.data(7 downto 0) <= std_logic_vector(config.block_avg(to_integer(unsigned(BUS_RX.addr(1 downto 0)))));
            when "01" => BUS_TX.data(7 downto 0) <= std_logic_vector(config.block_sums(to_integer(unsigned(BUS_RX.addr(1 downto 0)))));
            when "10" => BUS_TX.data(7 downto 0) <= std_logic_vector(config.block_scale(to_integer(unsigned(BUS_RX.addr(1 downto 0)))));
            when "11" => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr >= x"0030" and BUS_RX.addr <= x"003b" then
          BUS_TX.ack  <= '1';
          BUS_TX.data <= adc_debug(to_integer(unsigned(BUS_RX.addr(3 downto 0))) * 32 + 31 downto to_integer(unsigned(BUS_RX.addr(3 downto 0))) * 32);
        elsif BUS_RX.addr >= x"0800" and BUS_RX.addr <= x"08ff" and BUS_RX.addr(5 downto 0) < std_logic_vector(to_unsigned(DEVICES * CHANNELS, 6)) then
          buffer_device                                              <= to_integer(unsigned(BUS_RX.addr(5 downto 2)));
          buffer_addr                                                <= '0' & BUS_RX.addr(7 downto 6) & BUS_RX.addr(1 downto 0);
          buffer_read(to_integer(unsigned(BUS_RX.addr(5 downto 2)))) <= '1';
        elsif BUS_RX.addr >= x"0900" and BUS_RX.addr <= x"09ff" then
          if BUS_RX.addr(3 downto 0) < std_logic_vector(to_unsigned(DEVICES, 4)) then
            buffer_device                                              <= to_integer(unsigned(BUS_RX.addr(3 downto 0)));
            buffer_addr                                                <= '1' & BUS_RX.addr(7 downto 4);
            buffer_read(to_integer(unsigned(BUS_RX.addr(3 downto 0)))) <= '1';
          else
            BUS_TX.data <= (others => '0');
            BUS_TX.ack  <= '1';
          end if;
        else
          BUS_TX.unknown <= '1';
        end if;

      elsif BUS_RX.write = '1' then
        if BUS_RX.addr >= x"0010" and BUS_RX.addr <= x"001f" then --basic config registers
          BUS_TX.ack <= '1';
          case BUS_RX.addr(7 downto 0) is
            when x"10" => config.buffer_depth <= unsigned(BUS_RX.data(10 downto 0));
            when x"11" => config.samples_after <= unsigned(BUS_RX.data(10 downto 0));
            when x"12" => config.block_count <= unsigned(BUS_RX.data(1 downto 0));
            when x"13" => config.trigger_threshold <= unsigned(BUS_RX.data(17 downto 0));
            when x"14" => config.readout_threshold <= unsigned(BUS_RX.data(17 downto 0));
            when x"15" => config.presum <= unsigned(BUS_RX.data(7 downto 0));
            when x"16" => config.averaging <= unsigned(BUS_RX.data(3 downto 0));
            when x"17" => config.trigger_enable(31 downto 0) <= BUS_RX.data(31 downto 0);
            when x"18" => config.trigger_enable(47 downto 32) <= BUS_RX.data(15 downto 0);
            when x"19" => config.check_word1 <= BUS_RX.data(RESOLUTION - 1 downto 0);
              config.check_word2                               <= BUS_RX.data(RESOLUTION - 1 + 16 downto 16);
              config.check_word_enable                         <= BUS_RX.data(31);
            when x"1a" => config.channel_disable(31 downto 0)  <= BUS_RX.data(31 downto 0);
            when x"1b" => config.channel_disable(47 downto 32) <= BUS_RX.data(15 downto 0);
            when x"1c" => config.processing_mode               <= to_integer(unsigned(BUS_RX.data(1 downto 0)));
            when x"1d" => config.cfd_window                    <= unsigned(BUS_RX.data(7 downto 0));
              config.cfd_delay                                 <= unsigned(BUS_RX.data(11 downto 8));
            when others => BUS_TX.ack                          <= '0';
              BUS_TX.unknown                                   <= '1';
          end case;
        elsif BUS_RX.addr >= x"0020" and BUS_RX.addr <= x"002f" then
          BUS_TX.ack  <= '1';
          BUS_TX.data <= (others => '0');
          case BUS_RX.addr(3 downto 2) is
            when "00" => config.block_avg(to_integer(unsigned(BUS_RX.addr(1 downto 0)))) <= unsigned(BUS_RX.data(7 downto 0));
            when "01" => config.block_sums(to_integer(unsigned(BUS_RX.addr(1 downto 0)))) <= unsigned(BUS_RX.data(7 downto 0));
            when "10" => config.block_scale(to_integer(unsigned(BUS_RX.addr(1 downto 0)))) <= unsigned(BUS_RX.data(7 downto 0));
            when "11" => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr <= x"000f" then
          BUS_TX.ack <= '1';
          case BUS_RX.addr(3 downto 0) is
            when x"0"   => strobe_reg <= BUS_RX.data;
            when x"1"   => buffer_ctrl_reg <= BUS_RX.data;
            when others => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr = x"0080" then
          ctrl_reg   <= BUS_RX.data;
          BUS_TX.ack <= '1';
        elsif BUS_RX.addr >= x"0200" and BUS_RX.addr <= x"02FF" then
          psa_data   <= BUS_RX.data(8 downto 0);
          psa_write  <= '1';
          psa_addr   <= BUS_RX.addr(7 downto 0);
          BUS_TX.ack <= '1';
        else
          BUS_TX.unknown <= '1';
        end if;
      end if;
    end process;

    proc_baseline_reset_value : process
    begin
      wait until rising_edge(CLK);
      baseline_reset_value(3)                                                                                    <= (others => '0');
      baseline_reset_value(3)(to_integer(config.averaging) + RESOLUTION - 1 downto to_integer(config.averaging)) <= (others => not config.trigger_threshold(16));
      baseline_reset_value(2)                                                                                    <= baseline_reset_value(3);
      baseline_reset_value(1)                                                                                    <= baseline_reset_value(2)(23 downto 0) * resize(config.presum + 1, 8);
      baseline_reset_value(0)                                                                                    <= baseline_reset_value(1);
    end process;
    config.baseline_reset_value <= baseline_reset_value(0);

  end generate;

  --------------------------------------------
  -- CFD readout mode
  --------------------------------------------

  gen_readout_cfd : if READOUT_MODE = READOUT_MODE_CFD generate
    gen_processors : for i in 0 to DEVICES - 1 generate
      THE_ADC_PROC : entity work.adc_processor_cfd
        generic map(
          DEVICE => i
        )
        port map(
          CLK_SYS               => CLK,
          CLK_ADC               => adc_clk(i+1),
          ADC_DATA              => adc_data_out((i + 1) * RESOLUTION * CHANNELS - 1 downto i * RESOLUTION * CHANNELS),
          TRIGGER_OUT           => adc_trigger(i),
          CONTROL(31 downto 0)  => strobe_reg,
          CONTROL(63 downto 32) => buffer_ctrl_reg,
          CONFIG                => config_cfd, --trigger offset, zero sup offset, depth, 

          DEBUG_BUFFER_ADDR     => buffer_addr,
          DEBUG_BUFFER_READ     => buffer_read(i),
          DEBUG_BUFFER_DATA     => buffer_data(i),
          DEBUG_BUFFER_READY    => buffer_ready(i),
          READOUT_RX            => READOUT_RX,
          READOUT_TX            => READOUT_TX(i),
          EPOCH_COUNTER_IN      => epoch_counter
        );
    end generate;
    
    PROC_EPOCH_COUNTER : process is
    begin
      wait until rising_edge(adc_clk_left);
      epoch_counter <= epoch_counter + 1;
      trigger_in_i <= TRIGGER_IN;
      ADC_CLK_TDC_OUT <= '0';
      if trigger_in_i = '1' then
        epoch_counter_save <= epoch_counter;
        ADC_CLK_TDC_OUT <= '1';
      end if;
    end process PROC_EPOCH_COUNTER;
    
    PROC_READOUT_CFD : process is
    begin
      wait until rising_edge(CLK);
      epoch_counter_save_sys <= epoch_counter_save;
      READOUT_TX_CFD.busy_release  <= '0';
      READOUT_TX_CFD.data_finished <= '0';
      READOUT_TX_CFD.data          <= RDO_CFD_data;
      READOUT_TX_CFD.data_write    <= RDO_CFD_write;
      RDO_CFD_data          <= (others => '0');
      RDO_CFD_write    <= '0';
      
      case state_cfd is
        when IDLE =>
          READOUT_TX_CFD.statusbits <= (others => '0');
          if READOUT_RX.valid_notiming_trg = '1' then
            state_cfd <= RELEASE_DIRECT;
          elsif READOUT_RX.data_valid = '1' then --seems to have missed trigger...
            READOUT_TX_CFD.statusbits <= (23 => '1', others => '0'); --event not found
            state_cfd                 <= RELEASE_DIRECT;
          elsif READOUT_RX.valid_timing_trg = '1' then
            state_cfd <= WRITE_EPOCH;
          end if;

        when RELEASE_DIRECT =>
          state_cfd <= DO_RELEASE;

        when DO_RELEASE =>
          if READOUT_RX.data_valid = '1' then
            READOUT_TX_CFD.busy_release  <= '1';
            READOUT_TX_CFD.data_finished <= '1';
            state_cfd                    <= WAIT_FOR_END;
          end if;

        when WAIT_FOR_END =>
          if READOUT_RX.data_valid = '0' then
            state_cfd <= IDLE;
          end if;
        
        when WRITE_EPOCH =>
          RDO_CFD_data <= x"1" & std_logic_vector(resize(epoch_counter_save_sys,28));
          RDO_CFD_write <= '1';
          state_cfd <= RELEASE_DIRECT;
      end case;
    end process PROC_READOUT_CFD;
    


    config_cfd.BaselineAlwaysOn <= buffer_ctrl_reg(4);

    PROC_BUS : process
    begin
      wait until rising_edge(CLK);
      BUS_TX.ack     <= '0';
      BUS_TX.nack    <= '0';
      BUS_TX.unknown <= '0';
      buffer_read    <= (others => '0');
      strobe_reg     <= (others => '0');
      if or_all(buffer_ready) = '1' then
        BUS_TX.data <= buffer_data(buffer_device);
        BUS_TX.ack  <= '1';
      elsif BUS_RX.read = '1' then
        if BUS_RX.addr <= x"000f" then
          BUS_TX.ack <= '1';
          case BUS_RX.addr(3 downto 0) is
            when x"1"   => BUS_TX.data <= buffer_ctrl_reg;
            when others => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr = x"0080" then
          BUS_TX.data <= ctrl_reg;
          BUS_TX.ack  <= '1';
        elsif BUS_RX.addr >= x"0010" and BUS_RX.addr <= x"001f" then --basic config registers
          BUS_TX.ack  <= '1';
          BUS_TX.data <= (others => '0');
          case BUS_RX.addr(7 downto 0) is
            when x"10" => BUS_TX.data(7 downto 0)              <= std_logic_vector(config_cfd.DebugSamples);
            when x"11" => BUS_TX.data(11 downto 0)             <= std_logic_vector(config_cfd.TriggerDelay);
            when x"13" =>
              BUS_TX.data(9 downto 0)                          <= std_logic_vector(config_cfd.InputThreshold);
              BUS_TX.data(17)                                  <= config_cfd.PolarityInvert;
            when x"16" => BUS_TX.data(4 downto 0)              <= std_logic_vector(config_cfd.BaselineAverage);
            when x"17" => BUS_TX.data(31 downto 0)             <= config_cfd.TriggerEnable(31 downto 0);
            when x"18" => BUS_TX.data(15 downto 0)             <= config_cfd.TriggerEnable(47 downto 32);
            when x"19" => BUS_TX.data(RESOLUTION - 1 downto 0) <= config_cfd.CheckWord1;
              BUS_TX.data(RESOLUTION - 1 + 16 downto 16)       <= config_cfd.CheckWord2;
              BUS_TX.data(31)                                  <= config_cfd.CheckWordEnable;
            when x"1a" => BUS_TX.data(31 downto 0)             <= config_cfd.ChannelDisable(31 downto 0);
            when x"1b" => BUS_TX.data(15 downto 0)             <= config_cfd.ChannelDisable(47 downto 32);
            when x"1c" => BUS_TX.data(1 downto 0)              <= std_logic_vector(to_unsigned(config_cfd.DebugMode, 2));
            when x"1d" =>
              BUS_TX.data(7 downto 0)   <= std_logic_vector(config_cfd.IntegrateWindow);
              BUS_TX.data(12 downto 8)  <= std_logic_vector(resize(config_cfd.CFDDelay,5));
              BUS_TX.data(16 downto 13) <= std_logic_vector(resize(config_cfd.CFDMult,4));
              BUS_TX.data(20 downto 17) <= std_logic_vector(resize(config_cfd.CFDMultDly,4));
            when others =>
              BUS_TX.ack     <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr >= x"0030" and BUS_RX.addr <= x"003b" then
          BUS_TX.ack  <= '1';
          BUS_TX.data <= adc_debug(to_integer(unsigned(BUS_RX.addr(3 downto 0))) * 32 + 31 downto to_integer(unsigned(BUS_RX.addr(3 downto 0))) * 32);
        elsif BUS_RX.addr >= x"0800" and BUS_RX.addr <= x"08ff" and BUS_RX.addr(5 downto 0) < std_logic_vector(to_unsigned(DEVICES * CHANNELS, 6)) then
          buffer_device                                              <= to_integer(unsigned(BUS_RX.addr(5 downto 2)));
          buffer_addr                                                <= '0' & BUS_RX.addr(7 downto 6) & BUS_RX.addr(1 downto 0);
          buffer_read(to_integer(unsigned(BUS_RX.addr(5 downto 2)))) <= '1';
        elsif BUS_RX.addr >= x"0900" and BUS_RX.addr <= x"09ff" then
          if BUS_RX.addr(3 downto 0) < std_logic_vector(to_unsigned(DEVICES, 4)) then
            buffer_device                                              <= to_integer(unsigned(BUS_RX.addr(3 downto 0)));
            buffer_addr                                                <= '1' & BUS_RX.addr(7 downto 4);
            buffer_read(to_integer(unsigned(BUS_RX.addr(3 downto 0)))) <= '1';
          else
            BUS_TX.data <= (others => '0');
            BUS_TX.ack  <= '1';
          end if;
        else
          BUS_TX.unknown <= '1';
        end if;

      elsif BUS_RX.write = '1' then
        if BUS_RX.addr >= x"0010" and BUS_RX.addr <= x"001f" then --basic config registers
          BUS_TX.ack <= '1';
          case BUS_RX.addr(7 downto 0) is
            when x"10" => config_cfd.DebugSamples <= unsigned(BUS_RX.data(7 downto 0));
            when x"11" => config_cfd.TriggerDelay <= unsigned(BUS_RX.data(11 downto 0));
            when x"13" =>
              config_cfd.InputThreshold                          <= unsigned(BUS_RX.data(9 downto 0));
              config_cfd.PolarityInvert                          <= BUS_RX.data(17);
            when x"16" => config_cfd.BaselineAverage             <= unsigned(BUS_RX.data(4 downto 0));
            when x"17" => config_cfd.TriggerEnable(31 downto 0)  <= BUS_RX.data(31 downto 0);
            when x"18" => config_cfd.TriggerEnable(47 downto 32) <= BUS_RX.data(15 downto 0);
            when x"19" =>
              config_cfd.CheckWord1                               <= BUS_RX.data(RESOLUTION - 1 downto 0);
              config_cfd.CheckWord2                               <= BUS_RX.data(RESOLUTION - 1 + 16 downto 16);
              config_cfd.CheckWordEnable                          <= BUS_RX.data(31);
            when x"1a" => config_cfd.ChannelDisable(31 downto 0)  <= BUS_RX.data(31 downto 0);
            when x"1b" => config_cfd.ChannelDisable(47 downto 32) <= BUS_RX.data(15 downto 0);
            when x"1c" => config_cfd.DebugMode                    <= to_integer(unsigned(BUS_RX.data(1 downto 0)));  
            when x"1d" =>
              config_cfd.IntegrateWindow <= unsigned(BUS_RX.data(7 downto 0));
              config_cfd.CFDDelay        <= resize(unsigned(BUS_RX.data(12 downto  8)), config_cfd.CFDDelay'length);
              config_cfd.CFDMult         <= resize(unsigned(BUS_RX.data(16 downto 13)), config_cfd.CFDMult'length);
              config_cfd.CFDMultDly      <= resize(unsigned(BUS_RX.data(20 downto 17)), config.CFDMult'length);
            when others => BUS_TX.ack    <= '0';
              BUS_TX.unknown             <= '1';
          end case;
        elsif BUS_RX.addr <= x"000f" then
          BUS_TX.ack <= '1';
          case BUS_RX.addr(3 downto 0) is
            when x"0"   => strobe_reg <= BUS_RX.data;
            when x"1"   => buffer_ctrl_reg <= BUS_RX.data;
            when others => BUS_TX.ack <= '0';
              BUS_TX.unknown <= '1';
          end case;
        elsif BUS_RX.addr = x"0080" then
          ctrl_reg   <= BUS_RX.data;
          BUS_TX.ack <= '1';
        else
          BUS_TX.unknown <= '1';
        end if;
      end if;
    end process;

  end generate;

end architecture;

--   type CTRLBUS_TX is record
--     data       : std_logic_vector(31 downto 0);
--     ack        : std_logic;
--     wack,rack  : std_logic; --for the old-fashioned guys
--     unknown    : std_logic;
--     nack       : std_logic;
--   end record;
-- 
--   type CTRLBUS_RX is record
--     data       : std_logic_vector(31 downto 0);
--     addr       : std_logic_vector(15 downto 0);
--     write      : std_logic;
--     read       : std_logic;
--     timeout    : std_logic;
--   end record; 
-- 
--   
