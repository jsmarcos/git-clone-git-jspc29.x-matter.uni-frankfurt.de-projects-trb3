library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.nxyter_components.all;

entity adc_ad9228_data_handler is
  generic (
    DEBUG_ENABLE : boolean := false
    );
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    DDR_DATA_CLK         : in  std_logic;
    DDR_DATA_IN          : in  std_logic_vector(19 downto 0);
    
    DATA_A_OUT           : out std_logic_vector(11 downto 0);
    DATA_B_OUT           : out std_logic_vector(11 downto 0);
    DATA_C_OUT           : out std_logic_vector(11 downto 0);
    DATA_D_OUT           : out std_logic_vector(11 downto 0);
    DATA_CLK_OUT         : out std_logic;

    FRAME_LOCKED_OUT     : out std_logic;
    ERROR_STATUS_OUT     : out std_logic_vector(2 downto 0);
    
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end adc_ad9228_data_handler;

architecture Behavioral of  adc_ad9228_data_handler is

  -- Frame Lock Handler
  type adc_data_s       is array(0 to 4) of std_logic_vector(13 downto 0);
  type adc_data_t       is array(0 to 3) of std_logic_vector(11 downto 0);

  type BYTE_STATUS is (B_UNDEF,
                       B_BITSHIFTED,
                       B_ALIGNED,
                       B_SHIFTED
                       );
  signal adc_data_shift        : adc_data_s;
  
  signal adc_data_m            : adc_data_t;
  signal adc_data_clk_m        : std_logic;
  
  signal adc_byte_status       : BYTE_STATUS;
  signal adc_byte_status_last  : BYTE_STATUS;

  signal adc_frame_clk_ok      : std_logic;
  signal adc_frame_clk_ok_hist : std_logic_vector(15 downto 0);
  signal adc_frame_locked      : std_logic;
  signal error_status          : std_logic_vector(2 downto 0);
  
  -- Clock Transfer             
  signal adc_fifo_empty        : std_logic;
  signal adc_fifo_full         : std_logic;
  signal adc_write_enable      : std_logic;
  signal adc_read_enable       : std_logic;
  signal adc_read_enable_t     : std_logic;
  signal adc_read_enable_tt    : std_logic;
  signal adc_locked_ff         : std_logic;
  signal adc_locked_f          : std_logic;
  signal adc_locked_o          : std_logic;
  signal adc_error_status_ff   : std_logic_vector(2 downto 0);
  signal adc_error_status_f    : std_logic_vector(2 downto 0);
  signal adc_error_status_o    : std_logic_vector(2 downto 0);

  signal adc_data              : adc_data_t;

  -- Output
  signal adc_data_clk_o        : std_logic;
  signal adc_data_o            : adc_data_t;

  -- RESET Handler
  signal RESET_DDR_DATA_CLK_F  : std_logic;
  signal RESET_DDR_DATA_CLK    : std_logic;
  
  -- Attributes
  attribute syn_keep : boolean;
  attribute syn_keep of RESET_DDR_DATA_CLK_F      : signal is true;
  attribute syn_keep of RESET_DDR_DATA_CLK        : signal is true; 

  attribute syn_keep of adc_locked_ff             : signal is true;
  attribute syn_keep of adc_locked_f              : signal is true;

  attribute syn_keep of adc_error_status_ff       : signal is true;
  attribute syn_keep of adc_error_status_f        : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of RESET_DDR_DATA_CLK_F  : signal is true;
  attribute syn_preserve of RESET_DDR_DATA_CLK    : signal is true;

  attribute syn_preserve of adc_locked_ff         : signal is true;
  attribute syn_preserve of adc_locked_f          : signal is true;

  attribute syn_preserve of adc_error_status_ff   : signal is true;
  attribute syn_preserve of adc_error_status_f    : signal is true;
  
