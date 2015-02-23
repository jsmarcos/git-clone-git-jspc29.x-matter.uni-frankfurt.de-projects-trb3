library ieee;
   use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;

library work;
   use work.trb_net_std.all;
   use work.trb_net_components.all;
   use work.trb3_components.all;

entity billboard is
   generic (
      BLOCK_ADDR_WIDTH : integer range 8 to 11 := 8 -- less than 8 no sensible because of EBR granuality
   );
   port (
      CLK_IN : in std_logic;
      RESET_IN : in std_logic;
      
      REGIO_IN : in CTRLBUS_RX;
      REGIO_OUT : out CTRLBUS_TX;
      
      RDO_IN : in READOUT_RX;
      RDO_OUT: out READOUT_TX
   );
end billboard;

architecture billboard_arch of billboard is
-- configuration
   constant MEM_BASE_ADDR_C : std_logic_vector(15 downto 0) := (BLOCK_ADDR_WIDTH=>'1', others =>'0');

-- regio
   signal regio_addr_rewrite_i, regio_ctrl_rx_i, regio_mem_rx_i : CTRLBUS_RX;
   signal regio_ctrl_tx_i, regio_mem_tx_i : CTRLBUS_TX;
   signal regio_mem_rack_delay_i : std_logic;

-- control
   type TRIGGER_SKIP_T is array(0 to 15) of unsigned(31 downto 0);
   signal ctrl_trigger_skip_i : TRIGGER_SKIP_T;
   signal ctrl_time_threshold_i : unsigned(31 downto 0);
   signal ctrl_enabled_i : std_logic;
   
   signal trigger_skip_cnt_i : TRIGGER_SKIP_T;
   signal time_counter_i : unsigned(31 downto 0);

   
-- stats
   signal stat_frames_sent_i  : unsigned(31 downto 0);
   signal stat_words_sent_i   : unsigned(31 downto 0);
   signal stat_commits_i      : unsigned(31 downto 0);
   signal stat_last_commit_age_i  : unsigned(31 downto 0);
   
-- block handling
   signal next_rdo_block_i : std_logic;
   signal next_rdo_length_i : unsigned(BLOCK_ADDR_WIDTH-1 downto 0);

   signal current_rdo_active : std_logic;
   signal current_rdo_block_i : std_logic;
   signal current_rdo_length_i : unsigned(BLOCK_ADDR_WIDTH-1 downto 0);
   
   signal current_regio_block_i : std_logic;
   
-- memory
   type MEM_T is array(0 to 2**BLOCK_ADDR_WIDTH) of std_logic_vector(31 downto 0);
   signal mem_i : MEM_T;   -- will be dual port, single clock, output-registered EBR

-- rdo
   signal rdo_pointer_i : unsigned(BLOCK_ADDR_WIDTH downto 0);
   type RDO_FSM_T is (IDLE, HEADER, TRANSMIT, FINISH, WAIT_UNTIL_IDLE);
   signal rdo_fsm_i : RDO_FSM_T;
   signal rdo_accept_trigger_i : std_logic;
   signal rdo_mem_data_i : std_logic_vector(31 downto 0);
  
