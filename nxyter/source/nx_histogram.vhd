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
  
  -- Hist Fill/Ctr Handler
  type H_STATES is (H_IDLE,
                    H_WRITE_CHANNEL
                    );
  signal H_STATE, H_NEXT_STATE : H_STATES;

  signal address_hist_m          : std_logic_vector(6 downto 0);
  signal address_hist_m_x        : std_logic_vector(6 downto 0);
  signal data_hist_m             : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal data_hist_m_x           : std_logic_vector(DATA_WIDTH - 1 downto 0);
  
  signal read_data_hist          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal read_address_hist       : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_enable_hist        : std_logic;

  signal write_address_hist      : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_data_hist         : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal write_enable_hist       : std_logic;

  signal write_address           : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_data              : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal write_enable            : std_logic;

  signal channel_write_busy_o    : std_logic;
  
  -- Hist Read Handler
  signal read_address            : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_data               : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal read_enable             : std_logic;
  signal channel_data_o          : std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal channel_data_valid_o    : std_logic;
  signal channel_data_valid_o_f  : std_logic;
  signal channel_read_busy_o     : std_logic;

begin

  -----------------------------------------------------------------------------

  DEBUG_OUT(0)              <= CLK_IN;
  DEBUG_OUT(1)              <= channel_write_busy_o;
  DEBUG_OUT(2)              <= CHANNEL_ADD_IN;
  DEBUG_OUT(3)              <= write_enable_hist;
  DEBUG_OUT(4)              <= channel_read_busy_o;
  DEBUG_OUT(5)              <= CHANNEL_READ_IN;
  DEBUG_OUT(6)              <= read_enable_hist;
  DEBUG_OUT(7)              <= channel_data_valid_o;
  DEBUG_OUT(15 downto 8)    <= channel_data_o(7 downto 0);

  -----------------------------------------------------------------------------

  ram_dp_128x32_hist: ram_dp_128x32
    port map (
      WrAddress => write_address_hist,
      RdAddress => read_address_hist,
      Data      => write_data_hist,
      WE        => not RESET_IN,
      RdClock   => CLK_IN,
      RdClockEn => read_enable_hist,
      Reset     => RESET_IN,
      WrClock   => CLK_IN,
      WrClockEn => write_enable_hist,
      Q         => read_data_hist
      );

  ram_dp_128x32_result: ram_dp_128x32
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

  pulse_to_level_1: pulse_to_level
    generic map (
      NUM_CYCLES => 3
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => read_enable,
      LEVEL_OUT => channel_read_busy_o
      );

  read_enable                <= CHANNEL_READ_IN;
  read_address               <= CHANNEL_ID_READ_IN; 
  channel_data_valid_o_f     <= CHANNEL_READ_IN when rising_edge(CLK_IN);
  channel_data_valid_o       <= channel_data_valid_o_f when rising_edge(CLK_IN);
  channel_data_o             <= read_data when rising_edge(CLK_IN);
    
  PROC_HIST_HANDLER_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        address_hist_m       <= (others => '0');
        data_hist_m          <= (others => '0');
        H_STATE              <= H_IDLE;
      else
        address_hist_m       <= address_hist_m_x;
        data_hist_m          <= data_hist_m_x;
        H_STATE              <= H_NEXT_STATE;
      end if;
    end if;
  end process PROC_HIST_HANDLER_TRANSFER;

  PROC_HIST_HANDLER: process(H_STATE,
                             CHANNEL_ID_IN,
                             CHANNEL_DATA_IN,
                             CHANNEL_ADD_IN,
                             CHANNEL_WRITE_IN
                             )
    variable new_data           : unsigned(31 downto 0);
  begin
    address_hist_m_x            <= address_hist_m;
    data_hist_m_x               <= data_hist_m;
    
    case H_STATE is
      when H_IDLE =>
        write_address_hist    <= (others => '0');
        write_data_hist       <= (others => '0');
        write_enable_hist     <= '0';
        write_address         <= (others => '0');
        write_data            <= (others => '0');
        write_enable          <= '0';

        if (CHANNEL_ADD_IN = '1') then
          read_address_hist     <= CHANNEL_ID_IN;
          read_enable_hist      <= '1';
          address_hist_m_x      <= CHANNEL_ID_IN;
          data_hist_m_x         <= CHANNEL_DATA_IN;
          channel_write_busy_o  <= '1';
          H_NEXT_STATE          <= H_WRITE_CHANNEL;
        else
          read_address_hist     <= (others => '0');
          read_enable_hist      <= '0';
          address_hist_m_x      <= (others => '0');
          data_hist_m_x         <= (others => '0');
          channel_write_busy_o  <= '0';
          H_NEXT_STATE          <= H_IDLE;
        end if;                 

      when H_WRITE_CHANNEL =>
        new_data                :=
          std_logic_vector(unsigned(read_data_hist) + unsigned(data_hist_m));
        read_address_hist       <= (others => '0');
        read_enable_hist        <= '0';
        write_address_hist      <= address_hist_m;
        write_data_hist         <= new_data;
        write_enable_hist       <= '1';

        write_address           <= address_hist_m;
        write_data              <= new_data;
        write_enable            <= '1';
        channel_write_busy_o    <= '1';
        H_NEXT_STATE            <= H_IDLE;
    end case;
        
  end process PROC_HIST_HANDLER;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  CHANNEL_WRITE_BUSY_OUT    <= channel_write_busy_o;
  CHANNEL_DATA_OUT          <= channel_data_o;
  CHANNEL_DATA_VALID_OUT    <= channel_data_valid_o;
  CHANNEL_READ_BUSY_OUT     <= channel_read_busy_o;

end Behavioral;
