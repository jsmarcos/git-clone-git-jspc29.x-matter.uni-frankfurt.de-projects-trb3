library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_control is
  port(
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
                           
    -- Monitor PLL Locks           
    PLL_NX_CLK_LOCK_IN     : in std_logic;
    PLL_ADC_DCLK_LOCK_IN   : in std_logic;
    PLL_ADC_SCLK_LOCK_IN   : in std_logic;

    -- Signals             
    I2C_SM_RESET_OUT       : out std_logic;
    I2C_REG_RESET_OUT      : out std_logic;
    NX_TS_RESET_OUT        : out std_logic;
    I2C_OFFLINE_IN         : in  std_logic;
    OFFLINE_OUT            : out std_logic;
        
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

architecture Behavioral of nx_control is

  -- Offline Handler
  signal offline_force_internal   : std_logic;
  signal offline_force            : std_logic;
  signal offline_o                : std_logic;
  signal offline_on               : std_logic;
  signal online_on                : std_logic;
  signal offline_last             : std_logic;
                                  
  -- I2C Reset                    
  signal i2c_sm_reset_start       : std_logic;
  signal i2c_reg_reset_start      : std_logic;
  signal nx_ts_reset_start        : std_logic;
                                  
  signal i2c_sm_reset_o           : std_logic;
  signal i2c_reg_reset_o          : std_logic;
  signal nx_ts_reset_o            : std_logic;


  type STATES is (S_IDLE,
                  S_I2C_SM_RESET,
                  S_I2C_SM_RESET_WAIT,
                  S_I2C_REG_RESET,
                  S_I2C_REG_RESET_WAIT,
                  S_NX_TS_RESET,
                  S_NX_TS_RESET_WAIT
                  );
  
  signal STATE : STATES;
  
  -- Wait Timer
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
  DEBUG_OUT(3)            <= nx_ts_reset_o;
  DEBUG_OUT(4)            <= PLL_NX_CLK_LOCK_IN;
  DEBUG_OUT(5)            <= pll_nx_clk_lock;
  DEBUG_OUT(6)            <= PLL_ADC_DCLK_LOCK_IN;
  DEBUG_OUT(7)            <= pll_adc_dclk_lock;
  DEBUG_OUT(8)            <= PLL_ADC_SCLK_LOCK_IN;
  DEBUG_OUT(9)            <= pll_adc_sclk_lock;


  DEBUG_OUT(10)           <= I2C_OFFLINE_IN;
  DEBUG_OUT(11)           <= offline_force;
  DEBUG_OUT(12)           <= offline_force_internal;
  DEBUG_OUT(13)           <= offline_o;
  DEBUG_OUT(14)           <= online_on;
  DEBUG_OUT(15)           <= '0';
  
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 8
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  -----------------------------------------------------------------------------
  -- Offline Handler
  -----------------------------------------------------------------------------

  offline_force_internal <= '0';

  PROC_NXYTER_OFFLINE: process(CLK_IN)
    variable offline_state : std_logic_vector(1 downto 0) := "00";
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        offline_on         <= '0';
        online_on          <= '0';
        offline_o          <= '1';
        offline_last       <= '0';
      else
        if (offline_force = '1' or offline_force_internal = '1') then
          offline_o        <= '1';
        else
          offline_o        <= I2C_OFFLINE_IN;
        end if;
        
        -- Offline State changes
        offline_on         <= '0';
        online_on          <= '0';
        offline_last       <= offline_o;
        offline_state      := offline_o & offline_last;
        
        case offline_state is
          when  "01" =>
            offline_on     <= '1';
            
          when  "10" =>
            online_on      <= '0';

          when others => null;
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
        wait_timer_init    <= (others => '0');
        i2c_sm_reset_o     <= '0';
        i2c_reg_reset_o    <= '0';
        nx_ts_reset_o      <= '0';
        STATE              <= S_IDLE;
      else
        i2c_sm_reset_o     <= '0';
        i2c_reg_reset_o    <= '0';
        nx_ts_reset_o      <= '0';
        wait_timer_init    <= (others => '0');
        
        case STATE is
          when S_IDLE =>
            if (i2c_sm_reset_start = '1') then
              STATE          <= S_I2C_SM_RESET;
            elsif (i2c_reg_reset_start = '1') then
              STATE          <= S_I2C_REG_RESET;
            elsif (nx_ts_reset_start = '1') then
              STATE          <= S_NX_TS_RESET;
            else
              STATE          <= S_IDLE;
            end if;
            
          when S_I2C_SM_RESET =>
            i2c_sm_reset_o   <= '1';
            wait_timer_init  <= x"8f";
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
            STATE            <= S_I2C_REG_RESET_WAIT;

          when S_I2C_REG_RESET_WAIT =>
            i2c_reg_reset_o  <= '1';
            if (wait_timer_done = '0') then
              STATE          <= S_I2C_REG_RESET_WAIT;
            else
              STATE          <= S_IDLE;
            end if;

          when S_NX_TS_RESET =>
            nx_ts_reset_o    <= '1';
            wait_timer_init  <= x"01";
            STATE            <= S_NX_TS_RESET_WAIT;

          when S_NX_TS_RESET_WAIT =>
            nx_ts_reset_o    <= '1';
            if (wait_timer_done = '0') then
              STATE          <= S_NX_TS_RESET_WAIT;
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
      RESET_IN    => RESET_IN,
      SIGNAL_A_IN => PLL_NX_CLK_LOCK_IN,
      SIGNAL_OUT  => pll_nx_clk_lock
      );

  signal_async_trans_2: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      RESET_IN    => RESET_IN,
      SIGNAL_A_IN => PLL_ADC_DCLK_LOCK_IN,
      SIGNAL_OUT  => pll_adc_dclk_lock
      );

  signal_async_trans_3: signal_async_trans
    port map (
      CLK_IN      => CLK_IN,
      RESET_IN    => RESET_IN,
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
      if( RESET_IN = '1' or clear_notlock_counters = '1') then
        pll_nx_clk_notlock_ctr    <= (others => '0');
        pll_adc_dclk_notlock_ctr   <= (others => '0');
        pll_adc_sclk_notlock_ctr   <= (others => '0');
      else
        if (pll_nx_clk_notlock = '1') then
          pll_nx_clk_notlock_ctr  <= pll_nx_clk_notlock_ctr + 1;
        end if;

        if (pll_adc_dclk_notlock = '1') then
         pll_adc_dclk_notlock_ctr  <= pll_adc_dclk_notlock_ctr + 1;
        end if;

        if (pll_adc_sclk_notlock = '1') then
         pll_adc_sclk_notlock_ctr  <= pll_adc_sclk_notlock_ctr + 1;
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
        nx_ts_reset_start          <= '0';
        offline_force              <= '0';
        nx_data_clk_dphase_o       <= x"7";
        nx_data_clk_finedelb_o     <= x"0";
        clear_notlock_counters     <= '0';
      else                         
        slv_unknown_addr_o         <= '0';
        slv_no_more_data_o         <= '0';
        slv_data_out_o             <= (others => '0');    
        i2c_sm_reset_start         <= '0';
        i2c_reg_reset_start        <= '0';
        nx_ts_reset_start          <= '0';
        clear_notlock_counters     <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              i2c_sm_reset_start          <= '1';
              slv_ack_o                   <= '1';

            when x"0001" =>               
              i2c_reg_reset_start         <= '1';
              slv_ack_o                   <= '1';

            when x"0002" =>               
              nx_ts_reset_start           <= '1';
              slv_ack_o                   <= '1';

            when x"0003" =>               
              offline_force               <= SLV_DATA_IN(0);
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
            when x"0003" =>
              slv_data_out_o(0)           <= offline_force;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0004" =>
              slv_data_out_o(0)           <= I2C_OFFLINE_IN;
              slv_data_out_o(31 downto 1) <= (others => '0');
              slv_ack_o                   <= '1';

            when x"0005" =>
              slv_data_out_o(0)           <= offline_o;
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

  -- Output Signals
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o;          
  
  I2C_SM_RESET_OUT     <= i2c_sm_reset_o;
  I2C_REG_RESET_OUT    <= i2c_reg_reset_o;
  NX_TS_RESET_OUT      <= nx_ts_reset_o;
  OFFLINE_OUT          <= offline_o;

end Behavioral;
