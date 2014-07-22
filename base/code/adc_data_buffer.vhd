library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;

entity adc_data_buffer is
  generic(
    CHANNELS       : integer := 4;
    DEVICES        : integer := 12;
    RESOLUTION     : integer := 10
    );
  port(
    CLK        : in std_logic;
    
    ADC_DATA_IN    : in std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
    ADC_FCO_IN     : in std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
    ADC_DATA_VALID : in std_logic_vector(DEVICES-1 downto 0);
    
    ADC_RESET_OUT  : out std_logic;
    
    BUS_RX   : in  CTRLBUS_RX;
    BUS_TX   : out CTRLBUS_TX
    );
end entity;



architecture adc_data_buffer_arch of adc_data_buffer is

signal fifo_read      : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_empty     : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_full      : std_logic_vector(DEVICES*CHANNELS-1 downto 0);
signal fifo_reset     : std_logic;

type dout_t is array(0 to DEVICES*CHANNELS-1) of std_logic_vector(17 downto 0);
signal fifo_dout : dout_t;

type fifo_count_t is array(0 to DEVICES*CHANNELS-1) of std_logic_vector(10 downto 0);
signal fifo_count : fifo_count_t;

signal ctrl_reg  : std_logic_vector(31 downto 0);

signal saved_addr : integer range 0 to DEVICES*CHANNELS-1;
signal fifo_wait_1, fifo_wait_2 : std_logic;

begin
 

gen_data_fifo : for i in 0 to DEVICES*CHANNELS-1 generate
  THE_FIFO : entity work.fifo_18x1k_oreg
    port map (
      Data(9 downto 0)   => ADC_DATA_IN(10*i+9 downto 10*i),
      Data(17 downto 10) => ADC_FCO_IN (10*(i/CHANNELS)+7 downto 10*(i/CHANNELS)),
      Clock              => CLK, 
      WrEn               => ADC_DATA_VALID(i / CHANNELS),
      RdEn               => fifo_read(i),
      Reset              => fifo_reset,
      AmFullThresh       => "1111110000",
      Q                  => fifo_dout(i),
      WCNT               => fifo_count(i),
      Empty              => fifo_empty(i), 
      Full               => open,
      AlmostFull         => fifo_full(i)
      );
end generate;    

fifo_wait_1 <= or_all(fifo_read) when rising_edge(CLK);
fifo_wait_2 <= fifo_wait_1       when rising_edge(CLK);


PROC_BUS : process begin
  wait until rising_edge(CLK);
  BUS_TX.ack     <= '0';
  BUS_TX.nack    <= '0';
  BUS_TX.unknown <= '0';
  ADC_RESET_OUT  <= '0';
  fifo_read      <= fifo_full;
  
  if BUS_RX.read = '1' then
    if BUS_RX.addr(7 downto 0) = x"80" then
      BUS_TX.data  <= ctrl_reg;
      BUS_TX.ack   <= '1';
    elsif BUS_RX.addr(7 downto 0) < std_logic_vector(to_unsigned(DEVICES*CHANNELS,8)) then
      saved_addr   <= to_integer(unsigned(BUS_RX.addr(6 downto 0)));
      fifo_read(to_integer(unsigned(BUS_RX.addr(6 downto 0)))) <= '1';
    else
      BUS_TX.unknown <= '1';
    end if;
  
  elsif BUS_RX.write = '1' then
    if BUS_RX.addr(7 downto 0) = x"80" then
      ctrl_reg       <= BUS_RX.data;
      BUS_TX.ack     <= '1';
    elsif BUS_RX.addr(7 downto 0) = x"81" then
      ADC_RESET_OUT  <= '1';
      BUS_TX.ack     <= '1';
    else
      BUS_TX.unknown <= '1';
    end if;
  end if;
  
  if fifo_wait_2 = '1' then
    BUS_TX.ack <= '1';
    BUS_TX.data(17 downto 0)  <= fifo_dout(saved_addr);
    BUS_TX.data(30 downto 18) <= (others => '0');
    BUS_TX.data(31)           <= fifo_empty(saved_addr / CHANNELS);
  end if;
end process;


end architecture;



