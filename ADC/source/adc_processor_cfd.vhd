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

  type ram_addr_t is array (CHANNELS - 1 downto 0) of std_logic_vector(8 downto 0);
  type ram_data_t is array (CHANNELS - 1 downto 0) of std_logic_vector(31 downto 0);
  type ram_counter_t is array (CHANNELS - 1 downto 0) of unsigned(8 downto 0);
  signal ram_addr_adc, ram_addr_sys : ram_addr_t := (others => (others => '0'));
  signal ram_data_adc, ram_data_sys : ram_data_t := (others => (others => '0'));
  signal ram_counter : ram_counter_t := (others => (others => '0')); 
  --signal ram_we_adc : std_logic_vector(CHANNELS - 1 downto 0) := (others => '0');

  type state_t is (IDLE, DO_RELEASE, RELEASE_DIRECT, WAIT_FOR_END, CHECK_STATUS_TRIGGER, SEND_STATUS, READOUT, WAIT_BSY, WAIT_RAM, TRIG_DLY);
  signal state     : state_t;
  signal statebits : std_logic_vector(7 downto 0);

  signal RDO_data_main  : std_logic_vector(31 downto 0) := (others => '0');
  signal RDO_write_main : std_logic                     := '0';
  signal readout_reset  : std_logic                     := '0';
  signal busy_in_adc, busy_in_sys : std_logic := '0';
  signal busy_out_adc, busy_out_sys : std_logic_vector(CHANNELS-1 downto 0) := (others => '0');
  
  type epoch_counter_t is array(CHANNELS - 1 downto 0) of unsigned(23 downto 0);
  signal epoch_counter, epoch_counter_save : epoch_counter_t;
  signal epoch_counter_sys, epoch_counter_adc : epoch_counter_t;
  
