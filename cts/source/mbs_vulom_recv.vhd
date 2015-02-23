library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;


entity mbs_vulom_recv is
   generic (
      INCL_RDO_TIMESTAMP : integer range c_NO to c_YES := c_NO; -- will yield an unexpected rdo length (2 words instead the signalled 1 word)
                                                               -- if used as an ETM for the CTS
      INCL_REGIO : integer range c_NO to c_YES := c_NO                                                        
   );
   port(
      CLK        : in std_logic;  -- e.g. 100 MHz
      RESET_IN   : in std_logic;  -- could be used after busy_release to make sure entity is in correct state

      --Module inputs
      MBS_IN     : in std_logic;  -- raw input
      CLK_200    : in std_logic;  -- internal sampling clock

      --trigger outputs
      TRG_ASYNC_OUT  : out std_logic;  -- asynchronous rising edge, length varying, here: approx. 110 ns
      TRG_SYNC_OUT   : out std_logic;  -- sync. to CLK

      --data output for read-out
      TRIGGER_IN     : in  std_logic;
      TRG_NUMBER_IN  : in  std_logic_vector (15 downto 0);
      TRG_CODE_IN    : in  std_logic_vector (7  downto 0);     
      TIMING_TRG_IN : in std_logic := '0';

      
      DATA_OUT     : out std_logic_vector(31 downto 0);
      WRITE_OUT    : out std_logic;
      STATUSBIT_OUT: out std_logic_vector(31 downto 0) := (others => '0');
      FINISHED_OUT : out std_logic;

      --Registers / Debug    
      REGIO_IN  : in  CTRLBUS_RX := (data => x"00000000", addr => x"0000", others => '0');
      REGIO_OUT : out CTRLBUS_TX;
      
      
      -- Ctrl and Status registers are only in use, if INCL_REGIO = c_NO ("ETM" mode)
      CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
      STATUS_REG_OUT : out std_logic_vector(31 downto 0) := (others => '0');
      HEADER_REG_OUT : out std_logic_vector(1 downto 0);
      DEBUG          : out std_logic_vector(31 downto 0)    
   );

   attribute syn_useioff : boolean;
   --no IO-FF for MBS input
   attribute syn_useioff of MBS_IN    : signal is false;
end entity;

--MBS format
--Startbit    (0): “0“
--Preamb. (1): “1010“
--Trig.nr.  (2) :24bit
--Status  (3): unused (2 bits)
--Paritybit   (4): “0“ or “1“ (positive?)
--Postam. (5):“1010“
--Stopbit   (0): “1“
--Parity check over counter & status bit

--Data Format: 
-- Bit 23 -  0 : Trigger Number
-- Bit 30 - 29 : Status
-- Bit 31      : Error flag

--statusbit 23 will be set in case of a data error from MBS

architecture mbs_vulom_recv_arch of mbs_vulom_recv is


   signal bitcnt : integer range 0 to 37;
   signal shift_reg : std_logic_vector(36 downto 0);

   signal first_bits_fast : std_logic;
   signal first_bits_slow : std_logic;
   signal reg_MBS_IN      : std_logic;
   signal reg_MBS_DELAY   : std_logic;
   signal done            : std_logic;
   signal done_slow       : std_logic;

   signal number_reg      : std_logic_vector(23 downto 0);
   signal status_reg      : std_logic_vector(1 downto 0);
   signal error_reg       : std_logic;

   signal trg_async       : std_logic;
   signal trg_sync        : std_logic;
   signal trg_sync200     : std_logic;

   type state_t is (IDLE, WAIT1,WAIT2,WAIT3,WAIT4, FINISH);
   signal state           : state_t;

   type rdo_state_t is (RDO_IDLE, RDO_WAIT, RDO_WRITE, RDO_TIMESTAMP, RDO_LVL1_ID, RDO_FINISH);
   signal rdostate        : rdo_state_t;

   signal config_rdo_disable_i : std_logic;
   signal config_invert_input_i : std_logic;

   signal rec_counter_i  : unsigned(31 downto 0) := (others => '0');
   signal act_counter_i : unsigned(31 downto 0) := (others => '0');
   signal high_counter_i : unsigned(31 downto 0) := (others => '0');
   
-- timestamp
   signal timing_trg_i : std_logic;
   signal lvl1_trg_i   : std_logic;
   
   signal timestamp_i        : unsigned(31 downto 0); -- time since last timing trigger with lvl1 received (200 MHz)
   signal timestamp_fresh_i  : unsigned(31 downto 0); -- time since last timing trigger (200 MHz)
   signal lvl1_id_i          : std_logic_vector(23 downto 0); -- TRG-NUM + CODE
   
   signal rec_timestamp_i : std_logic_vector(31 downto 0); -- time trg_sync200 was asserted
   signal rec_lvl1_id_i   : std_logic_vector(23 downto 0); -- lvl1 info for timestamp
   
   signal rdo_buf_rec_timestamp_i : std_logic_vector(31 downto 0); -- read-out buffer for the above
   signal rdo_buf_rec_lvl1_id_i   : std_logic_vector(23 downto 0); -- read-out buffer for the above
