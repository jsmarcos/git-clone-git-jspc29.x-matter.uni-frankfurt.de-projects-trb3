library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;


entity adc_ad9222 is
  generic(
    CHANNELS : integer range 4 to 4 := 4;
    DEVICES  : integer range 1 to 2 := 1;
    RESOLUTION : integer range 12 to 12 := 12
    );
  port(
    CLK        : in std_logic;
    CLK_ADCREF : in std_logic;
    CLK_ADCDAT : in std_logic;
    RESTART_IN : in std_logic;
    ADCCLK_OUT : out std_logic;
    ADC_DATA   : in  std_logic_vector(DEVICES*CHANNELS-1 downto 0);
    ADC_DCO    : in  std_logic_vector(DEVICES-1 downto 0);
    ADC_FCO    : in  std_logic_vector(DEVICES-1 downto 0);
    
    DATA_OUT       : out std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
    FCO_OUT        : out std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
    DATA_VALID_OUT : out std_logic_vector(DEVICES-1 downto 0);
    DEBUG          : out std_logic_vector(31 downto 0)    
    );
end entity;



architecture adc_ad9222_arch of  adc_ad9222 is


signal clk_data  : std_logic;

signal data_in   : std_logic_vector(DEVICES*20-1 downto 0);
signal data_int  : std_logic_vector(DEVICES*20-1 downto 0);
signal fifo_empty : std_logic_vector(DEVICES-1 downto 0);
signal fifo_full  : std_logic_vector(DEVICES-1 downto 0);
signal valid_read : std_logic_vector(DEVICES-1 downto 0);

type cdt_t is array(0 to DEVICES-1) of std_logic_vector(59 downto 0);
signal cdt_data_in : cdt_t;
signal cdt_data_out: cdt_t;
signal cdt_write : std_logic_vector(DEVICES-1 downto 0);

type datarr_sub_t is array(0 to CHANNELS) of std_logic_vector(3 downto 0);
type datarr_t is array(0 to DEVICES-1) of datarr_sub_t;
signal data_block : datarr_t;

type dat_final_subt is array(0 to CHANNELS) of std_logic_vector(RESOLUTION-1 downto 0);
type dat_final_t is array(0 to DEVICES-1) of dat_final_subt;
signal last_data : dat_final_t;
signal curr_data : dat_final_t;

type arr_4DEV_t is array(0 to DEVICES-1) of std_logic_vector(3 downto 0);
signal mask : arr_4DEV_t;


type state_t is array(0 to DEVICES-1) of integer range 0 to 3;
signal state : state_t := (others => 0);

signal data_buffer : std_logic_vector(DEVICES*CHANNELS*RESOLUTION-1 downto 0);
signal fco_buffer  : std_logic_vector(DEVICES*RESOLUTION-1 downto 0);
signal data_ready  : std_logic_vector(DEVICES-1 downto 0);
signal restart_i   : std_logic;

begin

  ADCCLK_OUT <= CLK_ADCREF;
  restart_i <= RESTART_IN when rising_edge(clk_data);

gen_2 : if DEVICES = 2 generate
  THE_INPUT : dqsinput
    port map(
      clk_0 => ADC_DCO(0),
      clk_1 => ADC_DCO(1),
      clkdiv_reset => '0',
      eclk => CLK_ADCDAT,
      reset_0 => '0',
      reset_1 => '0',
      sclk => clk_data,
      datain_0(3 downto 0) => ADC_DATA(3 downto 0),
      datain_1(3 downto 0) => ADC_DATA(7 downto 4),
      datain_0(4)          => ADC_FCO(0),
      datain_1(4)          => ADC_FCO(1),
      q_0 => data_in(19 downto 0),
      q_1 => data_in(39 downto 20)
      );
end generate;

gen_1 : if DEVICES = 1 generate
  THE_INPUT : entity work.dqsinput1x4
    port map(
      clk => ADC_DCO(0),
      eclk => open,
      clkdiv_reset => '0',
      sclk => clk_data,
      datain(3 downto 0) => ADC_DATA(3 downto 0),
      datain(4)          => ADC_FCO(0),
      q => data_in(19 downto 0)
      );
