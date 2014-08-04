library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_handler is
  port(
    CLK        : in std_logic;
    CLK_ADCRAW : in std_logic;

--ADC
    ADCCLK_OUT : out std_logic; 
    ADC_DATA   : in  std_logic_vector((DEVICES_1+DEVICES_2)*(CHANNELS+1)-1 downto 0);
    ADC_DCO    : in  std_logic_vector((DEVICES_1+DEVICES_2) downto 1);
--Trigger In and Out
    TRIGGER_IN : in  std_logic;
    TRIGGER_FLAG_OUT : out std_logic;
--Readout    
    READOUT_RX : in  READOUT_RX;
    READOUT_TX : out readout_tx_array_t((DEVICES_1+DEVICES_2)-1 downto 0);
--Slow control    
    BUS_RX     : in  CTRLBUS_RX;
    BUS_TX     : out CTRLBUS_TX;
    
    ADCSPI_CTRL: out std_logic_vector(7 downto 0)
    );
end entity;

architecture adc_handler_arch of adc_handler is

signal adc_data_out  : std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
signal adc_fco_out   : std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
signal adc_valid_out : std_logic_vector(DEVICES-1 downto 0);
signal adc_debug     : std_logic_vector(DEVICES*CHANNELS*32-1 downto 0);

signal buffer_empty    : std_logic;
signal buffer_stop_override : std_logic;

signal ctrl_reg        : std_logic_vector(31 downto 0);
signal adc_restart     : std_logic;
    
signal adc_trigger     : std_logic_vector(DEVICES-1 downto 0);
signal adc_stop        : std_logic;

signal config          : cfg_t;

signal buffer_addr     : std_logic_vector(3 downto 0);
signal buffer_data     : buffer_data_t;
signal buffer_read     : std_logic_vector(DEVICES-1 downto 0);
signal buffer_ready    : std_logic_vector(DEVICES-1 downto 0);


-- 000 - 0ff configuration
--       000 reset, buffer clear strobes
--       010 buffer depth  (1-1023)
--       011 number of samples after trigger arrived (0-1023 * 25ns)
--       012 number of blocks to process (1-4)
--       013 trigger generation offset (0-1023 from baseline, polarity)
--       014 read-out threshold (0-1023 from baseline, polarity)
--       015 number of values to sum before storing
--       016 baseline averaging
--       020 - 023 number of values to sum  (1-255)
--       024 - 027 number of sums           (1-255)
--       028 - 02b 2^k scaling factor       (0-8)
--       02c - 02f 
-- 100 - 1ff status
--       100 clock valid (1 bit per ADC)
--       101 fco valid (1 bit per ADC)
--       102 readout state
-- 800 - 87f last ADC values              (local 0x0 - 0x3)
-- 880 - 8ff long-term average / baseline (local 0x4 - 0x7)
-- e00 - e7f fifo access (debugging only) (local 0x8 - 0xb)


begin



THE_ADC_LEFT : entity work.adc_ad9219
  generic map(
    NUM_DEVICES        => DEVICES_1
    )
  port map(
    CLK         => CLK,
    CLK_ADCRAW  => CLK_ADCRAW,
    RESTART_IN  => adc_restart,
    ADCCLK_OUT  => ADCCLK_OUT,
        --FCO is another channel for each ADC    
    ADC_DATA( 4 downto  0)   => ADC_DATA( 4 downto  0),
    ADC_DATA( 9 downto  5)   => ADC_DATA( 9 downto  5),
    ADC_DATA(14 downto 10)   => ADC_DATA(14 downto 10),
    ADC_DATA(19 downto 15)   => ADC_DATA(19 downto 15),
    ADC_DATA(24 downto 20)   => ADC_DATA(24 downto 20),
    ADC_DATA(29 downto 25)   => ADC_DATA(29 downto 25),
    ADC_DATA(34 downto 30)   => ADC_DATA(39 downto 35),
    ADC_DCO(6 downto 1)      => ADC_DCO(6 downto 1),
    ADC_DCO(7)               => ADC_DCO(8),
    
    DATA_OUT(6*CHANNELS*RESOLUTION-1 downto 0)
                               => adc_data_out(6*CHANNELS*RESOLUTION-1 downto 0),
    DATA_OUT(7*CHANNELS*RESOLUTION-1 downto 6*CHANNELS*RESOLUTION)                             
                               => adc_data_out(8*CHANNELS*RESOLUTION-1 downto 7*CHANNELS*RESOLUTION),
    FCO_OUT(6*RESOLUTION-1 downto 0)
                               => adc_fco_out(6*RESOLUTION-1 downto 0),
    FCO_OUT(7*RESOLUTION-1 downto 6*RESOLUTION) 
                               => adc_fco_out(8*RESOLUTION-1 downto 7*RESOLUTION),
    
    DATA_VALID_OUT(5 downto 0) => adc_valid_out(5 downto 0),
    DATA_VALID_OUT(6)          => adc_valid_out(7),
    
    DEBUG(32*6*CHANNELS-1 downto 0)
                               => adc_debug(32*6*CHANNELS-1 downto 0),
    DEBUG(32*7*CHANNELS -1 downto 32*6*CHANNELS)
                               => adc_debug(32*8*CHANNELS-1 downto 32*7*CHANNELS)
    
    );

