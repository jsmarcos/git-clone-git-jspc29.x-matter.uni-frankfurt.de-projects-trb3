library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;
use work.trb3_components.all;

entity nx_status_event is
  generic (
    BOARD_ID                   : std_logic_vector(1 downto 0) := "11";
    VERSION_NUMBER             : std_logic_vector(3 downto 0) := x"1"
    );
  port (
    CLK_IN                     : in  std_logic;  
    RESET_IN                   : in  std_logic;
    NXYTER_OFFLINE_IN          : in  std_logic;

    -- Trigger
    TRIGGER_IN                 : in  std_logic;
    FAST_CLEAR_IN              : in  std_logic;
    TRIGGER_BUSY_OUT           : out std_logic;
    
    --Response from FEE        
    FEE_DATA_OUT               : out std_logic_vector(31 downto 0);
    FEE_DATA_WRITE_OUT         : out std_logic;
    FEE_DATA_ALMOST_FULL_IN    : in  std_logic;

    -- Interface to NX Setup
    INT_READ_OUT               : out std_logic;
    INT_ADDR_OUT               : out std_logic_vector(15 downto 0);
    INT_ACK_IN                 : in  std_logic;
    INT_DATA_IN                : in  std_logic_vector(31 downto 0);
    
    DEBUG_OUT                  : out std_logic_vector(15 downto 0)
    );

end entity;

architecture Behavioral of nx_status_event is

  --Data channel
  signal trigger_busy_o       : std_logic;
  signal event_write_start    : std_logic;

  type STATES is (S_IDLE,
                  S_EVT_WRITE_WAIT
                  );

  signal STATE    : STATES;
  
  -- Event Write
  type E_STATES is (E_IDLE,
                    E_HEADER,
                    E_READ_NEXT,
                    E_READ,
                    E_NEXT_INDEX,
                    E_TRAILER,
                    E_END
                    );

  signal E_STATE  : E_STATES;

 -- constant NUM_REGS : integer      := 3;
 -- type reg_addr_t is array(0 to NUM_REGS - 1) of std_logic_vector(15 downto 0);
 -- constant reg_addr_start          : reg_addr_t :=
 --   (x"0000",
 --    x"0100",
 --    x"0080"
 --    );
 -- constant reg_addr_end            : reg_addr_t :=
 --   (x"002d",
 --    x"0180",
 --    x"0083"
 --    );        

  -- For the moment just the 4 I2C ADC Values, event must be small
  constant NUM_REGS : integer      := 1;
  type reg_addr_t is array(0 to NUM_REGS - 1) of std_logic_vector(15 downto 0);
  constant reg_addr_start          : reg_addr_t :=
    (x"0080"
     );
  constant reg_addr_end            : reg_addr_t :=
    (x"0083"
     );        

  signal index_ctr                 : unsigned(3 downto 0);
  signal register_addr             : unsigned(15 downto 0);
  signal int_read_o                : std_logic;
  signal int_addr_o                : std_logic_vector(15 downto 0);
  signal fee_data_o                : std_logic_vector(31 downto 0);
  signal fee_data_write_o          : std_logic;
  signal event_write_done          : std_logic;
  