end generate;




  gen_chips : for i in 0 to DEVICES-1 generate
    THE_FIFO : fifo_cdt_200
      port map(
        Data     => cdt_data_in(i),
        WrClock  => clk_data,
        RdClock  => CLK,
        WrEn     => cdt_write(i),
        RdEn     => '1',
        Reset    => '0',
        RPReset  => restart_i,
        Q        => cdt_data_out(i),
        Empty    => fifo_empty(i),
        Full     => fifo_full(i)
        );
        
    valid_read(i) <= not fifo_empty(i) when rising_edge(CLK);    
    
    gen_data_mapping : for j in 0 to CHANNELS generate
      gen_data_mapping_bits : for k in 0 to 3 generate
        data_block(i)(j)(3-k) <= data_in(i*(CHANNELS+1)*4+k*(CHANNELS+1)+j);
      end generate;
    end generate;
    
    
    process begin
      wait until rising_edge(clk_data);
      cdt_write(i) <= '0';
      case state(i) is
        when 0 => 
          if data_block(i)(CHANNELS) = x"F" then
            state(i) <= 2;
          end if;
        when 1 =>
          loop_chan_0 : for j in 0 to CHANNELS loop
            cdt_data_in(i)(j*12+11 downto j*12+8) <= data_block(i)(j);
          end loop;
          state(i) <= 2;
        when 2 =>
          loop_chan_1 : for j in 0 to CHANNELS loop
            cdt_data_in(i)(j*12+7 downto j*12+4) <= data_block(i)(j);
          end loop;
          state(i) <= 3;
        when 3 =>
          loop_chan_2 : for j in 0 to CHANNELS loop
            cdt_data_in(i)(j*12+3 downto j*12+0) <= data_block(i)(j);
          end loop;
          cdt_write(i) <= '1';
          state(i) <= 1;
      end case;
      if restart_i = '1' then
        state(i) <= 0;
      end if;
    end process;
    
    
  end generate;  
  
  gen_shift_bits : for i in 0 to DEVICES-1 generate
    mask(i) <= cdt_data_out(i)(CHANNELS*RESOLUTION+3 downto CHANNELS*RESOLUTION);
    gen_shift_bits_2 : for j in 0 to CHANNELS-1 generate

      curr_data(i)(j) <= cdt_data_out(i)(j*RESOLUTION+RESOLUTION-1 downto j*RESOLUTION);

      process begin
        wait until rising_edge(CLK);
        if valid_read(i) = '1' then
          if mask(i) = x"3" then
            data_buffer(i*RESOLUTION*CHANNELS+(j+1)*RESOLUTION-1 downto i*RESOLUTION*CHANNELS+j*RESOLUTION) <= last_data(i)(j)(1 downto 0) & curr_data(i)(j)(RESOLUTION-1 downto 2);
          else --if mask = x"0" then
            data_buffer(i*RESOLUTION*CHANNELS+(j+1)*RESOLUTION-1 downto i*RESOLUTION*CHANNELS+j*RESOLUTION) <= curr_data(i)(j);
          end if;
          last_data(i)(j) <= curr_data(i)(j);
        end if;
      end process;
    end generate;
  end generate;

gen_outputs_2 : if DEVICES = 2 generate  
  FCO_OUT <=  cdt_data_out(1)(CHANNELS*12+11 downto CHANNELS*12) & cdt_data_out(0)(CHANNELS*12+11 downto CHANNELS*12);
end generate;

gen_outputs_1 : if DEVICES = 1 generate  
  FCO_OUT <=   cdt_data_out(0)(CHANNELS*12+11 downto CHANNELS*12);
end generate;

  DATA_OUT <= data_buffer;
  DATA_VALID_OUT <= valid_read when rising_edge(CLK);
  
  DEBUG(3 downto 0)  <= std_logic_vector(to_unsigned(state(0),4));
  DEBUG(7 downto 4)  <= data_block(0)(1);
  DEBUG(11 downto 8) <= data_block(0)(4);
  DEBUG(12)          <= fifo_empty(0);
  DEBUG(13)          <= fifo_full(0);
  DEBUG(14)          <= clk_data;
  DEBUG(15)          <= DATA_VALID_OUT(0);
  
end architecture;