THE_ADC_RIGHT : entity work.adc_ad9219
  generic map(
    NUM_DEVICES        => DEVICES_2
    )
  port map(
    CLK         => CLK,
    CLK_ADCRAW  => CLK_ADCRAW,
    RESTART_IN  => adc_restart,
    ADCCLK_OUT  => open,
        --FCO is another channel for each ADC    
    ADC_DATA( 4 downto  0)   => ADC_DATA(34 downto 30),
    ADC_DATA( 9 downto  5)   => ADC_DATA(44 downto 40),
    ADC_DATA(14 downto 10)   => ADC_DATA(49 downto 45),
    ADC_DATA(19 downto 15)   => ADC_DATA(54 downto 50),
    ADC_DATA(24 downto 20)   => ADC_DATA(59 downto 55),
    ADC_DCO(1)               => ADC_DCO(7),
    ADC_DCO(5 downto 2)      => ADC_DCO(12 downto 9),
    
    DATA_OUT(1*CHANNELS*RESOLUTION-1 downto 0)
                               => adc_data_out(7*CHANNELS*RESOLUTION-1 downto 6*CHANNELS*RESOLUTION),
    DATA_OUT(5*CHANNELS*RESOLUTION-1 downto 1*CHANNELS*RESOLUTION)                             
                               => adc_data_out(12*CHANNELS*RESOLUTION-1 downto 8*CHANNELS*RESOLUTION),
    FCO_OUT(1*RESOLUTION-1 downto 0)
                               => adc_fco_out(7*RESOLUTION-1 downto 6*RESOLUTION),
    FCO_OUT(5*RESOLUTION-1 downto 1*RESOLUTION) 
                               => adc_fco_out(12*RESOLUTION-1 downto 8*RESOLUTION),
    
    DATA_VALID_OUT(0)          => adc_valid_out(6),
    DATA_VALID_OUT(4 downto 1) => adc_valid_out(11 downto 8),
    
    DEBUG(32*1*CHANNELS-1 downto 0)
                               => adc_debug(32*7*CHANNELS-1 downto 32*6*CHANNELS),
    DEBUG(32*5*CHANNELS -1 downto 32*1*CHANNELS)
                               => adc_debug(32*12*CHANNELS-1 downto 32*8*CHANNELS)
    
    );    

    
gen_processors : for i in 0 to DEVICES-1 generate    
  THE_ADC_PROC : entity work.adc_processor
    generic map(
      DEVICE   => i
      )
    port map(
      CLK      => CLK,
      
      ADC_DATA  => adc_data_out((i+1)*RESOLUTION*CHANNELS-1 downto i*RESOLUTION*CHANNELS),
      ADC_VALID => adc_valid_out(i),
      
      STOP_IN     => adc_stop,
      TRIGGER_OUT => adc_trigger(i),
      
      CONFIG             => config,  --trigger offset, zero sup offset, depth, 
      
      DEBUG_BUFFER_ADDR  => buffer_addr,
      DEBUG_BUFFER_READ  => buffer_read(i),
      DEBUG_BUFFER_DATA  => buffer_data(i),
      DEBUG_BUFFER_READY => buffer_ready(i),
      
      READOUT_RX => READOUT_RX,
      READOUT_TX => READOUT_TX(i)
      
      );
end generate;      

TRIGGER_FLAG_OUT <= or_all(adc_trigger);