begin

  DEBUG_OUT(0)           <= CLK_IN;
  DEBUG_OUT(1)           <= TRIGGER_IN;
  DEBUG_OUT(2)           <= FAST_CLEAR_IN;
  DEBUG_OUT(3)           <= FEE_DATA_ALMOST_FULL_IN;
  DEBUG_OUT(4)           <= trigger_busy_o;
  DEBUG_OUT(5)           <= event_write_start;
  DEBUG_OUT(6)           <= event_write_done;
  DEBUG_OUT(10 downto 7) <= index_ctr;
  DEBUG_OUT(11)          <= int_read_o;
  DEBUG_OUT(12)          <= INT_ACK_IN;
  DEBUG_OUT(13)          <= fee_data_write_o;
  DEBUG_OUT(14)          <= '0';
  DEBUG_OUT(15)          <= NXYTER_OFFLINE_IN;
  
  -----------------------------------------------------------------------------
  -- 
  -----------------------------------------------------------------------------

  PROC_DATA_HANDLER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        event_write_start    <= '0';
        trigger_busy_o       <= '0';
        STATE                <= S_IDLE;
      else
        event_write_start    <= '0';
        trigger_busy_o       <= '1';
        
        if (FAST_CLEAR_IN = '1') then
          STATE                      <= S_IDLE;
        else
          case STATE is
            when S_IDLE =>
              if (NXYTER_OFFLINE_IN = '1') then
                trigger_busy_o             <= '0';
                STATE                      <= S_IDLE;
              elsif (TRIGGER_IN = '1') then
                event_write_start          <= '1';
                STATE                      <= S_EVT_WRITE_WAIT;
              else
                trigger_busy_o             <= '0';
                STATE                      <= S_IDLE;
              end if;
              
            when S_EVT_WRITE_WAIT =>
              if (event_write_done = '0') then
                STATE                      <= S_EVT_WRITE_WAIT;
              else                         
                STATE                      <= S_IDLE;
              end if;                      
              
          end case;
        end if;
      end if;
    end if;
  end process PROC_DATA_HANDLER;

  
  PROC_WRITE_EVENT: process(CLK_IN)
    variable index  : integer   := 0;
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        index_ctr             <= (others => '0');
        register_addr         <= (others => '0');
        int_read_o            <= '0';
        int_addr_o            <= (others => '0');
        fee_data_o            <= (others => '0');
        fee_data_write_o      <= '0';
        event_write_done      <= '0';
        E_STATE               <= E_IDLE;
      else
        index                 := to_integer(index_ctr);
        int_read_o            <= '0';
        int_addr_o            <= (others => '0');
        fee_data_o            <= (others => '0');
        fee_data_write_o      <= '0';
        event_write_done      <= '0';
        
        case E_STATE is
          when E_IDLE =>
            index_ctr                  <= (others => '0');
            if (event_write_start = '1') then
              E_STATE                  <= E_HEADER;
            else                       
              E_STATE                  <= E_IDLE;
            end if;                    

          when E_HEADER =>
            fee_data_o(25 downto 0)    <= (others => '1');
            fee_data_o(29 downto 26)   <= VERSION_NUMBER;
            fee_data_o(31 downto 30)   <= BOARD_ID;
            fee_data_write_o           <= '1';
            E_STATE                    <= E_NEXT_INDEX;
            
          when E_READ_NEXT =>          
            if (register_addr <= unsigned(reg_addr_end(index))) then
              int_addr_o               <= register_addr;
              int_read_o               <= '1';
              E_STATE                  <= E_READ;
            else                       
              index_ctr                <= index_ctr + 1;
              E_STATE                  <= E_NEXT_INDEX;
            end if;

          when E_READ =>
            if (INT_ACK_IN = '1') then
              fee_data_o(15 downto 0)  <= INT_DATA_IN(15 downto 0);
              fee_data_o(31 downto 16) <= register_addr;
              fee_data_write_o         <= '1';
              register_addr            <= register_addr + 1;
              E_STATE                  <= E_READ_NEXT;
            else
              E_STATE                  <= E_READ;
            end if;

          when E_NEXT_INDEX =>
            if (index_ctr < NUM_REGS) then
              register_addr            <= reg_addr_start(index);
              E_STATE                  <= E_READ_NEXT;
            else
              E_STATE                  <= E_TRAILER;
            end if;
            
          when E_TRAILER =>
            fee_data_o                 <= (others => '1');
            fee_data_write_o           <= '1';
            E_STATE                    <= E_END;
            
          when E_END =>
            event_write_done           <= '1';
            E_STATE                    <= E_IDLE;
                        
        end case;
      end if;
    end if;
  end process PROC_WRITE_EVENT;
 
  -- Output Signals

  TRIGGER_BUSY_OUT       <= trigger_busy_o;
  FEE_DATA_OUT           <= fee_data_o;
  FEE_DATA_WRITE_OUT     <= fee_data_write_o;

  INT_READ_OUT           <= int_read_o;
  INT_ADDR_OUT           <= int_addr_o; 
  
end Behavioral;
