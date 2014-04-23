library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_trigger_generator is
  port (
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;
    NX_MAIN_CLK_IN       : in  std_logic;

    TRIGGER_BUSY_IN      : in  std_logic;
    
    TRIGGER_OUT          : out std_logic;
    
    DATA_IN              : in  std_logic_vector(43 downto 0);
    DATA_CLK_IN          : in  std_logic;
    SELF_TRIGGER_OUT     : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_trigger_generator is

  -- Self Trigger
  
  type ST_STATES is (ST_IDLE,
                     ST_BUSY
                     );
  signal ST_STATE : ST_STATES;

  signal self_trigger_ctr        : unsigned(4 downto 0);
  signal self_trigger_busy       : std_logic;
  signal self_trigger            : std_logic;
  signal self_trigger_o          : std_logic;
  
  -- TRBNet Slave Bus            
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;

  -- Reset
  signal RESET_NX_MAIN_CLK_IN    : std_logic;

  signal new_data_frame_debug    : std_logic;
  
begin
  -- Debug Line
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= NX_MAIN_CLK_IN;
  DEBUG_OUT(2)            <= self_trigger;
  DEBUG_OUT(3)            <= self_trigger_o;
  DEBUG_OUT(4)            <= self_trigger_busy;
  DEBUG_OUT(5)            <= TRIGGER_BUSY_IN;
  DEBUG_OUT(6)            <= DATA_CLK_IN;
  DEBUG_OUT(7)            <= new_data_frame_debug;
  DEBUG_OUT(15 downto 8 ) <= (others => '0');

  -----------------------------------------------------------------------------
  -- Reset Domain Transfer
  -----------------------------------------------------------------------------
  signal_async_trans_RESET_IN: signal_async_trans
    port map (
      CLK_IN      => NX_MAIN_CLK_IN,
      SIGNAL_A_IN => RESET_IN,
      SIGNAL_OUT  => RESET_NX_MAIN_CLK_IN
    );
  
  -----------------------------------------------------------------------------
  -- Generate Trigger
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Self Trigger
  -----------------------------------------------------------------------------

  PROC_SELF_TRIGGER: process(CLK_IN)
    variable frame_bits : std_logic_vector(3 downto 0);
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        self_trigger_ctr   <= (others => '0');
        self_trigger_busy  <= '0';
        self_trigger       <= '0';
      else
        frame_bits      := DATA_IN(31) &
                           DATA_IN(23) &
                           DATA_IN(15) &
                           DATA_IN(7);
        self_trigger            <= '0';
        self_trigger_busy       <= '0';

        if (DATA_CLK_IN     = '1' and
            frame_bits      = "1000") then
          new_data_frame_debug  <= '1';
        else
          new_data_frame_debug  <= '0';
        end if;
        
        case ST_STATE is
          when ST_IDLE =>
            if (TRIGGER_BUSY_IN = '0' and
                DATA_CLK_IN     = '1' and
                frame_bits      = "1000") then
              self_trigger_ctr  <= "10100";  -- 20
              self_trigger      <= '1';
              ST_STATE          <= ST_BUSY;
            else
              self_trigger_ctr  <= (others => '0');
              ST_STATE          <= ST_IDLE;
            end if;
            
          when ST_BUSY =>
            if (self_trigger_ctr > 0) then
              self_trigger_ctr  <= self_trigger_ctr  - 1;
              self_trigger_busy <= '1';
              ST_STATE          <= ST_BUSY;
            else
              ST_STATE          <= ST_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_SELF_TRIGGER;

  pulse_to_level_SELF_TRIGGER: pulse_to_level
    generic map (
      NUM_CYCLES => 8
      )
    port map (
      CLK_IN    => CLK_IN,
      RESET_IN  => RESET_IN,
      PULSE_IN  => self_trigger,
      LEVEL_OUT => self_trigger_o
      );
    
  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o           <= (others => '0');
        slv_no_more_data_o       <= '0';
        slv_unknown_addr_o       <= '0';
        slv_ack_o                <= '0';
      else
        slv_unknown_addr_o       <= '0';
        slv_no_more_data_o       <= '0';
        slv_data_out_o           <= (others => '0');

        if (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is

            when others =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;

        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is

            when others =>
              slv_unknown_addr_o           <= '1';
              slv_ack_o                    <= '0';
          end case;

        else
          slv_ack_o                        <= '0';
        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;
  
  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- Trigger Output
  TRIGGER_OUT              <= '0';
  SELF_TRIGGER_OUT         <= self_trigger_o;
                           
  -- Slave Bus             
  SLV_DATA_OUT             <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT     <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT     <= slv_unknown_addr_o;
  SLV_ACK_OUT              <= slv_ack_o;    

end Behavioral;
