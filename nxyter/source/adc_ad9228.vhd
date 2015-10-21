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
    CLK_IN                : in  std_logic;
    RESET_IN              : in  std_logic;
    RESET_ADCS            : in  std_logic;    

    ADC_SCLK_IN           : in  std_logic;  -- Sampling Clock ADC0
    ADC_SCLK_OUT          : out std_logic;
    ADC_DATA_A_IN         : in  std_logic;
    ADC_DATA_B_IN         : in  std_logic;
    ADC_DATA_C_IN         : in  std_logic;
    ADC_DATA_D_IN         : in  std_logic;
    ADC_DCLK_IN           : in  std_logic;  -- Data Clock from ADC0
    ADC_FCLK_IN           : in  std_logic;  -- Frame Clock from ADC0
                              
    ADC_DATA_A_OUT        : out std_logic_vector(11 downto 0);
    ADC_DATA_B_OUT        : out std_logic_vector(11 downto 0);
    ADC_DATA_C_OUT        : out std_logic_vector(11 downto 0);
    ADC_DATA_D_OUT        : out std_logic_vector(11 downto 0);
    ADC_DATA_CLK_OUT      : out std_logic;
                          
    ADC_LOCKED_OUT        : out std_logic;
    ADC_ERROR_STATUS_OUT  : out std_logic_vector(2 downto 0);
    
    DEBUG_IN              : in  std_logic_vector(3 downto 0);
    DEBUG_OUT             : out std_logic_vector(15 downto 0)
    );
end adc_ad9228;

architecture Behavioral of  adc_ad9228 is

  -- DDR Generic Handler
  signal DDR_DATA_CLK           : std_logic;
  signal q_0_ff                 : std_logic_vector(19 downto 0);
  signal q_0_f                  : std_logic_vector(19 downto 0);
  signal q_0                    : std_logic_vector(19 downto 0);
 
  -- ADC Frame Lock Handler
  type adc_data_s       is array(0 to 4) of std_logic_vector(14 downto 0);
  type adc_data_t       is array(0 to 3) of std_logic_vector(11 downto 0);

  type BYTE_STATUS is (B_INVALID,
                       B_ALIGNED,
                       B_ALIGNED_BIT_SHIFTED,
                       B_BYTE_SHIFTED,
                       B_BIT_SHIFTED,
                       B_BYTE_BIT_SHIFTED
                       );
  signal adc_data_shift           : adc_data_s;
  
  signal adc_data_m               : adc_data_t;
  signal adc_data_clk_m           : std_logic;
  signal adc_byte_status          : BYTE_STATUS;
  signal adc_byte_status_last     : BYTE_STATUS;
  signal adc_frame_clk_ok         : std_logic;
  signal adc_frame_clk_ok_hist    : std_logic_vector(15 downto 0);
  signal adc_frame_locked         : std_logic;
  signal adc_status_fifo_clk      : std_logic;
  signal adc_status               : std_logic_vector(3 downto 0);
  signal adc_status_last          : std_logic_vector(3 downto 0);

  -- Clock Domain Transfer ADC Data
  signal adc_data                 : adc_data_t;
  signal adc_fifo_empty           : std_logic;
  signal adc_fifo_full            : std_logic;
  signal adc_write_enable         : std_logic;
  signal adc_read_enable          : std_logic;
  signal adc_read_enable_t        : std_logic;
  signal adc_read_enable_tt       : std_logic;
  
  -- Clock Domain Transfer ADC Status
  signal status                   : std_logic_vector(3 downto 0);
  signal status_fifo_empty        : std_logic;
  signal status_fifo_full         : std_logic;
  signal status_write_enable      : std_logic;
  signal status_read_enable       : std_logic;
  signal status_read_enable_t     : std_logic;
  signal status_read_enable_tt    : std_logic;
  signal status_locked_ff         : std_logic;
  
  signal frame_locked_o           : std_logic;
  signal adc_status_o                 : std_logic_vector(2 downto 0);
  signal status_clk_o             : std_logic;
    
  -- Output
  signal adc_data_clk_o        : std_logic;
  signal adc_data_o            : adc_data_t;
  signal adc_locked_o          : std_logic;
  signal adc_error_status_o    : std_logic_vector(2 downto 0);
  
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
  signal RESET_ADC              : std_logic;


  signal debug_state            : std_logic_vector(1 downto 0);

  -- 
  attribute syn_keep : boolean;

  attribute syn_keep of q_0_ff                    : signal is true;
  attribute syn_keep of q_0_f                     : signal is true;
  
  attribute syn_preserve : boolean;
  
  attribute syn_preserve of q_0_ff                : signal is true;
  attribute syn_preserve of q_0_f                 : signal is true;
                                                 
