library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;
use work.config.all;

entity adc_ad9219 is
  generic(
    NUM_DEVICES : integer := 5
  );
  port(
    CLK            : in  std_logic;
    CLK_ADCRAW     : in  std_logic;
    RESTART_IN     : in  std_logic;
    ADCCLK_OUT     : out std_logic;
    --FCO is another channel for each ADC    
    ADC_DATA       : in  std_logic_vector(NUM_DEVICES * (CHANNELS + 1) - 1 downto 0);
    ADC_DCO        : in  std_logic_vector(NUM_DEVICES downto 1);

    DATA_OUT       : out std_logic_vector(NUM_DEVICES * CHANNELS * RESOLUTION - 1 downto 0);
    FCO_OUT        : out std_logic_vector(NUM_DEVICES * RESOLUTION - 1 downto 0);
    DATA_VALID_OUT : out std_logic_vector(NUM_DEVICES - 1 downto 0);
    DEBUG          : out std_logic_vector(NUM_DEVICES * 32 - 1 downto 0)
  );
end entity;

architecture adc_ad9219_arch of adc_ad9219 is
  type q_t is array (0 to NUM_DEVICES - 1) of std_logic_vector(19 downto 0);
  signal q, qq, qqq : q_t;

  signal clk_adcfast_i : std_logic;     --200MHz/400MHz
  signal clk_data      : std_logic;     --100MHz/200MHz
  signal restart_i     : std_logic;

  type cnt_t is array (0 to NUM_DEVICES - 1) of unsigned(27 downto 0);
  signal counter, counter_q : cnt_t;

  type state_t is (S1, S2, S3, S4, S5);
  type states_t is array (0 to NUM_DEVICES - 1) of state_t;
  signal state   : states_t;
  signal state_q : states_t;

  type value_it is array (0 to 4) of std_logic_vector(9 downto 0);
  type value_t is array (0 to NUM_DEVICES - 1) of value_it;
  signal value      : value_t;
  signal fifo_input : value_t;

  type fifo_t is array (0 to NUM_DEVICES - 1) of std_logic_vector(49 downto 0);
  signal fifo_output : fifo_t;

  signal fifo_write      : std_logic_vector(NUM_DEVICES - 1 downto 0);
  signal fifo_read       : std_logic_vector(NUM_DEVICES - 1 downto 0);
  signal fifo_empty      : std_logic_vector(NUM_DEVICES - 1 downto 0);
  signal fifo_last_empty : std_logic_vector(NUM_DEVICES - 1 downto 0);
  signal fifo_true_empty : std_logic_vector(NUM_DEVICES - 1 downto 0);

  signal clk_fifo, clk_adc : std_logic;