begin

  -----------------------------------------------------------------------------
  RESET_DDR_DATA_CLK_F  <= RESET_IN             when rising_edge(DDR_DATA_CLK);
  RESET_DDR_DATA_CLK    <= RESET_DDR_DATA_CLK_F when rising_edge(DDR_DATA_CLK);

  -----------------------------------------------------------------------------
  -- Debug Handler
  -----------------------------------------------------------------------------

  DEBUG_OUT               <= (others => '0');
  --DEBUG_OUT(0)            <= CLK_IN;
  --DEBUG_OUT(1)            <= DDR_DATA_CLK;
  --DEBUG_OUT(2)            <= adc_write_enable;
  --DEBUG_OUT(3)            <= adc_fifo_full;
  --DEBUG_OUT(4)            <= adc_fifo_empty;
  --DEBUG_OUT(5)            <= adc_data_clk_m;
  --DEBUG_OUT(6)            <= adc_read_enable;
  --DEBUG_OUT(7)            <= adc_read_enable_t;
  --DEBUG_OUT(8)            <= adc_read_enable_tt;
  --DEBUG_OUT(9)            <= adc_data_clk_o;
  --DEBUG_OUT(10)           <= adc_error;
  --DEBUG_OUT(11)           <= adc_frame_locked;
  --DEBUG_OUT(12)           <= adc_frame_clk_ok;
  --DEBUG_OUT(14)           <= RESET_CLKDIV;
  --DEBUG_OUT(15)           <= RESET_ADC;
  
  -----------------------------------------------------------------------------
  -- Lock to ADC Frame Data
  -----------------------------------------------------------------------------

  PROC_LOCK_TO_ADC_FRAME: process(DDR_DATA_CLK)
  begin
    if (rising_edge(DDR_DATA_CLK)) then
      if (RESET_DDR_DATA_CLK = '1') then 
        for I in 0 to 4 loop
          adc_data_shift(I)       <= (others => '0');
        end loop;

        for I in 0 to 3 loop
          adc_data_m(I)           <= (others => '0');
        end loop;                  
        adc_data_clk_m            <= '0';
        
        adc_byte_status           <= B_UNDEF;
        adc_byte_status_last      <= B_UNDEF;
        adc_frame_clk_ok          <= '0';
        adc_frame_clk_ok_hist     <= (others => '0');
        adc_frame_locked          <= '0';
        error_status              <= (others => '0');
      else
        -- Store new incoming Data in Shift Registers
        for I in 0 to 4 loop
          adc_data_shift(I)(3)             <= DDR_DATA_IN(I + 0);
          adc_data_shift(I)(2)             <= DDR_DATA_IN(I + 5);
          adc_data_shift(I)(1)             <= DDR_DATA_IN(I + 10);
          adc_data_shift(I)(0)             <= DDR_DATA_IN(I + 15);
          adc_data_shift(I)(13 downto  4)  <= adc_data_shift(I)(9 downto 0);
        end loop;
        
        -- Check Frame Lock and valid Status, Index 4 is THE Frame Clock
        case adc_data_shift(4)(11 downto 0) is
          when "111111000000" =>
            -- Input Data is correct and new Frame is available
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(11 downto 0);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED;
            
          when "111100000011" =>
            -- Input Data is correct and new Frame is available,
            -- but byte shifted by one
            for I in 0 to 3 loop
              adc_data_m(I)                <= adc_data_shift(I)(13 downto 2);
            end loop;
            adc_data_clk_m                 <= '1';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_SHIFTED;

          when "110000001111" | "000011111100"    =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_ALIGNED;

          when "000000111111" | "001111110000" =>
            -- Input Data is correct
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '1';
            adc_byte_status                <= B_SHIFTED;

          when "000001111110" |
               "000111111000" |
               "011111100000" |
               "111110000001" |
               "111000000111" |
               "100000011111" =>
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '0';
            adc_byte_status                <= B_BITSHIFTED;
                        
          when others =>
            -- Input Data is invalid, Fatal Error of DDR Data, needs reset.
            adc_data_clk_m                 <= '0';
            adc_frame_clk_ok               <= '0';
            adc_byte_status                <= B_UNDEF;
            
        end case;

        -- Determin ADC Frame Lock Status
        adc_frame_clk_ok_hist(0)           <= adc_frame_clk_ok;
        adc_frame_clk_ok_hist(15 downto 1) <=
          adc_frame_clk_ok_hist(14 downto 0);
        
        if (adc_frame_clk_ok_hist = x"ffff") then
          adc_frame_locked                 <= '1';
        else
          adc_frame_locked                 <= '0';
        end if;
        
        -- Error Status
        adc_byte_status_last               <= adc_byte_status;
        if (adc_byte_status /= adc_byte_status_last) then
          error_status(2)                  <= '1';
        else
          error_status(2)                  <= '0';
        end if;
        
        if (adc_byte_status = B_BITSHIFTED) then
          error_status(1)                  <= '1';
        else
          error_status(1)                  <= '0';
        end if;

        if (adc_byte_status = B_UNDEF) then
          error_status(0)                  <= '1';
        else
          error_status(0)                  <= '0';
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
  -- Domain Transfer of Control Signals
  -----------------------------------------------------------------------------
  adc_locked_ff       <= adc_frame_locked    when rising_edge(CLK_IN);
  adc_locked_f        <= adc_locked_ff       when rising_edge(CLK_IN);
  adc_locked_o        <= adc_locked_f        when rising_edge(CLK_IN);

  adc_error_status_ff <= error_status        when rising_edge(CLK_IN);
  adc_error_status_f  <= adc_error_status_ff when rising_edge(CLK_IN);
  adc_error_status_o  <= adc_error_status_f  when rising_edge(CLK_IN);
  
  -----------------------------------------------------------------------------
  -- Output
  -----------------------------------------------------------------------------
  DATA_A_OUT          <= adc_data_o(0);
  DATA_B_OUT          <= adc_data_o(1);
  DATA_C_OUT          <= adc_data_o(2);
  DATA_D_OUT          <= adc_data_o(3);
  DATA_CLK_OUT        <= adc_data_clk_o;

  FRAME_LOCKED_OUT    <= adc_locked_o;
  ERROR_STATUS_OUT    <= adc_error_status_o;

end Behavioral;
