-------------------------------------------------------------------------------
--Event Buffer FiFo for MuPix Readout
--FiFo can be read via SlowControl Bus or transferred into FEE-FiFo on TRB
--T.Weber, University Mainz
-------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

use work.mupix_components.all;


entity eventbuffer is
  port (
    clk   : in std_logic;
    reset : in std_logic;

    --data from mupix interface
    mupixdata_in       : in std_logic_vector(31 downto 0);
    mupixdatawr_in     : in std_logic;

    --response from fee (to trb fifo)       
    fee_data_out            : out std_logic_vector(31 downto 0);
    fee_data_write_out      : out std_logic;
    fee_data_finished_out   : out std_logic;
    fee_data_almost_full_in : in  std_logic;

    --trigger
    valid_trigger_in : in std_logic;

    --clear buffer (in case of invalid trigger)
    clear_buffer_in : in std_logic;

    -- slave bus         
    slv_read_in          : in  std_logic;
    slv_write_in         : in  std_logic;
    slv_data_in          : in  std_logic_vector(31 downto 0);
    slv_addr_in          : in  std_logic_vector(15 downto 0);
    slv_data_out         : out std_logic_vector(31 downto 0);
    slv_ack_out          : out std_logic;
    slv_no_more_data_out : out std_logic;
    slv_unknown_addr_out : out std_logic);
end eventbuffer;


architecture behavioral of eventbuffer is

  
  --response to fee
  signal fee_data_int : std_logic_vector(31 downto 0) := (others => '0');
  signal fee_data_write_int : std_logic := '0';
  signal fee_data_finished_int : std_logic := '0';
  signal fee_data_write_f : std_logic := '0';
  
  --fifo signals
  signal fifo_reset       : std_logic;
  signal fifo_full        : std_logic;
  signal fifo_empty       : std_logic;
  signal fifo_write       : std_logic;
  signal fifo_status      : std_logic_vector(31 downto 0) ;
  signal fifo_write_ctr   : std_logic_vector(11 downto 0) ;
  signal fifo_data_in     : std_logic_vector(31 downto 0) ;
  signal fifo_data_out    : std_logic_vector(31 downto 0) ;
  signal fifo_read_enable : std_logic;

  --fifo readout via slv_bus
  type   fifo_read_s_states is (idle, wait1, wait2, done);
  signal fifo_read_s_fsm  : fifo_read_s_states := idle;
  signal fifo_start_read  : std_logic := '0';
  signal fifo_read_s      : std_logic := '0';
  signal fifo_read_wasempty_s : std_logic := '0';
  signal fifo_reading_s   : std_logic := '0';
  signal fifo_read_done_s : std_logic := '0';
  signal fifo_read_busy_s : std_logic := '0';
  signal slv_fifo_reset : std_logic := '0';

  --fifo fast readout to trb data channel
  type fifo_read_f_states is (idle, wait_for_data,flush_data, lastword, done);
  signal fifo_read_f_fsm : fifo_read_f_states := idle;
  signal fifo_read_f : std_logic := '0';
  signal fifo_read_busy_f : std_logic := '0';

  component fifo_32x2k
    port (Data: in  std_logic_vector(31 downto 0);
        Clock: in  std_logic;
        WrEn: in  std_logic;
        RdEn: in  std_logic;
        Reset: in  std_logic;
        Q: out  std_logic_vector(31 downto 0);
        WCNT: out  std_logic_vector(11 downto 0);
        Empty: out  std_logic;
        Full: out  std_logic);
  end component;

