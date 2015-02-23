library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.nxyter_components.all;

entity nx_i2c_master is
  generic (
    I2C_SPEED : unsigned(11 downto 0) := x"3e8"
    );
  port(
    CLK_IN               : in    std_logic;
    RESET_IN             : in    std_logic;

    -- I2C connections
    SDA_INOUT            : inout std_logic;
    SCL_INOUT            : inout std_logic;

    -- Internal Interface
    INTERNAL_COMMAND_IN  : in    std_logic_vector(31 downto 0);
    COMMAND_BUSY_OUT     : out   std_logic;
    I2C_DATA_OUT         : out   std_logic_vector(31 downto 0);
    I2C_DATA_BYTES_OUT   : out   std_logic_vector(31 downto 0);
    I2C_LOCK_IN          : in    std_logic;

    -- Slave bus         
    SLV_READ_IN          : in    std_logic;
    SLV_WRITE_IN         : in    std_logic;
    SLV_DATA_OUT         : out   std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in    std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in    std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out   std_logic;
    SLV_NO_MORE_DATA_OUT : out   std_logic;
    SLV_UNKNOWN_ADDR_OUT : out   std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_i2c_master is

  signal sda_o                 : std_logic;
  signal scl_o                 : std_logic;
  
  signal sda_i                 : std_logic;
  signal sda_x                 : std_logic;
  signal sda                   : std_logic;
                               
  signal scl_i                 : std_logic;
  signal scl_x                 : std_logic;
  signal scl                   : std_logic;
  signal command_busy_o        : std_logic;

  -- I2C Master  
  signal sda_master            : std_logic;
  signal scl_master            : std_logic;
  signal i2c_start             : std_logic;
  signal i2c_busy              : std_logic;
  signal startstop_select      : std_logic;
  signal startstop_seq_start   : std_logic;
  signal sendbyte_seq_start    : std_logic;
  signal readbyte_seq_start    : std_logic;
  signal sendbyte_byte         : std_logic_vector(7 downto 0);
  signal read_seq_ctr          : std_logic;
  signal i2c_data              : std_logic_vector(31 downto 0);
  signal i2c_bytes             : std_logic_vector(31 downto 0);

  signal i2c_busy_x            : std_logic;
  signal startstop_select_x    : std_logic;
  signal startstop_seq_start_x : std_logic;
  signal sendbyte_seq_start_x  : std_logic;
  signal sendbyte_byte_x       : std_logic_vector(7 downto 0);
  signal readbyte_seq_start_x  : std_logic;
  signal read_seq_ctr_x        : std_logic;
  signal i2c_data_x            : std_logic_vector(31 downto 0);
  signal i2c_bytes_x           : std_logic_vector(31 downto 0);
  
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
  signal readbyte_byte         : std_logic_vector(31 downto 0);
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

  -- TRBNet Slave Bus            
  signal slv_data_out_o            : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o        : std_logic;
  signal slv_unknown_addr_o        : std_logic;
  signal slv_ack_o                 : std_logic;
                                   
  signal i2c_chipid                : std_logic_vector(6 downto 0);
  signal i2c_rw_bit                : std_logic;
  signal i2c_num_bytes             : unsigned(2 downto 0);
  signal i2c_registerid            : std_logic_vector(7 downto 0);
  signal i2c_register_data         : std_logic_vector(7 downto 0);
  signal i2c_register_value_read   : std_logic_vector(7 downto 0);
                                   
  signal disable_slave_bus         : std_logic; 
  signal internal_command          : std_logic;
  signal internal_command_d        : std_logic;
  signal i2c_data_internal_o       : std_logic_vector(31 downto 0);
  signal i2c_data_internal_bytes_o : std_logic_vector(31 downto 0);
  signal i2c_data_slave            : std_logic_vector(31 downto 0);

begin

  -- Debug
  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(3 downto 1)   <= i2c_num_bytes; --i2c_data(7 downto 0);
  DEBUG_OUT(4)            <= startstop_seq_start;
  DEBUG_OUT(5)            <= readbyte_seq_start;
  DEBUG_OUT(6)            <= startstop_done;
  DEBUG_OUT(7)            <= sendbyte_done;
  DEBUG_OUT(8)            <= readbyte_done;
 
  --DEBUG_OUT(10 downto 9)  <= i2c_data(31 downto 30);
  DEBUG_OUT(9)            <= i2c_busy;
  DEBUG_OUT(10)           <= i2c_busy;
  DEBUG_OUT(11)           <= i2c_busy;
  DEBUG_OUT(12)           <= sda_o;
  DEBUG_OUT(13)           <= scl_o;
  DEBUG_OUT(14)           <= sda_i;
  DEBUG_OUT(15)           <= scl_i;
  --DEBUG_OUT(12 downto 9)  <= i2c_data(31 downto 28);
  
  -- Start / Stop Sequence
  nx_i2c_startstop_1: nx_i2c_startstop
    generic map (
      I2C_SPEED => I2C_SPEED
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
      I2C_SPEED => I2C_SPEED
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
      SCL_IN            => scl,
      ACK_OUT           => sendbyte_ack
      );

  nx_i2c_readbyte_1: nx_i2c_readbyte
    generic map (
      I2C_SPEED => I2C_SPEED
      )
    port map (
      CLK_IN            => CLK_IN,
      RESET_IN          => RESET_IN,
      START_IN          => readbyte_seq_start,
      NUM_BYTES_IN      => i2c_num_bytes,
      BYTE_OUT          => readbyte_byte,
      SEQUENCE_DONE_OUT => readbyte_done,
      SDA_OUT           => sda_readbyte,
      SCL_OUT           => scl_readbyte,
      SDA_IN            => sda
      );
  
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
        i2c_data              <= (others => '0');
        i2c_bytes             <= (others => '0');
        read_seq_ctr          <= '0';
        STATE                 <= S_RESET;
      else
        i2c_busy              <= i2c_busy_x;
        startstop_select      <= startstop_select_x;
        startstop_seq_start   <= startstop_seq_start_x;
        sendbyte_seq_start    <= sendbyte_seq_start_x;
        readbyte_seq_start    <= readbyte_seq_start_x;
        sendbyte_byte         <= sendbyte_byte_x;
        i2c_data              <= i2c_data_x;
        i2c_bytes             <= i2c_bytes_x;
        read_seq_ctr          <= read_seq_ctr_x;
        STATE                 <= NEXT_STATE;
      end if;
    end if;
  end process PROC_I2C_MASTER_TRANSFER;
  
        
  PROC_I2C_MASTER: process(STATE,
                           i2c_start,
                           startstop_done,
                           read_seq_ctr,
                           sendbyte_done,
                           sendbyte_ack,
                           readbyte_done,
                           startstop_done
                           )

  begin
    -- Defaults
    sda_master                <= '1';
    scl_master                <= '1';
    i2c_busy_x                <= '1';
    startstop_select_x        <= '0';
    startstop_seq_start_x     <= '0';
    sendbyte_seq_start_x      <= '0';
    sendbyte_byte_x           <= (others => '0');
    readbyte_seq_start_x      <= '0';
    i2c_data_x                <= i2c_data;
    i2c_bytes_x               <= i2c_bytes;
    read_seq_ctr_x            <= read_seq_ctr;
    
    case STATE is

      when S_RESET =>
        i2c_data_x              <= (others => '0');
        i2c_bytes_x             <= (others => '0');
        NEXT_STATE              <= S_IDLE;
        
      when S_IDLE =>
        if (i2c_start = '1') then
          i2c_data_x            <= x"8000_0000"; -- Set Running, clear all
                                                 -- other bits 
          NEXT_STATE            <= S_START;
        else
          i2c_busy_x            <= '0';
          i2c_data_x            <= i2c_data and x"7fff_ffff";  -- clear running
                                                               -- bit;
          read_seq_ctr_x        <= '0';
          NEXT_STATE            <= S_IDLE;
        end if;
            
        -- I2C START Sequence 
      when S_START =>
        startstop_select_x      <= '1';
        startstop_seq_start_x   <= '1';
        NEXT_STATE              <= S_START_WAIT;
        
      when S_START_WAIT =>
        if (startstop_done = '0') then
          NEXT_STATE            <= S_START_WAIT;
        else
          sda_master            <= '0';
          scl_master            <= '0';
          NEXT_STATE            <= S_SEND_CHIP_ID;
        end if;
                   
        -- I2C SEND ChipId Sequence
      when S_SEND_CHIP_ID =>
        scl_master                  <= '0';
        sendbyte_byte_x(7 downto 1) <= i2c_chipid;
        if (read_seq_ctr = '0') then
          sendbyte_byte_x(0)    <= '0';
        else
          sendbyte_byte_x(0)    <= '1';
        end if;
        sendbyte_seq_start_x    <= '1';
        NEXT_STATE              <= S_SEND_CHIP_ID_WAIT;
        
      when S_SEND_CHIP_ID_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE            <= S_SEND_CHIP_ID_WAIT;
        else
          scl_master            <= '0';
          if (sendbyte_ack = '0') then
            i2c_data_x          <= i2c_data or x"0100_0000";
            NEXT_STATE          <= S_STOP;
          else
            if (read_seq_ctr = '0') then
              read_seq_ctr_x    <= '1';
              NEXT_STATE        <= S_SEND_REGISTER;
            else
              NEXT_STATE        <= S_GET_DATA;
            end if;
          end if;
        end if;
        
        -- I2C SEND RegisterId
      when S_SEND_REGISTER =>
        scl_master              <= '0';
        sendbyte_byte_x         <= i2c_registerid;          
        sendbyte_seq_start_x    <= '1';
        NEXT_STATE              <= S_SEND_REGISTER_WAIT;
        
      when S_SEND_REGISTER_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE            <= S_SEND_REGISTER_WAIT;
        else
          scl_master            <= '0';
          if (sendbyte_ack = '0') then
            i2c_data_x          <= i2c_data or x"0200_0000";
            NEXT_STATE          <= S_STOP;
          else
            if (i2c_rw_bit = '0') then
              NEXT_STATE        <= S_SEND_DATA;
            else
              NEXT_STATE        <= S_START;
            end if;
          end if;
        end if;

        -- I2C SEND DataWord
      when S_SEND_DATA =>
        scl_master              <= '0';
        sendbyte_byte_x         <= i2c_register_data;
        sendbyte_seq_start_x    <= '1';
        NEXT_STATE              <= S_SEND_DATA_WAIT;
        
      when S_SEND_DATA_WAIT =>
        if (sendbyte_done = '0') then
          NEXT_STATE            <= S_SEND_DATA_WAIT;
        else
          scl_master            <= '0';
          if (sendbyte_ack = '0') then
            i2c_data_x          <= i2c_data or x"0400_0000";
          end if;
          NEXT_STATE            <= S_STOP;
        end if;

        -- I2C GET DataWord
      when S_GET_DATA =>
        scl_master              <= '0';
        readbyte_seq_start_x    <= '1';
        NEXT_STATE              <= S_GET_DATA_WAIT;
        
      when S_GET_DATA_WAIT =>
        if (readbyte_done = '0') then
          NEXT_STATE            <= S_GET_DATA_WAIT;
        else
          scl_master                    <= '0';
          i2c_data_x(7 downto 0)<= readbyte_byte(7 downto 0);
          i2c_bytes_x           <= readbyte_byte;
          NEXT_STATE            <= S_STOP;
        end if;
        
        -- I2C STOP Sequence 
      when S_STOP =>
        sda_master              <= '0';
        scl_master              <= '0';
        startstop_select_x      <= '0';
        startstop_seq_start_x   <= '1';
        NEXT_STATE              <= S_STOP_WAIT;
        
      when S_STOP_WAIT =>
        if (startstop_done = '0') then
          NEXT_STATE            <= S_STOP_WAIT;
        else
          i2c_data_x            <= i2c_data or x"4000_0000"; -- Set DONE Bit
          NEXT_STATE            <= S_IDLE;
        end if;
        
    end case;
  end process PROC_I2C_MASTER;

  PROC_I2C_DATA_MULTIPLEXER: process(CLK_IN)
  begin 
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_data_internal_o       <= (others => '0');
        i2c_data_internal_bytes_o <= (others => '0');
        i2c_data_slave            <= (others => '0');
        command_busy_o            <= '0';
      else
        if (internal_command = '0' and internal_command_d = '0') then  
          i2c_data_slave            <= i2c_data;
        else
          i2c_data_internal_o       <= i2c_data;
          i2c_data_internal_bytes_o <= i2c_bytes;
        end if;
      end if;
      command_busy_o                <= i2c_busy;
    end if;
  end process PROC_I2C_DATA_MULTIPLEXER;
  
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
  --   D[29:27] RESERVED        set all to '0'
  --   D[26:24] I2C_NUM_BYTES   number of bytes to be read 1..4       
  --   D[23:16] I2C_ADDRESS     address of I2C chip
  --   D[15:8]  I2C_REG_ADDRESS command byte for access
  --   D[7:0]   I2C_DATA        data to be written
  --   
  --   Read bit definition
  --   ===================
  --   
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
        internal_command   <= '0';
        internal_command_d <= '0';

        i2c_chipid              <= (others => '0');    
        i2c_rw_bit              <= '0';
        i2c_num_bytes           <= "001";
        i2c_registerid          <= (others => '0');    
        i2c_register_data       <= (others => '0');    
        i2c_register_value_read <= (others => '0');
            
      else
        slv_unknown_addr_o     <= '0';
        slv_no_more_data_o     <= '0';
        slv_data_out_o         <= (others => '0');
        i2c_start              <= '0';

        internal_command_d     <= internal_command;
                
        if (i2c_busy = '0' and internal_command_d = '1') then
          internal_command     <= '0';
          slv_ack_o            <= '0';

        elsif (i2c_busy = '0' and INTERNAL_COMMAND_IN(31) = '1') then
          -- Internal Interface Command
          i2c_rw_bit           <= INTERNAL_COMMAND_IN(30);
          i2c_num_bytes        <= unsigned(INTERNAL_COMMAND_IN(26 downto 24));
          i2c_chipid           <= INTERNAL_COMMAND_IN(22 downto 16);
          i2c_registerid       <= INTERNAL_COMMAND_IN(15 downto 8);
          i2c_register_data    <= INTERNAL_COMMAND_IN(7 downto 0); 
          i2c_start            <= '1';
          internal_command     <= '1';
          slv_ack_o            <= '0';

        elsif (SLV_WRITE_IN  = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              if (internal_command = '0' and
                  I2C_LOCK_IN      = '0' and
                  i2c_busy         = '0' and
                  SLV_DATA_IN(31)  = '1') then
                i2c_rw_bit         <= SLV_DATA_IN(30);
                if (SLV_DATA_IN(29 downto 24) = "111111") then
                  i2c_num_bytes    <= "001";
                else
                  i2c_num_bytes    <= unsigned(SLV_DATA_IN(26 downto 24));
                end if;       
                i2c_chipid         <= SLV_DATA_IN(22 downto 16);
                i2c_registerid     <= SLV_DATA_IN(15 downto 8);
                i2c_register_data  <= SLV_DATA_IN(7 downto 0); 
                i2c_start          <= '1';
                slv_ack_o          <= '1';
              else
                slv_no_more_data_o <= '1';
                slv_ack_o          <= '0';
              end if;

            when others =>
              slv_unknown_addr_o   <= '1';
              slv_ack_o            <= '0';
          end case;
              
        elsif (SLV_READ_IN = '1') then
          case SLV_ADDR_IN is
            when x"0000" =>
              if (internal_command = '0' and
                  I2C_LOCK_IN      = '0' and
                  i2c_busy         = '0') then
                slv_data_out_o     <= i2c_data_slave;
                slv_ack_o          <= '1';
              else
                slv_data_out_o     <= (others => '0');
                slv_no_more_data_o <= '1';
                slv_ack_o          <= '0';
              end if;

            when x"0001" =>
              slv_data_out_o       <= i2c_bytes;
              slv_ack_o            <= '1';
              
            when others =>
              slv_unknown_addr_o   <= '1';
              slv_ack_o            <= '0';
          end case;   
              
        else
          slv_ack_o            <= '0';
        end if;

      end if;
    end if;           
  end process PROC_SLAVE_BUS;


  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------

  -- I2C Outputs
  sda_o                <= (sda_master    and
                           sda_startstop and
                           sda_sendbyte  and
                           sda_readbyte
                           );
  SDA_INOUT            <= '0' when (sda_o = '0') else 'Z';
                       
  scl_o                <= (scl_master    and
                           scl_startstop and
                           scl_sendbyte  and
                           scl_readbyte
                           );
  SCL_INOUT            <= '0' when (scl_o = '0') else 'Z';
                       
  COMMAND_BUSY_OUT     <= command_busy_o;
  I2C_DATA_OUT         <= i2c_data_internal_o;
  I2C_DATA_BYTES_OUT   <= i2c_data_internal_bytes_o;
  
  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o; 

end Behavioral;
