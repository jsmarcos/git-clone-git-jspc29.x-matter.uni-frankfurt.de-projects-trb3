library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_data_buffer is
  port (
    CLK_IN               : in std_logic;  
    RESET_IN             : in std_logic;

    -- Data Buffer FIFO
    DATA_IN              : in std_logic_vector(31 downto 0);
    DATA_CLK_IN          : in std_logic;

    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;

    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );

end nx_data_buffer;

architecture Behavioral of nx_data_buffer is
  -- FIFO Input Handler
  signal fifo_next_word     : std_logic_vector(31 downto 0);
  signal fifo_full          : std_logic;
  signal fifo_write_enable  : std_logic;
  
  -- FIFO Read Handler
  signal fifo_o             : std_logic_vector(31 downto 0);
  signal fifo_empty         : std_logic;       
  signal fifo_read_start    : std_logic;

  signal fifo_read_enable   : std_logic;
  signal fifo_read_busy     : std_logic;
  signal fifo_no_data       : std_logic;
  signal fifo_read_done     : std_logic;
  signal fifo_data          : std_logic_vector(31 downto 0);

  type STATES is (S_IDLE,
                  S_NOP1,
                  S_NOP2,
                  S_READ_WORD
                  );

  signal STATE : STATES;
  
  -- Slave Bus
  signal slv_data_out_o        : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o    : std_logic;
  signal slv_unknown_addr_o    : std_logic;
  signal slv_ack_o             : std_logic;

  signal register_fifo_status  : std_logic_vector(31 downto 0);

  signal data_wait             : std_logic;

begin

  DEBUG_OUT(0)     <= CLK_IN;
  DEBUG_OUT(1)     <= '0';
  DEBUG_OUT(2)     <= data_wait;
  DEBUG_OUT(3)     <= fifo_read_done;
  DEBUG_OUT(4)     <= fifo_read_busy;
  DEBUG_OUT(5)     <= fifo_write_enable;
  DEBUG_OUT(6)     <= fifo_full;
  DEBUG_OUT(7)     <= fifo_empty;
  DEBUG_OUT(8)     <= fifo_read_enable;
  DEBUG_OUT(9)     <= slv_ack_o;
  DEBUG_OUT(10)    <= fifo_no_data;
  DEBUG_OUT(11)    <= fifo_read_start;
  DEBUG_OUT(15 downto 12) <= fifo_o(3 downto 0);
    
  -----------------------------------------------------------------------------
  -- FIFO Input Handler
  -----------------------------------------------------------------------------

  -- Send data to FIFO
  fifo_32_data_1: fifo_32_data
    port map (
      Data  => fifo_next_word,
      Clock => CLK_IN,
      WrEn  => fifo_write_enable,
      RdEn  => fifo_read_enable,
      Reset => RESET_IN,
      Q     => fifo_o,
      Empty => fifo_empty,
      Full  => fifo_full
      );

  PROC_FIFO_WRITE_HANDLER: process(CLK_IN)
  begin
    if(rising_edge(CLK_IN)) then
      if(RESET_IN = '1') then
        fifo_write_enable  <= '0';
      else
        fifo_write_enable <= '0';
        fifo_next_word    <= x"deadbeef";
        
        if (DATA_CLK_IN = '1' and fifo_full = '0') then
          fifo_next_word    <= DATA_IN;
          fifo_write_enable <= '1';
        end if;
        
      end if;
    end if;
  end process PROC_FIFO_WRITE_HANDLER;
  
  -----------------------------------------------------------------------------
  -- FIFO Output Handler
  -----------------------------------------------------------------------------
  
  PROC_FIFO_READ_WORD: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        fifo_read_enable  <= '0';
        fifo_read_busy    <= '0';
        fifo_data         <= (others => '0');
        fifo_read_done    <= '0';
        fifo_no_data      <= '1';
        STATE             <= S_IDLE;
      else                
        fifo_read_busy    <= '0';
        fifo_no_data      <= '0';
        fifo_read_done    <= '0';
        fifo_data         <= (others => '0');
        fifo_read_enable  <= '0';

        case STATE is 
          when S_IDLE =>
            if (fifo_read_start = '1') then
              if (fifo_empty = '0') then
                fifo_read_enable <= '1';
                fifo_read_busy   <= '1';
                STATE            <= S_NOP1;
              else
                fifo_no_data     <= '1';
                fifo_read_done   <= '1';
                STATE            <= S_IDLE;
              end if;
            else
              STATE              <= S_IDLE;
            end if;

          when S_NOP1 =>
            fifo_read_busy       <= '1';
            STATE                <= S_NOP2;

          when S_NOP2 =>
            fifo_read_busy       <= '1';
            STATE                <= S_READ_WORD;
            
          when S_READ_WORD =>
            fifo_read_busy       <= '0';
            fifo_data            <= fifo_o;
            fifo_read_done       <= '1';
            STATE                <= S_IDLE;
            
        end case; 
      end if;
    end if;

  end process PROC_FIFO_READ_WORD;
  
  -----------------------------------------------------------------------------
  -- Slave Bus Slow Control
  -----------------------------------------------------------------------------

  register_fifo_status(0)            <= fifo_write_enable;
  register_fifo_status(1)            <= fifo_full;
  register_fifo_status(3 downto 2)   <= (others => '0');
  register_fifo_status(4)            <= fifo_read_enable;
  register_fifo_status(5)            <= fifo_empty;
  register_fifo_status(7 downto 6)   <= (others => '0');
  register_fifo_status(31 downto 8)  <= (others => '0');

  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o        <= (others => '0');
        slv_ack_o             <= '0';
        slv_unknown_addr_o    <= '0';
        slv_no_more_data_o    <= '0';

        fifo_read_start       <= '0';
        data_wait             <= '0';
      else
        slv_data_out_o     <= (others => '0');
        slv_ack_o          <= '0';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        
        fifo_read_start    <= '0';
        data_wait          <= '0';
        
        if (data_wait = '1') then
          if (fifo_read_done = '0') then
            data_wait      <= '1';
          else
            if (fifo_no_data = '0') then
              slv_data_out_o     <= fifo_data;
              slv_ack_o          <= '1';
            else
              slv_no_more_data_o <= '1';
              slv_ack_o          <= '0';
            end if;
            data_wait            <= '0';
          end if;

        elsif (SLV_READ_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              fifo_read_start <= '1';
              data_wait       <= '1';
              
            when x"0001" =>
              slv_data_out_o <= register_fifo_status;
              slv_ack_o      <= '1';
              
            when others  =>
              slv_unknown_addr_o <= '1';
          end case;
            
        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when others  =>
              slv_unknown_addr_o <= '1';              
              slv_ack_o <= '0';
          end case;                

        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;
  end process PROC_SLAVE_BUS;

-- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;

end Behavioral;
