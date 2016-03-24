library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.scaler_components.all;

entity scaler_channel is
  port(
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
    CLK_D1_IN              : in  std_logic;
    RESET_D1_IN            : in  std_logic;
    
    -- Scaler Inputs
    RESET_CTR_IN           : in  std_logic;
    LATCH_IN               : in  std_logic;
    PULSE_IN               : in  std_logic;
    INHIBIT_IN             : in  std_logic;

    -- Trigger
    COUNTER_OUT            : out std_logic_vector(47 downto 0);
    
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

architecture Behavioral of scaler_channel is

  -- Sync Inputs
  signal reset_d1_ff                 : std_logic_vector(1 downto 0);
  signal RESET_D1                    : std_logic;

  signal reset_ctr_ff                : std_logic_vector(1 downto 0);
  signal RESET_CTR                   : std_logic;
  
  signal pulse_ff                    : std_logic_vector(2 downto 0);
  signal pulse_l                     : std_logic;     
  signal pulse_i                     : std_logic;
  signal latch_d1                    : std_logic;
  
  -- Scaler CLK_SCALER Domain 
  signal inhibit                     : std_logic;

  signal johnson                     : std_logic_vector(3 downto 0);

  signal counter_low_d1                 : std_logic_vector(2 downto 0);
  signal counter_low_ovfl_d1         : std_logic;
  
  signal counter_latched             : std_logic_vector(47 downto 0);

  -- Counter Clock Domain Transfer
  signal fifo_reset_i                : std_logic;
  signal fifo_write_enable           : std_logic;
  signal fifo_read_enable            : std_logic;
  signal fifo_empty                  : std_logic;
  signal fifo_full                   : std_logic;
  signal fifo_data_clk_t             : std_logic;
  signal fifo_data_clk               : std_logic;
  signal fifo_data                   : std_logic_vector(5 downto 0);
  
  signal counter_low                 : std_logic_vector(2 downto 0);
  signal counter_low_ovfl            : std_logic;
  signal latch                       : std_logic;

  signal counter_high                : unsigned(44 downto 0);
  
  signal data_clk                    : std_logic;
  signal data_reg                    : std_logic_vector(47 downto 0);

  -- Slave Bus
  signal slv_data_out_o              : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o          : std_logic;
  signal slv_unknown_addr_o          : std_logic;
  signal slv_ack_o                   : std_logic;
  signal counter_latched_offset_sign : std_logic;  -- 1 = +
  signal counter_latched_offset      : unsigned(15 downto 0);

  -----------------------------------------------------------------------------
  
  attribute syn_keep : boolean;
  attribute syn_keep of pulse_ff       : signal is true;

  attribute syn_preserve : boolean;
  attribute syn_preserve of pulse_ff   : signal is true;

  -----------------------------------------------------------------------------
  
begin

  ----------------------------------------------------------------------
  -- DEBUG
  ----------------------------------------------------------------------
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= pulse_i; --LATCH_IN; --data_clk;
  DEBUG_OUT(2)            <= fifo_data_clk;
  DEBUG_OUT(3)            <= counter_low_ovfl;
  DEBUG_OUT(4)            <= latch;
  DEBUG_OUT(5)            <= data_clk;
  DEBUG_OUT(15 downto 6)  <= counter_latched(9 downto 0);

  -- Sync input signals to Scaler CLK_D1_IN Domain
  reset_d1_ff(1)  <= RESET_D1_IN     when rising_edge(CLK_D1_IN);
  reset_d1_ff(0)  <= reset_d1_ff(1)  when rising_edge(CLK_D1_IN);
  RESET_D1        <= reset_d1_ff(0)  when rising_edge(CLK_D1_IN);

  reset_ctr_ff(1) <= RESET_CTR_IN     when rising_edge(CLK_D1_IN);
  reset_ctr_ff(0) <= reset_ctr_ff(1)  when rising_edge(CLK_D1_IN);
  RESET_CTR       <= reset_ctr_ff(0)  when rising_edge(CLK_D1_IN);
    
  pulse_ff(2) <= PULSE_IN    when rising_edge(CLK_D1_IN);
  pulse_ff(1) <= pulse_ff(2) when rising_edge(CLK_D1_IN);
  pulse_ff(0) <= pulse_ff(1) when rising_edge(CLK_D1_IN);

  pulse_i     <= '1' when pulse_ff(1 downto 0) = "10" else '0'; 
  
  -----------------------------------------------------------------------------
  -- The Primary Counter
  -----------------------------------------------------------------------------
  
  -- Johnson Counter for lower 3 Bits
  PROC_LOWER_BIT_COUNTER: process(CLK_D1_IN)
  begin
    if (rising_edge(CLK_D1_IN)) then
      if (RESET_D1 = '1' or RESET_CTR = '1') then
        johnson                 <= (others => '0');
        counter_low_ovfl_d1     <= '0';
      else
        counter_low_ovfl_d1     <= '0';
        if (pulse_i = '1') then
          johnson(0)            <= not johnson(3);
          johnson(1)            <= johnson(0);
          johnson(2)            <= johnson(1);
          johnson(3)            <= johnson(2);
          counter_low_ovfl_d1   <= '0';
          
          case johnson is
            when "0000" => counter_low_d1         <= "001";
            when "0001" => counter_low_d1         <= "010";
            when "0011" => counter_low_d1         <= "011";
            when "0111" => counter_low_d1         <= "100";
            when "1111" => counter_low_d1         <= "101";
            when "1110" => counter_low_d1         <= "110";
            when "1100" => counter_low_d1         <= "111";
            when "1000" => counter_low_d1         <= "000";
                           counter_low_ovfl_d1    <= '1';
            when others => counter_low_d1         <= "000";
          end case;
        end if;
      end if;
    end if;
  end process PROC_LOWER_BIT_COUNTER;

  -----------------------------------------------------------------------------
  -- Clock Domain Transfer in case of latch or overflow
  -----------------------------------------------------------------------------

  latch_d1 <= LATCH_IN when rising_edge(CLK_D1_IN);
  --latch_d1 <= counter_low_ovfl_d1 when rising_edge(CLK_D1_IN);
  
  COUNTER_LOW_DOMAIN_TRANSFER_1: entity work.fifo_6to6_dc
    port map (
      Data(2 downto 0) => counter_low_d1,
      Data(3)          => counter_low_ovfl_d1,
      Data(4)          => latch_d1,
      Data(5)          => RESET_CTR,
      WrClock          => CLK_D1_IN,
      RdClock          => CLK_IN,
      WrEn             => fifo_write_enable,
      RdEn             => fifo_read_enable,
      Reset            => fifo_reset_i,
      RPReset          => fifo_reset_i,
      Q                => fifo_data,
      Empty            => fifo_empty,
      Full             => fifo_full
      );
  fifo_reset_i         <= RESET_IN;
  fifo_write_enable    <= not fifo_full and (counter_low_ovfl_d1 or
                                             latch_d1 or
                                             RESET_CTR);
  fifo_read_enable     <= not fifo_empty;

  PROC_FIFO_READ_ENABLE: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      fifo_data_clk_t      <= fifo_read_enable;
      if (RESET_IN = '1') then
        fifo_data_clk_t    <= '0';
        fifo_data_clk      <= '0';
      else
        -- Delay read signal by two Clock Cycles
        fifo_data_clk      <= fifo_data_clk_t;
      end if;
    end if;
  end process PROC_FIFO_READ_ENABLE;

  PROC_FIFO_OUTPUT_HANDLER: process(CLK_IN)
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        counter_high         <= (others => '0');
        counter_low          <= (others => '0');
        counter_low_ovfl     <= '0';
        latch                <= '0';
      else
        counter_low            <= (others => '0');
        counter_low_ovfl       <= '0';
        latch                  <= '0';
        
        if (fifo_data_clk = '1') then
          counter_low          <= fifo_data(2 downto 0);
          counter_low_ovfl     <= fifo_data(3);
          latch                <= fifo_data(4);

          -- High Bit Counter
          if (fifo_data(5) = '1') then    -- in case of Reset Counters 
            counter_high       <= (others => '0');
          else
            if (fifo_data(3) = '1') then  -- in case of overflow
              counter_high     <= counter_high + 1;
            end if;
          end if;
        end if;
      end if;
    end if;
  end process PROC_FIFO_OUTPUT_HANDLER;

  PROC_LATCH: process(CLK_IN)
    variable counter_latched_new : unsigned(47 downto 0);
  begin
    if (rising_edge(CLK_IN)) then
      if (RESET_IN = '1') then
        counter_latched      <= (others => '0');
        data_clk             <= '0';
      else
        data_clk             <= '0';
        if (latch = '1') then
          counter_latched_new(2 downto 0)   := unsigned(counter_low);
          counter_latched_new(47 downto 3)  := unsigned(counter_high);
          if (counter_latched_offset_sign = '0') then
            counter_latched_new             :=
              counter_latched_new - resize(counter_latched_offset, 47);
          else
            counter_latched_new             :=
              counter_latched_new + resize(counter_latched_offset, 47);
          end if;
          counter_latched <= std_logic_vector(counter_latched_new);
          data_clk        <= '1';
        end if;
      end if;
    end if;
  end process PROC_LATCH;
  
  -----------------------------------------------------------------------------
  -- Slave Bus
  -----------------------------------------------------------------------------

  PROC_TRB3_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o              <= (others => '0');
        slv_no_more_data_o          <= '0';
        slv_unknown_addr_o          <= '0';
        slv_ack_o                   <= '0';
        
        counter_latched_offset      <= (others => '0');
        counter_latched_offset_sign <= '0';
        data_reg                    <= (others => '0');
      else
        slv_unknown_addr_o          <= '0';
        slv_no_more_data_o          <= '0';
        slv_data_out_o              <= (others => '0');    
       
        if (data_clk = '1') then
          data_reg                  <= counter_latched;
        end if;
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              counter_latched_offset(15 downto 0)  <=
                unsigned(SLV_DATA_IN(15 downto 0));
              counter_latched_offset_sign  <= SLV_DATA_IN(31);
              slv_ack_o                    <= '1';
            
            when others =>                
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;
          
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              slv_data_out_o(15 downto 0)  <=
                std_logic_vector(counter_latched_offset);
              slv_data_out_o(30 downto 16) <= (others => '0');
              slv_data_out_o(31)           <= counter_latched_offset_sign;
              slv_ack_o                    <= '1';
                   
            when x"0001" =>
              slv_data_out_o               <= data_reg(31 downto 0);
              slv_ack_o                    <= '1';

            when x"0002" =>
              slv_data_out_o(15 downto 0)  <= data_reg(47 downto 32);
              slv_data_out_o(31 downto 16) <= (others => '0');
              slv_ack_o                    <= '1';
              
            when others =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;
          
        else
          slv_ack_o                        <= '0';
        end if;
      end if;
    end if;           
  end process PROC_TRB3_REGISTERS;

  ----------------------------------------------------------------------
  -- Output Signals
  ----------------------------------------------------------------------

  --COUNTER_OUT           <= x"affedeadbeef";
  
  COUNTER_OUT           <= counter_latched;

  SLV_DATA_OUT          <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT  <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT  <= slv_unknown_addr_o;
  SLV_ACK_OUT           <= slv_ack_o;          
  
end Behavioral;