begin
   HEADER_REG_OUT <= b"01"; -- we tell the CTS that we send one word of over DATA_OUT
   
   reg_MBS_IN <= MBS_IN xor config_invert_input_i when rising_edge(CLK_200);
   reg_MBS_DELAY <= reg_MBS_IN when rising_edge(CLK_200);

   PROC_FIRST_BITS : process begin
   wait until rising_edge(CLK_200);
   if bitcnt > 32 and RESET_IN = '0' then
      first_bits_fast <= '1';
   else
      first_bits_fast <= '0';
   end if;
   end process;
   
   first_bits_slow <= first_bits_fast when rising_edge(CLK);

   trg_async     <= (not MBS_IN or trg_async) when first_bits_fast = '1' else '0';
   trg_sync      <= (not reg_MBS_IN or trg_sync) and first_bits_slow when rising_edge(CLK);

   TRG_ASYNC_OUT <= trg_async;
   TRG_SYNC_OUT  <= trg_sync when rising_edge(CLK);

   PROC_FSM: process begin
   wait until rising_edge(CLK_200);

   case state is
      when IDLE =>
         bitcnt <= 37;
         done <= '1';
         if reg_MBS_IN = '0' then
         done  <= '0';
         state <= WAIT1;
         end if;
         
      when WAIT1 =>
         state <= WAIT2;
         
      when WAIT2 =>
         bitcnt <= bitcnt - 1;
         shift_reg <= shift_reg(shift_reg'high - 1 downto 0) & reg_MBS_IN;
         state <= WAIT3;
         
      when WAIT3 =>
         if bitcnt = 0 then
         state <= FINISH;
         else
         state <= WAIT4;
         end if;
         
      when WAIT4 =>
         state <= WAIT1;
         
      when FINISH =>
         if reg_MBS_IN = '1' then
         state <= IDLE;
         end if;
         done <= '1';
   end case;
   if RESET_IN = '1' then
      state <= IDLE;
      done <= '0';
   end if;
   end process;

   done_slow <= done when rising_edge(CLK);

   PROC_REG_INFO : process begin
   wait until rising_edge(CLK);
   if done_slow = '1' then
      number_reg <= shift_reg(31 downto 8);
      status_reg <= shift_reg(7 downto 6);

      if shift_reg(36 downto 32) = "01010" and shift_reg(4 downto 0) = "10101" and xor_all(shift_reg(31 downto 5)) = '0' then
         error_reg <= '0';
      else
         error_reg <= '1';
      end if;
   end if;
   end process;


   PROC_RDO : process
      variable incl_timestamp_v : std_logic;
   begin
   wait until rising_edge(CLK);
   WRITE_OUT     <= '0';
   FINISHED_OUT  <= config_rdo_disable_i;
   incl_timestamp_v := '0';
   case rdostate is
      when RDO_IDLE =>
         if TRIGGER_IN = '1' and config_rdo_disable_i = '0' then
         if done_slow = '0' then
            rdostate <= RDO_WAIT;
         else
            rdostate <= RDO_WRITE;
         end if;
         end if;
      when RDO_WAIT =>
         if done_slow = '1' then
         rdostate <= RDO_WRITE;
         end if;
         
      when RDO_WRITE =>
         if INCL_RDO_TIMESTAMP=c_YES then
            rdostate <= RDO_TIMESTAMP;
            incl_timestamp_v := '1';
         else
            rdostate <= RDO_FINISH;
         end if;
         
         DATA_OUT <= error_reg & status_reg & "0000" & incl_timestamp_v & number_reg;
         WRITE_OUT <= '1';
      
      when RDO_TIMESTAMP =>
         DATA_OUT <= rdo_buf_rec_timestamp_i;
         WRITE_OUT <= '1';
         rdostate <= RDO_LVL1_ID;
         
      when RDO_LVL1_ID =>
         DATA_OUT <= x"00" & rdo_buf_rec_lvl1_id_i;
         WRITE_OUT <= '1';
         rdostate <= RDO_FINISH;
      
      when RDO_FINISH =>
         FINISHED_OUT <= '1';
         rdostate     <= RDO_IDLE;
   end case;
   end process;

   STATUSBIT_OUT(23) <= error_reg when rising_edge(CLK);
   STATUS_REG_OUT <= error_reg & MBS_IN & "000000" & number_reg;
   DEBUG <= x"00000000"; -- & done & '0' & shift_reg(13 downto 0);

   
   -- when timing trigger arives first we reset a temporary timestamp, that will
   -- be not used until we know the corresponding lvl1 id ...
   PROC_TIME_BASE: process is
      variable timing_trg_delay : std_logic;
      variable lvl1_trg_delay : std_logic;
   begin
      wait until rising_edge(CLK_200);

      timestamp_fresh_i <= timestamp_fresh_i + 1;
      if timing_trg_i='1' and timing_trg_delay='0' then
         timestamp_fresh_i <= (others => '0');
      end if;
      
      timestamp_i <= timestamp_i + 1;
      if lvl1_trg_i='1' and lvl1_trg_delay='0' then
         timestamp_i <= timestamp_fresh_i + 1;
         lvl1_id_i <= TRG_CODE_IN & TRG_NUMBER_IN; -- no sync necessary, as signal should be stable until now
      end if;
      
      lvl1_trg_delay := lvl1_trg_i;
      timing_trg_delay := timing_trg_i;
   end process;
   
   
   PROC_TIMESTAMP_EVENT: process is
      variable trg_sync200_delay : std_logic;
      variable lvl1_trg_delay : std_logic;
   begin
      wait until rising_edge(CLK_200);

      if trg_sync200='1' and trg_sync200_delay='0' then
         rec_timestamp_i <= timestamp_i;
         rec_lvl1_id_i <= lvl1_id_i;
      end if;

      if lvl1_trg_i='1' and lvl1_trg_delay='0' then
         rdo_buf_rec_timestamp_i <= rec_timestamp_i;
         rdo_buf_rec_lvl1_id_i <= rec_lvl1_id_i;
      end if;
      
      lvl1_trg_delay := lvl1_trg_i;
      trg_sync200_delay := trg_sync200;
   end process;
   
   -- SYNC EXTERNAL SIGNALS FOR TIMESTAMPING
   THE_TMG_TRG_SYNC: signal_sync
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK,
      CLK1 => CLK_200,
      D_IN(0) =>  TIMING_TRG_IN,
      D_OUT(0) => timing_trg_i
   );
   
   THE_LVL1_SYNC: signal_sync
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK,
      CLK1 => CLK_200,
      D_IN(0) =>  TRIGGER_IN,
      D_OUT(0) => lvl1_trg_i
   );
   
   THE_REC_SYNC: signal_sync
   generic map (WIDTH => 1, DEPTH => 3)
   port map (
      RESET => RESET_IN,
      CLK0 => CLK_200,
      CLK1 => CLK_200,
      D_IN(0) =>  trg_async,
      D_OUT(0) => trg_sync200
   );
   
