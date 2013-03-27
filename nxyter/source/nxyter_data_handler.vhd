----------------------------------------------------------------------------
--
-- two  nXyter FEB Data handler 
--
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.nxyter_components.all;

entity nXyter_data_handler is
  
  port (
    CLK_IN                     : in std_logic;  
    RESET_IN                   : in std_logic;  
    
    -- TRBNet RegIO Port for the slave bus
    REGIO_ADDR_IN              : in    std_logic_vector(15 downto 0);
    REGIO_DATA_IN              : in    std_logic_vector(31 downto 0);
    REGIO_DATA_OUT             : out   std_logic_vector(31 downto 0);
    REGIO_READ_ENABLE_IN       : in    std_logic;                    
    REGIO_WRITE_ENABLE_IN      : in    std_logic;
    REGIO_TIMEOUT_IN           : in    std_logic;
    REGIO_DATAREADY_OUT        : out   std_logic;
    REGIO_WRITE_ACK_OUT        : out   std_logic;
    REGIO_NO_MORE_DATA_OUT     : out   std_logic;
    REGIO_UNKNOWN_ADDR_OUT     : out   std_logic;

    -- TrbNet Timing trigger
    LVL1_TRG_DATA_VALID_IN     : in std_logic;
    LVL1_VALID_TIMING_TRG_IN   : in std_logic;
    LVL1_VALID_NOTIMING_TRG_IN : in std_logic;
    LVL1_INVALID_TRG_IN        : in std_logic;

    LVL1_TRG_TYPE_IN           : in std_logic_vector(3 downto 0);
    LVL1_TRG_NUMBER_IN         : in std_logic_vector(15 downto 0);
    LVL1_TRG_CODE_IN           : in std_logic_vector(7 downto 0);
    LVL1_TRG_INFORMATION_IN    : in std_logic_vector(23 downto 0);
    LVL1_INT_TRG_NUMBER_IN     : in std_logic_vector(15 downto 0);

    -- Response from FEE
    FEE_TRG_RELEASE_OUT        : out std_logic;
    FEE_TRG_STATUSBITS_OUT     : out std_logic_vector(31 downto 0);
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_FINISHED_OUT      : out std_logic;
    FEE_DATA_ALMOST_FULL_IN    : in std_logic;
      
    -- Debug Signals
    DEBUG_LINE_OUT             : out   std_logic_vector(15 downto 0)
    );
  
end nXyter_data_handler;


architecture Behavioral of nXyter_data_handler is

-------------------------------------------------------------------------------
-- Signals
-------------------------------------------------------------------------------
  
  -- LV2 Data Out Handler
   signal fee_trg_release_o        : std_logic;
   signal fee_trg_release_o_x      : std_logic;
   signal fee_trg_statusbits_o     : std_logic_vector(31 downto 0);
   signal fee_trg_statusbits_o_x   : std_logic_vector(31 downto 0);
   signal fee_data_o               : std_logic_vector(31 downto 0);
   signal fee_data_o_x             : std_logic_vector(31 downto 0);
   signal fee_data_write_o         : std_logic;
   signal fee_data_write_o_x       : std_logic;
   signal fee_data_finished_o      : std_logic;
   signal fee_data_finished_o_x    : std_logic;
   

   type STATES is (S_IDLE,
                   S_SEND_DATA,
                   S_END
                  );
   signal STATE, NEXT_STATE   : STATES; 

begin

-------------------------------------------------------------------------------
-- DEBUG
-------------------------------------------------------------------------------
  DEBUG_LINE_OUT(0)            <= CLK_IN;
  DEBUG_LINE_OUT(1)            <= LVL1_TRG_DATA_VALID_IN; 
  DEBUG_LINE_OUT(2)            <= LVL1_VALID_TIMING_TRG_IN;
  DEBUG_LINE_OUT(3)            <= LVL1_VALID_NOTIMING_TRG_IN;
  DEBUG_LINE_OUT(4)            <= LVL1_INVALID_TRG_IN;
  DEBUG_LINE_OUT(5)            <= FEE_TRG_RELEASE_OUT;
  DEBUG_LINE_OUT(6)            <= FEE_DATA_WRITE_OUT;
  DEBUG_LINE_OUT(7)            <= FEE_DATA_FINISHED_OUT;
  DEBUG_LINE_OUT(8)            <= FEE_DATA_ALMOST_FULL_IN;
  DEBUG_LINE_OUT(15 downto 9)  <= LVL1_TRG_NUMBER_IN(6 downto 0);

 PROC_DATA_HANDLER_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fee_trg_release_o    <= '0';
        fee_data_o           <= (others => '0');
        fee_data_write_o     <= '0'; 
        fee_data_finished_o  <= '0';
        STATE                <= S_IDLE;
      else
        fee_trg_release_o    <= fee_trg_release_o_x;
        fee_data_o           <= fee_data_o_x;
        fee_data_write_o     <= fee_data_write_o_x;
        fee_data_finished_o  <= fee_data_finished_o_x;
        STATE                <= NEXT_STATE;
      end if;
    end if;
  end process PROC_DATA_HANDLER_TRANSFER;
  
  PROC_DATA_HANDLER: process(STATE)
  begin
    fee_trg_release_o_x       <= '0';
    fee_data_o_x              <= (others => '0');
    fee_data_write_o_x        <= '0'; 
    fee_data_finished_o_x     <= '0';

    case STATE is
      when S_IDLE =>
        if (LVL1_TRG_DATA_VALID_IN = '1') then
          NEXT_STATE          <= S_SEND_DATA;
        end if;
        
      when S_SEND_DATA =>
        fee_data_o_x          <= x"deadbeef";
        fee_data_write_o_x    <= '1';
        NEXT_STATE            <= S_END;

      when S_END =>
        fee_trg_release_o_x   <= '1';
        fee_data_finished_o_x <= '1';
        NEXT_STATE            <= S_IDLE;
        
    end case;
    
  end process PROC_DATA_HANDLER;

  
-------------------------------------------------------------------------------
-- OUTPUT
-------------------------------------------------------------------------------
  FEE_TRG_RELEASE_OUT       <= fee_trg_release_o;      
  FEE_TRG_STATUSBITS_OUT    <= fee_trg_statusbits_o;   
  FEE_DATA_OUT              <= fee_data_o;             
  FEE_DATA_WRITE_OUT        <= fee_data_write_o;       
  FEE_DATA_FINISHED_OUT     <= fee_data_finished_o;
  

end Behavioral;
