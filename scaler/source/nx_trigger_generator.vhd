library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_generator is
  port (
    CLK_IN                 : in  std_logic;
    RESET_IN               : in  std_logic;
                           
    TRIGGER_BUSY_IN        : in  std_logic;
    EXTERNAL_TRIGGER_OUT   : out std_logic;
    INTERNAL_TRIGGER_OUT   : out std_logic;
                           
    DATA_IN                : in  std_logic_vector(43 downto 0);
    DATA_CLK_IN            : in  std_logic;
                           
    -- Slave bus           
    SLV_READ_IN            : in  std_logic;
    SLV_WRITE_IN           : in  std_logic;
    SLV_DATA_OUT           : out std_logic_vector(31 downto 0);
    SLV_DATA_IN            : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN            : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT            : out std_logic;
    SLV_NO_MORE_DATA_OUT   : out std_logic;
    SLV_UNKNOWN_ADDR_OUT   : out std_logic;
    
    -- Debug Line
    DEBUG_OUT              : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_trigger_generator is

  -- Internal Trigger Generator 
  signal pulser_trigger_on         : std_logic;
  signal pulser_trigger_period     : unsigned(27 downto 0);
  signal pulser_trigger            : std_logic;

  -- Self Trigger Generator
  signal data_i_f                  : std_logic_vector(43 downto 0);
  signal data_i                    : std_logic_vector(43 downto 0);
  signal data_clk_i_f              : std_logic;
  signal data_clk_i                : std_logic;
  
  signal self_trigger_on           : std_logic;
  signal self_trigger              : std_logic;
  
  -- Trigger Outputs
  signal trigger_output_select     : std_logic;  -- 0: Ext 1: Intern
  signal external_trigger_i        : std_logic;
  signal external_trigger_o        : std_logic;
  signal internal_trigger_o        : std_logic;
  signal trigger                   : std_logic;

  type S_STATES is (S_IDLE,
                     S_BUSY
                     );
  signal S_STATE : S_STATES;

  signal external_trigger_on       : std_logic; 
  signal external_trigger_ctr      : unsigned(4 downto 0);
  signal external_trigger_busy     : std_logic;
  signal external_trigger          : std_logic;

  -- Rate Calculation
  signal self_trigger_rate_t       : unsigned(27 downto 0);
  signal self_trigger_rate         : unsigned(27 downto 0);
  signal pulser_trigger_rate_t     : unsigned(27 downto 0);
  signal pulser_trigger_rate       : unsigned(27 downto 0);
  signal trigger_rate              : unsigned(27 downto 0);
  signal trigger_rate_t            : unsigned(27 downto 0);
  signal rate_timer                : unsigned(27 downto 0);
                                   
  -- TRBNet Slave Bus              
  signal slv_data_out_o            : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o        : std_logic;
  signal slv_unknown_addr_o        : std_logic;
  signal slv_ack_o                 : std_logic;
  signal pulser_trigger_period_r   : unsigned(27 downto 0);
  signal ignore_busy               : std_logic;

begin
  -- Debug Line
  DEBUG_OUT(0)             <= CLK_IN;
  DEBUG_OUT(1)             <= '0';
  DEBUG_OUT(2)             <= DATA_CLK_IN;
  DEBUG_OUT(3)             <= TRIGGER_BUSY_IN;
  
  DEBUG_OUT(4)             <= self_trigger_on;
  DEBUG_OUT(5)             <= self_trigger;

  DEBUG_OUT(6)             <= pulser_trigger_on;
  DEBUG_OUT(7)             <= pulser_trigger;

  DEBUG_OUT(8)             <= external_trigger_busy;
  DEBUG_OUT(9)             <= external_trigger;
                           
  DEBUG_OUT(10)            <= internal_trigger_o;
  DEBUG_OUT(11)            <= external_trigger_o;
  DEBUG_OUT(12)            <= trigger_output_select;
  DEBUG_OUT(13)            <= trigger;
  DEBUG_OUT(15 downto 14)  <= (others => '0');
                             
  -----------------------------------------------------------------------------
  -- Generate Pulser Trigger
  -----------------------------------------------------------------------------

  timer_PULSER_TRIGGER: timer
    generic map (
      CTR_WIDTH => 28
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => pulser_trigger_on,
      TIMER_END_IN   => pulser_trigger_period,

      TIMER_DONE_OUT => pulser_trigger
      );

  pulser_trigger_period <= (pulser_trigger_period_r - 1)
                           when pulser_trigger_period_r > 10
                           else x"0000009";

  -----------------------------------------------------------------------------
  -- Self Trigger
  -----------------------------------------------------------------------------
  
  PROC_SELF_TRIGGER: process(CLK_IN)
    variable frame_bits : std_logic_vector(3 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      data_i_f      <= DATA_IN;
      data_i        <= data_i_f;
      data_clk_i_f  <= DATA_CLK_IN;
      data_clk_i    <= data_clk_i_f;
                       
      if( RESET_IN = '1' ) then
        self_trigger       <= '0';
      else
        frame_bits      := data_i(31) &
                           data_i(23) &
                           data_i(15) &
                           data_i(7);
        self_trigger       <= '0';

        if (self_trigger_on = '1' and
            data_clk_i      = '1' and
            frame_bits      = "1000") then
          self_trigger     <= '1';
        else
          self_trigger     <= '0';
        end if;
      end if;
    end if;
  end process PROC_SELF_TRIGGER;

  -----------------------------------------------------------------------------
  -- Trigger Output Handler
  -----------------------------------------------------------------------------

  PROC_TRIGGER_OUTPUTS: process (CLK_IN)
    variable trigger_signals : std_logic;
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        external_trigger_i     <= '0';
        internal_trigger_o     <= '0';
      else
        trigger_signals        := self_trigger or pulser_trigger;

        if (trigger_output_select = '0') then
          external_trigger_i   <= trigger_signals;
        else
          internal_trigger_o   <= trigger_signals;
        end if;

        -- For Rate Counter
        trigger                <= external_trigger or internal_trigger_o;
      end if;
    end if;
  end process PROC_TRIGGER_OUTPUTS;

  PROC_EXTERN_TRIGGER_OUT: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        external_trigger_ctr    <= (others => '0');
        external_trigger_busy   <= '0';
        external_trigger        <= '0';
      else
        external_trigger             <= '0';
        external_trigger_busy        <= '0';
        
        case S_STATE is
          when S_IDLE =>
            if (TRIGGER_BUSY_IN = '0' and
                external_trigger_i = '1') then
              external_trigger       <= '1';
              if (ignore_busy = '0') then 
                external_trigger_ctr   <= "10100";  -- 20
                S_STATE                <= S_BUSY;
              else
                S_STATE              <= S_IDLE;
              end if;
            else
              external_trigger_ctr   <= (others => '0');
              S_STATE                <= S_IDLE;
            end if;
            
          when S_BUSY =>
            if (external_trigger_ctr > 0) then
              external_trigger_ctr   <= external_trigger_ctr  - 1;
              external_trigger_busy  <= '1';
              S_STATE                <= S_BUSY;
            else
              S_STATE                <= S_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_EXTERN_TRIGGER_OUT;
  
  -- Goes to CTS
  pulse_to_level_EXTERNAL_TRIGGER: pulse_to_level
    generic map (
      NUM_CYCLES => 8
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => external_trigger,
      LEVEL_OUT => external_trigger_o
      );
  
  -----------------------------------------------------------------------------
  --  Rate Counter
  -----------------------------------------------------------------------------
  PROC_CAL_RATES: process (CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if (RESET_IN = '1') then
        self_trigger_rate_t        <= (others => '0');
        self_trigger_rate          <= (others => '0');
        pulser_trigger_rate_t      <= (others => '0');
        pulser_trigger_rate        <= (others => '0');
        trigger_rate_t             <= (others => '0');
        trigger_rate               <= (others => '0');
        rate_timer                 <= (others => '0');
      else
        if (rate_timer < x"5f5e100") then
          if (self_trigger = '1') then
            self_trigger_rate_t     <= self_trigger_rate_t + 1;
          end if;

          if (pulser_trigger = '1') then
            pulser_trigger_rate_t   <= pulser_trigger_rate_t + 1;
          end if;

          if (trigger = '1') then
            trigger_rate_t          <= trigger_rate_t + 1;
          end if;

          rate_timer                <= rate_timer + 1;
        else
          self_trigger_rate_t(27 downto 1)    <= (others => '0');
          self_trigger_rate_t(0)              <= '0';
            
          pulser_trigger_rate_t(27 downto 1)  <= (others => '0');
          pulser_trigger_rate_t(0)            <= pulser_trigger;

          trigger_rate_t(27 downto 1)         <= (others => '0');
          trigger_rate_t(0)                   <= trigger;
        
          self_trigger_rate                   <= self_trigger_rate_t;
          pulser_trigger_rate                 <= pulser_trigger_rate_t;
          trigger_rate                        <= trigger_rate_t;

          rate_timer                          <= (others => '0');
        end if;
      end if;
    end if;
  end process PROC_CAL_RATES;
  
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o             <= (others => '0');
        slv_no_more_data_o         <= '0';
        slv_unknown_addr_o         <= '0';
        slv_ack_o                  <= '0';
        trigger_output_select      <= '0';
        self_trigger_on            <= '1';
        pulser_trigger_on          <= '0';
        pulser_trigger_period_r    <= x"00186a0";
      else
        slv_unknown_addr_o       <= '0';
        slv_no_more_data_o       <= '0';
        slv_data_out_o           <= (others => '0');
        
        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            
            when x"0000" =>
              self_trigger_on               <= SLV_DATA_IN(0);
              pulser_trigger_on             <= SLV_DATA_IN(1);
              trigger_output_select         <= SLV_DATA_IN(2);
              ignore_busy                   <= SLV_DATA_IN(15);
              slv_ack_o                     <= '1';

            when x"0001" =>
              pulser_trigger_period_r       <=
                unsigned(SLV_DATA_IN(27 downto 0));
              slv_ack_o                     <= '1';
                
            when others =>
              slv_unknown_addr_o            <= '1';
              slv_ack_o                     <= '0';
          end case;

        elsif (SLV_READ_IN = '1') then

          case SLV_ADDR_IN is

            when x"0000" =>
              slv_data_out_o(0)             <= self_trigger_on;
              slv_data_out_o(1)             <= pulser_trigger_on;
              slv_data_out_o(2)             <= trigger_output_select;
              slv_data_out_o(14 downto 3)   <= (others => '0');
              slv_data_out_o(15)            <= ignore_busy;
              slv_data_out_o(31 downto 16)  <= (others => '0');
              slv_ack_o                     <= '1';
           
            when x"0001" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(pulser_trigger_period_r);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';
            
            when x"0002" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(self_trigger_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0003" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(pulser_trigger_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when x"0004" =>
              slv_data_out_o(27 downto 0)   <=
                std_logic_vector(trigger_rate);
              slv_data_out_o(31 downto 28)  <= (others => '0');
              slv_ack_o                     <= '1';

            when others =>
              slv_unknown_addr_o            <= '1';
              slv_ack_o                     <= '0';
          end case;

        else
          slv_ack_o                         <= '0';
        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- Trigger Output
  EXTERNAL_TRIGGER_OUT     <= external_trigger_o;
  INTERNAL_TRIGGER_OUT     <= internal_trigger_o;
                           
  -- Slave Bus             
  SLV_DATA_OUT             <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT     <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT     <= slv_unknown_addr_o;
  SLV_ACK_OUT              <= slv_ack_o;    

end Behavioral;