begin
  CONF_adc <= CONF_sys when rising_edge(CLK_ADC);
  CONF_sys <= CONFIG   when rising_edge(CLK_SYS);

  trigger_mask <= CONF_sys.TriggerEnable((DEVICE + 1) * CHANNELS - 1 downto DEVICE * CHANNELS);
  TRIGGER_OUT  <= or_all(trigger_gen and trigger_mask) when rising_edge(CLK_SYS);

  debug_sys <= debug_adc when rising_edge(CLK_SYS);
  busy_in_adc <= busy_in_sys when rising_edge(CLK_ADC);
  busy_out_sys <= busy_out_adc when rising_edge(CLK_SYS);
  gen_cfd : for i in 0 to CHANNELS - 1 generate
    trigger_gen(i) <= debug_sys(i).Trigger;
        
    -- first convert to gray counting, then do clock domain crossing 
    epoch_counter_adc(i) <= debug_adc(i).EpochCounter xor shift_right(debug_adc(i).EpochCounter,1);
    epoch_counter_sys(i) <= epoch_counter_adc(i) when rising_edge(CLK_SYS);
    epoch_counter(i) <= epoch_counter_sys(i); -- no back conversion to binary for now  
    
    THE_CFD : entity work.adc_processor_cfd_ch
      generic map(
        DEVICE  => DEVICE,
        CHANNEL => i
      )
      port map(CLK      => CLK_ADC,
               ADC_DATA => ADC_DATA(RESOLUTION * (i + 1) - 1 downto RESOLUTION * i),
               CONF     => CONF_adc,
               RAM_ADDR => ram_addr_adc(i),
               RAM_DATA => ram_data_adc(i),
               RAM_BSY_IN => busy_in_adc,
               RAM_BSY_OUT => busy_out_adc(i),
               DEBUG    => debug_adc(i)
      );
    
    ram_addr_sys(i) <= std_logic_vector(resize(ram_counter(i),ram_addr_sys(i)'length));
    dpram : entity work.dpram_32x512
      port map(WrAddress => ram_addr_adc(i),
               RdAddress => ram_addr_sys(i),
               Data      => ram_data_adc(i),
               WE        => '1',        -- always write
               RdClock   => CLK_SYS,
               RdClockEn => '1',
               Reset     => '0',
               WrClock   => CLK_ADC,
               WrClockEn => '1',
               Q         => ram_data_sys(i));
  end generate;

  READOUT_TX.data_write <= RDO_write_main when rising_edge(CLK_SYS);
  READOUT_TX.data       <= RDO_data_main when rising_edge(CLK_SYS);
  readout_reset         <= CONTROL(12) when rising_edge(CLK_SYS);
  statebits             <= std_logic_vector(to_unsigned(state_t'pos(state), 8));

  proc_readout : process
    variable channelselect : integer range 0 to 3;
    variable counter : integer range 0 to 2**CONFIG.TriggerDelay'length - 1; 
  begin
    wait until rising_edge(CLK_SYS);
    READOUT_TX.busy_release  <= '0';
    READOUT_TX.data_finished <= '0';
    RDO_data_main            <= (others => '0');
    RDO_write_main           <= '0';

    busy_in_sys <= '0';

    case state is
      when IDLE =>
        READOUT_TX.statusbits <= (others => '0');
        if READOUT_RX.valid_notiming_trg = '1' then
          state <= CHECK_STATUS_TRIGGER;
        elsif READOUT_RX.data_valid = '1' then --seems to have missed trigger...
          READOUT_TX.statusbits <= (23 => '1', others => '0'); --event not found
          state                 <= RELEASE_DIRECT;
        elsif READOUT_RX.valid_timing_trg = '1' then
          if CONF_sys.ProcessingMode = 0 then
            counter := to_integer(CONF_sys.TriggerDelay);
            state <= TRIG_DLY;
          else
            state <= WAIT_BSY;
          end if;
          epoch_counter_save <= epoch_counter; -- all channels at the same time
        end if;

      when RELEASE_DIRECT =>
        state <= DO_RELEASE;

      when DO_RELEASE =>
        if READOUT_RX.data_valid = '1' then
          READOUT_TX.busy_release  <= '1';
          READOUT_TX.data_finished <= '1';
          state                    <= WAIT_FOR_END;
        end if;

      when WAIT_FOR_END =>
        if READOUT_RX.data_valid = '0' then
          state <= IDLE;
        end if;

      when CHECK_STATUS_TRIGGER =>
        if READOUT_RX.data_valid = '1' then
          if READOUT_RX.trg_type = x"E" then
            state <= SEND_STATUS;
          else
            state <= RELEASE_DIRECT;
          end if;
        end if;

      when TRIG_DLY =>
        if counter = 0 then
          busy_in_sys <= '1';
          state <= WAIT_BSY;
        else
          counter := counter - 1;
        end if;             

      when WAIT_BSY =>
        busy_in_sys <= '1';
        if busy_out_sys(channelselect) = '1' then
          -- start moving the counter already now
          -- the RAM output is registered 
          ram_counter(channelselect) <= ram_counter(channelselect) + 1;
          state <= WAIT_RAM;
        end if;
      
      when WAIT_RAM =>
        busy_in_sys <= '1';
        ram_counter(channelselect) <= ram_counter(channelselect) + 1;
        RDO_data_main <= x"cc" & std_logic_vector(epoch_counter_save(channelselect));
        RDO_write_main <= '1'; 
        state <= READOUT;
        
          
      when READOUT =>
        busy_in_sys <= '1';
        if ram_data_sys(channelselect) = x"00000000" then
          -- for old channel, decrease count since we found the end
          ram_counter(channelselect) <= ram_counter(channelselect) - 2;
          -- go to next channel or finish readout
          if channelselect = 3 then
            state <= RELEASE_DIRECT;
            channelselect := 0;
          else
            channelselect := channelselect + 1;
            state <= WAIT_BSY;
          end if;
        else
          RDO_data_main <= ram_data_sys(channelselect);
          RDO_write_main <= '1';
          ram_counter(channelselect) <= ram_counter(channelselect) + 1;
        end if;
        
        
      when SEND_STATUS =>
        RDO_write_main <= '1';
        RDO_data_main  <= x"20000000";
        -- nothing implemented yet
        state          <= RELEASE_DIRECT;
    end case;

    if readout_reset = '1' then
      state <= IDLE;
    end if;
  end process;

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
            DEBUG_BUFFER_DATA(12)           <= '1'; -- ADC_VALID
            DEBUG_BUFFER_DATA(19 downto 16) <= trigger_gen;
          when x"6" =>
            DEBUG_BUFFER_DATA(7 downto 0) <= statebits;
          when others => null;
        end case;
      end if;
    end if;

    DEBUG_BUFFER_READY <= reg_buffer_read;

  end process;

end architecture arch;