begin
  ADCCLK_OUT <= clk_adc;

  gen_40MHz : if ADC_SAMPLING_RATE = 40 generate
    THE_ADC_REF : entity work.pll_in200_out40
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adc,
        LOCK  => open
      );
    THE_ADC_PLL_0 : entity work.pll_adc10bit
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adcfast_i,
        LOCK  => open
      );
  end generate;

  gen_80MHz : if ADC_SAMPLING_RATE = 80 generate
    THE_ADC_REF : entity work.pll_in200_out80
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adc,
        LOCK  => open
      );
    THE_ADC_PLL_0 : entity work.pll_adc10bit_80
      port map(
        CLK   => CLK_ADCRAW,
        CLKOP => clk_adcfast_i,
        LOCK  => open
      );
  end generate;

  restart_i <= RESTART_IN when rising_edge(clk_data);

  gen_7 : if NUM_DEVICES = 7 generate
    THE_7 : entity work.dqsinput_7x5
      port map(
        clk_0        => ADC_DCO(1),
        clk_1        => ADC_DCO(2),
        clk_2        => ADC_DCO(3),
        clk_3        => ADC_DCO(4),
        clk_4        => ADC_DCO(5),
        clk_5        => ADC_DCO(6),
        clk_6        => ADC_DCO(7),
        clkdiv_reset => RESTART_IN,
        eclk         => clk_adcfast_i,
        reset_0      => restart_i,
        reset_1      => restart_i,
        reset_2      => restart_i,
        reset_3      => restart_i,
        reset_4      => restart_i,
        reset_5      => restart_i,
        reset_6      => restart_i,
        sclk         => clk_data,
        datain_0     => ADC_DATA(4 downto 0),
        datain_1     => ADC_DATA(9 downto 5),
        datain_2     => ADC_DATA(14 downto 10),
        datain_3     => ADC_DATA(19 downto 15),
        datain_4     => ADC_DATA(24 downto 20),
        datain_5     => ADC_DATA(29 downto 25),
        datain_6     => ADC_DATA(34 downto 30),
        q_0          => q(0),
        q_1          => q(1),
        q_2          => q(2),
        q_3          => q(3),
        q_4          => q(4),
        q_5          => q(5),
        q_6          => q(6)
      );
  end generate;

  gen_5 : if NUM_DEVICES = 5 generate
    THE_5 : entity work.dqsinput_5x5
      port map(
        clk_0        => ADC_DCO(1),
        clk_1        => ADC_DCO(2),
        clk_2        => ADC_DCO(3),
        clk_3        => ADC_DCO(4),
        clk_4        => ADC_DCO(5),
        clkdiv_reset => RESTART_IN,
        eclk         => clk_adcfast_i,
        reset_0      => restart_i,
        reset_1      => restart_i,
        reset_2      => restart_i,
        reset_3      => restart_i,
        reset_4      => restart_i,
        sclk         => clk_data,
        datain_0     => ADC_DATA(4 downto 0),
        datain_1     => ADC_DATA(9 downto 5),
        datain_2     => ADC_DATA(14 downto 10),
        datain_3     => ADC_DATA(19 downto 15),
        datain_4     => ADC_DATA(24 downto 20),
        q_0          => q(0),
        q_1          => q(1),
        q_2          => q(2),
        q_3          => q(3),
        q_4          => q(4)
      );
  end generate;

  -- for simulation purposes only
  gen_dummy_dqs : if NUM_DEVICES = 1 generate
    THE_DUMMY_DQS : entity work.dqsinput_dummy
      port map(eclk => clk_adcfast_i,
               sclk => clk_data,
               q_0  => q(0)
      );
  end generate;

  gen_output_for_psa : if READOUT_MODE = READOUT_MODE_PSA generate
    clk_fifo   <= CLK;
    fifo_empty <= fifo_true_empty;
    fifo_read <= (others => '1');
  end generate;

  gen_output_for_cfd : if READOUT_MODE = READOUT_MODE_CFD generate
    clk_fifo   <= clk_adc;
    fifo_empty <= (others => '0'); -- since we're reading with sampling frequency
    fill_fifo : process is
      variable count : integer range 0 to 7 := 0;
    begin
      wait until rising_edge(clk_fifo);
      if RESTART_IN = '1' then
        count := 0;
      elsif count /= count'high then
        count := count + 1;
        fifo_read <= (others => '0');
      else
        fifo_read <= (others => '1');  
      end if;
    end process fill_fifo;    
  end generate;

  gen_chips : for i in 0 to NUM_DEVICES - 1 generate
    gen_data_mapping : for j in 0 to CHANNELS generate
      gen_data_mapping_bits : for k in 0 to 3 generate
        qqq(i)(j * 4 + 3 - k) <= qq(i)(k * (CHANNELS + 1) + j);
      end generate;
    end generate;

    proc_collect_data : process
    begin
      wait until rising_edge(clk_data);
      qq(i)         <= q(i);
      fifo_write(i) <= '0';
      case state(i) is
        when S1 =>
          if qqq(i)(19 downto 16) = "0011" then
            state(i)                <= S2;
            value(i)(0)(9 downto 8) <= qqq(i)(1 downto 0);
            value(i)(1)(9 downto 8) <= qqq(i)(5 downto 4);
            value(i)(2)(9 downto 8) <= qqq(i)(9 downto 8);
            value(i)(3)(9 downto 8) <= qqq(i)(13 downto 12);
            value(i)(4)(9 downto 8) <= qqq(i)(17 downto 16);

            fifo_input(i)                <= value(i);
            fifo_input(i)(0)(1 downto 0) <= qqq(i)(3 downto 2);
            fifo_input(i)(1)(1 downto 0) <= qqq(i)(7 downto 6);
            fifo_input(i)(2)(1 downto 0) <= qqq(i)(11 downto 10);
            fifo_input(i)(3)(1 downto 0) <= qqq(i)(15 downto 14);
            fifo_input(i)(4)(1 downto 0) <= qqq(i)(19 downto 18);
            fifo_write(i)                <= '1';
          end if;
        when S2 =>
          state(i)                <= S3;
          value(i)(0)(7 downto 4) <= qqq(i)(3 downto 0);
          value(i)(1)(7 downto 4) <= qqq(i)(7 downto 4);
          value(i)(2)(7 downto 4) <= qqq(i)(11 downto 8);
          value(i)(3)(7 downto 4) <= qqq(i)(15 downto 12);
          value(i)(4)(7 downto 4) <= qqq(i)(19 downto 16);
        when S3 =>
          state(i)                     <= S4;
          fifo_input(i)                <= value(i);
          fifo_input(i)(0)(3 downto 0) <= qqq(i)(3 downto 0);
          fifo_input(i)(1)(3 downto 0) <= qqq(i)(7 downto 4);
          fifo_input(i)(2)(3 downto 0) <= qqq(i)(11 downto 8);
          fifo_input(i)(3)(3 downto 0) <= qqq(i)(15 downto 12);
          fifo_input(i)(4)(3 downto 0) <= qqq(i)(19 downto 16);
          fifo_write(i)                <= '1';
        when S4 =>
          state(i)                <= S5;
          value(i)(0)(9 downto 6) <= qqq(i)(3 downto 0);
          value(i)(1)(9 downto 6) <= qqq(i)(7 downto 4);
          value(i)(2)(9 downto 6) <= qqq(i)(11 downto 8);
          value(i)(3)(9 downto 6) <= qqq(i)(15 downto 12);
          value(i)(4)(9 downto 6) <= qqq(i)(19 downto 16);
        when S5 =>
          state(i)                <= S1;
          value(i)(0)(5 downto 2) <= qqq(i)(3 downto 0);
          value(i)(1)(5 downto 2) <= qqq(i)(7 downto 4);
          value(i)(2)(5 downto 2) <= qqq(i)(11 downto 8);
          value(i)(3)(5 downto 2) <= qqq(i)(15 downto 12);
          value(i)(4)(5 downto 2) <= qqq(i)(19 downto 16);
      end case;
      if restart_i = '1' then
        state(i) <= S1;
      end if;
    end process;

    THE_FIFO : entity work.fifo_cdt_200_50 --50*16
      port map(
        Data(9 downto 0)   => fifo_input(i)(0),
        Data(19 downto 10) => fifo_input(i)(1),
        Data(29 downto 20) => fifo_input(i)(2),
        Data(39 downto 30) => fifo_input(i)(3),
        Data(49 downto 40) => fifo_input(i)(4),
        WrClock            => clk_data,
        RdClock            => clk_fifo,
        WrEn               => fifo_write(i),
        RdEn               => fifo_read(i),
        Reset              => RESTART_IN,
        RPReset            => RESTART_IN,
        Q(49 downto 0)     => fifo_output(i),
        Empty              => fifo_true_empty(i),
        Full               => open
      );

    proc_output : process
    begin
      wait until rising_edge(clk_fifo);
      fifo_last_empty(i) <= fifo_empty(i);
      if fifo_last_empty(i) = '0' then
        DATA_OUT(i * 40 + 39 downto i * 40 + 0) <= fifo_output(i)(39 downto 0);
        FCO_OUT(i * 10 + 9 downto i * 10 + 0)   <= fifo_output(i)(49 downto 40);
        DATA_VALID_OUT(i)                       <= '1';
        counter(i)                              <= counter(i) + 1;
      else
        DATA_VALID_OUT(i) <= '0';
      end if;
    end process;

    proc_debug : process
    begin
      wait until rising_edge(CLK);
      state_q(i) <= state(i);
      counter_q(i) <= counter(i);
      DEBUG(i * 32 + 31 downto i * 32 + 4) <= std_logic_vector(counter_q(i));
      case state_q(i) is
        when S1     => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"1";
        when S2     => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"2";
        when S3     => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"3";
        when S4     => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"4";
        when S5     => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"5";
        when others => DEBUG(i * 32 + 3 downto i * 32 + 0) <= x"f";
      end case;
    end process;

  end generate;                         -- gen_chips

end architecture;



