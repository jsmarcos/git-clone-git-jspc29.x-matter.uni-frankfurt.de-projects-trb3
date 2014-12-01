library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_slowcontrol_data_buffer is
  port(
    CLK        : in std_logic;
    CLK_ADCRAW : in std_logic;

    ADCCLK_OUT : out std_logic; 
    ADC_DATA   : in  std_logic_vector((DEVICES_1+DEVICES_2)*(CHANNELS+1)-1 downto 0);
    ADC_DCO    : in  std_logic_vector((DEVICES_1+DEVICES_2) downto 1);
    
    ADC_CONTROL_OUT : out std_logic_vector(7 downto 0);
    
    BUS_RX   : in  CTRLBUS_RX;
    BUS_TX   : out CTRLBUS_TX
    );
end entity;



architecture adc_slowcontrol_data_buffer_arch of adc_slowcontrol_data_buffer is

signal fifo_read      : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_empty     : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_full      : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_write     : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_reset     : std_logic;
signal fifo_stop      : std_logic;

type dout_t is array(0 to DEVICES*CHANNELS-1) of std_logic_vector(17 downto 0);
signal fifo_dout : dout_t;

type fifo_count_t is array(0 to DEVICES*CHANNELS-1) of std_logic_vector(10 downto 0);
signal fifo_count : fifo_count_t;

signal ctrl_reg  : std_logic_vector(31 downto 0);

signal saved_addr : integer range 0 to DEVICES*CHANNELS-1;
signal fifo_wait_0, fifo_wait_1, fifo_wait_2 : std_logic;


signal adc_data_out  : std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
signal adc_fco_out   : std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
signal adc_valid_out : std_logic_vector(DEVICES-1 downto 0);
signal adc_debug     : std_logic_vector(DEVICES*32-1 downto 0);
signal adc_restart   : std_logic;
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
    
    DEBUG(32*6-1 downto 0)
                               => adc_debug(32*6-1 downto 0),
    DEBUG(32*7 -1 downto 32*6)
                               => adc_debug(32*8-1 downto 32*7)
    
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
    
    DEBUG(32*1-1 downto 0)
                               => adc_debug(32*7-1 downto 32*6),
    DEBUG(32*5 -1 downto 32*1)
                               => adc_debug(32*12-1 downto 32*8)
    
    );    



gen_data_fifo : for i in 0 to DEVICES*CHANNELS-1 generate
  THE_FIFO : entity work.fifo_18x1k_oreg
    port map (
      Data(9 downto 0)   => adc_data_out(10*i+9 downto 10*i),
--       Data(17 downto 10) => ADC_FCO_IN (10*(i/CHANNELS)+7 downto 10*(i/CHANNELS)),
      Data(17 downto 12) => adc_fco_out (10*(i/CHANNELS)+6 downto 10*(i/CHANNELS)+1),
      Clock              => CLK, 
      WrEn               => fifo_write(i),
      RdEn               => fifo_read(i),
      Reset              => fifo_reset,
      AmFullThresh       => "1111110000",
      Q                  => fifo_dout(i),
      WCNT               => fifo_count(i),
      Empty              => fifo_empty(i), 
      Full               => open,
      AlmostFull         => fifo_full(i)
      );
  fifo_write(i) <= adc_valid_out(i / CHANNELS) and not fifo_stop;
end generate;    

fifo_wait_1 <= fifo_wait_0       when rising_edge(CLK);
fifo_wait_2 <= fifo_wait_1       when rising_edge(CLK);

ADC_CONTROL_OUT <= ctrl_reg(7 downto 0);


PROC_BUS : process begin
  wait until rising_edge(CLK);
  BUS_TX.ack     <= '0';
  BUS_TX.nack    <= '0';
  BUS_TX.unknown <= '0';
  adc_restart    <= '0';
  fifo_read      <= fifo_full;
  fifo_wait_0    <= '0';
  fifo_reset     <= '0';
  
  if BUS_RX.read = '1' then
    if BUS_RX.addr(7 downto 0) = x"80" then
      BUS_TX.data  <= ctrl_reg;
      BUS_TX.ack   <= '1';
    elsif BUS_RX.addr(7 downto 0) >= x"40" and BUS_RX.addr(7 downto 0) < x"50" 
           and BUS_RX.addr(5 downto 0) < std_logic_vector(to_unsigned(DEVICES*CHANNELS,6)) then
      BUS_TX.data  <= adc_debug(to_integer(unsigned(BUS_RX.addr(3 downto 0)))*32+31 downto to_integer(unsigned(BUS_RX.addr(3 downto 0)))*32);
      BUS_TX.ack   <= '1';
    elsif BUS_RX.addr(7 downto 0) = x"83" then
      BUS_TX.data  <= (others => '0');
      BUS_TX.data(10 downto 0) <= fifo_count(0);
      BUS_TX.ack   <= '1';
    elsif BUS_RX.addr(7 downto 0) < std_logic_vector(to_unsigned(DEVICES*CHANNELS,8)) then
      saved_addr   <= to_integer(unsigned(BUS_RX.addr(6 downto 0)));
      fifo_read(to_integer(unsigned(BUS_RX.addr(6 downto 0)))) <= '1';
      fifo_wait_0 <= '1';
    else
      BUS_TX.unknown <= '1';
    end if;
  
  elsif BUS_RX.write = '1' then
    if BUS_RX.addr(7 downto 0) = x"80" then
      ctrl_reg       <= BUS_RX.data;
      BUS_TX.ack     <= '1';
    elsif BUS_RX.addr(7 downto 0) = x"81" then
      adc_restart    <= BUS_RX.data(0);
      fifo_stop      <= BUS_RX.data(1);
      fifo_reset     <= BUS_RX.data(2);
      BUS_TX.ack     <= '1';
    else
      BUS_TX.unknown <= '1';
    end if;
  end if;
  
  if fifo_wait_2 = '1' then
    BUS_TX.ack <= '1';
    BUS_TX.data(17 downto 0)  <= fifo_dout(saved_addr);
    BUS_TX.data(30 downto 18) <= (others => '0');
    BUS_TX.data(31)           <= fifo_empty(saved_addr);
  end if;
end process;


end architecture;