begin  -- behavioral

  fifo_1:  fifo_32x2k
    port map (
      Data => fifo_data_in,
      Clock => clk,
      WrEn => fifo_write,
      RdEn => fifo_read_enable,
      Reset => fifo_reset,
      Q => fifo_data_out,
      WCNT => fifo_write_ctr,
      Empty => fifo_empty,
      Full => fifo_full);
  
  fifo_read_enable <= fifo_read_s or fifo_read_f;
  fifo_reset <= clear_buffer_in or slv_fifo_reset;

  fifo_write_handler : process(clk)
  begin  -- process fifo_write_handler
    if rising_edge(clk) then
      fifo_write   <= '0';
      fifo_data_in <= (others => '0');
      if mupixdatawr_in = '1' and fifo_full = '0' then
        fifo_write   <= '1';
        fifo_data_in <= mupixdata_in;
      end if;
    end if;
  end process fifo_write_handler;

  ------------------------------------------------------------
  --fifo readout to ipu channel
  ------------------------------------------------------------
  fifo_data_write_ff: process (clk) is
  begin  -- process fifo_data_write_ff
    if rising_edge(clk) then
      fee_data_write_f <= fee_data_write_int;
    end if;
  end process fifo_data_write_ff;
  
  fifo_data_read_f: process is
  begin  -- process fifo_data_read_f
    wait until rising_edge(clk);
    fifo_read_f <= '0';
    fifo_read_busy_f <= '0';
    fee_data_int <= (others => '0');
    fee_data_write_int <= '0';
    fee_data_finished_int <= '0';
    if clear_buffer_in ='1' then
      fifo_read_f_fsm <= idle;
    end if;
    case fifo_read_f_fsm is
      when idle =>
        fifo_read_f_fsm <= idle;
        if valid_trigger_in = '1' then
          if fifo_empty = '1' then
            fifo_read_f_fsm <= done;
          else
            fifo_read_f <= '1';
            fifo_read_busy_f <= '1';
            fifo_read_f_fsm <= wait_for_data;
            end if;
        end if;
      when wait_for_data =>
        fifo_read_f      <= '1';
        fifo_read_busy_f <= '1';
        fifo_read_f_fsm  <= flush_data;
      when flush_data =>
        fifo_read_f      <= '1';
        fifo_read_busy_f <= '1';
        fee_data_int <= fifo_data_out;
        fee_data_write_int <= '1';
        if fifo_empty = '1' then
          fifo_read_f <= '0';
          fifo_read_f_fsm <= lastword;
        end if;
      when lastword =>
        fifo_read_f_fsm <= done;
        fifo_read_busy_f <= '1';
        fee_data_int <= fifo_data_out;
      when done =>
        fee_data_finished_int <= '1';
        fifo_read_f_fsm <= idle;
      when others => null;
    end case;
  end process fifo_data_read_f;

  ------------------------------------------------------------
  --fifo readout using trb slow control channel
  ------------------------------------------------------------
  fifo_data_read_s : process(clk)
  begin
    if rising_edge(clk) then
      fifo_read_done_s <= '0';
      fifo_read_s      <= '0';
      fifo_read_busy_s <= '0';
      fifo_read_wasempty_s <= '0';
      case fifo_read_s_fsm is
        when idle =>
          if fifo_start_read = '1' then
            if fifo_read_busy_f = '1' then
              fifo_read_done_s <= '1';
              fifo_read_s_fsm  <= idle;
            else
              if fifo_empty = '0' then
                fifo_read_s      <= '1';
                fifo_read_busy_s <= '1';
                fifo_read_s_fsm  <= wait1;
              else
                fifo_read_done_s <= '1';
                fifo_read_wasempty_s <= '1';
                fifo_read_s_fsm  <= idle;
              end if;
            end if;
          end if;
        when wait1 =>
          fifo_read_busy_s <= '1';
          fifo_read_s_fsm  <= done;
        when wait2 =>
          fifo_read_busy_s <= '1';
          fifo_read_s_fsm  <= done;
        when done =>
          fifo_read_busy_s <= '0';
          fifo_read_done_s <= '1';
          fifo_read_s_fsm  <= idle;
      end case;
    end if;
  end process fifo_data_read_s;


  -----------------------------------------------------------------------------
  --trb slave bus
  --0x0300: read fifo status
  --0x0301: read fifo write counter
  --0x0302: read fifo data
  ----------------------------------------------------------------------------- 

  fifo_status(1 downto 0)   <= fifo_empty & fifo_full;
  fifo_status(11 + 2 downto 2)  <= fifo_write_ctr;
  fifo_status(31 downto 12 + 2) <= (others => '0');
  
  slv_bus_handler : process(clk)
  begin
    if rising_edge(clk) then
      slv_data_out         <= (others => '0');
      slv_ack_out          <= '0';
      slv_no_more_data_out <= '0';
      slv_unknown_addr_out <= '0';
      fifo_start_read      <= '0';
      slv_fifo_reset       <= '0';

      if fifo_reading_s = '1' then
        if (fifo_read_done_s = '0') then
          fifo_reading_s <= '1';
        else
          if (fifo_read_wasempty_s = '0') then
            slv_data_out <= fifo_data_out;
            slv_ack_out  <= '1';
          else
            slv_no_more_data_out <= '1';
            slv_ack_out          <= '0';
          end if;
          fifo_reading_s <= '0';
        end if;
        
      elsif slv_write_in = '1' then
        case SLV_ADDR_IN is
          when x"0303" =>
            slv_fifo_reset <= '1';
            slv_ack_out <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;
        
      elsif slv_read_in = '1' then
        case slv_addr_in is
          when x"0300" =>
            slv_data_out <= fifo_status;
            slv_ack_out  <= '1';
          when x"0301" =>
            slv_data_out(11 downto 0) <= fifo_write_ctr;
            slv_ack_out               <= '1';
          when x"0302" =>
            fifo_start_read <= '1';
            fifo_reading_s  <= '1';
          when others =>
            slv_unknown_addr_out <= '1';
        end case;

      end if;
    end if;
  end process slv_bus_handler;
  

  --map output signals
  fee_data_out          <= fee_data_int;
  fee_data_write_out    <= fee_data_write_f;
  fee_data_finished_out <= fee_data_finished_int;
  
end behavioral;
