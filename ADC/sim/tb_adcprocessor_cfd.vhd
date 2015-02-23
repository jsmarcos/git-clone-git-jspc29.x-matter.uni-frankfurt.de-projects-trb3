library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity tb is
end entity;

architecture tb_arch of tb is
  signal clock100    : std_logic                     := '1';
  signal clock200    : std_logic                     := '1';
  signal clock_adc   : std_logic                     := '1';
  signal adc_data    : std_logic_vector(39 downto 0) := (others => '0');
  signal stop_in     : std_logic                     := '0';
  signal trigger_out : std_logic                     := '0';
  signal config      : cfg_cfd_t := cfg_cfd_t_INIT;
  signal readout_rx  : READOUT_RX;
  signal readout_tx  : READOUT_TX;
  signal control     : std_logic_vector(63 downto 0);

  signal restart : std_logic := '0';

begin
  clock100 <= not clock100 after 5 ns;

  clock200 <= not clock200 after 2.5 ns;

  restart <= '1', '0' after 200 ns;

  config.BaselineAlwaysOn <= '1', '0' after 20 us;

  config.InputThreshold  <= to_unsigned(40, 10);
  config.BaselineAverage <= to_unsigned(8, 4);
  config.PolarityInvert  <= '1';

  config.CFDDelay <= to_unsigned(2, 5);
  config.CFDMult <= to_unsigned(2, 4);
  config.CFDMultDly <= to_unsigned(3, 4);

  config.IntegrateWindow <= to_unsigned(60, 8);
   
  config.CheckWord1       <= (others => '0');
  config.CheckWord2       <= (others => '0');
  config.CheckWordEnable  <= '0';

  readout_rx.valid_notiming_trg <= '0';
  readout_rx.invalid_trg        <= '0';
  readout_rx.trg_type           <= (others => '0');
  readout_rx.trg_number         <= (others => '0');
  readout_rx.trg_code           <= (others => '0');
  readout_rx.trg_information    <= (others => '0');
  readout_rx.trg_int_number     <= (others => '0');
  readout_rx.trg_multiple       <= '0';
  readout_rx.trg_timeout        <= '0';
  readout_rx.trg_spurious       <= '0';
  readout_rx.trg_missing        <= '0';
  readout_rx.trg_spike          <= '0';
  readout_rx.buffer_almost_full <= '0';

  control <= (others => '0'), (8 => '1', others => '0') after 1 us, (others => '0') after 1.01 us, (5 => '1', others => '0') after 5 us, (others => '0') after 5.01 us;

  proc_rdo : process
  begin
    readout_rx.data_valid       <= '0';
    readout_rx.valid_timing_trg <= '0';
    wait for 13740 ns;
    wait until rising_edge(clock100);
    wait for 0.5 ns;
    readout_rx.valid_timing_trg <= '1';
    wait until rising_edge(clock100);
    wait for 0.5 ns;
    readout_rx.valid_timing_trg <= '0';
    wait for 250 ns;
    wait until rising_edge(clock100);
    wait for 0.5 ns;
    readout_rx.data_valid <= '1';
    wait until readout_tx.busy_release = '1';
    wait for 10 ns;
    wait until rising_edge(clock100);
    wait for 0.5 ns;
    readout_rx.data_valid <= '0';
    wait;
  end process;

  THE_ADC : entity work.adc_ad9219
    generic map(
      NUM_DEVICES => 1
    )
    port map(CLK            => clock100,
             CLK_ADCRAW     => clock200,
             RESTART_IN     => restart,
             ADCCLK_OUT     => clock_adc,
             ADC_DATA       => (others => '0'),
             ADC_DCO        => (others => '0'),
             DATA_OUT       => adc_data,
             FCO_OUT        => open,
             DATA_VALID_OUT => open,
             DEBUG          => open
    );

  UUT : entity work.adc_processor_cfd
    generic map(
      DEVICE => 0
    )
    port map(
      CLK_SYS            => clock100,
      CLK_ADC            => clock_adc,
      ADC_DATA           => adc_data,
      TRIGGER_OUT        => trigger_out,
      CONTROL            => control,
      CONFIG             => config,
      DEBUG_BUFFER_READ  => '0',
      DEBUG_BUFFER_ADDR  => (others => '0'),
      DEBUG_BUFFER_DATA  => open,
      DEBUG_BUFFER_READY => open,
      READOUT_TX         => readout_tx,
      READOUT_RX         => readout_rx
    );

  PROC_ADC : process
  begin
    wait until rising_edge(clock100);
    wait for 0.5 ns;

  end process;

end architecture;