begin
   -- handles control and status registers
   PROC_CTRL_REGIO: process is
      variable addr : integer;
      variable trg_addr : integer;
      
   begin
      wait until rising_edge(CLK_IN);
      addr     := to_integer(unsigned(regio_ctrl_rx_i.addr(4 downto 0)));
      trg_addr := to_integer(unsigned(regio_ctrl_rx_i.addr(3 downto 0)));

      regio_ctrl_tx_i.wack <= regio_ctrl_rx_i.write;
      regio_ctrl_tx_i.rack <= regio_ctrl_rx_i.read;
      regio_ctrl_tx_i.unknown <= '0';
      regio_ctrl_tx_i.data <= (others => '0');
      regio_ctrl_tx_i.nack <= '0';

      
      stat_last_commit_age_i <= stat_last_commit_age_i + 1;
      
      if RESET_IN='1' then
         -- as disabled as it gets ;)
         next_rdo_length_i <= (others => '0');
         next_rdo_block_i <= '1';

         ctrl_trigger_skip_i <= (others => (others => '1'));
         ctrl_time_threshold_i <= (others => '0');
         
         stat_commits_i <= (others => '0');
         stat_last_commit_age_i <= (others => '0');
         
      else
         case addr is
            when 0 => regio_ctrl_tx_i.data(BLOCK_ADDR_WIDTH-1 downto 0) <= next_rdo_length_i;
            when 1 => regio_ctrl_tx_i.data <= ctrl_time_threshold_i;
            when 2 => regio_ctrl_tx_i.data <= stat_frames_sent_i;
            when 3 => regio_ctrl_tx_i.data <= stat_words_sent_i;
            when 4 => regio_ctrl_tx_i.data <= stat_commits_i;
            when 5 => regio_ctrl_tx_i.data <= stat_last_commit_age_i;
            
            when 16#10# to 16#1f# =>
               regio_ctrl_tx_i.data <= ctrl_trigger_skip_i(trg_addr);
         
            when others =>
               regio_ctrl_tx_i.unknown <= regio_ctrl_rx_i.write or regio_ctrl_rx_i.read;
         end case;
         
         if regio_ctrl_rx_i.write='1' then
            case addr is
               when 0 => -- commit
                  next_rdo_block_i <= current_regio_block_i;
                  next_rdo_length_i <= regio_ctrl_rx_i.data(BLOCK_ADDR_WIDTH-1 downto 0);
                  stat_last_commit_age_i <= (others => '0');
                  stat_commits_i <= stat_commits_i + 1;
               
               when 1 => 
                  ctrl_time_threshold_i <= regio_ctrl_rx_i.data;
               
               when 16#10# to 16#1f# =>
                  ctrl_trigger_skip_i(trg_addr) <= regio_ctrl_rx_i.data;
                  
               when others =>
                  regio_ctrl_tx_i.wack <= '0';
                  regio_ctrl_tx_i.nack <= '1';
            end case;
         
         end if;
      end if;
   end process;
   current_regio_block_i <= not next_rdo_block_i;

   PROC_MEM: process is
      variable rdo_addr_u : unsigned(BLOCK_ADDR_WIDTH downto 0);
      variable regio_addr, rdo_addr : integer range 0 to 2**BLOCK_ADDR_WIDTH;
      variable regio_read_ack_delay_v : std_logic;
   begin
      wait until rising_edge(CLK_IN);
   
      rdo_addr_u := rdo_pointer_i;
      rdo_addr_u(BLOCK_ADDR_WIDTH) := current_rdo_block_i;
      rdo_addr := to_integer(rdo_addr_u);
      regio_addr := to_integer(unsigned(current_regio_block_i & regio_mem_rx_i.addr(BLOCK_ADDR_WIDTH-1 downto 0)));
   
      -- dual read port
      rdo_mem_data_i <= mem_i(rdo_addr);
      regio_mem_tx_i.data <= mem_i(regio_addr);
      regio_mem_rack_delay_i <= regio_mem_rx_i.read;
      
      regio_mem_tx_i.wack <= '0';
      -- single write port
      if regio_mem_rx_i.write='1' then
         -- is write protected, because rdo is currently reading from block and cell was not transmitted yet?
         if not(current_rdo_active='1' and current_rdo_block_i=current_regio_block_i and regio_addr <= rdo_addr) then
            mem_i(regio_addr) <= regio_mem_rx_i.data;
            regio_mem_tx_i.wack <= '1';
         end if;
      end if;
   end process;
   regio_mem_tx_i.unknown <= '0';
   regio_mem_tx_i.nack <= '0';
   regio_mem_tx_i.rack <= regio_mem_rack_delay_i when rising_edge(CLK_IN);

   PROC_RDO_DECISION: process is
      variable accept_trigger : std_logic;
      variable trg_type : integer range 0 to 15;
      variable new_trigger : std_logic;
      variable rdo_delay : std_logic;
   begin
      wait until rising_edge(CLK_IN);
      
      accept_trigger := '0';
      trg_type := to_integer(unsigned(RDO_IN.trg_type));
      time_counter_i <= time_counter_i + 1;
      new_trigger := RDO_IN.data_valid and not rdo_delay;
      
      if RESET_IN='1' then
         trigger_skip_cnt_i <= (others => (others => '0'));
         time_counter_i <= (others => '0');
      else
         if trigger_skip_cnt_i(trg_type) >= ctrl_trigger_skip_i(trg_type) and trigger_skip_cnt_i(trg_type) /= x"ffffffff" then
            accept_trigger := '1';
         elsif new_trigger='1' then
            trigger_skip_cnt_i(trg_type) <= trigger_skip_cnt_i(trg_type) + 1;
         end if;
         
         if time_counter_i >= ctrl_time_threshold_i and ctrl_time_threshold_i /= 0 then
            accept_trigger := '1';
         end if;
      
         if accept_trigger = '1' and new_trigger = '1' then
            trigger_skip_cnt_i(trg_type) <= (others => '0');
            time_counter_i <= (others => '0');
         end if;
      end if;
      
      rdo_accept_trigger_i <= accept_trigger;
      rdo_delay := RDO_IN.data_valid;
   end process;
   
   
   PROC_RDO: process is
   begin
      wait until rising_edge(CLK_IN);
      
   -- RDO state machine
      current_rdo_active <= '1';
      rdo_pointer_i <= (others => '0'); -- only incremented in TRANSMIT
      
      RDO_OUT.data <= rdo_mem_data_i;
      RDO_OUT.data_finished <= '0';
      RDO_OUT.busy_release <= '0';
      RDO_OUT.data_write <= '0';
      
      if RESET_IN = '1' then
         rdo_fsm_i <= IDLE;
         current_rdo_active <= '0';
         
      else
         case rdo_fsm_i is
            when IDLE =>
               current_rdo_active <= '0';
               current_rdo_block_i <= next_rdo_block_i;
               current_rdo_length_i <= next_rdo_length_i;

               if RDO_IN.data_valid = '1' then
                  rdo_fsm_i <= HEADER;
               end if;
               
            when HEADER =>
               RDO_OUT.data <= (others => '0');
               RDO_OUT.data(current_rdo_length_i'HIGH-1 downto 0) <= current_rdo_length_i(current_rdo_length_i'HIGH-1 downto 0);
               RDO_OUT.data(15 downto 12) <= stat_commits_i(3 downto 0);
               RDO_OUT.data(30 downto 16) <= stat_last_commit_age_i(31 downto 17);
               RDO_OUT.data(31) <= rdo_accept_trigger_i;
               RDO_OUT.data_write <= '1';
              
               if rdo_accept_trigger_i = '1' and current_rdo_length_i /= 0 then
                  current_rdo_active <= '1';
                  stat_frames_sent_i <= stat_frames_sent_i + 1;
                  rdo_fsm_i <= TRANSMIT;
               else
                  rdo_fsm_i <= FINISH;
               end if;

               stat_words_sent_i <= stat_words_sent_i + 1;
                  
            when TRANSMIT =>
               if rdo_pointer_i+1 = current_rdo_length_i then
                  rdo_fsm_i <= FINISH;
               end if;
               
               stat_words_sent_i <= stat_words_sent_i + 1;
               RDO_OUT.data_write <= '1';
               rdo_pointer_i <= rdo_pointer_i + 1;
               
            when FINISH =>
               RDO_OUT.data_finished <= '1';
               RDO_OUT.busy_release <= '1';
               rdo_fsm_i <= WAIT_UNTIL_IDLE;
               
            when WAIT_UNTIL_IDLE =>
               if RDO_IN.data_valid = '0' then
                  rdo_fsm_i <= IDLE;
               end if; 
               
         end case;
      
      end if;
   end process;
   
   THE_BUS_HANDLER : entity work.trb_net16_regio_bus_handler_record
   generic map(
      PORT_NUMBER      => 2,
      PORT_ADDRESSES   => (0 => x"0000", 1 => MEM_BASE_ADDR_C,    others => x"0000"),
      PORT_ADDR_MASK   => (0 => 5,       1 => BLOCK_ADDR_WIDTH, others => 0),
      PORT_MASK_ENABLE => 1
   )
   port map(
      CLK   => CLK_IN,
      RESET => RESET_IN,

      REGIO_RX  => regio_addr_rewrite_i,
      REGIO_TX  => REGIO_OUT,

      BUS_RX(0) => regio_ctrl_rx_i,
      BUS_RX(1) => regio_mem_rx_i,
      BUS_TX(0) => regio_ctrl_tx_i,
      BUS_TX(1) => regio_mem_tx_i,

      STAT_DEBUG => open
   );   
   
   PROC_ADDR_REWRITE: process(REGIO_IN) is
   begin
      regio_addr_rewrite_i <= REGIO_IN;
      regio_addr_rewrite_i.addr(15 downto BLOCK_ADDR_WIDTH+1) <= (others => '0');
   end process;
end architecture;
      