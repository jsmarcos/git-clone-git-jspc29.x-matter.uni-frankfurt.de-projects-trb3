library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_status is
  port(
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
                           
    -- Monitor PLL Locks           
    PLL_NX_CLK_LOCK_IN     : in std_logic;
    PLL_ADC_DCLK_LOCK_IN   : in std_logic;
    PLL_ADC_SCLK_LOCK_IN   : in std_logic;
    PLL_RESET_OUT          : out std_logic;
    
    -- Signals             
    I2C_SM_RESET_OUT       : inout std_logic;
    I2C_REG_RESET_OUT      : out std_logic;
    NX_ONLINE_OUT          : out std_logic;
    
    -- Error
    ERROR_ALL_IN           : in  std_logic_vector(7 downto 0);
    
    -- Slave bus           
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;
                               
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_status is

  -- Offline Handler

  signal i2c_sm_reset_i_x         : std_logic;
  signal i2c_sm_reset_i           : std_logic;
  signal i2c_sm_online            : std_logic;
  signal i2c_sm_online_ctr        : unsigned(8 downto 0);

  signal offline_force            : std_logic;
  signal online_o                 : std_logic;
  signal online_trigger           : std_logic;
  signal online_last              : std_logic;

  -- Reset Handler                    
  signal i2c_sm_reset_start       : std_logic;
  signal i2c_reg_reset_start      : std_logic;
                                  
  signal i2c_sm_reset_o           : std_logic;
  signal i2c_reg_reset_o          : std_logic;

  type STATES is (S_IDLE,
                  S_I2C_SM_RESET,
                  S_I2C_SM_RESET_WAIT,
                  S_I2C_REG_RESET,
                  S_I2C_REG_RESET_WAIT
                  );
  
  signal STATE : STATES;
  
  -- Wait Timer
  signal wait_timer_start         : std_logic;
  signal wait_timer_init          : unsigned(7 downto 0);
  signal wait_timer_done          : std_logic;

  -- PLL Locks
  signal pll_nx_clk_lock          : std_logic;
  signal pll_adc_dclk_lock        : std_logic;
  signal pll_adc_sclk_lock        : std_logic;

  signal pll_nx_clk_notlock       : std_logic;
  signal pll_adc_dclk_notlock     : std_logic;
  signal pll_adc_sclk_notlock     : std_logic;
  
  signal pll_nx_clk_notlock_ctr   : unsigned(15 downto 0);
  signal pll_adc_dclk_notlock_ctr : unsigned(15 downto 0);
  signal pll_adc_sclk_notlock_ctr : unsigned(15 downto 0);

  signal clear_notlock_counters   : std_logic;
  signal pll_reset_p              : std_logic;
  signal pll_reset_o              : std_logic;
  
  -- Nxyter Data Clock
  signal nx_data_clk_dphase_o     : std_logic_vector(3 downto 0);
  signal nx_data_clk_finedelb_o   : std_logic_vector(3 downto 0);
  
  -- Slave Bus
  signal slv_data_out_o           : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o       : std_logic;
  signal slv_unknown_addr_o       : std_logic;
  signal slv_ack_o                : std_logic;
  
begin

  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= i2c_sm_reset_o;
  DEBUG_OUT(2)            <= i2c_reg_reset_o;
  DEBUG_OUT(3)            <= '0';
  DEBUG_OUT(4)            <= PLL_NX_CLK_LOCK_IN;
  DEBUG_OUT(5)            <= pll_nx_clk_lock;
  DEBUG_OUT(6)            <= PLL_ADC_DCLK_LOCK_IN;
  DEBUG_OUT(7)            <= pll_adc_dclk_lock;
  DEBUG_OUT(8)            <= PLL_ADC_SCLK_LOCK_IN;
  DEBUG_OUT(9)            <= pll_adc_sclk_lock;


  DEBUG_OUT(10)           <= i2c_sm_online;
  DEBUG_OUT(11)           <= offline_force;
  DEBUG_OUT(12)           <= online_o;
  DEBUG_OUT(13)           <= i2c_sm_reset_i;
  DEBUG_OUT(14)           <= pll_reset_o;
  DEBUG_OUT(15)           <= online_trigger;
  
  timer_1: timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN          => CLK_IN,
      RESET_IN        => RESET_IN,
      TIMER_START_IN  => wait_timer_start,
      TIMER_END_IN    => wait_timer_init,
      TIMER_DONE_OUT  => wait_timer_done
      );

  -----------------------------------------------------------------------------
  -- Offline Handler
  -----------------------------------------------------------------------------

  signal_async_trans_i2c_sm_reset_i: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => i2c_sm_reset_i_x,
      SIGNAL_OUT  => i2c_sm_reset_i
      );

  PROC_I2C_OFFLINE_SCHMITT_TRIGGER: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_sm_online       <= '0';
        i2c_sm_online_ctr   <= (others => '0');
      else
        if (i2c_sm_reset_i = '1') then
          if (i2c_sm_online_ctr < x"1ff") then
            i2c_sm_online_ctr  <= i2c_sm_online_ctr + 1;
          end if;
        else
          if (i2c_sm_online_ctr > x"000") then
            i2c_sm_online_ctr  <= i2c_sm_online_ctr - 1;
          end if;
        end if;

        if (i2c_sm_online_ctr > x"1d6") then
          i2c_sm_online        <= '1';
        elsif (i2c_sm_online_ctr < x"01e") then
          i2c_sm_online        <= '0';
        end if;
      end if;
    end if;
  end process PROC_I2C_OFFLINE_SCHMITT_TRIGGER;
  
  PROC_NXYTER_OFFLINE: process(CLK_IN)
    variable online_state : std_logic_vector(1 downto 0) := "00";
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        online_trigger    <= '0';
        online_o          <= '1';
        online_last       <= '0';
      else
        if (i2c_sm_online = '1' and
            offline_force = '0' and
            pll_nx_clk_lock = '1') then
          online_o        <= '1';
        else
          online_o        <= '0';
        end if;
        
        -- Offline State changes
        online_last       <= online_o;
        online_state      := online_o & online_last;
        
        case online_state is
          when  "01" | "10" =>
            online_trigger <= '1';

          when others =>
            online_trigger <= '0';
        end case;
      end if;
    end if;
  end process PROC_NXYTER_OFFLINE;
    
  -----------------------------------------------------------------------------
  -- I2C SM Reset
  -----------------------------------------------------------------------------

  PROC_I2C_SM_RESET: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        wait_timer_start   <= '0';
        i2c_sm_reset_o     <= '0';
        STATE              <= S_IDLE;
      else
        i2c_sm_reset_o     <= '0';
        i2c_reg_reset_o    <= '0';
        wait_timer_start   <= '0';

        case STATE is
          when S_IDLE =>
            if (i2c_sm_reset_start = '1') then
              STATE          <= S_I2C_SM_RESET;
            elsif (i2c_reg_reset_start = '1') then
              STATE          <= S_I2C_REG_RESET;
            else
              STATE          <= S_IDLE;
            end if;
            
          when S_I2C_SM_RESET =>
            i2c_sm_reset_o   <= '1';
            wait_timer_init  <= x"8f";
            wait_timer_start <= '1';
            STATE            <= S_I2C_SM_RESET_WAIT;

          when S_I2C_SM_RESET_WAIT =>
            i2c_sm_reset_o   <= '1';
            if (wait_timer_done = '0') then
              STATE          <= S_I2C_SM_RESET_WAIT;
            else
              STATE          <= S_IDLE;
            end if;

          when S_I2C_REG_RESET =>
            i2c_reg_reset_o  <= '1';
            wait_timer_init  <= x"8f";
            wait_timer_start <= '1';
            STATE            <= S_I2C_REG_RESET_WAIT;

          when S_I2C_REG_RESET_WAIT =>
            i2c_reg_reset_o  <= '1';
            if (wait_timer_done = '0') then
              STATE          <= S_I2C_REG_RESET_WAIT;
            else
              STATE          <= S_IDLE;
            end if;

        end case;
      end if;
    end if;
    
  end process PROC_I2C_SM_RESET;

  -----------------------------------------------------------------------------
  -- PLL Not Lock Counters
  -----------------------------------------------------------------------------

  signal_async_trans_1: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => PLL_NX_CLK_LOCK_IN,
      SIGNAL_OUT  => pll_nx_clk_lock
      );

  signal_async_trans_2: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => PLL_ADC_DCLK_LOCK_IN,
      SIGNAL_OUT  => pll_adc_dclk_lock
      );

  signal_async_trans_3: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      SIGNAL_A_IN => PLL_ADC_SCLK_LOCK_IN,
      SIGNAL_OUT  => pll_adc_sclk_lock
      );

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => not pll_nx_clk_lock,
      PULSE_OUT => pll_nx_clk_notlock
      );

  level_to_pulse_2: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => not pll_adc_dclk_lock,
      PULSE_OUT => pll_adc_dclk_notlock    
      );

  level_to_pulse_3: level_to_pulse
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      LEVEL_IN  => not pll_adc_sclk_lock,
      PULSE_OUT => pll_adc_sclk_notlock    
      );
  
  PROC_PLL_UNLOCK_COUNTERS: process (CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1') then
        pll_nx_clk_notlock_ctr     <= (others => '0');
        pll_adc_dclk_notlock_ctr   <= (others => '0');
        pll_adc_sclk_notlock_ctr   <= (others => '0');
      else
        if (clear_notlock_counters = '1') then
          pll_nx_clk_notlock_ctr      <= (others => '0');
          pll_adc_dclk_notlock_ctr    <= (others => '0');
          pll_adc_sclk_notlock_ctr    <= (others => '0');
        else
          if (pll_nx_clk_notlock = '1') then
            pll_nx_clk_notlock_ctr    <= pll_nx_clk_notlock_ctr + 1;
          end if;

          if (pll_adc_dclk_notlock = '1') then
            pll_adc_dclk_notlock_ctr  <= pll_adc_dclk_notlock_ctr + 1;
          end if;

          if (pll_adc_sclk_notlock = '1') then
            pll_adc_sclk_notlock_ctr  <= pll_adc_sclk_notlock_ctr + 1;
          end if;
        end if;
      end if;
    end if;
  end process PROC_PLL_UNLOCK_COUNTERS;
        
  -----------------------------------------------------------------------------
  -- Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_NX_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o             <= (others => '0');
        slv_no_more_data_o         <= '0';
        slv_unknown_addr_o         <= '0';
        slv_ack_o                  <= '0';
        i2c_sm_reset_start         <= '0';
        i2c_reg_reset_start        <= '0';
        offline_force              <= '0';
        nx_data_clk_dphase_o       <= x"7";
        nx_data_clk_finedelb_o     <= x"0";
        clear_notlock_counters     <= '0';
        pll_reset_p                <= '0';
      else                         
        slv_unknown_addr_o         <= '0';
        slv_no_more_data_o         <= '0';
        slv_data_out_o             <= (others => '0');    
        i2c_sm_reset_start         <= '0';
        i2c_reg_reset_start        <= '0';
        clear_notlock_counters     <= '0';
        pll_reset_p                <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              i2c_sm_reset_start          <= '1';
              slv_ack_o                   <= '1';

            when x"0001" =>               
              i2c_reg_reset_start         <= '1';
              slv_ack_o                   <= '1';

            when x"0002" =>               
              slv_ack_o                   <= '1';

            when x"0003" =>               
              offline_force               <= SLV_DATA_IN(0);
              slv_ack_o                   <= '1';

            when x"0006" =>               
              pll_reset_p                 <= '1';
              slv_ack_o                   <= '1';
              
            when x"000a" =>               
              clear_notlock_counters      <= '1';
              slv_ack_o                   <= '1';

            when others =>                
              slv_unknown_addr_o          <= '1';
              slv_ack_o                   <= '0';
          end case;
          
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(0)           <= i2c_sm_reset_i;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';
              
            when x"0003" =>
              slv_data_out_o(0)           <= offline_force;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0004" =>
              slv_data_out_o(0)           <= i2c_sm_online;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0005" =>
              slv_data_out_o(0)           <= online_o;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0006" =>
              slv_data_out_o(0)           <= pll_nx_clk_lock;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';
              
            when x"0007" =>
              slv_data_out_o(0)           <= pll_adc_dclk_lock;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0008" =>
              slv_data_out_o(0)           <= pll_adc_sclk_lock;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0009" =>
              slv_data_out_o(15 downto 0) <= pll_nx_clk_notlock_ctr;
              slv_data_out_o(31 downto 6) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"000a" =>
              slv_data_out_o(15 downto 0) <= pll_adc_dclk_notlock_ctr;
              slv_data_out_o(31 downto 6) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"000b" =>
              slv_data_out_o(15 downto 0) <= pll_adc_sclk_notlock_ctr;
              slv_data_out_o(31 downto 6) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"000c" =>
              slv_data_out_o(7 downto 0)  <= ERROR_ALL_IN;
              slv_data_out_o(31 downto 8) <= (others => '0');
              slv_ack_o                   <= '1';
              
            when others =>
              slv_unknown_addr_o          <= '1';
              slv_ack_o                   <= '0';
          end case;

        else
          slv_ack_o                       <= '0';
        end if;
      end if;
    end if;           
  end process PROC_NX_REGISTERS;

  -----------------------------------------------------------------------------
  pulse_to_level_1: pulse_to_level
    generic map (
      NUM_CYCLES => 15)
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => pll_reset_p,
      LEVEL_OUT => pll_reset_o
      );
  
  -- Output Signals
  i2c_sm_reset_i_x      <= I2C_SM_RESET_OUT;

  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;          

  PLL_RESET_OUT         <= pll_reset_o;
  I2C_SM_RESET_OUT      <= '0' when i2c_sm_reset_o = '1' else 'Z';
  I2C_REG_RESET_OUT     <= i2c_reg_reset_o;
  NX_ONLINE_OUT         <= online_o;
  
end Behavioral;
