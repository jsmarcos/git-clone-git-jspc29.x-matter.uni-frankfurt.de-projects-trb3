library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;

library machxo2;
use machxo2.all;


entity spi_slave is
  port(
    CLK        : in std_logic;
    
    SPI_CLK    : in  std_logic;
    SPI_CS     : in  std_logic;
    SPI_IN     : in  std_logic;
    SPI_OUT    : out std_logic;
  
    DATA_OUT   : out std_logic_vector(15 downto 0);
    REG00_IN   : in  std_logic_vector(15 downto 0);
    REG10_IN   : in  std_logic_vector(15 downto 0);
    REG20_IN   : in  std_logic_vector(15 downto 0);
    REG40_IN   : in  std_logic_vector(15 downto 0);
    
    OPERATION_OUT : out std_logic_vector(3 downto 0);
    CHANNEL_OUT   : out std_logic_vector(7 downto 0);
    WRITE_OUT     : out std_logic_vector(15 downto 0);

    DEBUG_OUT     : out std_logic_vector(15 downto 0)
    );
end entity;



architecture spi_slave_arch of spi_slave is
signal spi_clk_last : std_logic;
signal spi_clk_reg : std_logic;
signal spi_cs_reg  : std_logic;
signal spi_in_reg  : std_logic;
signal buf_SPI_OUT : std_logic;

signal input       : std_logic_vector(31 downto 0);
signal output_data : std_logic_vector(31 downto 0);
signal data_write  : std_logic_vector(15 downto 0);
signal write_i     : std_logic_vector(15 downto 0) := x"0000";
signal last_input  : std_logic;
signal bitcnt : integer range 0 to 31 := 31;

signal next_output : std_logic;
signal operation_i : std_logic_vector(3 downto 0) := x"0";
signal channel_i   : std_logic_vector(7 downto 0) := x"00";

type state_t is (IDLE, WAIT_FOR_CMD, GET_DATA, PREPARE_OUTPUT, WRITE_DATA, WAIT_FINISH);
signal state : state_t;

begin

spi_clk_last <= spi_clk_reg when rising_edge(CLK);
spi_clk_reg <= SPI_CLK when rising_edge(CLK);
spi_cs_reg  <= SPI_CS  when rising_edge(CLK);
spi_in_reg  <= SPI_IN  when rising_edge(CLK);

OPERATION_OUT <= operation_i;
CHANNEL_OUT   <= channel_i;
DATA_OUT      <= data_write;
WRITE_OUT     <= write_i;

PROC_OUTPUT : process begin
  wait until rising_edge(CLK);
  next_output <= output_data(bitcnt);
  if spi_clk_reg = '0' and spi_clk_last = '1' then
    SPI_OUT <= last_input;
    if operation_i = x"0" and bitcnt <= 15 then
      SPI_OUT <= next_output;
    end if;
  end if;
end process;


PROC_INPUT_SHIFT : process begin
  wait until rising_edge(CLK);
  if spi_cs_reg = '1' then
    bitcnt <= 31;
  else
    if spi_clk_reg = '1' and spi_clk_last = '0' then
      if bitcnt /= 0 then
        bitcnt <= bitcnt - 1;
      else
        bitcnt <= 31;
      end if;
      last_input <= spi_in_reg;
      input(bitcnt) <= spi_in_reg;
    end if;
  end if;
end process;


PROC_GEN_SIGNALS : process begin
  wait until rising_edge(CLK);
  write_i <= (others => '0');
  case state is
    when IDLE =>
      channel_i   <= x"ff";
      operation_i <= x"7";
      if spi_cs_reg = '0' then
        state       <= WAIT_FOR_CMD;
      end if;
    when WAIT_FOR_CMD =>
      if bitcnt = 15 then
        operation_i <= input(23 downto 20);
        channel_i   <= input(27 downto 24) & input(19 downto 16);
        state       <= GET_DATA;
      end if;
    when GET_DATA =>
      state <= PREPARE_OUTPUT;
    when PREPARE_OUTPUT =>
      if    input(31 downto 28) = x"0" then
        output_data(15 downto 0) <= REG00_IN;
      elsif input(31 downto 28) = x"1" then
        output_data(15 downto 0) <= REG10_IN;
      elsif input(31 downto 28) = x"2" then
        output_data(15 downto 0) <= REG20_IN;
      else
        output_data(15 downto 0) <= REG40_IN;
      end if;
      state <= WRITE_DATA;
    when WRITE_DATA =>
      if bitcnt = 31 then
        if operation_i(3) = '1' then
          data_write <= input(15 downto 0);
          write_i(to_integer(unsigned(input(31 downto 28)))) <= '1';
        end if;
        state <= WAIT_FINISH;
      end if;
    when WAIT_FINISH =>
      if spi_cs_reg = '1' then
        state <= IDLE;
      end if;
  end case;
   
  if spi_cs_reg = '1' then
    state <= IDLE;
    operation_i <= x"7";    
  end if;
end process;

DEBUG_OUT(0) <= spi_clk_reg;
DEBUG_OUT(1) <= spi_cs_reg;
DEBUG_OUT(2) <= spi_in_reg;
DEBUG_OUT(3) <= buf_SPI_OUT;
DEBUG_OUT(7 downto 4) <= std_logic_vector(to_unsigned(bitcnt,4));
DEBUG_OUT(14 downto 8) <= input(30 downto 24);
DEBUG_OUT(15) <= write_i(4);



end architecture;