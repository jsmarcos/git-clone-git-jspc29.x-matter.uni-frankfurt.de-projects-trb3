library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_i2c_master is
  generic (
    i2c_speed : unsigned(11 downto 0) := x"3e8"
    );
  port(
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;

    -- I2C connections
    SDA_INOUT            : inout std_logic;
    SCL_INOUT            : inout std_logic;

    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_i2c_master is

  signal sda_i : std_logic;
  signal sda_x : std_logic;
  signal sda   : std_logic;

  signal scl_i : std_logic;
  signal scl_x : std_logic;
  signal scl   : std_logic;

  -- I2C Master  
  signal sda_o                 : std_logic;
  signal scl_o                 : std_logic;
  signal i2c_start             : std_logic;

  signal i2c_busy              : std_logic;
  signal startstop_select      : std_logic;
  signal startstop_seq_start   : std_logic;
  signal sendbyte_seq_start    : std_logic;
  signal readbyte_seq_start    : std_logic;
  signal sendbyte_byte         : std_logic_vector(7 downto 0);
  signal read_seq_ctr          : std_logic;
  signal reg_data              : std_logic_vector(31 downto 0);

  signal i2c_busy_x            : std_logic;
  signal startstop_select_x    : std_logic;
  signal startstop_seq_start_x : std_logic;
  signal wait_timer_init_x     : std_logic_vector(11 downto 0);
  signal sendbyte_seq_start_x  : std_logic;
  signal sendbyte_byte_x       : std_logic_vector(7 downto 0);
  signal readbyte_seq_start_x  : std_logic;
  signal read_seq_ctr_x        : std_logic;
  signal reg_data_x            : std_logic_vector(31 downto 0);
  
  signal sda_startstop         : std_logic;
  signal scl_startstop         : std_logic;
  signal i2c_notready          : std_logic;
  signal startstop_done        : std_logic;

  signal sda_sendbyte          : std_logic;
  signal scl_sendbyte          : std_logic;
  signal sendbyte_ack          : std_logic;
  signal sendbyte_done         : std_logic;
  
  signal sda_readbyte          : std_logic;
  signal scl_readbyte          : std_logic;
  signal readbyte_byte         : std_logic_vector(7 downto 0);
  signal readbyte_done         : std_logic;
  
  type STATES is (S_RESET,
                  S_IDLE,
                  S_START,
                  S_START_WAIT,

                  S_SEND_CHIP_ID,
                  S_SEND_CHIP_ID_WAIT,
                  S_SEND_REGISTER,
                  S_SEND_REGISTER_WAIT,
                  S_SEND_DATA,
                  S_SEND_DATA_WAIT,
                  S_GET_DATA,
                  S_GET_DATA_WAIT,

                  S_STOP,
                  S_STOP_WAIT
                  );
  signal STATE, NEXT_STATE : STATES;

  
  -- I2C Timer
  signal wait_timer_init         : unsigned(11 downto 0);
  signal wait_timer_done         : std_logic;
                                 
  -- TRBNet Slave Bus            
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;
  signal i2c_chipid              : std_logic_vector(6 downto 0);
  signal i2c_rw_bit              : std_logic;
  signal i2c_registerid          : std_logic_vector(7 downto 0);
  signal i2c_register_data       : std_logic_vector(7 downto 0);
  signal i2c_register_value_read : std_logic_vector(7 downto 0);

begin

  -- Timer
  nx_timer_1: nx_timer
    generic map (
      CTR_WIDTH => 12
      )
    port map (
      CLK_IN         => CLK_IN,
      RESET_IN       => RESET_IN,
      TIMER_START_IN => wait_timer_init,
      TIMER_DONE_OUT => wait_timer_done
      );

  -- Start / Stop Sequence
  nx_i2c_startstop_1: nx_i2c_startstop
    generic map (
      i2c_speed => i2c_speed
      )
    port map (
      CLK_IN            => CLK_IN,
      RESET_IN          => RESET_IN,
      START_IN          => startstop_seq_start,
      SELECT_IN         => startstop_select,
      SEQUENCE_DONE_OUT => startstop_done,
      SDA_OUT           => sda_startstop,
      SCL_OUT           => scl_startstop,
      NREADY_OUT        => i2c_notready
      );

  nx_i2c_sendbyte_1: nx_i2c_sendbyte
    generic map (
      i2c_speed => i2c_speed
      )
    port map (
      CLK_IN            => CLK_IN,
      RESET_IN          => RESET_IN,
      START_IN          => sendbyte_seq_start,
      BYTE_IN           => sendbyte_byte,
      SEQUENCE_DONE_OUT => sendbyte_done,
      SDA_OUT           => sda_sendbyte,
      SCL_OUT           => scl_sendbyte,
      SDA_IN            => sda,
      ACK_OUT           => sendbyte_ack
      );

  nx_i2c_readbyte_1: nx_i2c_readbyte
    generic map (
      i2c_speed => i2c_speed
      )
    port map (
      CLK_IN            => CLK_IN,
      RESET_IN          => RESET_IN,
      START_IN          => readbyte_seq_start,
      BYTE_OUT          => readbyte_byte,
      SEQUENCE_DONE_OUT => readbyte_done,
      SDA_OUT           => sda_readbyte,
      SCL_OUT           => scl_readbyte,
      SDA_IN            => sda
      );
  
  -- Debug Line
  -- DEBUG_OUT(0) <= not sendbyte_ack;
  -- DEBUG_OUT(1) <= sda_o;
  -- DEBUG_OUT(2) <= scl_o;
  -- DEBUG_OUT(3) <= sda_startstop;
  -- DEBUG_OUT(4) <= scl_startstop;
  -- DEBUG_OUT(5) <= sda_sendbyte;
  -- DEBUG_OUT(6) <= scl_sendbyte;
  -- DEBUG_OUT(7) <= sda_readbyte;
  -- DEBUG_OUT(8) <= scl_readbyte;
  -- DEBUG_OUT(9) <= i2c_start;
  
  --  DEBUG_OUT(8) <= i2c_start;
  --  DEBUG_OUT(15 downto 10) <= (others => '0');
  DEBUG_OUT(0) <= i2c_start;
  DEBUG_OUT(15 downto 14) <= (others => '0');
  DEBUG_OUT(13 downto 9)  <= reg_data(28 downto 24);
  DEBUG_OUT(8 downto 1)   <= reg_data(7 downto 0);

  -- Sync I2C Lines
  sda_i <= SDA_INOUT;
  scl_i <= SCL_INOUT;

  PROC_I2C_LINES_SYNC: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        sda_x <= '1';
        sda   <= '1';

        scl_x <= '1';
        scl   <= '1';
      else
        sda_x <= sda_i;
        sda   <= sda_x;

        scl_x <= scl_i;
        scl   <= scl_x;
      end if;
    end if;
  end process PROC_I2C_LINES_SYNC;

  PROC_I2C_MASTER_TRANSFER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_busy              <= '1';
        startstop_select      <= '0';
        startstop_seq_start   <= '0';
        sendbyte_seq_start    <= '0';
        readbyte_seq_start    <= '0';
        sendbyte_byte         <= (others => '0');
        wait_timer_init       <= (others => '0');
        reg_data              <= (others => '0');
        read_seq_ctr          <= '0';
        STATE                 <= S_RESET;
      else
        i2c_busy              <= i2c_busy_x;
        startstop_select      <= startstop_select_x;
        startstop_seq_start   <= startstop_seq_start_x;
        sendbyte_seq_start    <= sendbyte_seq_start_x;
        readbyte_seq_start    <= readbyte_seq_start_x;
        sendbyte_byte         <= sendbyte_byte_x;
        wait_timer_init       <= wait_timer_init_x;
        reg_data              <= reg_data_x;
        read_seq_ctr          <= read_seq_ctr_x;
        STATE                 <= NEXT_STATE;
      end if;
    end if;
  end process PROC_I2C_MASTER_TRANSFER;
  
        
  PROC_I2C_MASTER: process(STATE)

  begin
    -- Defaults
    sda_o                   <= '1';
    scl_o                   <= '1';
    i2c_busy_x              <= '1';
    startstop_select_x      <= '0';
    startstop_seq_start_x   <= '0';
    sendbyte_seq_start_x    <= '0';
    sendbyte_byte_x         <= (others => '0');
    readbyte_seq_start_x    <= '0';
    wait_timer_init_x       <= (others => '0');
    reg_data_x              <= reg_data;
    read_seq_ctr_x          <= read_seq_ctr;
    
    case STATE is

      when S_RESET =>
        reg_data_x <= (others => '0');
        NEXT_STATE <= S_IDLE;
        
      when S_IDLE =>
        if (i2c_start = '1') then
          reg_data_x <= x"8000_0000";  -- Set Running , clear all other bits 
          NEXT_STATE <= S_START;
        else
          i2c_busy_x     <= '0';
          reg_data_x     <= reg_data and x"7fff_ffff";  -- clear running bit;
          read_seq_ctr_x <= '0';
          NEXT_STATE     <= S_IDLE;
        end if;
            
        -- I2C START Sequence 
      when S_START =>
        startstop_select_x    <= '1';
        startstop_seq_start_x <= '1';
        NEXT_STATE            <= S_START_WAIT;
        
      when S_START_WAIT =>
        if (startstop_done = '0') then
          NEXT_STATE <= S_START_WAIT;
        else
          sda_o      <= '0';
          scl_o      <= '0';
          NEXT_STATE <= S_SEND_CHIP_ID;
        end if;
                   
        -- I2C SEND ChipId Sequence
      when S_SEND_CHIP_ID =>
        scl_o <= '0';
        sendbyte_byte_x(7 downto 1) <= i2c_chipid;
        if (read_seq_ctr = '0') then
          sendbyte_byte_x(0)        <= '0';
        else
          sendbyte_byte_x(0)        <= '1';
        end if;
        sendbyte_seq_start_x        <= '1';
        NEXT_STATE                  <= S_SEND_CHIP_ID_WAIT;
        
      when S_SEND_CHIP_ID_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_CHIP_ID_WAIT;
        else
          scl_o      <= '0';
          if (sendbyte_ack = '0') then
            reg_data_x <= reg_data or x"0100_0000";
            NEXT_STATE <= S_STOP;
          else
            if (read_seq_ctr = '0') then
              read_seq_ctr_x <= '1';
              NEXT_STATE <= S_SEND_REGISTER;
            else
              NEXT_STATE <= S_GET_DATA;
            end if;
          end if;
        end if;
        
        -- I2C SEND RegisterId
      when S_SEND_REGISTER =>
        scl_o <= '0';
        sendbyte_byte_x       <= i2c_registerid;          
        sendbyte_seq_start_x  <= '1';
        NEXT_STATE            <= S_SEND_REGISTER_WAIT;
        
      when S_SEND_REGISTER_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_REGISTER_WAIT;
        else
          scl_o      <= '0';
          if (sendbyte_ack = '0') then
            reg_data_x <= reg_data or x"0200_0000";
            NEXT_STATE <= S_STOP;
          else
            if (i2c_rw_bit = '0') then
              NEXT_STATE <= S_SEND_DATA;
            else
              NEXT_STATE <= S_START;
            end if;
          end if;
        end if;

        -- I2C SEND DataWord
      when S_SEND_DATA =>
        scl_o <= '0';
        sendbyte_byte_x        <= i2c_register_data;
        sendbyte_seq_start_x   <= '1';
        NEXT_STATE             <= S_SEND_DATA_WAIT;
        
      when S_SEND_DATA_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE <= S_SEND_DATA_WAIT;
        else
          scl_o      <= '0';
          if (sendbyte_ack = '0') then
            reg_data_x <= reg_data or x"0400_0000";
          end if;
          NEXT_STATE <= S_STOP;
        end if;

        -- I2C GET DataWord
      when S_GET_DATA =>
        scl_o <= '0';
        readbyte_seq_start_x   <= '1';
        NEXT_STATE             <= S_GET_DATA_WAIT;
        
      when S_GET_DATA_WAIT =>
        if (readbyte_done = '0') then
          NEXT_STATE <= S_GET_DATA_WAIT;
        else
          scl_o                  <= '0';
          reg_data_x(7 downto 0) <= readbyte_byte; 
          NEXT_STATE             <= S_STOP;
        end if;
        
        -- I2C STOP Sequence 
      when S_STOP =>
        sda_o                 <= '0';
        scl_o                 <= '0';
        startstop_select_x    <= '0';
        startstop_seq_start_x <= '1';
        NEXT_STATE            <= S_STOP_WAIT;
        
      when S_STOP_WAIT =>
        if (startstop_done = '0') then
          NEXT_STATE <= S_STOP_WAIT;
        else
          reg_data_x <= reg_data or x"4000_0000"; -- Set DONE Bit
          NEXT_STATE <= S_IDLE;
        end if;
        
    end case;
  end process PROC_I2C_MASTER;

  -----------------------------------------------------------------------------
  -- TRBNet Slave Bus
  -----------------------------------------------------------------------------
  --
  --   Write bit definition
  --   ====================
  -- 
  --   D[31]    I2C_GO          0 => don't do anything on I2C,
  --                            1 => start I2C access
  --   D[30]    I2C_ACTION      0 => write byte, 1 => read byte
  --   D[29:24] I2C_SPEED       set to all '1'
  --   D[23:16] I2C_ADDRESS     address of I2C chip
  --   D[15:8]  I2C_CMD         command byte for access
  --   D[7:0]   I2C_DATA        data to be written
  -- 
  --   
  --   Read bit definition
  --   ===================
  --   
  --   D[31:24] status          status information
  --   D[31]    RUNNING         whatever
  --   D[30]    I2C_DONE        whatever
  --   D[29]    ERROR_RADDACK   no acknowledge for repeated address byte
  --   D[28]    ERROR_RSTART    generation of repeated START condition failed
  --   D[27]    ERROR_DATACK    no acknowledge for data byte
  --   D[26]    ERROR_CMDACK    no acknowledge for command byte
  --   D[25]    ERROR_ADDACK    no acknowledge for address byte
  --   D[24]    ERROR_START     generation of START condition failed
  --   D[23:21] reserved        reserved
  --   D[20:16] debug           subject to change, don't use
  --   D[15:8]  reserved        reserved
  --   D[7:0]   I2C_DATA        result of I2C read operation
  --
  
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o     <= (others => '0');
        slv_no_more_data_o <= '0';
        slv_unknown_addr_o <= '0';
        slv_ack_o          <= '0';
        i2c_start          <= '0';

        i2c_chipid              <= (others => '0');    
        i2c_rw_bit              <= '0';    
        i2c_registerid          <= (others => '0');    
        i2c_register_data       <= (others => '0');    
        i2c_register_value_read <= (others => '0');
            
      else
        slv_ack_o          <= '1';
        slv_unknown_addr_o <= '0';
        slv_no_more_data_o <= '0';
        slv_data_out_o     <= (others => '0');
        i2c_start          <= '0';
        
        if (SLV_WRITE_IN  = '1') then
          if (i2c_busy = '0' and SLV_DATA_IN(31) = '1') then
            i2c_rw_bit        <= SLV_DATA_IN(30);
            i2c_chipid        <= SLV_DATA_IN(22 downto 16);
            i2c_registerid    <= SLV_DATA_IN(15 downto 8);
            i2c_register_data <= SLV_DATA_IN(7 downto 0); 
            i2c_start         <= '1';
          end if;

        elsif (SLV_READ_IN = '1') then
          if (i2c_busy = '1') then
            slv_data_out_o     <= (others => '0');
            slv_no_more_data_o <= '1';
            slv_ack_o          <= '0';
          else
          slv_data_out_o       <= reg_data;
          end if;

        else
          slv_ack_o <= '0';
        end if;
      end if;
    end if;           
  end process PROC_SLAVE_BUS;


  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- I2C Outputs
  SDA_INOUT <= '0' when (sda_o = '0' or
                         sda_startstop = '0' or
                         sda_sendbyte = '0' or
                         sda_readbyte = '0')
               else 'Z';
  
  SCL_INOUT <= '0' when (scl_o = '0' or
                         scl_startstop = '0' or
                         scl_sendbyte = '0' or
                         scl_readbyte = '0')
               else 'Z';

  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o; 

end Behavioral;
