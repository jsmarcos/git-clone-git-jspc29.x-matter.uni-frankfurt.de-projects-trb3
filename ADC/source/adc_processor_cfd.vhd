library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.trb_net_std.all;
use work.trb3_components.all;
use work.adc_package.all;

entity adc_processor_cfd is
  generic(
    DEVICE : integer range 0 to 15 := 15
  );
  port(
    CLK_SYS            : in  std_logic;
    CLK_ADC            : in  std_logic;

    ADC_DATA           : in  std_logic_vector(RESOLUTION * CHANNELS - 1 downto 0);
    STOP_IN            : in  std_logic;
    TRIGGER_OUT        : out std_logic;

    CONTROL            : in  std_logic_vector(63 downto 0);
    CONFIG             : in  cfg_cfd_t;

    DEBUG_BUFFER_READ  : in  std_logic;
    DEBUG_BUFFER_ADDR  : in  std_logic_vector(4 downto 0);
    DEBUG_BUFFER_DATA  : out std_logic_vector(31 downto 0);
    DEBUG_BUFFER_READY : out std_logic;

    READOUT_RX         : in  READOUT_RX;
    READOUT_TX         : out READOUT_TX
  );
end entity adc_processor_cfd;

architecture arch of adc_processor_cfd is
  attribute syn_hier : string;
  attribute syn_keep : boolean;
  attribute syn_preserve : boolean;
  attribute syn_hier of arch : architecture is "hard";

  signal CONF_adc, CONF_sys : cfg_cfd_t := cfg_cfd_t_INIT;
  attribute syn_keep of CONF_adc, CONF_sys : signal is true;
  attribute syn_preserve of CONF_adc, CONF_sys : signal is true;

  signal trigger_gen, trigger_mask : std_logic_vector(CHANNELS - 1 downto 0);
  type debug_t is array (CHANNELS - 1 downto 0) of debug_cfd_t;
  signal debug_adc, debug_sys : debug_t;

  signal reg_buffer_addr : std_logic_vector(4 downto 0) := (others => '0');
  signal reg_buffer_read : std_logic;

begin
  CONF_adc <= CONFIG when rising_edge(CLK_ADC);
  CONF_sys <= CONFIG when rising_edge(CLK_SYS);

  trigger_mask <= CONF_sys.TriggerEnable((DEVICE + 1) * CHANNELS - 1 downto DEVICE * CHANNELS);
  TRIGGER_OUT <= or_all(trigger_gen and trigger_mask) when rising_edge(CLK_SYS);

  debug_sys <= debug_adc when rising_edge(CLK_SYS);
  gen_cfd : for i in 0 to CHANNELS - 1 generate
    trigger_gen(i) <= debug_sys(i).Trigger;
    THE_CFD : entity work.adc_processor_cfd_ch
      port map(CLK      => CLK_ADC,
               ADC_DATA => ADC_DATA(RESOLUTION * (i + 1) - 1 downto RESOLUTION * i),
               CONF     => CONF_adc,
               RAM_RD   => '0',
               RAM_ADDR => (others => '0'),
               RAM_DATA => open,
               DEBUG    => debug_adc(i)
      );
  end generate;

  PROC_DEBUG_BUFFER : process
    variable c : integer range 0 to 3;
  begin
    wait until rising_edge(CLK_SYS);
    reg_buffer_addr   <= DEBUG_BUFFER_ADDR;
    reg_buffer_read   <= DEBUG_BUFFER_READ;
    c                 := to_integer(unsigned(reg_buffer_addr(1 downto 0)));
    DEBUG_BUFFER_DATA <= (others => '0');
    if reg_buffer_read = '1' then
      if reg_buffer_addr(4) = '0' then
        DEBUG_BUFFER_READY <= '1';
        case reg_buffer_addr(3 downto 2) is
          when "00"   => DEBUG_BUFFER_DATA <= std_logic_vector(resize(debug_sys(c).LastWord, 32));
          when "01"   => DEBUG_BUFFER_DATA <= std_logic_vector(resize(debug_sys(c).Baseline, 32));
          when "11"   => DEBUG_BUFFER_DATA <= std_logic_vector(resize(debug_sys(c).InvalidWordCount, 32));
          when others => null;
        end case;
      else
        DEBUG_BUFFER_READY <= '1';
        case reg_buffer_addr(3 downto 0) is
          when x"2" =>
            DEBUG_BUFFER_DATA(2)            <= STOP_IN;
            DEBUG_BUFFER_DATA(12)           <= '1'; -- ADC_VALID
            DEBUG_BUFFER_DATA(19 downto 16) <= trigger_gen;
          when others => null;
        end case;
      end if;
    end if;

    DEBUG_BUFFER_READY <= reg_buffer_read;

  end process;

end architecture arch;
