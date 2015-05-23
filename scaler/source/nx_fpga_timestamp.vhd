library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_fpga_timestamp is
  port (
    CLK_IN                   : in  std_logic;
    RESET_IN                 : in  std_logic;
    NX_MAIN_CLK_IN           : in  std_logic;      
                             
    TIMESTAMP_RESET_IN       : in  std_logic;
    TIMESTAMP_RESET_OUT      : out std_logic;
    TRIGGER_IN               : in  std_logic; -- must be in NX_MAIN_CLK_DOMAIN
    TIMESTAMP_HOLD_OUT       : out unsigned(11 downto 0);
    TIMESTAMP_TRIGGER_OUT    : out std_logic;

    -- Slave bus         
    SLV_READ_IN              : in  std_logic;
    SLV_WRITE_IN             : in  std_logic;
    SLV_DATA_OUT             : out std_logic_vector(31 downto 0);
    SLV_DATA_IN              : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT              : out std_logic;
    SLV_NO_MORE_DATA_OUT     : out std_logic;
    SLV_UNKNOWN_ADDR_OUT     : out std_logic;
                             
    -- Debug Line            
    DEBUG_OUT                : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_fpga_timestamp is
  type S_STATES is (S_IDLE,
                    S_RESET,
                    S_RESET_WAIT,
                    S_HOLD
                    );
  signal S_STATE : S_STATES;
  
  signal wait_timer_start     : std_logic;
  signal wait_timer_done      : std_logic;

  signal timestamp_reset_ff   : std_logic;
  signal timestamp_reset_f    : std_logic;
  signal timestamp_reset      : std_logic;
  signal timestamp_ctr        : unsigned(11 downto 0);

  signal timestamp_hold_o     : std_logic_vector(11 downto 0);
  signal timestamp_trigger_o  : std_logic;
  signal timestamp_reset_o    : std_logic;

  -- Reset
  signal reset_nx_main_clk_in_ff  : std_logic;
  signal reset_nx_main_clk_in_f   : std_logic;
  signal RESET_NX_MAIN_CLK_IN     : std_logic;

  attribute syn_keep : boolean;
  attribute syn_keep of reset_nx_main_clk_in_ff     : signal is true;
  attribute syn_keep of reset_nx_main_clk_in_f      : signal is true;

  attribute syn_keep of timestamp_reset_ff          : signal is true;
  attribute syn_keep of timestamp_reset_f           : signal is true;
  
  attribute syn_preserve : boolean;
  attribute syn_preserve of reset_nx_main_clk_in_ff : signal is true;
  attribute syn_preserve of reset_nx_main_clk_in_f  : signal is true;

  attribute syn_preserve of timestamp_reset_ff      : signal is true;
  attribute syn_preserve of timestamp_reset_f       : signal is true;
  
begin
  DEBUG_OUT(0)             <= NX_MAIN_CLK_IN;
  DEBUG_OUT(1)             <= '0';
  DEBUG_OUT(2)             <= TIMESTAMP_RESET_IN;
  DEBUG_OUT(3)             <= '0';
  DEBUG_OUT(4)             <= TRIGGER_IN;
  DEBUG_OUT(5)             <= '0';
  DEBUG_OUT(6)             <= timestamp_reset_ff;
  DEBUG_OUT(7)             <= '0';
  DEBUG_OUT(8)             <= timestamp_reset_f;
  DEBUG_OUT(9)             <= '0';
  DEBUG_OUT(10)            <= timestamp_reset;
  DEBUG_OUT(11)            <= '0';
  DEBUG_OUT(12)            <= timestamp_reset_o;
  DEBUG_OUT(13)            <= '0';
  DEBUG_OUT(14)            <= timestamp_trigger_o;

  DEBUG_OUT(15)            <= '0';
  --timestamp_hold_o(10 downto 0);

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  reset_nx_main_clk_in_ff   <= RESET_IN when rising_edge(NX_MAIN_CLK_IN);
  reset_nx_main_clk_in_f    <= reset_nx_main_clk_in_ff
                               when rising_edge(NX_MAIN_CLK_IN); 
  RESET_NX_MAIN_CLK_IN      <= reset_nx_main_clk_in_f
                               when rising_edge(NX_MAIN_CLK_IN);

  -----------------------------------------------------------------------------
  -- NX Clock Domain
  -----------------------------------------------------------------------------

  -- Timestamp Process + Trigger
  timestamp_reset_ff         <= TIMESTAMP_RESET_IN
                                when rising_edge(NX_MAIN_CLK_IN);
  timestamp_reset_f          <= timestamp_reset_ff
                                when rising_edge(NX_MAIN_CLK_IN);
  timestamp_reset            <= timestamp_reset_f
                                when rising_edge(NX_MAIN_CLK_IN);

  -- Timer
  timer_static_TS_RESET: timer_static
    generic map (
      CTR_WIDTH => 3,
      CTR_END   => 7
      )
    port map (
      CLK_IN         => NX_MAIN_CLK_IN,
      RESET_IN       => RESET_NX_MAIN_CLK_IN,
      TIMER_START_IN => wait_timer_start,
      TIMER_DONE_OUT => wait_timer_done
      );

  PROC_TIMESTAMP_CTR: process (NX_MAIN_CLK_IN)
  begin
    if (rising_edge(NX_MAIN_CLK_IN)) then
      if (RESET_NX_MAIN_CLK_IN = '1') then
        wait_timer_start         <= '0';
        timestamp_ctr            <= (others => '0');
        timestamp_hold_o         <= (others => '0');
        timestamp_reset_o        <= '0';
        S_STATE                  <=  S_RESET;
      else
        wait_timer_start         <= '0';
        timestamp_trigger_o      <= '0'; 
        timestamp_reset_o        <= '0';

        case S_STATE is

          when S_IDLE =>
            timestamp_ctr            <= timestamp_ctr + 1;            
            if (timestamp_reset = '0' and timestamp_reset_f = '1') then
              S_STATE                <= S_RESET;
            elsif (TRIGGER_IN = '1') then
              S_STATE                <= S_HOLD;
            else
              S_STATE                <= S_IDLE;
            end if;
            
          when S_RESET =>
            timestamp_reset_o        <= '1';
            wait_timer_start         <= '1';
            S_STATE                  <=  S_RESET_WAIT;

          when S_RESET_WAIT =>
            if (wait_timer_done = '0') then
              timestamp_reset_o      <= '1';
              S_STATE                <= S_RESET_WAIT;
            else
              timestamp_ctr          <= (others => '0');
              S_STATE                <= S_IDLE;
            end if;

          when S_HOLD =>
            timestamp_ctr            <= timestamp_ctr + 1;
            timestamp_hold_o         <= timestamp_ctr;
            timestamp_trigger_o      <= '1';
            S_STATE                  <=  S_IDLE;
            
        end case;
        
      end if;
    end if;
  end process PROC_TIMESTAMP_CTR;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  TIMESTAMP_RESET_OUT       <= timestamp_reset_o;
  TIMESTAMP_HOLD_OUT        <= timestamp_hold_o;
  TIMESTAMP_TRIGGER_OUT     <= timestamp_trigger_o;

end Behavioral;
