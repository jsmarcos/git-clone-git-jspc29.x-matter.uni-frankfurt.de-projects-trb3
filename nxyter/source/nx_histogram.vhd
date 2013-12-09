library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_histogram is
  generic (
    BUS_WIDTH    : integer   := 7;
    DATA_WIDTH   : integer   := 32
    );
  port (
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;

    CHANNEL_ID_IN          : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    CHANNEL_DATA_IN        : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    CHANNEL_ADD_IN         : in  std_logic;
    CHANNEL_WRITE_IN       : in  std_logic;
    CHANNEL_WRITE_BUSY_OUT : out std_logic;      

    CHANNEL_ID_READ_IN     : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    CHANNEL_READ_IN        : in  std_logic;
    CHANNEL_DATA_OUT       : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    CHANNEL_DATA_VALID_OUT : out std_logic;
    CHANNEL_READ_BUSY_OUT  : out std_logic;
    
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
    
end entity;

architecture Behavioral of nx_histogram is
  
  -- Read Handler
  type R_STATES is (R_IDLE,
                    R_WAIT,
                    R_READ
                    );
  signal R_STATE, R_NEXT_STATE : R_STATES;

  signal read_data              : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal read_address           : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_address_f         : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_enable            : std_logic;
  signal channel_data_o         : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal channel_data_valid_o   : std_logic;
  signal channel_read_busy_o    : std_logic;

  -- Write Handler
  type W_STATES is (W_IDLE,
                    W_WRITE,
                    W_ADD
                    );
  signal W_STATE, W_NEXT_STATE : W_STATES;

  signal write_address          : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_address_f        : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_data             : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal write_data_f           : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal write_enable           : std_logic;
  signal channel_write_busy_o   : std_logic;
  
begin

  -----------------------------------------------------------------------------

  DEBUG_OUT(0)              <= CLK_IN;
  DEBUG_OUT(1)              <= channel_write_busy_o;
  DEBUG_OUT(2)              <= CHANNEL_WRITE_IN;
  DEBUG_OUT(3)              <= write_enable;
  DEBUG_OUT(4)              <= channel_read_busy_o;
  DEBUG_OUT(5)              <= CHANNEL_READ_IN;
  DEBUG_OUT(6)              <= read_enable;
  DEBUG_OUT(7)              <= channel_data_valid_o;
  DEBUG_OUT(15 downto 8)    <= read_data(7 downto 0);

  -----------------------------------------------------------------------------

  ram_dp_128x32_1: ram_dp_128x32
    port map (
      WrAddress => write_address,
      RdAddress => read_address,
      Data      => write_data,
      WE        => not RESET_IN,
      RdClock   => CLK_IN,
      RdClockEn => read_enable,
      Reset     => RESET_IN,
      WrClock   => CLK_IN,
      WrClockEn => write_enable,
      Q         => read_data
      );

  -----------------------------------------------------------------------------
  -- Memory Handler
  -----------------------------------------------------------------------------
  PROC_MEM_HANDLER_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        read_address_f      <= (others => '0');
        R_STATE              <= R_IDLE;
        
        write_address_f      <= (others => '0');
        write_data_f         <= (others => '0');
        W_STATE              <= W_IDLE;
      else
        read_address_f       <= read_address;
        R_STATE              <= R_NEXT_STATE;

        write_address_f      <= write_address;
        write_data_f         <= write_data;
        W_STATE              <= W_NEXT_STATE;
      end if;
    end if;
  end process PROC_MEM_HANDLER_TRANSFER;

  PROC_MEM_HANDLER: process(R_STATE,
                            CHANNEL_ID_READ_IN,
                            CHANNEL_READ_IN
                            )
  begin
    case R_STATE is
      when R_IDLE =>
        channel_data_o          <= (others => '0');
        channel_data_valid_o    <= '0';

        if (CHANNEL_READ_IN = '1') then
          read_address          <= CHANNEL_ID_READ_IN;
          if (CHANNEL_ADD_IN = '1') then
            read_enable         <= '0';
            channel_read_busy_o <= '0';
            R_NEXT_STATE        <= R_WAIT;
          else
            read_enable         <= '1';
            channel_read_busy_o <= '1';
            R_NEXT_STATE        <= R_READ;
          end if;
        else                  
          read_address          <= (others => '0');
          read_enable           <= '0';
          channel_read_busy_o   <= '0';
          R_NEXT_STATE          <= R_IDLE;
        end if;               

      when R_WAIT =>
        read_address            <= read_address_f;
        if (channel_read_busy_o = '0') then
          channel_read_busy_o   <= '1';
          read_enable           <= '1';
          R_NEXT_STATE          <= R_READ; 
        else
          read_enable           <= '0';
          R_NEXT_STATE          <= R_WAIT;
        end if;
        
      when R_READ =>          
        read_address            <= (others => '0');
        read_enable             <= '0';
        channel_read_busy_o     <= '1';
        channel_data_o          <= read_data;
        channel_data_valid_o    <= '1';
        R_NEXT_STATE            <= R_IDLE;

    end case;

    case W_STATE is
      when W_IDLE =>
        if (CHANNEL_WRITE_IN = '1') then
          write_address         <= CHANNEL_ID_IN;
          write_data            <= CHANNEL_DATA_IN;
          write_enable          <= '1';
          channel_write_busy_o  <= '1';
          W_NEXT_STATE          <= W_WRITE;
        elsif (CHANNEL_ADD_IN = '1') then
          read_address          <= CHANNEL_ID_IN;
          read_enable           <= '1';
          write_address         <= CHANNEL_ID_IN;
          write_data            <= CHANNEL_DATA_IN;
          channel_read_busy_o   <= '1';
          channel_write_busy_o  <= '1';
          W_NEXT_STATE          <= W_ADD;
        else
          write_address         <= (others => '0');
          write_data            <= (others => '0');
          write_enable          <= '0';
          channel_write_busy_o  <= '0';
          W_NEXT_STATE          <= W_IDLE;
        end if;               

      when W_ADD =>          
        write_address           <= write_address_f;
        write_data              <=
          std_logic_vector(unsigned(read_data) + unsigned(write_data_f));
        write_enable            <= '1';
        channel_write_busy_o    <= '1';
        W_NEXT_STATE            <= W_WRITE;
                         
      when W_WRITE =>          
        write_address           <= (others => '0');
        write_data              <= (others => '0');
        write_enable            <= '0';
        channel_write_busy_o    <= '1';
        W_NEXT_STATE            <= W_IDLE;

    end case;
  end process PROC_MEM_HANDLER;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  CHANNEL_WRITE_BUSY_OUT    <= channel_write_busy_o;
  CHANNEL_DATA_OUT          <= channel_data_o;
  CHANNEL_DATA_VALID_OUT    <= channel_data_valid_o;
  CHANNEL_READ_BUSY_OUT     <= channel_read_busy_o;

end Behavioral;
