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

    ERROR_ADC0_OUT       : out std_logic;
    ERROR_ADC1_OUT       : out std_logic;
    ERROR_UNDEF_ADC0_OUT : out std_logic;
    ERROR_UNDEF_ADC1_OUT : out std_logic;
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

  -- Merge Data
  type adc_data_s       is array(0 to 4) of std_logic_vector(13 downto 0);
  type adc_data_t       is array(0 to 3) of std_logic_vector(11 downto 0);

  type BYTE_STATUS is (B_UNDEF,
                       B_BITSHIFTED,
                       B_ALIGNED,
                       B_SHIFTED
                       );
  -- ADC0
  signal adc0_data_shift        : adc_data_s;
  
  signal adc0_data_m            : adc_data_t;
  signal adc0_data_clk_m        : std_logic;

  signal adc0_byte_status       : BYTE_STATUS;
  signal adc0_byte_status_last  : BYTE_STATUS;

  signal adc0_frame_clk_ok      : std_logic;
  signal adc0_frame_clk_ok_hist : std_logic_vector(15 downto 0);
  signal adc0_frame_locked      : std_logic;
  signal adc0_error             : std_logic;
  signal adc0_error_undef       : std_logic;

  -- ADC0
  signal adc1_data_shift        : adc_data_s;
  
  signal adc1_data_m            : adc_data_t;
  signal adc1_data_clk_m        : std_logic;

  signal adc1_byte_status       : BYTE_STATUS;
  signal adc1_byte_status_last  : BYTE_STATUS;

  signal adc1_frame_clk_ok      : std_logic;
  signal adc1_frame_clk_ok_hist : std_logic_vector(15 downto 0);
  signal adc1_frame_locked      : std_logic;
  signal adc1_error             : std_logic;
  signal adc1_error_undef       : std_logic;

  -- Clock Transfer             
  signal adc0_fifo_empty        :  std_logic;
  signal adc0_fifo_full         :  std_logic;
  signal adc0_write_enable      :  std_logic;
  signal adc0_read_enable       :  std_logic;
  signal adc0_read_enable_t     :  std_logic;
  signal adc0_read_enable_tt    :  std_logic;
  signal adc0_locked_ff         : std_logic;
  signal adc0_locked_f          : std_logic;
  signal adc0_locked_o          : std_logic;
  
  signal adc1_fifo_empty        :  std_logic;
  signal adc1_fifo_full         :  std_logic;
  signal adc1_write_enable      :  std_logic;
  signal adc1_read_enable       :  std_logic;
  signal adc1_read_enable_t     :  std_logic;
  signal adc1_read_enable_tt    :  std_logic;
  signal adc1_locked_ff         : std_logic;
  signal adc1_locked_f          : std_logic;
  signal adc1_locked_o          : std_logic;
  
  -- Error
  signal error_adc0_o           : std_logic;
  signal error_adc1_o           : std_logic;
  signal error_undef_adc0_o     : std_logic;
  signal error_undef_adc1_o     : std_logic;

  -- Output
  signal adc0_data_clk_o        : std_logic;
  signal adc0_data_f            : adc_data_t;
  signal adc0_data_o            : adc_data_t;
                                
  signal adc1_data_clk_o        : std_logic;
  signal adc1_data_f            : adc_data_t;
  signal adc1_data_o            : adc_data_t;

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

  signal RESET_ADC0_CLKD_F      : std_logic;
  signal RESET_ADC0_CLKD        : std_logic;
  signal RESET_ADC1_CLKD_F      : std_logic;
  signal RESET_ADC1_CLKD        : std_logic;
  
  -- 
  attribute syn_keep : boolean;
  attribute syn_keep of q_0_ff              : signal is true;
  attribute syn_keep of q_0_f               : signal is true;
  attribute syn_keep of q_1_ff              : signal is true;
  attribute syn_keep of q_1_f               : signal is true;

  attribute syn_keep of adc0_locked_ff      : signal is true;
  attribute syn_keep of adc0_locked_f       : signal is true;
  attribute syn_keep of adc1_locked_ff      : signal is true;
  attribute syn_keep of adc1_locked_f       : signal is true;

  attribute syn_keep of RESET_ADC0_CLKD_F   : signal is true;
  attribute syn_keep of RESET_ADC0_CLKD     : signal is true;
  attribute syn_keep of RESET_ADC1_CLKD_F   : signal is true;
  attribute syn_keep of RESET_ADC1_CLKD     : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of q_0_ff          : signal is true;
  attribute syn_preserve of q_0_f           : signal is true;
  attribute syn_preserve of q_1_ff          : signal is true;
  attribute syn_preserve of q_1_f           : signal is true;
  
  attribute syn_preserve of adc0_locked_ff  : signal is true;
  attribute syn_preserve of adc0_locked_f   : signal is true;
  attribute syn_preserve of adc1_locked_ff  : signal is true;
  attribute syn_preserve of adc1_locked_f   : signal is true;

  attribute syn_preserve of RESET_ADC0_CLKD_F : signal is true;
  attribute syn_preserve of RESET_ADC0_CLKD   : signal is true;
  attribute syn_preserve of RESET_ADC1_CLKD_F : signal is true;
  attribute syn_preserve of RESET_ADC1_CLKD   : signal is true;

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
      DEBUG_OUT(0)            <= CLK_IN;
      DEBUG_OUT(1)            <= DDR_DATA_CLK;

      case DEBUG_IN is
        
        when x"1" =>
          DEBUG_OUT(15 downto 2)  <= adc0_data_shift(0);

        when x"2" =>
          DEBUG_OUT(15 downto 2)  <= adc0_data_shift(1);

        when x"3" =>
          DEBUG_OUT(15 downto 2)  <= adc0_data_shift(2);

        when x"4" =>
          DEBUG_OUT(15 downto 2)  <= adc0_data_shift(3);

        when x"5" =>
          DEBUG_OUT(15 downto 2)  <= adc0_data_shift(4);
          
        when others =>
          -- DEBUG
          DEBUG_OUT(2)            <= adc0_write_enable;
          DEBUG_OUT(3)            <= adc0_fifo_full;
          DEBUG_OUT(4)            <= adc0_fifo_empty;
          DEBUG_OUT(5)            <= adc0_data_clk_m;
          DEBUG_OUT(6)            <= adc0_read_enable;
          DEBUG_OUT(7)            <= adc0_read_enable_t;
          DEBUG_OUT(8)            <= adc0_read_enable_tt;
          DEBUG_OUT(9)            <= adc0_data_clk_o;
          DEBUG_OUT(10)           <= adc0_error;
          DEBUG_OUT(11)           <= adc0_frame_locked;
          DEBUG_OUT(12)           <= adc0_frame_clk_ok;
          DEBUG_OUT(13)           <= wait_timer_done;
          DEBUG_OUT(14)           <= RESET_CLKDIV;
          DEBUG_OUT(15)           <= RESET_ADC0;
          
      end case;
    end process PROC_DEBUG;       

  end generate DTRUE;

  -----------------------------------------------------------------------------

  RESET_ADC0_CLKD_F  <= RESET_ADC0        when rising_edge(DDR_DATA_CLK);
  RESET_ADC0_CLKD    <= RESET_ADC0_CLKD_F when rising_edge(DDR_DATA_CLK);
  
  RESET_ADC1_CLKD_F  <= RESET_ADC1        when rising_edge(DDR_DATA_CLK);
  RESET_ADC1_CLKD    <= RESET_ADC1_CLKD_F when rising_edge(DDR_DATA_CLK);

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
        RESET_CLKDIV      <= '1';
        RESET_ADC0        <= '1';
        RESET_ADC1        <= '1';
        wait_timer_start  <= '0';
        timer_reset       <= '1';
        startup_reset     <= '1';
        R_STATE           <= R_IDLE; 
      else
        RESET_CLKDIV      <= '0';
        RESET_ADC0        <= '0';
        RESET_ADC1        <= '0';
        wait_timer_start  <= '0';
        timer_reset       <= '0';
        startup_reset     <= '0';
          
        case R_STATE is
          when R_IDLE =>
            if (startup_reset = '1') then
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

  -- Two Input FIFOs to relaxe timing
  q_0_f   <= q_0_ff when rising_edge(DDR_DATA_CLK);
  q_0     <= q_0_f  when rising_edge(DDR_DATA_CLK);

  q_1_f   <= q_1_ff when rising_edge(DDR_DATA_CLK);
  q_1     <= q_1_f  when rising_edge(DDR_DATA_CLK);
  
  -----------------------------------------------------------------------------

  PROC_MERGE_DATA_ADC0: process(DDR_DATA_CLK)
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      if (RESET_ADC0_CLKD = '1') then 
        for I in 0 to 4 loop
          adc0_data_shift(I)         <= (others => '0');
        end loop;

        for I in 0 to 3 loop
          adc0_data_m(I)             <= (others => '0');
        end loop;                  
        adc0_data_clk_m            <= '0';
        
        adc0_byte_status           <= B_UNDEF;
        adc0_byte_status_last      <= B_UNDEF;
        adc0_frame_clk_ok          <= '0';
        adc0_frame_clk_ok_hist     <= (others => '0');
        adc0_frame_locked          <= '0';
        adc0_error                 <= '0';
        adc0_error_undef           <= '0';
      else
        -- Store new incoming Data in Shift Registers
        for I in 0 to 4 loop
          adc0_data_shift(I)(3)            <= q_0(I + 0);
          adc0_data_shift(I)(2)            <= q_0(I + 5);
          adc0_data_shift(I)(1)            <= q_0(I + 10);
          adc0_data_shift(I)(0)            <= q_0(I + 15);
          adc0_data_shift(I)(13 downto  4) <= adc0_data_shift(I)(9 downto 0);
        end loop;
        
        -- Check Frame Lock and valid Status, Index 4 is THE Frame Clock
        case adc0_data_shift(4)(11 downto 0) is
          when "111111000000" =>
            -- Input Data is correct and new Frame is available
            for I in 0 to 3 loop
              adc0_data_m(I)            <= adc0_data_shift(I)(11 downto 0);
            end loop;
            adc0_data_clk_m             <= '1';
            adc0_frame_clk_ok           <= '1';
            adc0_byte_status            <= B_ALIGNED;
            
          when "111100000011" =>
            -- Input Data is correct and new Frame is available,
            -- but byte shifted by one
            for I in 0 to 3 loop
              adc0_data_m(I)            <= adc0_data_shift(I)(13 downto 2);
            end loop;
            adc0_data_clk_m             <= '1';
            adc0_frame_clk_ok           <= '1';
            adc0_byte_status            <= B_SHIFTED;

          when "110000001111" | "000011111100"    =>
            -- Input Data is correct
            adc0_data_clk_m             <= '0';
            adc0_frame_clk_ok           <= '1';
            adc0_byte_status            <= B_ALIGNED;

          when "000000111111" | "001111110000" =>
            -- Input Data is correct
            adc0_data_clk_m             <= '0';
            adc0_frame_clk_ok           <= '1';
            adc0_byte_status            <= B_SHIFTED;

          when "000001111110" |
               "000111111000" |
               "011111100000" |
               "111110000001" |
               "111000000111" |
               "100000011111" =>
            adc0_data_clk_m             <= '0';
            adc0_frame_clk_ok           <= '0';
            adc0_byte_status            <= B_BITSHIFTED;
                        
          when others =>
            -- Input Data is invalid, Fatal Error of DDR Data, needs reset.
            adc0_data_clk_m             <= '0';
            adc0_frame_clk_ok           <= '0';
            adc0_byte_status            <= B_UNDEF;
            
        end case;

        -- Determin ADC Frame Lock Status
        adc0_frame_clk_ok_hist(0)           <= adc0_frame_clk_ok;
        adc0_frame_clk_ok_hist(15 downto 1) <=
          adc0_frame_clk_ok_hist(14 downto 0);
        
        if (adc0_frame_clk_ok_hist = x"ffff") then
          adc0_frame_locked             <= '1';
        else
          adc0_frame_locked             <= '0';
        end if;
        
        -- Error Status
        adc0_byte_status_last           <= adc0_byte_status;
        --if (adc0_byte_status  /= adc0_byte_status_last and
        --    adc0_byte_status  /= B_UNDEF and
        --    adc0_byte_status_last /= B_UNDEF) then
        if (adc0_byte_status = B_BITSHIFTED) then
          adc0_error                    <= '1';
        else
          adc0_error                    <= '0';
        end if;

        if (adc0_byte_status = B_UNDEF) then
          adc0_error_undef              <= '1';
        else
          adc0_error_undef              <= '0';
        end if;

      end if;

    end if;
  end process PROC_MERGE_DATA_ADC0;

  -----------------------------------------------------------------------------

  PROC_MERGE_DATA_ADC1: process(DDR_DATA_CLK)
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      if (RESET_ADC1_CLKD = '1') then
        for I in 0 to 4 loop
          adc1_data_shift(I)         <= (others => '0');
        end loop;

        for I in 0 to 3 loop
          adc1_data_m(I)             <= (others => '0');
        end loop;                  
        adc1_data_clk_m            <= '0';
        
        adc1_byte_status           <= B_UNDEF;
        adc1_byte_status_last      <= B_UNDEF;
        adc1_frame_clk_ok          <= '0';
        adc1_frame_clk_ok_hist     <= (others => '0');
        adc1_frame_locked          <= '0';
        adc1_error                 <= '0';
      else

        -- Store new incoming Data in Shift Registers
        for I in 0 to 4 loop
          adc1_data_shift(I)(3)         <= q_1(I + 0);
          adc1_data_shift(I)(2)         <= q_1(I + 5);
          adc1_data_shift(I)(1)         <= q_1(I + 10);
          adc1_data_shift(I)(0)         <= q_1(I + 15);
          
          adc1_data_shift(I)(13 downto  4) <= adc1_data_shift(I)(9 downto 0);
        end loop;

        -- Check Frame Lock and valid Status, Index 4 is THE Frame Clock
        case adc1_data_shift(4)(11 downto 0) is
          when "111111000000" =>
            -- Input Data is correct and new Frame is available
            for I in 0 to 3 loop
              adc1_data_m(I)            <= adc1_data_shift(I)(11 downto 0);
            end loop;
            adc1_data_clk_m             <= '1';
            adc1_frame_clk_ok           <= '1';
            adc1_byte_status            <= B_ALIGNED;
            
          when "111100000011" =>
            -- Input Data is correct and new Frame is available,
            -- but byte shifted by one
            for I in 0 to 3 loop
              adc1_data_m(I)            <= adc1_data_shift(I)(13 downto 2);
            end loop;
            adc1_data_clk_m             <= '1';
            adc1_frame_clk_ok           <= '1';
            adc1_byte_status            <= B_SHIFTED;

          when "110000001111" | "000011111100"    =>
            -- Input Data is correct
            adc1_data_clk_m             <= '0';
            adc1_frame_clk_ok           <= '1';
            adc1_byte_status            <= B_ALIGNED;
            
          when "000000111111" | "001111110000" =>
            -- Input Data is correct
            adc1_data_clk_m             <= '0';
            adc1_frame_clk_ok           <= '1';
            adc1_byte_status            <= B_SHIFTED;
            
          when others =>
            -- Input Data is invalid, Fatal Error of DDR Data, needs reset.
            adc1_data_clk_m             <= '0';
            adc1_frame_clk_ok           <= '0';
            adc1_byte_status            <= B_UNDEF;
            
        end case;

        -- Determin ADC Frame Lock Status
        adc1_frame_clk_ok_hist(0)           <= adc1_frame_clk_ok;
        adc1_frame_clk_ok_hist(15 downto 1) <=
          adc1_frame_clk_ok_hist(14 downto 0);
        
        if (adc1_frame_clk_ok_hist = x"ffff") then
          adc1_frame_locked             <= '1';
        else
          adc1_frame_locked             <= '0';
        end if;
        
        -- Error Status
        adc1_byte_status_last           <= adc1_byte_status;
        if (adc1_byte_status  /= adc1_byte_status_last) then
          adc1_error                    <= '1';
        else
          adc1_error                    <= '0';
        end if;

        if (adc1_byte_status = B_UNDEF) then
          adc1_error_undef              <= '1';
        else
          adc1_error_undef              <= '0';
        end if; 

      end if;
    end if;
  end process PROC_MERGE_DATA_ADC1;
  
  
  -----------------------------------------------------------------------------
  -- Tansfer to CLK_IN
  -----------------------------------------------------------------------------

  fifo_adc_48to48_dc_1: entity work.fifo_adc_48to48_dc
    port map (
      Data(11 downto 0)  => adc0_data_m(0),
      Data(23 downto 12) => adc0_data_m(1),
      Data(35 downto 24) => adc0_data_m(2),
      Data(47 downto 36) => adc0_data_m(3),
      WrClock            => DDR_DATA_CLK,
      RdClock            => CLK_IN,
      WrEn               => adc0_write_enable,
      RdEn               => adc0_read_enable,
      Reset              => RESET_ADC0_CLKD,
      RPReset            => RESET_ADC0,
      Q(11 downto 0)     => adc0_data_f(0),
      Q(23 downto 12)    => adc0_data_f(1),
      Q(35 downto 24)    => adc0_data_f(2),
      Q(47 downto 36)    => adc0_data_f(3),
      Empty              => adc0_fifo_empty,
      Full               => adc0_fifo_full
      );
    
  -- Readout Handler
  adc0_write_enable    <= adc0_data_clk_m and not adc0_fifo_full;
  adc0_read_enable     <= not adc0_fifo_empty;
  
  PROC_ADC0_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      adc0_read_enable_t     <= adc0_read_enable;
      if (RESET_ADC0_CLKD = '1') then
        adc0_read_enable_tt  <= '0';
        for I in 0 to 3 loop
          adc0_data_o(I)     <= (others => '0');
        end loop; 
        adc0_data_clk_o      <= '0';
      else
        -- Read enable
        adc0_read_enable_tt  <= adc0_read_enable_t;
        
        if (adc0_read_enable_tt = '1') then
          for I in 0 to 3 loop
            adc0_data_o(I)   <= adc0_data_f(I); 
          end loop;
          adc0_data_clk_o    <= '1';
        else
          adc0_data_clk_o    <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC0_FIFO_READ;

  -----------------------------------------------------------------------------

  fifo_adc_48to48_dc_2: entity work.fifo_adc_48to48_dc
    port map (
      Data(11 downto 0)  => adc1_data_m(0),
      Data(23 downto 12) => adc1_data_m(1),
      Data(35 downto 24) => adc1_data_m(2),
      Data(47 downto 36) => adc1_data_m(3),
      WrClock            => DDR_DATA_CLK,
      RdClock            => CLK_IN,
      WrEn               => adc1_write_enable,
      RdEn               => adc1_read_enable,
      Reset              => RESET_ADC1_CLKD,
      RPReset            => RESET_ADC1,
      Q(11 downto 0)     => adc1_data_f(0),
      Q(23 downto 12)    => adc1_data_f(1),
      Q(35 downto 24)    => adc1_data_f(2),
      Q(47 downto 36)    => adc1_data_f(3),
      Empty              => adc1_fifo_empty,
      Full               => adc1_fifo_full
      );
  
  -- Readout Handler
  adc1_write_enable    <= adc1_data_clk_m and not adc1_fifo_full;
  adc1_read_enable     <= not adc1_fifo_empty;
  
  PROC_ADC1_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_ADC1_CLKD = '1') then
        adc1_read_enable_t   <= '0';
        adc1_read_enable_tt  <= '0';
        for I in 0 to 3 loop
          adc1_data_o(I)     <= (others => '0');
        end loop; 
        adc1_data_clk_o      <= '0';
      else
        -- Read enable
        adc1_read_enable_t   <= adc1_read_enable;
        adc1_read_enable_tt  <= adc1_read_enable_t;

        if (adc1_read_enable_tt = '1') then
          for I in 0 to 3 loop
            adc1_data_o(I)   <= adc1_data_f(I); 
          end loop;
          adc1_data_clk_o    <= '1';
        else
          adc1_data_clk_o    <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC1_FIFO_READ;

  -- Domain Transfer
  adc0_locked_ff <= adc0_frame_locked when rising_edge(CLK_IN);
  adc0_locked_f  <= adc0_locked_ff    when rising_edge(CLK_IN);
  adc0_locked_o  <= adc0_locked_f     when rising_edge(CLK_IN);

  adc1_locked_ff <= adc1_frame_locked when rising_edge(CLK_IN);
  adc1_locked_f  <= adc1_locked_ff    when rising_edge(CLK_IN);
  adc1_locked_o  <= adc1_locked_f     when rising_edge(CLK_IN);

  pulse_dtrans_ADC0_ERROR: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => '0',
      PULSE_A_IN  => adc0_error,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => '0',
      PULSE_B_OUT => error_adc0_o
      );

  pulse_dtrans_ADC1_ERROR: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => '0',
      PULSE_A_IN  => adc1_error,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => '0',
      PULSE_B_OUT => error_adc1_o
      );

  pulse_dtrans_ADC0_ERROR_UNDEF: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => '0',
      PULSE_A_IN  => adc0_error_undef,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => '0',
      PULSE_B_OUT => error_undef_adc0_o
      );

  pulse_dtrans_ADC1_ERROR_UNDEF: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => '0',
      PULSE_A_IN  => adc1_error_undef,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => '0',
      PULSE_B_OUT => error_undef_adc1_o
      );
  
  -- Output
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

  ERROR_ADC0_OUT       <= error_adc0_o;
  ERROR_ADC1_OUT       <= error_adc1_o;

  ERROR_UNDEF_ADC0_OUT <= error_undef_adc0_o;
  ERROR_UNDEF_ADC1_OUT <= error_undef_adc1_o;
  
end Behavioral;
