library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity adc_ad9228 is
  generic (
    DEBUG_ENABLE : boolean := false
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    CLK_ADCDAT_IN        : in  std_logic;
    RESET_ADCS           : in  std_logic;    
    ADC0_SCLK_IN         : in  std_logic;  -- Sampling Clock ADC0
    ADC0_SCLK_OUT        : out std_logic;
    ADC0_DATA_A_IN       : in  std_logic;
    ADC0_DATA_B_IN       : in  std_logic;
    ADC0_DATA_C_IN       : in  std_logic;
    ADC0_DATA_D_IN       : in  std_logic;
    ADC0_DCLK_IN         : in  std_logic;  -- Data Clock from ADC0
    ADC0_FCLK_IN         : in  std_logic;  -- Frame Clock from ADC0

    ADC1_SCLK_IN         : in  std_logic;  -- Sampling Clock ADC1
    ADC1_SCLK_OUT        : out std_logic;
    ADC1_DATA_A_IN       : in  std_logic;
    ADC1_DATA_B_IN       : in  std_logic;
    ADC1_DATA_C_IN       : in  std_logic;
    ADC1_DATA_D_IN       : in  std_logic;
    ADC1_DCLK_IN         : in  std_logic;  -- Data Clock from ADC1
    ADC1_FCLK_IN         : in  std_logic;  -- Frame Clock from ADC1
    
    ADC0_DATA_A_OUT      : out std_logic_vector(11 downto 0);
    ADC0_DATA_B_OUT      : out std_logic_vector(11 downto 0);
    ADC0_DATA_C_OUT      : out std_logic_vector(11 downto 0);
    ADC0_DATA_D_OUT      : out std_logic_vector(11 downto 0);
    ADC0_DATA_CLK_OUT    : out std_logic;

    ADC1_DATA_A_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_B_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_C_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_D_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_CLK_OUT    : out std_logic;

    ADC0_LOCKED_OUT      : out std_logic;
    ADC1_LOCKED_OUT      : out std_logic;

    ADC0_SLOPPY_FRAME    : in  std_logic;
    ADC1_SLOPPY_FRAME    : in  std_logic;

    ADC0_ERROR_OUT       : out std_logic;
    ADC1_ERROR_OUT       : out std_logic;
    
    DEBUG_IN             : in  std_logic_vector(3 downto 0);
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end adc_ad9228;

architecture Behavioral of  adc_ad9228 is

  -- DDR Generic Handler
  signal DDR_DATA_CLK           : std_logic;
  signal q_0_ff                 : std_logic_vector(19 downto 0);
  signal q_0_f                  : std_logic_vector(19 downto 0);
  signal q_0                    : std_logic_vector(19 downto 0);
  signal q_1_ff                 : std_logic_vector(19 downto 0);
  signal q_1_f                  : std_logic_vector(19 downto 0);
  signal q_1                    : std_logic_vector(19 downto 0);

  -- ADC Data Handler
  signal adc0_error_status      : std_logic_vector(2 downto 0);
  signal adc1_error_status      : std_logic_vector(2 downto 0);
  signal adc0_error_status_sl   : std_logic_vector(2 downto 0);
  signal adc1_error_status_sl   : std_logic_vector(2 downto 0);

  -- Data Types
  type adc_data_t is array(0 to 3) of std_logic_vector(11 downto 0);
  
  -- Output
  signal adc0_data_clk_o        : std_logic;
  signal adc0_data_o            : adc_data_t;
  signal adc0_locked_o          : std_logic;
  signal adc0_error_o           : std_logic;
  
  signal adc1_data_clk_o        : std_logic;
  signal adc1_data_o            : adc_data_t;
  signal adc1_locked_o          : std_logic;
  signal adc1_error_o           : std_logic;
  
  -- RESET Handler
  type R_STATES is (R_IDLE,
                    R_WAIT_CLKDIV,
                    R_WAIT_RESET_ADC,
                    R_WAIT_RESET_END
                    );
  signal R_STATE : R_STATES;

  signal startup_reset          : std_logic;
  signal timer_reset            : std_logic;
  signal wait_timer_start       : std_logic;
  signal wait_timer_done        : std_logic;
  signal RESET_CLKDIV           : std_logic;
  signal RESET_ADC0             : std_logic;
  signal RESET_ADC1             : std_logic;
  
  -- 
  attribute syn_keep : boolean;

  attribute syn_keep of q_0_ff                 : signal is true;
  attribute syn_keep of q_0_f                  : signal is true;
  attribute syn_keep of q_1_ff                 : signal is true;
  attribute syn_keep of q_1_f                  : signal is true;
                                               
  attribute syn_preserve : boolean;
  
  attribute syn_preserve of q_0_ff             : signal is true;
  attribute syn_preserve of q_0_f              : signal is true;
  attribute syn_preserve of q_1_ff             : signal is true;
  attribute syn_preserve of q_1_f              : signal is true;
                                               
begin

  -----------------------------------------------------------------------------
  -- Debug Handler
  -----------------------------------------------------------------------------

  DFALSE: if (DEBUG_ENABLE = false) generate
    DEBUG_OUT               <= (others => '0');
    --DEBUG_OUT(0)            <= CLK_IN;
    --DEBUG_OUT(1)            <= DDR_DATA_CLK;
    --DEBUG_OUT(2)            <= adc0_write_enable;
    --DEBUG_OUT(3)            <= adc0_fifo_full;
    --DEBUG_OUT(4)            <= adc0_fifo_empty;
    --DEBUG_OUT(5)            <= adc0_data_clk_m;
    --DEBUG_OUT(6)            <= adc0_read_enable;
    --DEBUG_OUT(7)            <= adc0_read_enable_t;
    --DEBUG_OUT(8)            <= adc0_read_enable_tt;
    --DEBUG_OUT(9)            <= adc0_data_clk_o;
    --DEBUG_OUT(10)           <= adc0_error;
    --DEBUG_OUT(11)           <= adc0_frame_locked;
    --DEBUG_OUT(12)           <= adc0_frame_clk_ok;
    --DEBUG_OUT(13)           <= wait_timer_done;
    --DEBUG_OUT(14)           <= RESET_CLKDIV;
    --DEBUG_OUT(15)           <= RESET_ADC0;
  end generate DFALSE;

  DTRUE: if (DEBUG_ENABLE = true) generate
    
    PROC_DEBUG: process (DEBUG_IN)
    begin
      DEBUG_OUT(0)                <= CLK_IN;
      DEBUG_OUT(1)                <= DDR_DATA_CLK;

      case DEBUG_IN is
        
        when others =>
          DEBUG_OUT(15 downto 2)  <= (others => '0');

      end case;
    end process PROC_DEBUG;       

  end generate DTRUE;

  -----------------------------------------------------------------------------
  -- DDR Generic Interface to ADC
  -----------------------------------------------------------------------------
  adc_ddr_generic_1: entity work.adc_ddr_generic
    port map (
      clk_0          => ADC0_DCLK_IN,
      clk_1          => ADC1_DCLK_IN,
      clkdiv_reset   => RESET_CLKDIV,
      eclk           => CLK_ADCDAT_IN,
      reset_0        => RESET_ADC0,
      reset_1        => RESET_ADC1,
      sclk           => DDR_DATA_CLK,
      
      datain_0(0)    => ADC0_DATA_A_IN,
      datain_0(1)    => ADC0_DATA_B_IN,
      datain_0(2)    => ADC0_DATA_C_IN,
      datain_0(3)    => ADC0_DATA_D_IN,
      datain_0(4)    => ADC0_FCLK_IN,
      
      datain_1(0)    => ADC1_DATA_A_IN,
      datain_1(1)    => ADC1_DATA_B_IN,
      datain_1(2)    => ADC1_DATA_C_IN,
      datain_1(3)    => ADC1_DATA_D_IN,
      datain_1(4)    => ADC1_FCLK_IN,
      
      q_0            => q_0_ff,
      q_1            => q_1_ff
      );
  
  -- Two FIFOs to relaxe timing
  q_0_f   <= q_0_ff when rising_edge(DDR_DATA_CLK);
  q_0     <= q_0_f  when rising_edge(DDR_DATA_CLK);

  q_1_f   <= q_1_ff when rising_edge(DDR_DATA_CLK);
  q_1     <= q_1_f  when rising_edge(DDR_DATA_CLK);

  -- The ADC Data Handlers
  adc_ad9228_data_handler_1: entity work.adc_ad9228_data_handler
    generic map (
      DEBUG_ENABLE => DEBUG_ENABLE
      )
    port map (
      CLK_IN              => CLK_IN,
      RESET_IN            => RESET_ADC0,
      DDR_DATA_CLK        => DDR_DATA_CLK,
      DDR_DATA_IN         => q_0,
      DATA_A_OUT          => adc0_data_o(0), 
      DATA_B_OUT          => adc0_data_o(1),
      DATA_C_OUT          => adc0_data_o(2),
      DATA_D_OUT          => adc0_data_o(3),
      DATA_CLK_OUT        => adc0_data_clk_o,
      SLOPPY_FRAME_IN     => ADC0_SLOPPY_FRAME,
      FRAME_LOCKED_OUT    => adc0_locked_o,
      ERROR_STATUS_OUT    => adc0_error_status,
      ERROR_STATUS_SL_OUT => adc0_error_status_sl,
      DEBUG_OUT           => open
      );

  adc_ad9228_data_handler_2: entity work.adc_ad9228_data_handler
    generic map (
      DEBUG_ENABLE => DEBUG_ENABLE
      )
    port map (
      CLK_IN              => CLK_IN,
      RESET_IN            => RESET_ADC1,
      DDR_DATA_CLK        => DDR_DATA_CLK,
      DDR_DATA_IN         => q_1,
      DATA_A_OUT          => adc1_data_o(0), 
      DATA_B_OUT          => adc1_data_o(1),
      DATA_C_OUT          => adc1_data_o(2),
      DATA_D_OUT          => adc1_data_o(3),
      DATA_CLK_OUT        => adc1_data_clk_o,
      SLOPPY_FRAME_IN     => ADC1_SLOPPY_FRAME,
      FRAME_LOCKED_OUT    => adc1_locked_o,
      ERROR_STATUS_OUT    => open, --ERROR_STATUS_OUT,
      ERROR_STATUS_SL_OUT => open, --ERROR_STATUS_OUT,
      DEBUG_OUT           => open
      );

  -----------------------------------------------------------------------------
  -- Error Status Handler
  -----------------------------------------------------------------------------
  PROC_ERROR_STATUS: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then 
      if (RESET_IN = '1') then
        adc0_error_o       <= '0';
        adc1_error_o       <= '0';
      else
        adc0_error_o       <= '0';
        adc1_error_o       <= '0';
        
        if (adc0_error_status /= "000" or
            (ADC0_SLOPPY_FRAME = '1' and adc0_error_status_sl /= "000")) then
          adc0_error_o     <= '1';
        end if;

        if (adc1_error_status /= "000" or
            (ADC1_SLOPPY_FRAME = '1' and adc1_error_status_sl /= "000")) then
          adc1_error_o     <= '1';
        end if;
      end if;
    end if;
  end process PROC_ERROR_STATUS;
  
  -----------------------------------------------------------------------------
  -- Reset Handler
  -----------------------------------------------------------------------------
  
  timer_static_RESET_TIMER: timer_static
    generic map (
      CTR_WIDTH => 20,
      CTR_END   => 625000 -- 5ms
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => timer_reset,
      TIMER_START_IN => wait_timer_start,
      TIMER_DONE_OUT => wait_timer_done
      );
  
  PROC_DDR_RESET_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        RESET_CLKDIV      <= '0';
        RESET_ADC0        <= '0';
        RESET_ADC1        <= '0';
        wait_timer_start  <= '0';
        timer_reset       <= '1';
        R_STATE           <= R_IDLE; 
      else
        RESET_CLKDIV      <= '0';
        RESET_ADC0        <= '0';
        RESET_ADC1        <= '0';
        wait_timer_start  <= '0';
        timer_reset       <= '0';
        
        case R_STATE is
          when R_IDLE =>
            if (RESET_ADCS = '1') then
              -- Start Reset
              RESET_CLKDIV      <= '1';
              RESET_ADC0        <= '1';
              RESET_ADC1        <= '1';
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_CLKDIV;
            else
              timer_reset       <= '1';
              R_STATE           <= R_IDLE;
            end if;

          when R_WAIT_CLKDIV =>
            if (wait_timer_done = '0') then
              RESET_CLKDIV      <= '1';
              RESET_ADC0        <= '1';
              RESET_ADC1        <= '1';
              R_STATE           <= R_WAIT_CLKDIV;
            else
              -- Release RESET_CLKDIV
              RESET_ADC0        <= '1';
              RESET_ADC1        <= '1';
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_RESET_ADC;
            end if;

          when R_WAIT_RESET_ADC =>
            if (wait_timer_done = '0') then
              RESET_ADC0        <= '1';
              RESET_ADC1        <= '1';
              R_STATE           <= R_WAIT_RESET_ADC;
            else
              -- Release reset_adc
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_RESET_END;
            end if; 

          when R_WAIT_RESET_END =>
            if (wait_timer_done = '0') then
              R_STATE           <= R_WAIT_RESET_END;
            else
              R_STATE           <= R_IDLE;
            end if;  
        end case;
      end if;
    end if;
  end process PROC_DDR_RESET_HANDLER;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  ADC0_SCLK_OUT        <= ADC0_SCLK_IN;
  ADC1_SCLK_OUT        <= ADC1_SCLK_IN;
  
  ADC0_DATA_A_OUT      <= adc0_data_o(0);
  ADC0_DATA_B_OUT      <= adc0_data_o(1);
  ADC0_DATA_C_OUT      <= adc0_data_o(2);
  ADC0_DATA_D_OUT      <= adc0_data_o(3);
  ADC0_DATA_CLK_OUT    <= adc0_data_clk_o;

  ADC1_DATA_A_OUT      <= adc1_data_o(0);
  ADC1_DATA_B_OUT      <= adc1_data_o(1);
  ADC1_DATA_C_OUT      <= adc1_data_o(2);
  ADC1_DATA_D_OUT      <= adc1_data_o(3);
  ADC1_DATA_CLK_OUT    <= adc1_data_clk_o;

  ADC0_LOCKED_OUT      <= adc0_locked_o;
  ADC1_LOCKED_OUT      <= adc1_locked_o;

  ADC0_ERROR_OUT        <= adc0_error_o;
  ADC1_ERROR_OUT        <= adc1_error_o; 

end Behavioral;
