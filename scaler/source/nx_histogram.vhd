library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity nx_histogram is
  generic (
    BUS_WIDTH  : integer   := 7
    );
  port (
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;

    NUM_AVERAGES_IN        : in  unsigned(2 downto 0);
    AVERAGE_ENABLE_IN      : in  std_logic;
    CHANNEL_ID_IN          : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    CHANNEL_DATA_IN        : in  std_logic_vector(31 downto 0);
    CHANNEL_ADD_IN         : in  std_logic;
    CHANNEL_WRITE_IN       : in  std_logic;
    CHANNEL_WRITE_BUSY_OUT : out std_logic;      
    
    CHANNEL_ID_READ_IN     : in  std_logic_vector(BUS_WIDTH - 1 downto 0);
    CHANNEL_READ_IN        : in  std_logic;
    CHANNEL_DATA_OUT       : out std_logic_vector(31 downto 0);
    CHANNEL_DATA_VALID_OUT : out std_logic;
    CHANNEL_READ_BUSY_OUT  : out std_logic;
    
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
    
end entity;

architecture Behavioral of nx_histogram is

  -- Hist Fill/Ctr Handler
  type H_STATES is (H_IDLE,
                    H_WRITEADD_CHANNEL,
                    H_WRITE_CHANNEL,
                    H_ERASE,
                    H_ERASE_CHANNEL
                    );
  signal H_STATE, H_NEXT_STATE : H_STATES;

  signal address_hist_m          : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal address_hist_m_x        : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal data_hist_m             : std_logic_vector(31 downto 0);
  signal data_hist_m_x           : std_logic_vector(31 downto 0);
  
  signal read_data_hist          : std_logic_vector(31 downto 0);
  signal read_data_ctr_hist      : unsigned(7 downto 0);
  signal read_address_hist       : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_enable_hist        : std_logic;

  signal write_data_hist         : std_logic_vector(31 downto 0);
  signal write_data_ctr_hist     : unsigned(7 downto 0);
  signal write_address_hist      : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_enable_hist       : std_logic;

  signal write_address           : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal write_data              : std_logic_vector(31 downto 0);
  signal write_enable            : std_logic;

  signal channel_write_busy_o    : std_logic;

  signal erase_counter_x         : unsigned(BUS_WIDTH - 1 downto 0);
  signal erase_counter           : unsigned(BUS_WIDTH - 1 downto 0);
  
  -- Hist Read Handler
  signal read_address            : std_logic_vector(BUS_WIDTH - 1 downto 0);
  signal read_data               : std_logic_vector(31 downto 0);
  signal read_enable_p           : std_logic;
  signal read_enable             : std_logic;
  signal channel_data_o          : std_logic_vector(31 downto 0);
  signal channel_data_valid_o    : std_logic;
  signal channel_data_valid_o_f  : std_logic_vector(2 downto 0);
  signal channel_read_busy_o     : std_logic;

  signal debug_state_x        : std_logic_vector(2 downto 0);
  signal debug_state          : std_logic_vector(2 downto 0);

begin

  -----------------------------------------------------------------------------

  DEBUG_OUT(0)              <= CLK_IN;
  DEBUG_OUT(1)              <= channel_write_busy_o;
  DEBUG_OUT(2)              <= CHANNEL_ADD_IN;
  DEBUG_OUT(3)              <= write_enable_hist;
  DEBUG_OUT(4)              <= channel_read_busy_o;
  DEBUG_OUT(5)              <= CHANNEL_READ_IN;
  DEBUG_OUT(6)              <= read_enable;
  DEBUG_OUT(7)              <= channel_data_valid_o;
  DEBUG_OUT(8)              <= RESET_IN;
  DEBUG_OUT(11 downto 9)    <= debug_state;
  DEBUG_OUT(15 downto 12)   <= channel_data_o(3 downto 0);
  
  -----------------------------------------------------------------------------

  SMALL: if (BUS_WIDTH = 7) generate

    ram_dp_COUNTER_HIST: entity work.ram_dp_128x40
      port map (
        WrAddress          => write_address_hist,
        RdAddress          => read_address_hist,
        Data(31 downto 0)  => write_data_hist,
        Data(39 downto 32) => write_data_ctr_hist,
        WE                 => not RESET_IN,
        RdClock            => CLK_IN,
        RdClockEn          => read_enable_hist,
        Reset              => RESET_IN,
        WrClock            => CLK_IN,
        WrClockEn          => write_enable_hist,
        Q(31 downto 0)     => read_data_hist,
        Q(39 downto 32)    => read_data_ctr_hist
        );

    ram_dp_RESULT_HIST: entity work.ram_dp_128x32
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
  end generate SMALL;

  
  LARGE: if (BUS_WIDTH = 9) generate

    ram_dp_COUNTER_HIST: entity work.ram_dp_512x40
      port map (
        WrAddress          => write_address_hist,
        RdAddress          => read_address_hist,
        Data(31 downto 0)  => write_data_hist,
        Data(39 downto 32) => write_data_ctr_hist,
        WE                 => not RESET_IN,
        RdClock            => CLK_IN,
        RdClockEn          => read_enable_hist,
        Reset              => RESET_IN,
        WrClock            => CLK_IN,
        WrClockEn          => write_enable_hist,
        Q(31 downto 0)     => read_data_hist,
        Q(39 downto 32)    => read_data_ctr_hist
        );

    ram_dp_RESULT_HIST: entity work.ram_dp_512x32
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
  end generate LARGE;
  
  -----------------------------------------------------------------------------
  -- Memory Handler
  -----------------------------------------------------------------------------

  pulse_to_level_1: pulse_to_level
    generic map (
      NUM_CYCLES => 2
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => read_enable_p,
      LEVEL_OUT => read_enable
      );

  PROC_HIST_READ: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        read_enable_p               <= '0';
        read_address                <= (others => '0');
        channel_data_valid_o_f      <= (others => '0');
        channel_data_valid_o        <= '0';
        channel_data_o              <= (others => '0');
        channel_read_busy_o         <= '0';
      else
        channel_data_valid_o_f(2)   <= '0';
        channel_data_valid_o_f(1)   <= channel_data_valid_o_f(2);
        channel_data_valid_o_f(0)   <= channel_data_valid_o_f(1);

        read_enable_p               <= '0';
        read_address                <= (others => '0');
        channel_data_o              <= (others => '0');  
        channel_data_valid_o        <= '0';
        channel_read_busy_o         <= '0';
        
        if (CHANNEL_READ_IN = '1') then
          read_enable_p             <= '1';
          read_address              <= CHANNEL_ID_READ_IN; 
          channel_data_valid_o_f(2) <= '1';
        end if;
                
        if (channel_data_valid_o_f(0) = '1') then
          channel_data_o            <= read_data;
          channel_data_valid_o      <= '1';
        end if;
        if (channel_data_valid_o_f = "000" and CHANNEL_READ_IN = '0') then
          channel_read_busy_o       <= '0';
        else
          channel_read_busy_o       <= '1';
        end if;
      end if;
    end if;
  end process PROC_HIST_READ;
    
  PROC_HIST_HANDLER_TRANSFER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        address_hist_m       <= (others => '0');
        data_hist_m          <= (others => '0');
        erase_counter        <= (others => '0');
        H_STATE              <= H_ERASE;
        debug_state          <= (others => '0');
      else
        address_hist_m       <= address_hist_m_x;
        data_hist_m          <= data_hist_m_x;
        erase_counter        <= erase_counter_x;
        H_STATE              <= H_NEXT_STATE;
        debug_state          <= debug_state_x;
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
    erase_counter_x             <= erase_counter;
    
    case H_STATE is

      when H_IDLE =>
        write_address_hist      <= (others => '0');
        write_data_hist         <= (others => '0');
        write_data_ctr_hist     <= (others => '0');
        write_enable_hist       <= '0';
        write_address           <= (others => '0');
        write_data              <= (others => '0');
        write_enable            <= '0';
        channel_write_busy_o    <= '0';

        if (CHANNEL_ADD_IN = '1') then
          read_address_hist     <= CHANNEL_ID_IN;
          read_enable_hist      <= '1';
          address_hist_m_x      <= CHANNEL_ID_IN;
          data_hist_m_x         <= CHANNEL_DATA_IN;
          H_NEXT_STATE          <= H_WRITEADD_CHANNEL;
        elsif (CHANNEL_WRITE_IN = '1') then
          read_address_hist     <= (others => '0');
          read_enable_hist      <= '0';
          address_hist_m_x      <= CHANNEL_ID_IN;
          data_hist_m_x         <= CHANNEL_DATA_IN;
          H_NEXT_STATE          <= H_WRITE_CHANNEL;
        else
          read_address_hist     <= (others => '0');
          read_enable_hist      <= '0';
          address_hist_m_x      <= (others => '0');
          data_hist_m_x         <= (others => '0');
          H_NEXT_STATE          <= H_IDLE;
        end if;                 
        debug_state_x <= "001";

      when H_WRITEADD_CHANNEL =>
        if (AVERAGE_ENABLE_IN = '0') then
          new_data              := std_logic_vector(unsigned(read_data_hist) +
                                                    unsigned(data_hist_m));
          write_data_ctr_hist   <= read_data_ctr_hist + 1;
          
          write_address         <= address_hist_m;
          write_data            <= new_data;
          write_enable          <= '1';
        elsif ((read_data_ctr_hist srl to_integer(NUM_AVERAGES_IN)) > 0)
        then
          new_data              := std_logic_vector(unsigned(data_hist_m));
          write_data_ctr_hist   <= x"01";

          write_address         <= address_hist_m;
          write_data            <= new_data;
          write_enable          <= '1';
        else
          new_data              := std_logic_vector(unsigned(read_data_hist) +
                                                    unsigned(data_hist_m));
          write_data_ctr_hist <= read_data_ctr_hist + 1;
          
          write_address         <= (others => '0');
          write_data            <= (others => '0');
          write_enable          <= '0';
        end if;
        
        read_address_hist       <= (others => '0');
        read_enable_hist        <= '0';
        write_address_hist      <= address_hist_m;
        write_data_hist         <= new_data;
        write_enable_hist       <= '1';
        channel_write_busy_o    <= '1';
        H_NEXT_STATE            <= H_IDLE;
        debug_state_x <= "010";

      when H_WRITE_CHANNEL =>
        new_data                := unsigned(data_hist_m);
        read_address_hist       <= (others => '0');
        read_enable_hist        <= '0';
        write_address_hist      <= address_hist_m;
        write_data_hist         <= new_data;
        write_data_ctr_hist     <= (others => '0');
        write_enable_hist       <= '1';

        write_address           <= address_hist_m;
        write_data              <= new_data;
        write_enable            <= '1';
        channel_write_busy_o    <= '1';
        H_NEXT_STATE            <= H_IDLE;
        debug_state_x <= "011";

      when H_ERASE =>
        write_address_hist      <= (others => '0');
        write_data_hist         <= (others => '0');
        write_data_ctr_hist     <= (others => '0');
        write_enable_hist       <= '0';
        write_address           <= (others => '0');
        write_data              <= (others => '0');
        write_enable            <= '0';
        erase_counter_x         <= erase_counter + 1;
        read_address_hist       <= (others => '0');
        read_enable_hist        <= '0';
        address_hist_m_x        <= std_logic_vector(erase_counter);
        data_hist_m_x           <= (others => '0');
        channel_write_busy_o    <= '1';
        H_NEXT_STATE            <= H_ERASE_CHANNEL;
        debug_state_x <= "100";

      when H_ERASE_CHANNEL  =>
        new_data                := unsigned(data_hist_m);
        read_address_hist       <= (others => '0');
        read_enable_hist        <= '0';
        write_address_hist      <= address_hist_m;
        write_data_hist         <= new_data;
        write_data_ctr_hist     <= (others => '0');
        write_enable_hist       <= '1';

        write_address           <= address_hist_m;
        write_data              <= new_data;
        write_enable            <= '1';
        channel_write_busy_o    <= '1';
        if (erase_counter > 0) then
          H_NEXT_STATE          <= H_ERASE;
        else
          H_NEXT_STATE          <= H_IDLE;
        end if;
        debug_state_x <= "101";
        
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

