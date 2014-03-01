library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity adc_ad9228 is
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
    ADC0_DATA_VALID_OUT  : out std_logic;

    ADC1_DATA_A_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_B_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_C_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_D_OUT      : out std_logic_vector(11 downto 0);
    ADC1_DATA_VALID_OUT  : out std_logic;
    ADC0_NOTLOCK_COUNTER : out unsigned(7 downto 0);
    ADC1_NOTLOCK_COUNTER : out unsigned(7 downto 0);

    ERROR_ADC0_OUT       : out std_logic;
    ERROR_ADC1_OUT       : out std_logic;
    DEBUG_IN             : in  std_logic_vector(3 downto 0);
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end adc_ad9228;

architecture Behavioral of  adc_ad9228 is

  -- DDR Generic Handler
  signal DDR_DATA_CLK           : std_logic;
  signal q_0                    : std_logic_vector(19 downto 0);
  signal q_1                    : std_logic_vector(19 downto 0);

  -- NotLock Counters
  signal adc0_frame_notlocked   : std_logic;
  signal adc0_frame_notlocked_p : std_logic;
  signal adc0_notlock_ctr       : unsigned(7 downto 0);
  signal adc0_bit_shift         : unsigned(1 downto 0);
  signal adc0_bit_shift_last    : unsigned(1 downto 0);
  signal adc0_bit_shift_change  : std_logic;
  
  signal adc1_frame_notlocked   : std_logic;
  signal adc1_frame_notlocked_p : std_logic;
  signal adc1_notlock_ctr       : unsigned(7 downto 0);
  signal adc1_bit_shift         : unsigned(1 downto 0);
  signal adc1_bit_shift_last    : unsigned(1 downto 0);
  signal adc1_bit_shift_change  : std_logic;

  -- Merge Data
  type q_map_t          is array(0 to 4) of std_logic_vector(3 downto 0);
  type adc_data_buf_t   is array(0 to 4) of std_logic_vector(15 downto 0);
  type adc_data_t       is array(0 to 3) of std_logic_vector(11 downto 0);

  signal adc0_data_buf          : adc_data_buf_t;
  signal adc0_frame_ctr         : unsigned(2 downto 0);
  signal adc0_frame_locked      : std_logic;
                                
  signal adc0_new_data_t        : std_logic;
  signal adc0_data_t            : adc_data_t;
                                
  signal adc1_data_buf          : adc_data_buf_t;
  signal adc1_frame_ctr         : unsigned(2 downto 0);
  signal adc1_frame_locked      : std_logic;
                                
  signal adc1_new_data_t        : std_logic;
  signal adc1_data_t            : adc_data_t;
                                
  -- Clock Transfer             
  signal adc0_fifo_empty        :  std_logic;
  signal adc0_fifo_full         :  std_logic;
  signal adc0_write_enable      :  std_logic;
  signal adc0_read_enable       :  std_logic;
  signal adc0_read_enable_t     :  std_logic;
  signal adc0_read_enable_tt    :  std_logic;
  signal adc0_fifo_reset        :  std_logic;
  
  signal adc1_fifo_empty        :  std_logic;
  signal adc1_fifo_full         :  std_logic;
  signal adc1_write_enable      :  std_logic;
  signal adc1_read_enable       :  std_logic;
  signal adc1_read_enable_t     :  std_logic;
  signal adc1_read_enable_tt    :  std_logic;
  signal adc1_fifo_reset        :  std_logic;                                

  -- Error
  signal error_adc0_o           : std_logic;
  signal error_adc1_o           : std_logic;

  -- Output
  signal adc0_data_valid_o      : std_logic;
  signal adc0_data_f            : adc_data_t;
  signal adc0_data_o            : adc_data_t;
                                
  signal adc1_data_valid_o      : std_logic;
  signal adc1_data_f            : adc_data_t;
  signal adc1_data_o            : adc_data_t;


  -- Resets
  signal RESET_CLK_ADCDAT_IN    : std_logic;
  signal RESET_DDR_DATA_CLK     : std_logic;
    
