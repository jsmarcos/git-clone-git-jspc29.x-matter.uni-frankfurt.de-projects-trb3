-- Coincidence detection

library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

-- COIN Register
--    Bit   Description
-- <reg_table name="cts_trg_coin_register" >
--          COIN Module Configuration
--    7:0   Coincidence bitmask. Each selected channel must be asserted within the
--          coincidence window.
--   15:8   Inhibit bitmask. Corresponds to trigger input signals. Each mask channel
--          has to be asserted.  
--   19:16  Coincidence window (0 to 15 clock cycles)
-- </reg_table>
entity CTS_TRG_COIN is
   generic (
      INPUT_COUNT       : integer range 1 to 8 := 4
   );

   port (
      CLK_IN          : in  std_logic;
      RST_IN          : in  std_logic;
      
      DATA_IN         : in  std_logic_vector(INPUT_COUNT - 1 downto 0);
      TRIGGER_OUT     : out std_logic;
      
      CONFIG_IN       : in  std_logic_vector(31 downto 0) := (others => '0')
   );
end CTS_TRG_COIN;

architecture rtl of CTS_TRG_COIN is
   alias CONFIG_COIN_MASK_IN : STD_LOGIC_VECTOR(15 downto 0) is CONFIG_IN(15 downto 0);
   alias CONFIG_WINDOW_IN : STD_LOGIC_VECTOR(3 downto 0) is CONFIG_IN(19 downto 16);

   constant MAX_COIN_WINDOW : integer := 2**CONFIG_WINDOW_IN'LENGTH - 1;

-- configuration mapping
   signal config_window_i   : integer range 0 to MAX_COIN_WINDOW;

-- edge detection and generation of time window signals
   signal edge_detection_ref_i : std_logic_vector(INPUT_COUNT-1 downto 0);
   type COUNTERS_T is array(0 to INPUT_COUNT-1) of integer range 0 to MAX_COIN_WINDOW;
   signal counters_i : COUNTERS_T;

-- delayed inputs
   signal synch_inputs_i : std_logic_vector(DATA_IN'RANGE);

   signal coin_frames_i : std_logic_vector(INPUT_COUNT-1 downto 0);
begin
   proc_coin_frames: process(CLK_IN) is
   begin
      if rising_edge(CLK_IN) then
         coin_frames_i <= (others => '0');
         edge_detection_ref_i <= DATA_IN;      
         synch_inputs_i <=  DATA_IN;    -- as one cycle is needed to detect an
                                        -- edge, the bypassed signals must be 
                                        -- delayed for the same amount
                
         for i in 0 to INPUT_COUNT - 1 loop
            if RST_IN = '1' then
               counters_i(i) <= 0;
            else 
               if edge_detection_ref_i(i) = '0' and DATA_IN(i) = '1' then
                  coin_frames_i(i) <= '1';
                  counters_i(i) <= config_window_i;
               elsif counters_i(i) /= 0 then
                  coin_frames_i(i) <= '1';
                  counters_i(i) <= counters_i(i) - 1;
               end if;
            end if;
         end loop;        
      end if;
   end process;

   proc_mask: process(CLK_IN) is
      variable values: std_logic_vector(15 downto 0);
      variable result : std_logic;
   begin
      if rising_edge(CLK_IN) then
         values := X"FFFF";
         values(  INPUT_COUNT-1 downto   0) := coin_frames_i;
         values(8+INPUT_COUNT-1 downto 8+0) := synch_inputs_i;
      
         result := '1';
         for i in 0 to 15 loop
            result := result and (values(i) or not CONFIG_COIN_MASK_IN(i));
         end loop;
         
         TRIGGER_OUT <= result;
      end if;
   end process;

   proc_config: process(CONFIG_WINDOW_IN) is
      variable tmp : integer range 0 to 2**16-1;
   begin
      tmp := to_integer(UNSIGNED(CONFIG_WINDOW_IN));
      if tmp <= MAX_COIN_WINDOW then
         config_window_i <= tmp;
      else
         config_window_i <= MAX_COIN_WINDOW;
      end if;
   end process;
end architecture;