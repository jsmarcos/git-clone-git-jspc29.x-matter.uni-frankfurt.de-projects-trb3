library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb3_components.all;


entity cbmnet_dlm_etm is
  port(
    CLK        : in std_logic;  -- e.g. 100 MHz
    RESET_IN   : in std_logic;  -- could be used after busy_release to make sure entity is in correct state

    TRG_SYNC_OUT   : out std_logic;  -- sync. to CLK
    
    -- CBMNET DLM Port
    CBMNET_CLK_IN     : in std_logic;
    CBMNET_DLM_REC_IN : in std_logic_vector(3 downto 0);
    CBMNET_DLM_REC_VALID_IN : in std_logic;
    
    --data output for read-out
    TRIGGER_IN   : in  std_logic;
    DATA_OUT     : out std_logic_vector(31 downto 0);
    WRITE_OUT    : out std_logic;
    STATUSBIT_OUT: out std_logic_vector(31 downto 0);
    FINISHED_OUT : out std_logic;
    
    --Registers / Debug    
    CONTROL_REG_IN : in  std_logic_vector(31 downto 0);
    STATUS_REG_OUT : out std_logic_vector(31 downto 0) := (others => '0');
    HEADER_REG_OUT : out std_logic_vector(1 downto 0);
    DEBUG_OUT      : out std_logic_vector(31 downto 0)    
    );
end entity;


architecture cbmnet_dlm_etm_arch of cbmnet_dlm_etm is
   signal cbm_fine_grain_counter_i      : unsigned(31 downto 0);
   signal cbm_dlm_counter_i             : unsigned(31 downto 0);
   signal cbm_filtered_dlm_counter_i    : unsigned(31 downto 0);
   signal cbm_ignore_resets_threshold_i : unsigned(31 downto 0);
   signal cbm_listing_dlm_num_i         : std_logic_vector(3 downto 0);
   
   signal trb_fine_grain_counter_i      : unsigned(31 downto 0);
   signal trb_dlm_counter_i             : unsigned(31 downto 0);
   signal trb_filtered_dlm_counter_i    : unsigned(31 downto 0);
   signal trb_ignore_resets_threshold_i : unsigned(31 downto 0);
   
   type rdo_states_t is (RDO_IDLE, RDO_WRITE, RDO_FINISH);
   signal rdo_fsm_i : rdo_states_t;
   
   type rdo_buffer_t is array(0 to 3) of std_logic_vector(31 downto 0);
   signal rdo_buffer_i : rdo_buffer_t;
   signal rdo_index_i : integer range 0 to 3;
   
   signal rdo_disable_i : std_logic;
   
begin
FINISHED_OUT <= '1';
-- 
-- -- TrbNet sync
--    trb_fine_grain_counter_i <= cbm_fine_grain_counter_i when rising_edge(CLK);
--    trb_filtered_dlm_counter_i <= cbm_filtered_dlm_counter_i when rising_edge(CLK);
--    trb_dlm_counter_i <= cbm_dlm_counter_i when rising_edge(CLK);
--    
--    trb_ignore_resets_threshold_i <= UNSIGNED(x"00" & CONTROL_REG_IN(23 downto 0)) when rising_edge(CLK);
--    STATUS_REG_OUT <= x"00" & STD_LOGIC_VECTOR(trb_fine_grain_counter_i(31 downto 24)) & STD_LOGIC_VECTOR(trb_filtered_dlm_counter_i(15 downto 0)) when rising_edge(CLK);
-- 
--    TRG_SYNC_OUT <= '1' when trb_fine_grain_counter_i < 4 else '0';
--    
-- -- TrbNet readout
--    rdo_disable_i <= CONTROL_REG_IN(0);
--    HEADER_REG_OUT <= "10"; -- send four data words (3 not supported w/o header)
-- --   DATA_OUT <= rdo_buffer_i(rdo_index_i);
--    
--    PROC_RDO: process is
--    begin
--       wait until rising_edge(CLK);
--       
--       FINISHED_OUT <= '0';
--       WRITE_OUT <= '0';
--       STATUSBIT_OUT <= (others => '0');
--       
--       if RESET_IN = '1' or rdo_disable_i = '1' then
--          rdo_fsm_i <= RDO_IDLE;
--          FINISHED_OUT <= '1';
--          
--       else
--          case(rdo_fsm_i) is
--             when RDO_IDLE =>
--                rdo_buffer_i(0) <= trb_fine_grain_counter_i;
--                rdo_buffer_i(1) <= trb_dlm_counter_i;
--                rdo_buffer_i(2) <= trb_filtered_dlm_counter_i;
--                rdo_buffer_i(3) <= x"deadbeaf";
--                rdo_index_i <= 0;
--             
--                if TRIGGER_IN = '1' then
--                   rdo_fsm_i <= RDO_WRITE;
--                   WRITE_OUT <= '1';
--                end if;
--             
--             when RDO_WRITE =>
--                rdo_index_i <= rdo_index_i + 1;
--                if rdo_index_i = 3 then
--                   rdo_fsm_i <= RDO_FINISH;
--                end if;
--                WRITE_OUT <= '1';
--                
--             when RDO_FINISH =>
--                FINISHED_OUT <= '1';
--                rdo_fsm_i <= RDO_IDLE;
--                
--          end case;
--       end if;
--    end process;
--    
-- -- CBMNet synchronous
--    cbm_ignore_resets_threshold_i <= trb_ignore_resets_threshold_i;
--    PROC_RECV: process is
--    begin
--       wait until rising_edge(CBMNET_CLK_IN);
--       
--       if CBMNET_DLM_REC_IN = cbm_listing_dlm_num_i and CBMNET_DLM_REC_VALID_IN = '1' then
--          if cbm_fine_grain_counter_i >= cbm_ignore_resets_threshold_i then
--             cbm_fine_grain_counter_i <= (others => '0');
--             cbm_filtered_dlm_counter_i <= cbm_filtered_dlm_counter_i + 1;
--          end if;
--          
--          cbm_dlm_counter_i <= cbm_dlm_counter_i + 1;
--       end if;
--    end process;
--    
--    cbm_listing_dlm_num_i <= CONTROL_REG_IN(7 downto 4) when rising_edge(CBMNET_CLK_IN);
end architecture;
