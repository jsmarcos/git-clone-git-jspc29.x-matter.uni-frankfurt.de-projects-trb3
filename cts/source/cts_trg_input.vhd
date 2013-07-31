-- CTS_TRG_INPUT
--  INPUT -> INVERTER -> DELAY -> SPIKE REJECTION -> OVERRIDE -> OUTPUT

-- Configuration
--    Bit   Description
-- <reg_table name="cts_trg_input_register" >
--          Input Module Configuration
--    3:0   Delay (0 to 15 cycles)
--    7:4   Spike Rejection. Number of clock cycles the signal has to be stably asserted until it is interpreted high.
--    8     Invert (0: Bypass, 1: Invert Input)
--    9     Override Enable (0: Bypass, 1: Set Value of 10. Bit)
--    10    Override Value
-- </reg_table>

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

entity CTS_TRG_INPUT is
   port (
      CLK_IN      : in  std_logic;
      RST_IN      : in  std_logic;
      DATA_IN     : in  std_logic;
      DATA_OUT    : out std_logic;
      CONFIG_IN   : in  std_logic_vector(10 downto 0) := (others => '0')
   );
end CTS_TRG_INPUT;

architecture rtl of CTS_TRG_INPUT is
-- setup
   constant MAX_DELAY      : integer := 16;
   constant MAX_SPIKE_REJ  : integer := 16;

-- config mapping
   signal config_delay_i    : integer range 0 to MAX_DELAY-1;
   signal config_spike_i    : integer range 0 to MAX_SPIKE_REJ-1;
   signal config_invert_i   : std_logic;
   signal config_over_ena_i : std_logic;
   signal config_over_val_i : std_logic;

-- connection between stages
   signal from_inverter_i, from_delay_i, from_spike_i : std_logic;

   signal delay_line_i : std_logic_vector(15 downto 0);
   signal spike_rej_counter_i : integer range 0 to MAX_SPIKE_REJ-1;
begin
-- inverter
   proc_delay: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         from_inverter_i <= (DATA_IN xor config_invert_i) and (not RST_IN);
      end if;
   end process;
   
-- delays
   proc_delay: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         if RST_IN = '1' then
            delay_line_i <= (others => '0');
            from_delay_i <= '0';
         else
            delay_line_i <= delay_line_i(delay_line_i'HIGH - 1 downto 0) 
                            & from_inverter_i;
            from_delay_i <= delay_line_i(config_delay_i);
         end if;
      end if;
   end process;
   
-- spike rejection
   -- TODO: delay must be independent of spike rejection setting
   proc_spike: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         if RST_IN = '1' or from_delay_i = '0' then
            spike_rej_counter_i <= config_spike_i;
            from_spike_i <= '0';
         else
            if spike_rej_counter_i = 0 then
               from_spike_i <= '1';
            else
               spike_rej_counter_i <= spike_rej_counter_i - 1;
               from_spike_i <= '0';
            end if;
         end if;
      end if;
   end process;

-- override
   proc_override: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         if RST_IN = '1' then
            DATA_OUT <= '0';
         elsif config_over_ena_i = '1' then
            DATA_OUT <= config_over_val_i;
         else
            DATA_OUT <= from_spike_i;
         end if;
      end if;
   end process;
   
-- config mapping
   config_delay_i    <= to_integer(unsigned(CONFIG_IN(3 downto 0)));
   config_spike_i    <= to_integer(unsigned(CONFIG_IN(7 downto 4)));
   config_invert_i   <= CONFIG_IN(8);
   config_over_ena_i <= CONFIG_IN(9);
   config_over_val_i <= CONFIG_IN(10);
end architecture;