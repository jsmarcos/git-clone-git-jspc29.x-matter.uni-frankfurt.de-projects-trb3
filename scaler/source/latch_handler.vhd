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
    
    -- Outputs
    RESET_CTR_OUT              : out std_logic;
    LATCH_OUT                  : out std_logic;
    
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
  signal latch_ff                    : std_logic_vector(2 downto 0);
  signal latch_o                     : std_logic;

  -- TRBNet Slave Bus                
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;

  signal latch_select_r              : std_logic;

  -----------------------------------------------------------------------------
  
  attribute syn_keep : boolean;
  attribute syn_keep of latch_ff        : signal is true;
  attribute syn_keep of reset_ctr_ff    : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of latch_ff        : signal is true;
  attribute syn_preserve of reset_ctr_ff    : signal is true;

  -----------------------------------------------------------------------------

begin

  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= LATCH_TRIGGER_IN;

  DEBUG_OUT(2)            <= '0';
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

  latch_ff(2) <= LATCH_TRIGGER_IN when rising_edge(CLK_D1_IN);
  latch_ff(1) <= latch_ff(2)      when rising_edge(CLK_D1_IN);
  latch_ff(0) <= latch_ff(1)      when rising_edge(CLK_D1_IN);

  latch_o     <= '1' when latch_ff(1 downto 0) = "10" else '0'; 

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
     else                             
       slv_unknown_addr_o             <= '0';
       slv_no_more_data_o             <= '0';
       slv_data_out_o                 <= (others => '0');
       slv_ack_o                      <= '0';
 
       if (SLV_WRITE_IN  = '1') then
         case SLV_ADDR_IN is

           when others =>
             slv_unknown_addr_o           <= '1';
 
         end case;
 
       elsif (SLV_READ_IN = '1') then
         case SLV_ADDR_IN is

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

  -- Slave Bus              
  SLV_DATA_OUT              <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT      <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT      <= slv_unknown_addr_o;
  SLV_ACK_OUT               <= slv_ack_o;    

end Behavioral;