PROC_BUS : process begin
  wait until rising_edge(CLK);
  BUS_TX.ack     <= '0';
  BUS_TX.nack    <= '0';
  BUS_TX.unknown <= '0';
  
  if BUS_RX.read = '1' then
    if BUS_RX.addr >= x"0010" and BUS_RX.addr <= x"0015" then  --basic config registers
      BUS_TX.ack  <= '1';
      BUS_TX.data <= (othrs => '0');
      case BUS_RX.addr(7 downto 0) is
        when x"10" =>  BUS_TX.data(10 downto 0) <= config.buffer_depth;
        when x"11" =>  BUS_TX.data(10 downto 0) <= config.samples_after;
        when x"12" =>  BUS_TX.data( 1 downto 0) <= config.block_count;
        when x"13" =>  BUS_TX.data(17 downto 0) <= config.trigger_threshold;
        when x"14" =>  BUS_TX.data(17 downto 0) <= config.readout_threshold;
        when x"15" =>  BUS_TX.data( 7 downto 0) <= config.presum;
        
      end case;
    end if;
  elsif BUS_RX.write = '1' then
  end if;
end process;  
  
--       010 buffer depth  (1-1023)
--       011 number of samples after trigger arrived (0-1023 * 25ns)
--       012 number of blocks to process (1-4)
--       013 trigger generation offset (0-1023 from baseline, polarity)
--       014 read-out threshold (0-1023 from baseline, polarity)
--       015 number of values to sum before storing  
  
  
--     if BUS_RX.addr(7 downto 0) = x"80" then
--       BUS_TX.data  <= ctrl_reg;
--       BUS_TX.ack   <= '1';
--     elsif BUS_RX.addr(7 downto 0) >= x"40" and BUS_RX.addr(7 downto 0) < x"80" 
--            and BUS_RX.addr(5 downto 0) < std_logic_vector(to_unsigned(DEVICES*CHANNELS,6)) then
--       BUS_TX.data  <= adc_debug(to_integer(unsigned(BUS_RX.addr(5 downto 0)))*32+31 downto to_integer(unsigned(BUS_RX.addr(5 downto 0)))*32);
--       BUS_TX.ack   <= '1';
--     elsif BUS_RX.addr(7 downto 0) = x"83" then
--       BUS_TX.data  <= (others => '0');
--       --BUS_TX.data(10 downto 0) <= buffer_count(0);
--       BUS_TX.ack   <= '1';
--     elsif BUS_RX.addr(7 downto 0) < std_logic_vector(to_unsigned(DEVICES*CHANNELS,8)) then
--       buffer_addr  <= to_integer(unsigned(BUS_RX.addr(6 downto 0)));
--       buffer_read  <= '1';
--     else
--       BUS_TX.unknown <= '1';
--     end if;
--   
--   elsif BUS_RX.write = '1' then
--     if BUS_RX.addr(7 downto 0) = x"80" then
--       ctrl_reg       <= BUS_RX.data;
--       BUS_TX.ack     <= '1';
--     elsif BUS_RX.addr(7 downto 0) = x"81" then
--       adc_restart          <= BUS_RX.data(0);
--       buffer_stop_override <= BUS_RX.data(1);
--       BUS_TX.ack     <= '1';
--     else
--       BUS_TX.unknown <= '1';
--     end if;
--   end if;
--   
--   if buffer_ready = '1' then
--     BUS_TX.ack <= '1';
--     BUS_TX.data(17 downto 0)  <= buffer_data;
--     BUS_TX.data(30 downto 18) <= (others => '0');
--     BUS_TX.data(31)           <= buffer_empty;
--   end if;
-- end process;

    
    
    
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
--   type READOUT_RX is record 
--     data_valid         : std_logic;
--     valid_timing_trg   : std_logic;
--     valid_notiming_trg : std_logic;
--     invalid_trg        : std_logic;
--     --
--     trg_type           : std_logic_vector( 3 downto 0);
--     trg_number         : std_logic_vector(15 downto 0);
--     trg_code           : std_logic_vector( 7 downto 0);
--     trg_information    : std_logic_vector(23 downto 0);
--     trg_int_number     : std_logic_vector(15 downto 0);    
--     --
--     trg_multiple       : std_logic;
--     trg_timeout        : std_logic;
--     trg_spurious       : std_logic;
--     trg_missing        : std_logic;
--     trg_spike          : std_logic;
--     --
--     buffer_almost_full : std_logic;
--   end record; 
--   
--   
--   type READOUT_TX is record
--     busy_release  : std_logic;
--     statusbits    : std_logic_vector(31 downto 0);
--     data          : std_logic_vector(31 downto 0);
--     data_write    : std_logic;
--     data_finished : std_logic;
--   end record;
--  