-- REGIO
   GEN_REGIO: if INCL_REGIO = c_YES generate
      proc_regio: process is
         variable addr : integer range 0 to 3;
      begin
         wait until rising_edge(CLK);
         
         addr := to_integer(UNSIGNED(REGIO_IN.addr(1 downto 0)));
         REGIO_OUT.rack <= REGIO_IN.read;
         REGIO_OUT.wack <= REGIO_IN.write;
         REGIO_OUT.nack <= '0';
         REGIO_OUT.unknown <= '0';
         REGIO_OUT.data <= (others => '0');
         
         case addr is
            when 0 => 
               REGIO_OUT.data(1 downto 0) <= config_invert_input_i & (not config_rdo_disable_i);
               if INCL_RDO_TIMESTAMP=c_YES then
                  REGIO_OUT.data(2) <= '1';
               end if;
               REGIO_OUT.data(7) <= error_reg;
               REGIO_OUT.data(31 downto 8) <= number_reg;

            when 1 => 
               REGIO_OUT.data <= std_logic_vector(rec_counter_i);
               
            when 2 =>
               REGIO_OUT.data <= std_logic_vector(act_counter_i);
            
            when 3 =>
               REGIO_OUT.data <= std_logic_vector(high_counter_i);
            
         end case;
         
         if REGIO_IN.write='1' then
            if addr=0 then
               config_rdo_disable_i <= not REGIO_IN.data(0);
               config_invert_input_i <= REGIO_IN.data(1);
            else
               REGIO_OUT.unknown <= '1';
            end if;
         end if;
         
         if RESET_IN = '1' then
            config_rdo_disable_i <= '0';
            config_invert_input_i <= '0';
         end if;
      end process;
      
      proc_stats: process is
         variable this_mbs : std_logic;
         variable last_mbs : std_logic;
         variable last_trg_sync : std_logic;
      begin
         wait until rising_edge(CLK);
         
         this_mbs := reg_MBS_IN or reg_MBS_DELAY;
         
         if this_mbs = '1' then
            high_counter_i <= high_counter_i + 1;
         end if;
         
         if trg_sync = '1' and last_trg_sync='0' then
            rec_counter_i <= rec_counter_i + 1;
         end if;
         
         if this_mbs /= last_mbs then
            act_counter_i <= act_counter_i + 1;
         end if;
         
         if RESET_IN='1' then
            high_counter_i <= (others => '0');
            rec_counter_i  <= (others => '0');
            act_counter_i  <= (others => '0');
         end if;
         
         last_trg_sync := trg_sync;
         last_mbs := this_mbs;
      end process;
   end generate;

   GEN_NO_REGIO: if INCL_REGIO /= c_YES generate
      config_rdo_disable_i <= CONTROL_REG_IN(0);
      REGIO_OUT.unknown <= REGIO_IN.read or REGIO_IN.write;
   end generate;
end architecture;
