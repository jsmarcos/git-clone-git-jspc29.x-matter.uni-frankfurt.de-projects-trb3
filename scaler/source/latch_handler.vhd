library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity latch_handler is
  port (
    CLK_IN                     : in  std_logic;
    RESET_IN                   : in  std_logic;
    CLK_D1_IN                  : in  std_logic;
    RESET_D1_IN                : in  std_logic;  -- Rest CLK_D1 Domain
        
    --Inputs 
    RESET_CTR_IN               : in std_logic;
    LATCH_TRIGGER_IN           : in std_logic; -- The raw Timing Trigger Signal
    LATCH_EXTERN_IN            : in std_logic; -- The raw Latch Signal
    
    -- Outputs
    RESET_CTR_OUT              : out std_logic;
    LATCH_OUT                  : out std_logic;
    LATCH_VALID_OUT            : out std_logic;
    LATCH_INVALID_OUT          : out std_logic;
    
    -- Slave bus               
    SLV_READ_IN                : in  std_logic;
    SLV_WRITE_IN               : in  std_logic;
    SLV_DATA_OUT               : out std_logic_vector(31 downto 0);
    SLV_DATA_IN                : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN                : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT                : out std_logic;
    SLV_NO_MORE_DATA_OUT       : out std_logic;
    SLV_UNKNOWN_ADDR_OUT       : out std_logic;
    
    -- Debug Line              
    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of latch_handler is
  
  -- Reset Counters
  signal reset_d1_ff                 : std_logic_vector(1 downto 0);
  signal RESET_D1                    : std_logic;

  signal reset_ctr_ff                : std_logic_vector(2 downto 0);
  signal reset_ctr_o                 : std_logic;

  -- Latch Handler
  signal latch_select_ff             :  std_logic_vector(1 downto 0);
  signal latch_ff                    : std_logic_vector(2 downto 0);
  
  signal latch_i                     : std_logic;
  signal latch                       : std_logic;
  signal latch_o                     : std_logic;
  signal latch_valid_o               : std_logic;
  signal latch_invalid_o             : std_logic;
  
--  -- Latch Handler
--  type LH_STATES is (LH_IDLE,
--                     LH_VALIDATE,
--                     LH_WAIT
--                     );
--  signal LH_STATE : LH_STATES;
--
--  signal lh_wait_timer_reset         : std_logic;
--  signal lh_wait_timer_start         : std_logic;
--  signal lh_wait_timer_done          : std_logic;
--  
--  signal latch_validate_ctr          : unsigned(4 downto 0);
--  
--  signal latch_o                     : std_logic;
--  signal latch_valid_o               : std_logic;
--  signal latch_invalid_o             : std_logic;
--     
--  -- Rate Calculation
--  signal accepted_trigger_rate_t     : unsigned(27 downto 0);
--  signal rate_timer                  : unsigned(27 downto 0);
  
  -- TRBNet Slave Bus                
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;

  signal latch_select_r              : std_logic;

  -----------------------------------------------------------------------------
  
  attribute syn_keep : boolean;
  attribute syn_keep of latch_select_ff : signal is true;
  attribute syn_keep of latch_ff        : signal is true;
  attribute syn_keep of reset_ctr_ff    : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of latch_select_ff : signal is true;
  attribute syn_preserve of latch_ff        : signal is true;
  attribute syn_preserve of reset_ctr_ff    : signal is true;

  -----------------------------------------------------------------------------

begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= LATCH_TRIGGER_IN;

  DEBUG_OUT(2)            <= latch_i;
  DEBUG_OUT(3)            <= latch_ff(2);
  DEBUG_OUT(4)            <= latch_ff(1);
  DEBUG_OUT(5)            <= latch_ff(0);
  DEBUG_OUT(6)            <= latch_o;

  DEBUG_OUT(7)            <= RESET_CTR_IN;
  DEBUG_OUT(8)            <= reset_ctr_ff(2);
  DEBUG_OUT(9)            <= reset_ctr_ff(1);
  DEBUG_OUT(10)           <= reset_ctr_ff(0);
  DEBUG_OUT(11)           <= reset_ctr_o;
  

  DEBUG_OUT(15 downto 12)  <= (others => '0');

  -----------------------------------------------------------------------------
  -- Reset Counter Sync
  -----------------------------------------------------------------------------
  reset_d1_ff(1)  <= RESET_D1_IN     when rising_edge(CLK_D1_IN);
  reset_d1_ff(0)  <= reset_d1_ff(1)  when rising_edge(CLK_D1_IN);
  RESET_D1        <= reset_d1_ff(0)  when rising_edge(CLK_D1_IN);
  
  reset_ctr_ff(2) <= RESET_CTR_IN    when rising_edge(CLK_D1_IN);
  reset_ctr_ff(1) <= reset_ctr_ff(2) when rising_edge(CLK_D1_IN);
  reset_ctr_ff(0) <= reset_ctr_ff(1) when rising_edge(CLK_D1_IN);
  reset_ctr_o     <= reset_ctr_ff(0) when rising_edge(CLK_D1_IN);
  
  -----------------------------------------------------------------------------
  -- Latch Handler
  -----------------------------------------------------------------------------

  latch_select_ff(1) <= latch_select_r     when rising_edge(CLK_D1_IN);
  latch_select_ff(0) <= latch_select_ff(1) when rising_edge(CLK_D1_IN);

  PROC_LATCH_MULTIPLEXER: process(latch_select_ff(0),
                                  LATCH_TRIGGER_IN,
                                  LATCH_EXTERN_IN)
  begin
    if (latch_select_ff(0) = '0') then
      latch_i    <= LATCH_TRIGGER_IN;
    else
      latch_i    <= LATCH_EXTERN_IN;
    end if;     
  end process PROC_LATCH_MULTIPLEXER;
  
  latch_ff(2) <= latch_i     when rising_edge(CLK_D1_IN);
  latch_ff(1) <= latch_ff(2) when rising_edge(CLK_D1_IN);
  latch_ff(0) <= latch_ff(1) when rising_edge(CLK_D1_IN);

  latch       <= '1' when latch_ff(1 downto 0) = "10" else '0'; 

  latch_o          <= latch;
  latch_valid_o    <= latch;
  latch_invalid_o  <= '0';
  
--   -- Timer
--   lh_timer_static: timer_static
--     generic map (
--       CTR_WIDTH => 8,
--       CTR_END   => 32   -- 128ns
--       )
--     port map (
--       CLK_IN         => CLK_D1_IN,
--       RESET_IN       => lh_wait_timer_reset,
--       TIMER_START_IN => lh_wait_timer_start,
--       TIMER_DONE_OUT => lh_wait_timer_done
--       );
--   
--   PROC_LATCH_HANDLER: process(CLK_D1_IN)
--   begin
--     if( rising_edge(CLK_D1_IN) ) then
--       if (RESET_D1 = '1') then
--         latch_validate_ctr  <= (others => '0');
--         latch_o             <= '0';
--         latch_valid_o       <= '0';
--         latch_invalid_o     <= '0';
-- 
--         lh_wait_timer_start <= '0';
--         lh_wait_timer_reset <= '1';
--         
--         LH_STATE            <= LH_IDLE;
--       else
--         lh_wait_timer_start <= '0';
--         lh_wait_timer_reset <= '0';
-- 
--         latch_o             <= '0';
--         latch_valid_o       <= '0';
--         latch_invalid_o     <= '0';
-- 
--         case LH_STATE is
--           when  LH_IDLE =>
--             if (latch = '1') then
--               latch_validate_ctr  <= (others => '0');
--               latch_o             <= '1';
--               LH_STATE            <= LH_VALIDATE;
--             end if;
--             LH_STATE              <= LH_IDLE;
--             
--           when LH_VALIDATE =>
--             if (latch_validate_ctr < x"a") then
--               if (latch = '1') then
--                 latch_validate_ctr  <= latch_validate_ctr + 1;
--                 LH_STATE            <= LH_VALIDATE;
--               else
--                 latch_invalid_o     <= '1';
--                 lh_wait_timer_start <= '1';
--                 LH_STATE            <= LH_WAIT;
--               end if;
--             else
--               latch_valid_o         <= '1';
--               lh_wait_timer_start   <= '1';
--               LH_STATE              <= LH_WAIT;
--             end if;
-- 
--           when LH_WAIT =>
--             if (lh_wait_timer_done = '1') then
--               LH_STATE              <= LH_IDLE;
--             else
--               LH_STATE              <= LH_WAIT;
--             end if;
--         end case;
-- 
--       end if;
--     end if;
--   end process PROC_LATCH_HANDLER;

 ---------------------------------------------------------------------------
 -- TRBNet Slave Bus
 ---------------------------------------------------------------------------
 
 PROC_SLAVE_BUS: process(CLK_IN)
 begin
   if( rising_edge(CLK_IN) ) then
     if( RESET_IN = '1' ) then
       slv_data_out_o                 <= (others => '0');
       slv_no_more_data_o             <= '0';
       slv_unknown_addr_o             <= '0';
       slv_ack_o                      <= '0';
       latch_select_r                 <= '0';
     else                             
       slv_unknown_addr_o             <= '0';
       slv_no_more_data_o             <= '0';
       slv_data_out_o                 <= (others => '0');
       slv_ack_o                      <= '0';
 
       if (SLV_WRITE_IN  = '1') then
         case SLV_ADDR_IN is
           when x"0000" =>
             latch_select_r               <= SLV_DATA_IN(0); 
             slv_ack_o                    <= '1';
            
           when others =>
             slv_unknown_addr_o           <= '1';
 
         end case;
 
       elsif (SLV_READ_IN = '1') then
         case SLV_ADDR_IN is
           when x"0000" =>
             slv_data_out_o(0)            <= latch_select_r;
             slv_data_out_o(31 downto 1)  <= (others => '0');
             
             slv_ack_o                    <= '1';

           when others =>
             slv_unknown_addr_o           <= '1';
 
         end case;
 
       end if;
     end if;
   end if;           
 end process PROC_SLAVE_BUS;

-----------------------------------------------------------------------------
-- Output Signals
-----------------------------------------------------------------------------

  RESET_CTR_OUT             <= reset_ctr_o;
  LATCH_OUT                 <= latch_o;
  LATCH_VALID_OUT           <= latch_valid_o;
  LATCH_INVALID_OUT         <= latch_invalid_o;

  -- Slave Bus              
  SLV_DATA_OUT              <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT      <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT      <= slv_unknown_addr_o;
  SLV_ACK_OUT               <= slv_ack_o;    

end Behavioral;
