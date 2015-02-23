library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.math_real.all;
   use work.cbmnet_interface_pkg.all;

entity TB_CBMNET_READOUT_TRBNET_DECODER is
end TB_CBMNET_READOUT_TRBNET_DECODER;

architecture TB of TB_CBMNET_READOUT_TRBNET_DECODER is
   -- TrbNet
signal CLK_IN : std_logic := '1';
signal RESET_IN : std_logic := '0';

      -- connect to hub
signal HUB_CTS_START_READOUT_IN : std_logic := '0';
signal HUB_CTS_READOUT_FINISHED_OUT : std_logic := '0';  --no more data, end transfer, send TRM
signal HUB_FEE_DATA_IN : std_logic_vector (15 downto 0) := (others => '0');
signal HUB_FEE_DATAREADY_IN : std_logic := '0';
signal GBE_FEE_READ_IN : std_logic := '0';
      
      -- Decode
signal DEC_EVT_INFO_OUT : std_logic_vector(31 downto 0) := (others => '0');
signal DEC_LENGTH_OUT : std_logic_vector(15 downto 0) := (others => '0');
signal DEC_SOURCE_OUT : std_logic_vector(15 downto 0) := (others => '0');
signal DEC_DATA_OUT : std_logic_vector(15 downto 0) := (others => '0');
signal DEC_DATA_READY_OUT : std_logic := '0';
signal DEC_DATA_READ_IN : std_logic := '0';
      
signal DEC_ACTIVE_OUT : std_logic := '0';
signal DEC_ERROR_OUT : std_logic := '0';
      
signal DEBUG_OUT : std_logic_vector(31 downto 0) := (others => '0');
begin
   DUT: cbmnet_readout_trbnet_decoder
   port map (
      CLK_IN => CLK_IN,
      RESET_IN => RESET_IN,
      ENABLED_IN => '1',
      HUB_CTS_START_READOUT_IN => HUB_CTS_START_READOUT_IN,
      HUB_FEE_DATA_IN => HUB_FEE_DATA_IN,
      HUB_FEE_DATAREADY_IN => HUB_FEE_DATAREADY_IN,
      GBE_FEE_READ_IN => GBE_FEE_READ_IN,
      DEC_EVT_INFO_OUT => DEC_EVT_INFO_OUT,
      DEC_LENGTH_OUT => DEC_LENGTH_OUT,
      DEC_SOURCE_OUT => DEC_SOURCE_OUT,
      DEC_DATA_OUT => DEC_DATA_OUT,
      DEC_DATA_READY_OUT => DEC_DATA_READY_OUT,
      DEC_DATA_READ_IN => DEC_DATA_READ_IN,
      DEC_ACTIVE_OUT => DEC_ACTIVE_OUT,
      DEC_ERROR_OUT => DEC_ERROR_OUT,
      DEBUG_OUT => DEBUG_OUT
   );
   
   CLK_IN <= not CLK_IN after 5 ns;
   RESET_IN <= '1', '0' after 20 ns;
   
   TRBNET_EMU: process is 
      variable seed1, seed2: positive;               -- seed values for random generator
      variable rand: real;                           -- random real-number value in range 0 to 1.0
      variable int_rand: integer;                    -- random integer value in range 0..4095
   
   begin
      wait for 50 ns;
      wait until rising_edge(CLK_IN);
      
      HUB_CTS_START_READOUT_IN <= '1';
      wait for 50 ns;
      
      for i in 0 to 16#40# + 2 loop
         HUB_FEE_DATAREADY_IN <= '0';
         GBE_FEE_READ_IN <= '0';
         case(i) is
            when 0 => HUB_FEE_DATA_IN <= x"beaf";
            when 1 => HUB_FEE_DATA_IN <= x"dead";
            when 2 => HUB_FEE_DATA_IN <= x"0080";
            when 3 => HUB_FEE_DATA_IN <= x"affe";
            when others => HUB_FEE_DATA_IN <= STD_LOGIC_VECTOR(TO_UNSIGNED(i, 16));
         end case;
         
         UNIFORM(seed1, seed2, rand);
         while (rand > 0.8) loop
            UNIFORM(seed1, seed2, rand);
            wait until rising_edge(CLK_IN);
         end loop;
         HUB_FEE_DATAREADY_IN <= '1';
         UNIFORM(seed1, seed2, rand);
         while (rand > 0.7) loop
            UNIFORM(seed1, seed2, rand);
            wait until rising_edge(CLK_IN);
         end loop;
         GBE_FEE_READ_IN <= '1';
         wait until rising_edge(CLK_IN);
      end loop;
      
      wait for 1 us;
   end process;
end architecture;