begin

  -----------------------------------------------------------------------------
  -- Debug Handler
  -----------------------------------------------------------------------------

  DFALSE: if (DEBUG_ENABLE = false) generate
    DEBUG_OUT             <= (others => '0');

  end generate DFALSE;

  DTRUE: if (DEBUG_ENABLE = true) generate
    
    PROC_DEBUG: process (DEBUG_IN)
    begin
      case DEBUG_IN is
        when x"1" =>
          DEBUG_OUT(0)            <= DDR_DATA_CLK;
          DEBUG_OUT(1)            <= adc_status(0);
          DEBUG_OUT(2)            <= adc_status(1);
          DEBUG_OUT(3)            <= adc_status(2);
          DEBUG_OUT(15 downto 4)  <= adc_data_shift(4)(11 downto 0);

        when others =>
          DEBUG_OUT(0)  <= CLK_IN;
          DEBUG_OUT(1)  <= '0';
          DEBUG_OUT(2)  <= wait_timer_start;
          DEBUG_OUT(3)  <= '0';
          DEBUG_OUT(4)  <= wait_timer_done;
          DEBUG_OUT(5)  <= '0';
          DEBUG_OUT(6)  <= RESET_CLKDIV;
          DEBUG_OUT(7)  <= '0';
          DEBUG_OUT(8)  <= RESET_ADC;
          DEBUG_OUT(9)  <= '0';
          DEBUG_OUT(11 downto 10) <= debug_state;
          DEBUG_OUT(15 downto 12) <= (others => '0');
           
      end case;
    end process PROC_DEBUG;       

  end generate DTRUE;

  -----------------------------------------------------------------------------
  -- DDR Generic Interface to ADC
  -----------------------------------------------------------------------------
  adc_ddr_generic_1: entity work.adc_ddr_generic
    port map (
      clk          => ADC_DCLK_IN,
      clkdiv_reset => '0', --RESET_CLKDIV,
      eclk         => open,
      sclk         => DDR_DATA_CLK,
      datain(0)    => ADC_DATA_A_IN,
      datain(1)    => ADC_DATA_B_IN,
      datain(2)    => ADC_DATA_C_IN,
      datain(3)    => ADC_DATA_D_IN,
      datain(4)    => ADC_FCLK_IN,
      q            => q_0_ff
      );
  
  -- Two FIFOs to relaxe timing
  q_0_f   <= q_0_ff when rising_edge(DDR_DATA_CLK);
  q_0     <= q_0_f  when rising_edge(DDR_DATA_CLK);

  -----------------------------------------------------------------------------
  -- Lock to ADC Frame Data
  -----------------------------------------------------------------------------

  PROC_LOCK_TO_ADC_FRAME: process(DDR_DATA_CLK)
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      if (RESET_IN = '1') then 
        for I in 0 to 4 loop
          adc_data_shift(I)       <= (others => '0');
        end loop;

        for I in 0 to 3 loop
          adc_data_m(I)         <= (others => '0');
        end loop;                  
        adc_data_clk_m          <= '0';
        
        adc_byte_status         <= B_INVALID;
        adc_byte_status_last    <= B_INVALID;
        adc_frame_clk_ok        <= '0';
        adc_frame_clk_ok_hist   <= (others => '0');
        adc_frame_locked        <= '0';
        adc_status              <= (others => '0');
      else
        -- Store new incoming Data in Shift Registers
        for I in 0 to 4 loop
          adc_data_shift(I)(3)             <= q_0(I + 0);
          adc_data_shift(I)(2)             <= q_0(I + 5);
          adc_data_shift(I)(1)             <= q_0(I + 10);
          adc_data_shift(I)(0)             <= q_0(I + 15);
          adc_data_shift(I)(14 downto  4)  <= adc_data_shift(I)(10 downto 0);
        end loop;
        
        -----------------------------------------------------------------------
        -- Check Frame Lock and valid Status, Index 4 is THE Frame Clock
        -----------------------------------------------------------------------
        case adc_data_shift(4)(14 downto 0) is
          when "000111111000000" =>
            -- Input Data is correct and new Frame is available
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(11 downto 0);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED;

          when "001111110000001" =>
            -- Input Data is correct and new Frame is available,
            -- but bit shifted by one
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(12 downto 1);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED_BIT_SHIFTED;
            
          when "011111100000011" =>
            -- Input Data is correct and new Frame is available,
            -- but byte shifted by one
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(13 downto 2);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_BYTE_SHIFTED;

          when "111111000000111" =>
            -- Input Data is correct and new Frame is available,
            -- but byte and bit shifted by one
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(14 downto 3);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_BYTE_BIT_SHIFTED;

            
          when "111110000001111" | "100000011111100"    =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED;

          when "111100000011111" | "000000111111000"    =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED_BIT_SHIFTED;

          when "111000000111111" | "000001111110000" =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_BYTE_SHIFTED;

          when "110000001111110" | "000011111100000" =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_BYTE_BIT_SHIFTED;
            
          when others =>
            -- Input Data is invalid, Fatal Error 
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '0';
            adc_byte_status                <= B_INVALID;
            
        end case;
        
        -- Determin ADC Frame Lock Status
        adc_frame_clk_ok_hist(0)           <= adc_frame_clk_ok;
        adc_frame_clk_ok_hist(15 downto 1) <=
          adc_frame_clk_ok_hist(14 downto 0);
        
        if (adc_frame_clk_ok_hist = x"ffff") then
          adc_frame_locked                 <= '1';
          adc_status(0)                    <= '1';
        else
          adc_frame_locked                 <= '0';
          adc_status(0)                    <= '0';
        end if;
        
        -- Error Status
        adc_byte_status_last               <= adc_byte_status;
        if (adc_byte_status /= adc_byte_status_last) then
          adc_status(3)                    <= '1';
        else
          adc_status(3)                    <= '0';
        end if;

        if (adc_byte_status = B_BYTE_SHIFTED or
            adc_byte_status = B_BYTE_BIT_SHIFTED ) then
          adc_status(1)                    <= '1';
        else
          adc_status(1)                    <= '0';
        end if;
          
        if (adc_byte_status = B_BIT_SHIFTED or
            adc_byte_status = B_ALIGNED_BIT_SHIFTED or
            adc_byte_status = B_BYTE_BIT_SHIFTED) then
          adc_status(2)                    <= '1';
        else
          adc_status(2)                    <= '0';
        end if;

        adc_status_last                    <= adc_status;
        if (adc_status /= adc_status_last) then
          adc_status_fifo_clk              <= '1';
        else
          adc_status_fifo_clk              <= '0';
        end if;

      end if;
      
    end if;
  end process PROC_LOCK_TO_ADC_FRAME;
  
  -----------------------------------------------------------------------------
  -- Domain Tansfer of Data to CLK_IN
  -----------------------------------------------------------------------------
  
  fifo_adc_48to48_dc_1: entity work.fifo_adc_48to48_dc
    port map (
      Data(11 downto 0)  => adc_data_m(0),
      Data(23 downto 12) => adc_data_m(1),
      Data(35 downto 24) => adc_data_m(2),
      Data(47 downto 36) => adc_data_m(3),
      WrClock            => DDR_DATA_CLK,
      RdClock            => CLK_IN,
      WrEn               => adc_write_enable,
      RdEn               => adc_read_enable,
      Reset              => RESET_IN,
      RPReset            => RESET_IN,
      Q(11 downto 0)     => adc_data(0),
      Q(23 downto 12)    => adc_data(1),
      Q(35 downto 24)    => adc_data(2),
      Q(47 downto 36)    => adc_data(3),
      Empty              => adc_fifo_empty,
      Full               => adc_fifo_full
      );
    
  -- Readout Handler
  adc_write_enable    <= adc_data_clk_m and not adc_fifo_full;
  adc_read_enable     <= not adc_fifo_empty;

  PROC_ADC_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      adc_read_enable_tt    <= adc_read_enable;
      if (RESET_IN = '1') then
        adc_read_enable_t   <= '0';
        for I in 0 to 3 loop
          adc_data_o(I)     <= (others => '0');
        end loop; 
        adc_data_clk_o      <= '0';
      else
        -- Read enable
        adc_read_enable_t   <= adc_read_enable_tt;
        
        if (adc_read_enable_t = '1') then
          for I in 0 to 3 loop
            adc_data_o(I)   <= adc_data(I); 
          end loop;
          adc_data_clk_o    <= '1';
        else
          adc_data_clk_o    <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC_FIFO_READ;

  -----------------------------------------------------------------------------
  -- Domain Tansfer of Status to CLK_IN
  -----------------------------------------------------------------------------
  
  fifo_adc_status_4to4_dc_1: entity work.fifo_adc_status_4to4_dc
    port map (
      Data    => adc_status,
      WrClock => DDR_DATA_CLK,
      RdClock => CLK_IN,
      WrEn    => status_write_enable,
      RdEn    => status_read_enable,
      Reset   => RESET_IN,
      RPReset => RESET_IN,
      Q       => status,
      Empty   => status_fifo_empty,
      Full    => status_fifo_full
      );

  -- Readout Handler
  status_write_enable   <= adc_status_fifo_clk and not status_fifo_full;
  status_read_enable    <= not status_fifo_empty;

  PROC_ADC_STATUS_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      status_read_enable_tt   <= status_read_enable;
      if (RESET_IN = '1') then
        status_read_enable_t  <= '0';
        adc_status_o              <= (others => '0');
        status_clk_o          <= '0';
      else
        -- Read enable
        status_read_enable_t  <= status_read_enable_tt;
        
        if (status_read_enable_t = '1') then
          frame_locked_o      <= status(0);
          adc_status_o        <= status(3 downto 1); 
          status_clk_o        <= '1';
        end if;
      end if;
    end if;
  end process PROC_ADC_STATUS_FIFO_READ;
  
  -----------------------------------------------------------------------------
  -- Error Status Handler
  -----------------------------------------------------------------------------
  
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
        RESET_ADC         <= '0';
        wait_timer_start  <= '0';
        timer_reset       <= '1';
        R_STATE           <= R_IDLE;
        debug_state       <= "00";
      else
        RESET_CLKDIV      <= '0';
        RESET_ADC         <= '0';
        wait_timer_start  <= '0';
        timer_reset       <= '0';
        
        case R_STATE is
          when R_IDLE =>
            if (RESET_ADCS = '1') then
              -- Start Reset
              RESET_CLKDIV      <= '1';
              RESET_ADC         <= '1';
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_CLKDIV;
            else
              timer_reset       <= '1';
              R_STATE           <= R_IDLE;
            end if;
            debug_state         <= "00";

          when R_WAIT_CLKDIV =>
            if (wait_timer_done = '0') then
              RESET_CLKDIV      <= '1';
              RESET_ADC         <= '1';
              R_STATE           <= R_WAIT_CLKDIV;
            else
              -- Release RESET_CLKDIV
              RESET_ADC        <= '1';
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_RESET_ADC;
            end if;
            debug_state         <= "01";
            
          when R_WAIT_RESET_ADC =>
            if (wait_timer_done = '0') then
              RESET_ADC         <= '1';
              R_STATE           <= R_WAIT_RESET_ADC;
            else
              -- Release reset_adc
              wait_timer_start  <= '1';
              R_STATE           <= R_WAIT_RESET_END;
            end if; 
            debug_state         <= "10";
            
          when R_WAIT_RESET_END =>
            if (wait_timer_done = '0') then
              R_STATE           <= R_WAIT_RESET_END;
            else
              R_STATE           <= R_IDLE;
            end if;
            debug_state         <= "11";
        end case;
      end if;
    end if;
  end process PROC_DDR_RESET_HANDLER;

  -----------------------------------------------------------------------------
  -- Outputs
  -----------------------------------------------------------------------------
  ADC_SCLK_OUT          <= ADC_SCLK_IN;
  
  ADC_DATA_A_OUT        <= adc_data_o(0);
  ADC_DATA_B_OUT        <= adc_data_o(1);
  ADC_DATA_C_OUT        <= adc_data_o(2);
  ADC_DATA_D_OUT        <= adc_data_o(3);
  ADC_DATA_CLK_OUT      <= adc_data_clk_o;

  ADC_LOCKED_OUT        <= adc_locked_o;
  ADC_ERROR_STATUS_OUT  <= adc_status_o;

end Behavioral;
