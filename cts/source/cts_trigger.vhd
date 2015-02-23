   library IEEE;
   use IEEE.STD_LOGIC_1164.ALL;
   use IEEE.NUMERIC_STD.ALL;
   
library work;
   use work.cts_pkg.all;
   use work.trb_net_std.all;
   
entity CTS_TRIGGER is
   generic (
      TRIGGER_INPUT_COUNT  : integer range 0 to  8 := 4;
      TRIGGER_COIN_COUNT   : integer range 0 to 15 := 4;
      TRIGGER_PULSER_COUNT : integer range 0 to 15 := 2;
      TRIGGER_RAND_PULSER  : integer range 0 to 15 := 1;
      
      TRIGGER_ADDON_COUNT  : integer range 0 to 15 := 2;
      ADDON_LINE_COUNT     : integer range 0 to 255 := 22;
      ADDON_GROUPS        : integer range 1 to 8 := 5;
      ADDON_GROUP_UPPER   : CTS_GROUP_CONFIG_T  := (3,7,11,12,13, others=>'0');

      PERIPH_TRIGGER_COUNT: integer range 0 to 15 := 1;
      
      OUTPUT_MULTIPLEXERS : integer range 0 to 255 := 0;
      
      EXTERNAL_TRIGGER_ID  : std_logic_vector(7 downto 0) := X"00"
   );

   port (
      CLK_IN       : in  std_logic;
      CLK_1KHZ_IN  : in  std_logic;
      RESET_IN     : in  std_logic;      
      
    -- Trigger Inputs
      TRIGGERS_IN        : in std_logic_vector(MAX(0, TRIGGER_INPUT_COUNT-1) downto 0);

      ADDON_TRIGGERS_IN  : in std_logic_vector(ADDON_LINE_COUNT-1 downto 0) := (others => '0');
      ADDON_GROUP_ACTIVITY_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
      ADDON_GROUP_SELECTED_OUT : out std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
      
      PERIPH_TRIGGER_IN : in std_logic_vector(19 downto 0) := (others => '0');

      OUTPUT_MULTIPLEXERS_OUT : out std_logic_vector(OUTPUT_MULTIPLEXERS-1 downto 0);
      
    -- External 
      EXT_TRIGGER_IN  : in std_logic;
      EXT_STATUS_IN   : in std_logic_vector(31 downto 0) := X"00000000";
      EXT_CONTROL_OUT : out std_logic_vector(31 downto 0);

    -- Output
      TRIGGER_OUT         : out std_logic; -- asserted when trigger detected
      TRIGGER_TYPE_OUT    : out std_logic_vector(3 downto 0);
      TRIGGER_BITMASK_OUT : out std_logic_vector(15 downto 0);
      
    -- Counters
      INPUT_COUNTERS_OUT         : out std_logic_vector(32 * (TRIGGER_INPUT_COUNT+TRIGGER_ADDON_COUNT) - 1 downto 0) := (others => '0');
      INPUT_EDGE_COUNTERS_OUT    : out std_logic_vector(32 * (TRIGGER_INPUT_COUNT+TRIGGER_ADDON_COUNT) - 1 downto 0) := (others => '0');
      CHANNEL_COUNTERS_OUT       : out std_logic_vector(32 * 16 - 1 downto 0) := (others => '0');
      CHANNEL_EDGE_COUNTERS_OUT  : out std_logic_vector(32 * 16 - 1 downto 0) := (others => '0');
      NUM_OF_ITC_USED_OUT        : out std_logic_vector(4 downto 0);
      
    -- Slow Control
      REGIO_ADDR_IN            : in  std_logic_vector(15 downto 0);
      REGIO_DATA_IN            : in  std_logic_vector(31 downto 0);
      REGIO_READ_ENABLE_IN     : in  std_logic;
      REGIO_WRITE_ENABLE_IN    : in  std_logic;
      REGIO_TIMEOUT_IN         : in  std_logic;
      
      REGIO_DATA_OUT           : out std_logic_vector(31 downto 0);
      REGIO_DATAREADY_OUT      : out std_logic;
      REGIO_WRITE_ACK_OUT      : out std_logic;
      REGIO_NO_MORE_DATA_OUT   : out std_logic := '0';
      REGIO_UNKNOWN_ADDR_OUT   : out std_logic
   );