begin

  PROC_DEBUG: process (DEBUG_IN)
  begin
    case DEBUG_IN is
      when x"0" =>
        -- DEBUG
        DEBUG_OUT(0)            <= CLK_IN;
        DEBUG_OUT(1)            <= DDR_DATA_CLK;
        DEBUG_OUT(2)            <= adc0_bit_shift_change;
        DEBUG_OUT(3)            <= adc0_write_enable;
        DEBUG_OUT(4)            <= adc0_fifo_full;
        DEBUG_OUT(5)            <= adc0_fifo_empty;
        DEBUG_OUT(6)            <= adc0_frame_locked;
        DEBUG_OUT(7)            <= adc0_new_data_t;
        DEBUG_OUT(8)            <= adc0_read_enable;
        DEBUG_OUT(9)            <= adc0_read_enable_t;
        DEBUG_OUT(10)           <= adc0_read_enable_tt;
        DEBUG_OUT(11)           <= adc0_data_valid_o;
        DEBUG_OUT(15 downto 12) <= (others => '0');

      when x"1" =>
        DEBUG_OUT               <= adc0_data_buf(0);

      when x"2" =>
        DEBUG_OUT               <= adc0_data_buf(1);

      when x"3" =>
        DEBUG_OUT               <= adc0_data_buf(2);

      when x"4" =>
        DEBUG_OUT               <= adc0_data_buf(3);

      when x"5" =>
        DEBUG_OUT               <= adc0_data_buf(4);

      --when x"e" => 
      --  DEBUG_OUT               <= q_0(15 downto 0); 

      --when x"f" =>  
      --  DEBUG_OUT               <= q_1(15 downto 0);    

      when others =>
        DEBUG_OUT               <= (others => '0');
    end case;
  end process PROC_DEBUG;       

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  signal_async_trans_RESET_IN: signal_async_trans
    port map (
      CLK_IN      => CLK_ADCDAT_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_CLK_ADCDAT_IN
    );

  signal_async_trans_RESET_IN_2: signal_async_trans
    port map (
      CLK_IN      => DDR_DATA_CLK,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_DDR_DATA_CLK
    );
  
  -----------------------------------------------------------------------------
  
  adc_ddr_generic_1: adc_ddr_generic
    port map (
      clk_0          => ADC0_DCLK_IN,
      clk_1          => ADC1_DCLK_IN,
      clkdiv_reset   => RESET_CLK_ADCDAT_IN,
      eclk           => CLK_ADCDAT_IN,
      reset_0        => RESET_DDR_DATA_CLK,
      reset_1        => RESET_DDR_DATA_CLK,
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
                     
      q_0            => q_0,
      q_1            => q_1
      );

  -----------------------------------------------------------------------------
  
  PROC_MERGE_DATA0: process(DDR_DATA_CLK)
    variable q_0_map  : q_map_t;
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      -- Remap DDR Output q_value
      for I in 0 to 4 loop
        q_0_map(I) := q_0(I + 0) & q_0(I + 5) & q_0(I + 10) & q_0(I + 15);
      end loop; 
        
      for I in 0 to 4 loop
        adc0_data_buf(I)(3 downto 0)  <= q_0_map(I);
        adc0_data_buf(I)(15 downto 4) <= adc0_data_buf(I)(11 downto 0);
      end loop;

      if (RESET_DDR_DATA_CLK = '1') then
        adc0_new_data_t        <= '0';
        adc0_frame_ctr         <= (others => '0');
        adc0_frame_locked      <= '0';
        adc0_bit_shift         <= "00";
        adc0_bit_shift_last    <= "00";
        adc0_bit_shift_change  <= '0';
      else
        -- Test Frame Clock Pattern
        adc0_new_data_t                 <= '0';
        case adc0_data_buf(4) is        -- adc0_data_buf(4) is frame clock
          when "0000111111000000" =>    
            for I in 0 to 3 loop
              adc0_data_t(I)            <= adc0_data_buf(I)(11 downto 0);
            end loop;
            adc0_new_data_t             <= '1';
            adc0_bit_shift              <= "00";
            
          when "0001111110000001" =>    
            for I in 0 to 3 loop
              adc0_data_t(I)            <= adc0_data_buf(I)(12 downto 1);
            end loop;
            adc0_new_data_t             <= '1';
            adc0_bit_shift              <= "01";                          

          when "0011111100000011" =>    
            for I in 0 to 3 loop
              adc0_data_t(I)            <= adc0_data_buf(I)(13 downto 2);
            end loop;
            adc0_new_data_t             <= '1';
            adc0_bit_shift              <= "10";                              

          when "0111111000000111" =>    
            for I in 0 to 3 loop
              adc0_data_t(I)            <= adc0_data_buf(I)(14 downto 3);
            end loop;
            adc0_new_data_t             <= '1';
            adc0_bit_shift              <= "11";

          when others => null;
            
        end case;

        -- ADC Lock Status
        if (adc0_new_data_t = '1') then
          adc0_frame_ctr             <= (others => '0');
          adc0_frame_locked          <= '1';
        elsif (adc0_frame_ctr < x"4") then
          adc0_frame_ctr             <= adc0_frame_ctr + 1;
        else
          adc0_frame_locked          <= '0';
        end if;

        adc0_bit_shift_last          <= adc0_bit_shift;
        if (adc0_bit_shift /= adc0_bit_shift_last) then
          adc0_bit_shift_change      <= '1';
        else
          adc0_bit_shift_change      <= '0';
        end if;
        
      end if;
    end if;
  end process PROC_MERGE_DATA0;

  -----------------------------------------------------------------------------
  
  PROC_MERGE_DATA1: process(DDR_DATA_CLK)
    variable q_1_map  : q_map_t;
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      -- Remap DDR Output q_value
      for I in 0 to 4 loop
        q_1_map(I) := q_1(I + 0) & q_1(I + 5) & q_1(I + 10) & q_1(I + 15);
      end loop; 
        
      for I in 0 to 4 loop
        adc1_data_buf(I)(3 downto 0)  <= q_1_map(I);
        adc1_data_buf(I)(15 downto 4) <= adc1_data_buf(I)(11 downto 0);
      end loop;  

      if (RESET_DDR_DATA_CLK = '1') then
        adc1_new_data_t        <= '0';
        adc1_frame_ctr         <= (others => '0');
        adc1_frame_locked      <= '0';
        adc1_bit_shift         <= "00";
        adc1_bit_shift_last    <= "00";
        adc1_bit_shift_change  <= '0';
      else
        -- Test Frame Clock Pattern
        adc1_new_data_t                 <= '0';
        case adc1_data_buf(4) is           -- adc1_data_buf(4) is frame clock
          when "0000111111000000" =>    
            for I in 0 to 3 loop
              adc1_data_t(I)            <= adc1_data_buf(I)(11 downto 0);
            end loop;
            adc1_new_data_t             <= '1';
            adc1_bit_shift              <= "00";
            
          when "0001111110000001" =>    
            for I in 0 to 3 loop
              adc1_data_t(I)            <= adc1_data_buf(I)(12 downto 1);
            end loop;
            adc1_new_data_t             <= '1';
            adc1_bit_shift              <= "01";
            
          when "0011111100000011" =>    
            for I in 0 to 3 loop
              adc1_data_t(I)            <= adc1_data_buf(I)(13 downto 2);
            end loop;
            adc1_new_data_t             <= '1';
            adc1_bit_shift              <= "10";
            
          when "0111111000000111" =>    
            for I in 0 to 3 loop
              adc1_data_t(I)            <= adc1_data_buf(I)(14 downto 3);
            end loop;
            adc1_new_data_t             <= '1';
            adc1_bit_shift              <= "11";
            
          when others => null;

        end case;

        -- ADC Lock Status
        if (adc1_new_data_t = '1') then
          adc1_frame_ctr             <= (others => '0');
          adc1_frame_locked          <= '1';
        elsif (adc1_frame_ctr < x"4") then
          adc1_frame_ctr             <= adc1_frame_ctr + 1;
        else
          adc1_frame_locked          <= '0';
        end if;

        adc1_bit_shift_last          <= adc1_bit_shift;
        if (adc1_bit_shift /= adc1_bit_shift_last) then
          adc1_bit_shift_change      <= '1';
        else
          adc1_bit_shift_change      <= '0';
        end if;
        
      end if;
    end if;
  end process PROC_MERGE_DATA1;

  -----------------------------------------------------------------------------
  -- Tansfer to CLK_IN
  -----------------------------------------------------------------------------

  fifo_adc_48to48_dc_1: fifo_adc_48to48_dc
    port map (
      Data(11 downto 0)  => adc0_data_t(0),
      Data(23 downto 12) => adc0_data_t(1),
      Data(35 downto 24) => adc0_data_t(2),
      Data(47 downto 36) => adc0_data_t(3),
      WrClock            => DDR_DATA_CLK,
      RdClock            => CLK_IN,
      WrEn               => adc0_write_enable,
      RdEn               => adc0_read_enable,
      Reset              => RESET_IN,
      RPReset            => adc0_fifo_reset,
      Q(11 downto 0)     => adc0_data_f(0),
      Q(23 downto 12)    => adc0_data_f(1),
      Q(35 downto 24)    => adc0_data_f(2),
      Q(47 downto 36)    => adc0_data_f(3),
      Empty              => adc0_fifo_empty,
      Full               => adc0_fifo_full
      );
    
  -- Readout Handler
  adc0_fifo_reset      <= RESET_IN;
  adc0_write_enable    <= adc0_new_data_t and not adc0_fifo_full;
  adc0_read_enable     <= not adc0_fifo_empty;
  
  PROC_ADC0_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      adc0_read_enable_t   <= adc0_read_enable;
      if (RESET_IN = '1') then
        adc0_read_enable_tt  <= '0';
        for I in 0 to 3 loop
          adc0_data_o(I)     <= (others => '0');
        end loop; 
        adc0_data_valid_o    <= '0';
      else
        -- Read enable
        adc0_read_enable_tt  <= adc0_read_enable_t;
        
        if (adc0_read_enable_tt = '1') then
          for I in 0 to 3 loop
            adc0_data_o(I)   <= adc0_data_f(I); 
          end loop;
          adc0_data_valid_o  <= '1';
        else
          adc0_data_valid_o  <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC0_FIFO_READ;

  -----------------------------------------------------------------------------

  fifo_adc_48to48_dc_2: fifo_adc_48to48_dc
    port map (
      Data(11 downto 0)  => adc1_data_t(0),
      Data(23 downto 12) => adc1_data_t(1),
      Data(35 downto 24) => adc1_data_t(2),
      Data(47 downto 36) => adc1_data_t(3),
      WrClock            => DDR_DATA_CLK,
      RdClock            => CLK_IN,
      WrEn               => adc1_new_data_t,
      RdEn               => adc1_read_enable,
      Reset              => RESET_IN,
      RPReset            => adc1_fifo_reset,
      Q(11 downto 0)     => adc1_data_f(0),
      Q(23 downto 12)    => adc1_data_f(1),
      Q(35 downto 24)    => adc1_data_f(2),
      Q(47 downto 36)    => adc1_data_f(3),
      Empty              => adc1_fifo_empty,
      Full               => adc1_fifo_full
      );
  
  -- Readout Handler
  adc1_fifo_reset      <= RESET_IN;
  adc1_write_enable    <= adc1_new_data_t and not adc1_fifo_full;
  adc1_read_enable     <= not adc1_fifo_empty;
  
  PROC_ADC1_FIFO_READ: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        adc1_read_enable_t   <= '0';
        adc1_read_enable_tt  <= '0';
        for I in 0 to 3 loop
          adc1_data_o(I)     <= (others => '0');
        end loop; 
        adc1_data_valid_o    <= '0';
      else
        -- Read enable
        adc1_read_enable_t   <= adc1_read_enable;
        adc1_read_enable_tt  <= adc1_read_enable_t;

        if (adc1_read_enable_tt = '1') then
          for I in 0 to 3 loop
            adc1_data_o(I)   <= adc1_data_f(I); 
          end loop;
          adc1_data_valid_o  <= '1';
        else
          adc1_data_valid_o  <= '0';
        end if;
      end if;
    end if;
  end process PROC_ADC1_FIFO_READ;

  -----------------------------------------------------------------------------
  -- Lock Monitor 
  -----------------------------------------------------------------------------

  level_to_pulse_1: level_to_pulse
    port map (
      CLK_IN    => DDR_DATA_CLK,
      RESET_IN  => RESET_DDR_DATA_CLK,
      LEVEL_IN  => not adc0_frame_locked,
      PULSE_OUT => adc0_frame_notlocked_p
      );
  
  level_to_pulse_2: level_to_pulse
    port map (
      CLK_IN    => DDR_DATA_CLK,
      RESET_IN  => RESET_DDR_DATA_CLK,
      LEVEL_IN  => not adc1_frame_locked,
      PULSE_OUT => adc1_frame_notlocked_p
      );

  pulse_dtrans_1: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => RESET_DDR_DATA_CLK,
      PULSE_A_IN  => adc0_frame_notlocked_p,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => adc0_frame_notlocked
      );

  pulse_dtrans_2: pulse_dtrans
    generic map (
      CLK_RATIO => 2
      )
    port map (
      CLK_A_IN    => DDR_DATA_CLK,
      RESET_A_IN  => RESET_DDR_DATA_CLK,
      PULSE_A_IN  => adc1_frame_notlocked_p,
      CLK_B_IN    => CLK_IN,
      RESET_B_IN  => RESET_IN,
      PULSE_B_OUT => adc1_frame_notlocked
      );

  PROC_NOTLOCK_COUNTER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        adc0_notlock_ctr     <= (others => '0');
        adc1_notlock_ctr     <= (others => '0');
      else
        if (adc0_frame_notlocked = '1') then
          adc0_notlock_ctr   <= adc0_notlock_ctr + 1;
        end if;

        if (adc1_frame_notlocked = '1') then
          adc1_notlock_ctr   <= adc1_notlock_ctr + 1;
        end if;
      end if;
    end if;
  end process PROC_NOTLOCK_COUNTER;

  PROC_ERROR: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        error_adc0_o     <= '0';
        error_adc1_o     <= '0';
      else
        error_adc0_o     <= '0';
        error_adc1_o     <= '0';
        
        if (adc0_frame_notlocked = '1' or
            adc0_bit_shift_change = '1') then
          error_adc0_o   <= '1';
        end if;

        if (adc1_frame_notlocked = '1' or
            adc1_bit_shift_change = '1') then
          error_adc1_o   <= '1';
        end if;
      end if;
    end if;
  end process PROC_ERROR;
        
  -- Output
  
  ADC0_SCLK_OUT        <= ADC0_SCLK_IN;
  ADC1_SCLK_OUT        <= ADC1_SCLK_IN;
  
  ADC0_DATA_A_OUT      <= adc0_data_o(0);
  ADC0_DATA_B_OUT      <= adc0_data_o(1);
  ADC0_DATA_C_OUT      <= adc0_data_o(2);
  ADC0_DATA_D_OUT      <= adc0_data_o(3);
  ADC0_DATA_VALID_OUT  <= adc0_data_valid_o;

  ADC1_DATA_A_OUT      <= adc1_data_o(0);
  ADC1_DATA_B_OUT      <= adc1_data_o(1);
  ADC1_DATA_C_OUT      <= adc1_data_o(2);
  ADC1_DATA_D_OUT      <= adc1_data_o(3);
  ADC1_DATA_VALID_OUT  <= adc1_data_valid_o;

  ADC0_NOTLOCK_COUNTER <= adc0_notlock_ctr;
  ADC1_NOTLOCK_COUNTER <= adc1_notlock_ctr;

  ERROR_ADC0_OUT       <= error_adc0_o;
  ERROR_ADC1_OUT       <= error_adc1_o;
  
end Behavioral;