end CTS_TRIGGER;

architecture RTL of CTS_TRIGGER is
-- Internal Trigger Ports
   signal channels_i : std_logic_vector(15 downto 0) := (others => '0');
   signal channel_mask_i : std_logic_vector(15 downto 0);
   signal channel_edge_select_i : std_logic_vector(15 downto 0);
   
   -- internal trigger lines (i.e. all signals that are piped through the trigger input modules)
   constant EFFECTIVE_INPUT_COUNT : integer := TRIGGER_INPUT_COUNT + TRIGGER_ADDON_COUNT;

   constant ITC_NUM_EXT_BUF : unsigned(0 downto 0) := (others => or_all(EXTERNAL_TRIGGER_ID));  -- oh, that's dirty, but dont know a better solution (but define a func)
   constant ITC_NUM_EXT     : integer := to_integer( ITC_NUM_EXT_BUF )  ;
   
   constant ITC_BASE_EXT    : integer      := 0; 
   constant ITC_BASE_PULSER : integer      := ITC_BASE_EXT         + ITC_NUM_EXT;
   constant ITC_BASE_RAND_PULSER : integer := ITC_BASE_PULSER      + TRIGGER_PULSER_COUNT;
   constant ITC_BASE_INPUTS : integer      := ITC_BASE_RAND_PULSER + TRIGGER_RAND_PULSER;
   constant ITC_BASE_PERIPH : integer      := ITC_BASE_INPUTS      + EFFECTIVE_INPUT_COUNT;
   constant ITC_BASE_COINS  : integer      := ITC_BASE_PERIPH      + PERIPH_TRIGGER_COUNT;

   constant ITC_NUM_USED    : integer := ITC_BASE_COINS       + TRIGGER_COIN_COUNT;

   alias trigger_inputs_i : std_logic_vector(EFFECTIVE_INPUT_COUNT - 1 downto 0) 
      is channels_i(ITC_BASE_INPUTS + EFFECTIVE_INPUT_COUNT - 1 downto ITC_BASE_INPUTS);
      
   alias coins_i          : std_logic_vector(TRIGGER_COIN_COUNT - 1 downto 0) 
      is channels_i(ITC_BASE_COINS + TRIGGER_COIN_COUNT - 1 downto ITC_BASE_COINS);
      
   alias pulser_i         : std_logic_vector(TRIGGER_PULSER_COUNT - 1 downto 0) 
      is channels_i(ITC_BASE_PULSER + TRIGGER_PULSER_COUNT - 1 downto ITC_BASE_PULSER);
      
   alias rand_pulsers_i    : std_logic_vector(TRIGGER_RAND_PULSER - 1 downto 0)
      is channels_i(ITC_BASE_RAND_PULSER + TRIGGER_RAND_PULSER - 1 downto ITC_BASE_RAND_PULSER);
      
   type   channel_counters_t is array(channels_i'HIGH downto 0) of unsigned(31 downto 0);
   signal channel_counters_i : channel_counters_t;
   signal channel_edge_counters_i : channel_counters_t;
   
-- Trigger Inputs (Spike Rejection, Negation, Override ...)
   signal triggers_i : std_logic_vector(EFFECTIVE_INPUT_COUNT - 1 downto 0);

   type trigger_input_configs_t is array(EFFECTIVE_INPUT_COUNT - 1 downto 0) of std_logic_vector(10 downto 0);
   signal trigger_input_configs_i : trigger_input_configs_t;

   type   trigger_input_counters_t is array(EFFECTIVE_INPUT_COUNT - 1 downto 0) of unsigned(31 downto 0);
   signal trigger_input_counters_i : trigger_input_counters_t;
   signal trigger_input_edge_counters_i : trigger_input_counters_t;
   
-- Coincidence Detection
   type coin_config_t is array(MAX(0, TRIGGER_COIN_COUNT - 1) downto 0) of std_logic_vector(31 downto 0);
   signal coin_config_i : coin_config_t;
   
-- TRIGGER_PULSER_COUNT
   type   pulser_interval_t is array(MAX(0, TRIGGER_PULSER_COUNT - 1) downto 0) of std_logic_vector(31 downto 0);
   signal pulser_interval_i : pulser_interval_t;
   signal pulser_counter_i  : pulser_interval_t := (others => (others => '0'));
   
-- Random Pulser
   type   rand_pulser_threshold_t is array(MAX(0, TRIGGER_RAND_PULSER - 1) downto 0) of std_logic_vector(31 downto 0);
   signal rand_pulser_threshold_i : rand_pulser_threshold_t := (others => (others => '0'));

   
-- Peripheral Trigger Inputs
   type periph_trigger_mask_t is array(MAX(0, PERIPH_TRIGGER_COUNT - 1) downto 0) of std_logic_vector(19 downto 0);
   signal periph_trigger_mask_i   : periph_trigger_mask_t;
   
-- Add On 
   type trigger_addon_configs_t is array(TRIGGER_ADDON_COUNT - 1 downto 0) of std_logic_vector(7 downto 0);
   signal trigger_addon_configs_i : trigger_addon_configs_t;
   signal addon_group_activity_i : std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
   signal addon_group_selected_i : std_logic_vector(ADDON_GROUPS-1 downto 0) := (others => '0');
   
   type output_multiplexer_configs_t is array(MAX(0,OUTPUT_MULTIPLEXERS - 1) downto 0) of std_logic_vector(7 downto 0);
   signal output_multiplexer_configs_i : output_multiplexer_configs_t;
   signal output_multiplexer_ins_i : std_logic_vector(16 + 2*TRIGGER_INPUT_COUNT + ADDON_LINE_COUNT + TRIGGER_ADDON_COUNT downto 0);
   
-- Trigger Type Assoc 
   type trigger_type_assoc_t is array(0 to 15) of std_logic_vector(3 downto 0);
   signal trigger_type_assoc_i : trigger_type_assoc_t := (others => X"1");

-- External Trigger Logic
   signal ext_control_i : std_logic_vector(31 downto 0) := (others => '0');
begin
   assert ITC_NUM_USED <= 16
      report "Number of modules exceeds number of internal trigger channels"
      severity failure;

   NUM_OF_ITC_USED_OUT <= STD_LOGIC_VECTOR(TO_UNSIGNED(ITC_NUM_USED, 5));
   EXT_CONTROL_OUT <= ext_control_i;

-- Modules   
   proc_input_ffs: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) and TRIGGER_INPUT_COUNT > 0  then
         triggers_i(TRIGGER_INPUT_COUNT-1 downto 0) <= TRIGGERS_IN;
      end if;
   end process;
   
   proc_addon_mux: process(CLK_IN) is
      variable sel : integer range 0 to 255;
   begin
      if rising_edge(CLK_IN) then
         for i in 0 to TRIGGER_ADDON_COUNT - 1  loop
            sel := to_integer( UNSIGNED(trigger_addon_configs_i(i)) );
            
            triggers_i(TRIGGER_INPUT_COUNT + i) <= '0';
            if sel <= ADDON_TRIGGERS_IN'HIGH then
               triggers_i(TRIGGER_INPUT_COUNT + i) <= ADDON_TRIGGERS_IN( sel );
            elsif sel <= ADDON_TRIGGERS_IN'HIGH + 16 then
               triggers_i(TRIGGER_INPUT_COUNT + i) <= channels_i(sel - ADDON_TRIGGERS_IN'HIGH - 1);
            end if;
         end loop;
      end if;
   end process;

   gen_ext_trigger: if EXTERNAL_TRIGGER_ID /= X"00" generate
      channels_i(ITC_BASE_EXT) <= EXT_TRIGGER_IN;
   end generate;
   
   proc_output_mux_ins: process (channels_i, TRIGGERS_IN, ADDON_TRIGGERS_IN, trigger_inputs_i, output_multiplexer_configs_i, CLK_IN) is
      variable i : integer := 0;
   begin
      i := 0;
   
      output_multiplexer_ins_i(15 + i downto i) <= channels_i;
      i := i + 16;
      
      if TRIGGER_INPUT_COUNT > 0 then
         output_multiplexer_ins_i(TRIGGERS_IN'high + i downto i) <= TRIGGERS_IN;
         i := i + TRIGGER_INPUT_COUNT;
      end if;

      if ADDON_LINE_COUNT > 0 then
         output_multiplexer_ins_i(ADDON_TRIGGERS_IN'high + i downto i) <= ADDON_TRIGGERS_IN;
         i := i + ADDON_LINE_COUNT;
      end if;
      
      output_multiplexer_ins_i(trigger_inputs_i'high + i downto i) <= trigger_inputs_i;
      i := i + EFFECTIVE_INPUT_COUNT;
      
      output_multiplexer_ins_i(i) <= CLK_IN;
      i := i + 1;
   end process;
   
   proc_out_mux: process (output_multiplexer_ins_i, output_multiplexer_configs_i) is
      variable tmp : integer range 0 to 255 := 0;
      variable idx : integer range 0 to output_multiplexer_ins_i'high := 0;
      variable test : std_logic_vector(31 downto 0);
   begin
      for j in 0 to output_multiplexers - 1 loop
          output_multiplexers_out(j) <= output_multiplexer_ins_i(to_integer( unsigned( output_multiplexer_configs_i(j))));
      end loop;   
   end process;
   
   gen_trigger_inputs: for i in 0 to EFFECTIVE_INPUT_COUNT-1 generate
      my_trigger_input: CTS_TRG_INPUT port map (
         CLK_IN => CLK_IN,
         RST_IN => RESET_IN,
         DATA_IN => triggers_i(i),
         DATA_OUT => trigger_inputs_i(i),
         CONFIG_IN => trigger_input_configs_i(i)
      );
   end generate;
   
   gen_coin: for i in 0 to TRIGGER_COIN_COUNT - 1 generate
      my_coin: CTS_TRG_COIN 
      generic map (
         INPUT_COUNT => EFFECTIVE_INPUT_COUNT
      )
      port map (
         CLK_IN => CLK_IN,
         RST_IN => RESET_IN,
         DATA_IN => trigger_inputs_i,
         TRIGGER_OUT => coins_i(i),
         CONFIG_IN => coin_config_i(i)
      );
   end generate;
   
   gen_rand_pulser: for i in 0 to TRIGGER_RAND_PULSER - 1 generate
      my_rand_pulser: CTS_TRG_PSEUDORAND_PULSER
      generic map (
         DATA_XOR     => STD_LOGIC_VECTOR(TO_UNSIGNED(i, 32))
      ) port map (
         CLK_IN       => CLK_IN,
         THRESHOLD_IN => rand_pulser_threshold_i(i),
         TRIGGER_OUT  => rand_pulsers_i(i)
      );
   end generate;
   
   proc_periph: process(CLK_IN) is
   begin
      if rising_edge(clk_in) and PERIPH_TRIGGER_COUNT > 0 then
         for i in 0 to PERIPH_TRIGGER_COUNT - 1 loop
            channels_i(ITC_BASE_PERIPH + i) <= OR_ALL( periph_trigger_mask_i(i) and PERIPH_TRIGGER_IN );
         end loop;
      end if;
   end process;
   
   proc_pulser: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         for i in 0 to TRIGGER_PULSER_COUNT-1 loop
            pulser_i(i) <= '0';
            
            if pulser_counter_i(i) >= pulser_interval_i(i) then
               pulser_counter_i(i) <= (others => '0');
               pulser_i(i) <= '1';
               
            else
               pulser_counter_i(i) <= STD_LOGIC_VECTOR(UNSIGNED(pulser_counter_i(i)) + TO_UNSIGNED(1,1));
               
            end if;
         end loop;
      end if;
   end process;

   
-- Common   
   proc_output: process(CLK_IN) is
      variable channels_delay_v : std_logic_vector(15 downto 0) := (others => '1');
   begin
      if rising_edge(CLK_IN) then
         TRIGGER_OUT <= '0';
         TRIGGER_TYPE_OUT <= (others => '-');
         TRIGGER_BITMASK_OUT <= channels_i;
         
         if RESET_IN = '1' then
            channels_delay_v := (others => '1');
         else
            for i in 15 downto 0 loop
               if channel_edge_select_i(i) = '1' then
                  -- detect rising edges
                  if channels_delay_v(i) = '0' and channels_i(i) = '1' and channel_mask_i(i) = '1' then
                     TRIGGER_OUT <= '1';
                     TRIGGER_TYPE_OUT <= trigger_type_assoc_i(i);
                  end if;
               else
                  -- sensitive to high level
                  if channels_i(i) = '1' and channel_mask_i(i) = '1' then
                     TRIGGER_OUT <= '1';
                     TRIGGER_TYPE_OUT <= trigger_type_assoc_i(i);
                  end if;
               end if;
            end loop;
            
            channels_delay_v := channels_i;
         end if;
      end if;
   end process;
   
   proc_counter: process(CLK_IN) is
      variable last_inputs_v : std_logic_vector(triggers_i'range);
      variable last_itc_v : std_logic_vector(channels_i'range);
   
   begin
      if rising_edge(CLK_IN) then
         if RESET_IN = '1' then
            trigger_input_counters_i      <= (others => (others => '0'));
            channel_counters_i            <= (others => (others => '0'));
            trigger_input_edge_counters_i <= (others => (others => '0'));
            channel_edge_counters_i       <= (others => (others => '0'));
         
         else
            for i in 0 to EFFECTIVE_INPUT_COUNT-1 loop
               if triggers_i(i) = '1' then
                  trigger_input_counters_i(i) <= trigger_input_counters_i(i) + "1";
                  
                  if last_inputs_v(i) = '0' then
                     trigger_input_edge_counters_i(i) <= trigger_input_edge_counters_i(i) + "1";
                  end if;
               end if;
            end loop;

            for i in 0 to channels_i'HIGH loop
               if channels_i(i) = '1' then
                  channel_counters_i(i) <= channel_counters_i(i) + ("1");
                  
                  if last_itc_v(i) = '0' then
                     channel_edge_counters_i(i) <= channel_edge_counters_i(i) + "1";
                  end if;
               end if;
            end loop;
            
         end if;
         
         last_inputs_v := triggers_i;
         last_itc_v := channels_i;
      end if;
   end process;
   
   gen_input_counter: for i in 0 to EFFECTIVE_INPUT_COUNT-1 generate
      INPUT_COUNTERS_OUT(i*32 + 31 downto i*32) <= trigger_input_counters_i(i);
      INPUT_EDGE_COUNTERS_OUT(i*32 + 31 downto i*32) <= trigger_input_edge_counters_i(i);
   end generate;

   gen_channel_counter: for i in 0 to channels_i'HIGH generate
      CHANNEL_COUNTERS_OUT(i*32 + 31 downto i*32) <= channel_counters_i(i);
      CHANNEL_EDGE_COUNTERS_OUT(i*32 + 31 downto i*32) <= channel_edge_counters_i(i);
   end generate;

-- AddOn Leds
-----------------------------------------
   process(CLK_IN) is
      variable from : integer;
   begin
      if rising_edge(CLK_IN) then
         from := 0;
         if CLK_1KHZ_IN ='1' then
            addon_group_activity_i <= (others => '0');
         
         else
            for i in 0 to ADDON_GROUPS-1 loop
               addon_group_activity_i(i) <= addon_group_activity_i(i) or
                  OR_ALL(ADDON_TRIGGERS_IN(ADDON_GROUP_UPPER(i) downto from));
               
               addon_group_selected_i(i) <= '0';
               for j in 0 to TRIGGER_ADDON_COUNT-1 loop
                  if from <= to_integer( UNSIGNED(trigger_addon_configs_i(j)) ) and 
                     to_integer( UNSIGNED(trigger_addon_configs_i(j)) ) <= ADDON_GROUP_UPPER(i) then
                     addon_group_selected_i(i) <= '1';
                  end if;
               end loop;
               
               from := ADDON_GROUP_UPPER(i)+1;
            end loop;
         end if;
      end if;
   end process;
   
   ADDON_GROUP_ACTIVITY_OUT <= addon_group_activity_i;
   ADDON_GROUP_SELECTED_OUT <= addon_group_selected_i;
   
-- RegIO
-----------------------------------------
   proc_regio: process(CLK_IN) is
      variable addr : integer range 0 to 255;
      variable ref_addr : integer range 0 to 255;
   begin
      if rising_edge(CLK_IN) then
         REGIO_DATA_OUT <= (others => '0');
         REGIO_DATAREADY_OUT <= '0';
         REGIO_WRITE_ACK_OUT <= '0';
         REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN or REGIO_READ_ENABLE_IN;

         addr := to_integer(unsigned(REGIO_ADDR_IN(7 downto 0)));
         ref_addr := 0;
         
         if RESET_IN = '1' then
            -- modelsim want's it that way
            channel_mask_i <= (others => '0');
            channel_edge_select_i <= (others => '1');
            
            trigger_input_configs_i <= (others => (others => '0'));
            coin_config_i <= (others => X"000F0000");
            pulser_interval_i <= (1 => X"00000003",  others => (others => '1'));
            
            rand_pulser_threshold_i <= (others => (others => '0'));

            ext_control_i <= (others => '0');
            
            for i in 0 to TRIGGER_ADDON_COUNT - 1 loop
               trigger_addon_configs_i(i) <= STD_LOGIC_VECTOR(TO_UNSIGNED(i mod ADDON_LINE_COUNT, 8));
            end loop;
            
            for i in 0 to OUTPUT_MULTIPLEXERS - 1 loop
               output_multiplexer_configs_i(i) <= STD_LOGIC_VECTOR(TO_UNSIGNED(i mod output_multiplexer_ins_i'length, 8));
            end loop;
            
         else

-- Trigger Channel Masking         
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_DATA_OUT <= CTS_BLOCK_HEADER(id => 16#00#, len => 1);
            end if;
            ref_addr := ref_addr + 1;
            
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= '0';
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
               
               REGIO_DATA_OUT(31 downto 0) <= channel_edge_select_i & channel_mask_i;
               
               if REGIO_WRITE_ENABLE_IN = '1' then
                  channel_mask_i        <= REGIO_DATA_IN(15 downto 0);
                  channel_edge_select_i <= REGIO_DATA_IN(31 downto 16);
               end if;
            end if;
            ref_addr := ref_addr + 1;
            
-- Trigger Channel Counters
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_DATA_OUT <= CTS_BLOCK_HEADER(id => 16#01#, len => 32);
            end if;
            ref_addr := ref_addr + 1;
            
            for i in 0 to channel_counters_i'HIGH loop
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  
                  REGIO_DATA_OUT <= std_logic_vector( channel_counters_i(i) );
               end if;
               ref_addr := ref_addr + 1;

               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  
                  REGIO_DATA_OUT <= std_logic_vector( channel_edge_counters_i(i) );
               end if;
               ref_addr := ref_addr + 1;
            end loop;
            
-- Input Module Configuration            
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                  id => 16#10#,
                  len => EFFECTIVE_INPUT_COUNT,
                  itc_base => ITC_BASE_INPUTS,
                  itc_num  => EFFECTIVE_INPUT_COUNT
               );
            end if;
            ref_addr := ref_addr + 1;            

-- INPUT CONFIGURATION
            for i in 0 to EFFECTIVE_INPUT_COUNT - 1 loop
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= '0';
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                  
                  REGIO_DATA_OUT(10 downto 0) <= trigger_input_configs_i(i);
                  
                  if REGIO_WRITE_ENABLE_IN = '1' then
                     trigger_input_configs_i(i) <= REGIO_DATA_IN(10 downto 0);
                  end if;
               end if;
               ref_addr := ref_addr + 1;            
            end loop;

-- Trigger Input Counters
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_DATA_OUT <= CTS_BLOCK_HEADER(id => 16#11#, len => 2*EFFECTIVE_INPUT_COUNT);
            end if;
            ref_addr := ref_addr + 1;
            
            for i in 0 to EFFECTIVE_INPUT_COUNT - 1 loop
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  
                  REGIO_DATA_OUT <= std_logic_vector( trigger_input_counters_i(i) );
               end if;
               ref_addr := ref_addr + 1;

               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  
                  REGIO_DATA_OUT <= std_logic_vector( trigger_input_edge_counters_i(i) );
               end if;
               ref_addr := ref_addr + 1;               
            end loop;
            
-- COIN CONFIGURATION
            if TRIGGER_COIN_COUNT > 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => 16#20#,
                     len => TRIGGER_COIN_COUNT,
                     itc_base => ITC_BASE_COINS,
                     itc_num  => TRIGGER_COIN_COUNT
                  );
               end if;
               ref_addr := ref_addr + 1;  
               
               for i in 0 to TRIGGER_COIN_COUNT - 1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= coin_config_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        coin_config_i(i) <= REGIO_DATA_IN;
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 
   
               end loop;
            end if;
            
-- ADDON MULTIPLEXER
            if TRIGGER_ADDON_COUNT > 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => 16#15#,
                     len => TRIGGER_ADDON_COUNT,
                     itc_base => ITC_BASE_INPUTS + TRIGGER_INPUT_COUNT,
                     itc_num  => TRIGGER_ADDON_COUNT
                  );
               end if;
               ref_addr := ref_addr + 1;  
               
               for i in 0 to TRIGGER_ADDON_COUNT - 1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= (others => '0');
                     REGIO_DATA_OUT(trigger_addon_configs_i(i)'RANGE) <= trigger_addon_configs_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        trigger_addon_configs_i(i) <= REGIO_DATA_IN(trigger_addon_configs_i(i)'RANGE);
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 
   
               end loop;
            end if;            

-- OUTPUT MULTIPLEXER MODULE (important: has to appear AFTER type 0x10 and 0x12/0x15 in order to compute the length of the bitmasks correctly)
            if OUTPUT_MULTIPLEXERS > 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => 16#13#,
                     len => OUTPUT_MULTIPLEXERS,
                     itc_base => 0,
                     itc_num  => 0
                  );
               end if;
               ref_addr := ref_addr + 1;  
               
               for i in 0 to OUTPUT_MULTIPLEXERS - 1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= (others => '0');
                     REGIO_DATA_OUT(output_multiplexer_configs_i(i)'RANGE) <= output_multiplexer_configs_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        output_multiplexer_configs_i(i) <= REGIO_DATA_IN(output_multiplexer_configs_i(i)'RANGE);
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 
   
               end loop;
            end if;            
            
-- PERIPH TRIGGER 
            if PERIPH_TRIGGER_COUNT > 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => 16#14#,
                     len => PERIPH_TRIGGER_COUNT,
                     itc_base => ITC_BASE_PERIPH,
                     itc_num  => PERIPH_TRIGGER_COUNT
                  );
               end if;
               ref_addr := ref_addr + 1;  
               
               for i in 0 to PERIPH_TRIGGER_COUNT-1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= (others => '0');
                     REGIO_DATA_OUT(periph_trigger_mask_i(i)'range) <= periph_trigger_mask_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        periph_trigger_mask_i(i) <= REGIO_DATA_IN(periph_trigger_mask_i(i)'range);
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 
               end loop;
            end if;     
            
-- TRIGGER_PULSER_COUNT CONFIGURATION
            if TRIGGER_PULSER_COUNT > 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => 16#30#,
                     len => TRIGGER_PULSER_COUNT,
                     itc_base => ITC_BASE_PULSER,
                     itc_num  => TRIGGER_PULSER_COUNT
                  );
               end if;
               ref_addr := ref_addr + 1;  
               
               for i in 0 to TRIGGER_PULSER_COUNT - 1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= pulser_interval_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        pulser_interval_i(i) <= REGIO_DATA_IN;
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 

               end loop;
            end if;
            
-- Pseudo Random Pulser
            if TRIGGER_RAND_PULSER /= 0 then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id   => 16#50#,
                     len  => TRIGGER_RAND_PULSER,
                     itc_base => ITC_BASE_RAND_PULSER,
                     itc_num  => TRIGGER_RAND_PULSER,
                     last => false
                  );
               end if;
               ref_addr := ref_addr + 1;
               
               for i in 0 to TRIGGER_RAND_PULSER - 1 loop
                  if addr=ref_addr then
                     REGIO_UNKNOWN_ADDR_OUT <= '0';
                     REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                     REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                     
                     REGIO_DATA_OUT <= rand_pulser_threshold_i(i);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        rand_pulser_threshold_i(i) <= REGIO_DATA_IN;
                     end if;
                  end if;
                  ref_addr := ref_addr + 1;                 

               end loop;              
            end if;

-- External Trigger
            if EXTERNAL_TRIGGER_ID /= X"00" then
               if addr = ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                     id => to_integer(unsigned(EXTERNAL_TRIGGER_ID)),
                     len => 2,
                     itc_base => ITC_BASE_EXT,
                     itc_num  => 1,
                     last => false
                  );
               end if;
               ref_addr := ref_addr + 1;
             
             -- status register
               if addr=ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
                  REGIO_DATAREADY_OUT    <= REGIO_READ_ENABLE_IN;
                  REGIO_DATA_OUT         <= EXT_STATUS_IN;
               end if;
               ref_addr := ref_addr + 1;   
                  
               -- control register
               if addr=ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= '0';
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                  
                  REGIO_DATA_OUT <= ext_control_i;
                  
                  if REGIO_WRITE_ENABLE_IN = '1' then
                     ext_control_i <= REGIO_DATA_IN;
                  end if;
               end if;
               ref_addr := ref_addr + 1;   
            end if;
            
-- Trigger Type Assoc
            if addr = ref_addr then
               REGIO_UNKNOWN_ADDR_OUT <= REGIO_WRITE_ENABLE_IN;
               REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
               REGIO_DATA_OUT <= CTS_BLOCK_HEADER(
                  id => 16#40#,
                  len => 2,
                  last => true
               );
            end if;
            ref_addr := ref_addr + 1;  
            
            for i in 0 to 1 loop
               if addr=ref_addr then
                  REGIO_UNKNOWN_ADDR_OUT <= '0';
                  REGIO_DATAREADY_OUT <= REGIO_READ_ENABLE_IN;
                  REGIO_WRITE_ACK_OUT <= REGIO_WRITE_ENABLE_IN;
                  
                  for j in 0 to 7 loop
                     REGIO_DATA_OUT(j*4 + 3 downto j*4) <= trigger_type_assoc_i(8*i+j);
                     
                     if REGIO_WRITE_ENABLE_IN = '1' then
                        trigger_type_assoc_i(8*i+j) <= REGIO_DATA_IN(j*4 + 3 downto j*4);
                     end if;
                  end loop;
               end if;
               ref_addr := ref_addr + 1;
            end loop;

         end if;
      end if;
   end process;
end RTL;