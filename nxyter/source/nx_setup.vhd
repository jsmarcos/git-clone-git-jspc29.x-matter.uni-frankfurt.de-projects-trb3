library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.trb_net_std.all;
use work.trb_net_components.all;
use work.trb3_components.all;

entity nx_setup is
  port(
    CLK_IN               : in  std_logic;
    RESET_IN             : in  std_logic;

    I2C_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    I2C_COMMAND_BUSY_IN  : in  std_logic;
    I2C_DATA_IN          : in  std_logic_vector(31 downto 0);
    I2C_LOCK             : out std_logic;

    SPI_COMMAND_OUT      : out std_logic_vector(31 downto 0);
    SPI_COMMAND_BUSY_IN  : in  std_logic;
    SPI_DATA_IN          : in  std_logic_vector(31 downto 0);
    SPI_LOCK             : out std_logic;
    
    -- Slave bus         
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic;
    
    -- Debug Line
    DEBUG_OUT            : out std_logic_vector(15 downto 0)
    );
end entity;

architecture Behavioral of nx_setup is

  -- Send I2C Command
  type I2C_STATES is (I2C_IDLE,
                      I2C_WAIT_BUSY_HIGH,
                      I2C_WAIT_BUSY_LOW
                      );

  signal I2C_STATE : I2C_STATES;
  
  signal spi_command_o : std_logic_vector(31 downto 0);
  signal i2c_lock_o              : std_logic;
  signal i2c_command_o           : std_logic_vector(31 downto 0);
  signal i2c_command             : std_logic_vector(31 downto 0);
  signal i2c_command_busy        : std_logic;
  signal i2c_command_done        : std_logic;
  signal i2c_data                : std_logic_vector(31 downto 0);

  -- Write I2C Registers
  type W_STATES is (W_IDLE,
                    W_NEXT_REGISTER,
                    W_NOP,
                    W_REGISTER,
                    W_WAIT_DONE
                    );

  signal W_STATE, W_STATE_RETURN : W_STATES;

  signal write_defaults_start    : std_logic;
  signal write_i2c_command       : std_logic_vector(31 downto 0);
  signal write_i2c_lock          : std_logic;        
  signal w_register_ctr          : unsigned(7 downto 0);
  
  signal nx_ram_output_addr_i    : std_logic_vector(5 downto 0);
  signal nx_ram_input_addr_i     : std_logic_vector(5 downto 0);
  signal nx_ram_input_i          : std_logic_vector(7 downto 0);
  signal nx_ram_write_i          : std_logic;

  -- Read I2C Registers
  type R_STATES is (R_IDLE,
                    R_REGISTER,
                    R_NEXT_REGISTER,
                    R_WAIT_DONE
                    );
  
  signal R_STATE, R_STATE_RETURN : R_STATES;

  signal read_defaults_start     : std_logic;
  signal read_i2c_command        : std_logic_vector(31 downto 0);
  signal read_i2c_lock           : std_logic;        
  signal r_register_ctr          : unsigned(7 downto 0);
    
  -- RAM Handler
  signal nx_ram_input_addr       : std_logic_vector(5 downto 0);
  signal nx_ram_input            : std_logic_vector(7 downto 0);
  signal nx_ram_write            : std_logic;
  
  signal nx_ram_output_addr      : std_logic_vector(5 downto 0);
  signal nx_ram_output           : std_logic_vector(7 downto 0);
  
  -- TRBNet Slave Bus
  signal slv_data_out_o          : std_logic_vector(31 downto 0);
  signal slv_no_more_data_o      : std_logic;
  signal slv_unknown_addr_o      : std_logic;
  signal slv_ack_o               : std_logic;

  signal nx_ram_output_addr_s    : std_logic_vector(5 downto 0);
  signal nx_ram_input_addr_s     : std_logic_vector(5 downto 0);
  signal nx_ram_input_s          : std_logic_vector(7 downto 0);
  signal nx_ram_write_s          : std_logic;
  
  signal register_mem_read_s     : std_logic;
  signal register_mem_read       : std_logic;

  type register_access_type_t is array(0 to 45) of std_logic;
  constant register_access_type : register_access_type_t :=
    ('1','1','1','1','1','1','1','1',   -- 7
     '1','1','1','1','1','1','1','1',   -- 15
     '1','1','1','1','1','1','1','1',   -- 23
     '1','1','1','1','1','1','0','0',   -- 31
     '1','1','0','0','0','0','1','1',   --39
     '0','0','1','1','1','1'            -- 45
     );


  signal read_write_ding : std_logic;
  
begin

  -----------------------------------------------------------------------------
  -- DEBUG
  -----------------------------------------------------------------------------

  DEBUG_OUT(0)            <= CLK_IN;
  DEBUG_OUT(1)            <= read_defaults_start;
  DEBUG_OUT(2)            <= write_defaults_start;
  DEBUG_OUT(3)            <= i2c_lock_o;
  DEBUG_OUT(4)            <= i2c_command_busy;
  DEBUG_OUT(5)            <= i2c_command_done;
  DEBUG_OUT(6)            <= I2C_COMMAND_BUSY_IN;
  DEBUG_OUT(7)            <= register_mem_read_s;
  DEBUG_OUT(8)            <= register_mem_read;
  DEBUG_OUT(15 downto 9)  <= (others => '0');   
  
  -----------------------------------------------------------------------------
    
  -- Simple RAM to hold all nXyter I2C register settings

  
  ram_dp_1: ram_dp
    generic map (
      depth => 6,
      width => 8
      )
    port map (
      CLK   => CLK_IN,
      wr1   => nx_ram_write,
      a1    => nx_ram_input_addr,
      dout1 => open,
      din1  => nx_ram_input,
      a2    => nx_ram_output_addr,
      dout2 => nx_ram_output 
      );

  nx_ram_output_addr <= nx_ram_output_addr_s or nx_ram_output_addr_i;
  nx_ram_input_addr  <= nx_ram_input_addr_s or nx_ram_input_addr_i;
  nx_ram_input       <= nx_ram_input_s or nx_ram_input_i;
  nx_ram_write       <= nx_ram_write_s or nx_ram_write_i;
  
  ----------------------------------------------------------------------

  i2c_lock_o    <= write_i2c_lock or read_i2c_lock;
  i2c_command   <= write_i2c_command or read_i2c_command;

  PROC_SEND_I2C_COMMAND: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        i2c_command_o    <= (others => '0');
        i2c_command_busy <= '0';
        i2c_command_done <= '0';
        i2c_data         <= (others => '0');
        I2C_STATE        <= I2C_IDLE;
      else
        i2c_command_o    <= (others => '0');
        i2c_command_busy <= '0';
        i2c_command_done <= '0';
        
        case I2C_STATE is

          when I2C_IDLE =>
            if (i2c_command(31) = '1') then
              i2c_command_o    <= i2c_command;
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_HIGH;
            else
              I2C_STATE        <= I2C_IDLE;
            end if;

          when I2C_WAIT_BUSY_HIGH =>
            if (I2C_COMMAND_BUSY_IN = '0') then
              i2c_command_o    <= i2c_command_o;
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_HIGH;
            else
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_LOW;
            end if;

          when I2C_WAIT_BUSY_LOW =>
            if (I2C_COMMAND_BUSY_IN = '1') then
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_WAIT_BUSY_LOW;
            else
              i2c_data         <= I2C_DATA_IN;
              i2c_command_done <= '1';
              i2c_command_busy <= '1';
              I2C_STATE        <= I2C_IDLE;
            end if;
        end case;
        
      end if;
    end if;
  end process PROC_SEND_I2C_COMMAND;

PROC_WRITE_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        write_i2c_lock        <= '0';
        write_i2c_command     <= (others => '0');
        w_register_ctr        <= (others => '0');
        
        nx_ram_output_addr_i  <= (others => '0');

        W_STATE_RETURN        <= W_IDLE;
        W_STATE               <= W_IDLE;
      else
        write_i2c_command     <= (others => '0');
        write_i2c_lock        <= '1';

        nx_ram_output_addr_i  <= (others => '0');
        read_write_ding <= '0';
        
        case W_STATE is

          when W_IDLE =>
            if (write_defaults_start = '1') then
              w_register_ctr                  <= (others => '0');
              W_STATE                         <= W_NEXT_REGISTER;
            else
              write_i2c_lock                  <= '0';
              W_STATE                         <= W_IDLE;
            end if;

          when W_NEXT_REGISTER =>
            if (w_register_ctr <= x"2d") then
              nx_ram_output_addr_i            <= w_register_ctr(5 downto 0);
              W_STATE                         <= W_NOP;
            else
              W_STATE                         <= W_IDLE;
            end if;

          when W_NOP =>
            read_write_ding <= '1';
            W_STATE                           <= W_REGISTER;
            
          when W_REGISTER =>
            if (register_access_type(
              to_integer(unsigned(w_register_ctr))) = '1') 
            then
              write_i2c_command(31 downto 16) <= x"bf08";
              write_i2c_command(15 downto 8)  <= w_register_ctr;
              write_i2c_command(7 downto 0)   <= nx_ram_output;
              W_STATE_RETURN                  <= W_NEXT_REGISTER;
              W_STATE                         <= W_WAIT_DONE;
            else
              W_STATE                         <= W_NEXT_REGISTER;
            end if;

            w_register_ctr                    <= w_register_ctr + 1;
            
          when W_WAIT_DONE =>
            if (i2c_command_done = '0') then
              W_STATE                         <= W_WAIT_DONE;
            else
              W_STATE                         <= W_STATE_RETURN;
            end if;

        end case;
      end if;
    end if;
  end process PROC_WRITE_REGISTERS;

  PROC_READ_REGISTERS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        read_i2c_command    <= (others => '0');
        read_i2c_lock       <= '0';
        r_register_ctr      <= (others => '0');

        nx_ram_input_addr_i <= (others => '0');
        nx_ram_input_i      <= (others => '0');
        nx_ram_write_i      <= '0';

        R_STATE_RETURN      <= R_IDLE;
        R_STATE             <= R_IDLE;
      else
        read_i2c_command    <= (others => '0');
        read_i2c_lock       <= '1';

        nx_ram_input_addr_i <= (others => '0');
        nx_ram_input_i      <= (others => '0');
        nx_ram_write_i      <= '0';

        case R_STATE is
          when R_IDLE =>
            if (read_defaults_start = '1') then
              r_register_ctr                  <= (others => '0');
              R_STATE                         <= R_REGISTER;
            else
              read_i2c_lock                   <= '0';
              R_STATE                         <= R_IDLE;
            end if;

          when R_REGISTER =>
           if (register_access_type(to_integer(r_register_ctr)) = '1') then
             read_i2c_command(31 downto 16)  <= x"ff08";
             read_i2c_command(15 downto 8)   <= r_register_ctr;
             read_i2c_command(7 downto 0)    <= (others => '0');
             R_STATE_RETURN                  <= R_NEXT_REGISTER;
             R_STATE                         <= R_WAIT_DONE;
           else
             R_STATE                         <= R_NEXT_REGISTER;
           end if;
            
          when R_NEXT_REGISTER =>
            if (register_access_type(to_integer(r_register_ctr)) = '1') then
              nx_ram_input_i                  <= i2c_data(7 downto 0);
            else
              nx_ram_input_i                  <= x"be";
            end if;
            nx_ram_write_i                    <= '1';
            nx_ram_input_addr_i               <= r_register_ctr(5 downto 0);
            
            if (r_register_ctr <= x"2d") then
              r_register_ctr                  <= r_register_ctr + 1;
              R_STATE                         <= R_REGISTER;
            else
              R_STATE                         <= R_IDLE;
            end if;
            
          when R_WAIT_DONE =>
            if (i2c_command_done = '0') then
              R_STATE                         <= R_WAIT_DONE;
            else
              R_STATE                         <= R_STATE_RETURN;
            end if;

        end case;
     end if;
    end if;
  end process PROC_READ_REGISTERS;
        
  PROC_SLAVE_BUS: process(CLK_IN)
  begin
    if( rising_edge(CLK_IN) ) then
      if( RESET_IN = '1' ) then
        slv_data_out_o        <= (others => '0');
        slv_no_more_data_o    <= '0';
        slv_unknown_addr_o    <= '0';
        slv_ack_o             <= '0';
        write_defaults_start  <= '0';
        read_defaults_start   <= '0';
        register_mem_read_s   <= '0';
        register_mem_read     <= '0';
        nx_ram_output_addr_s  <= (others => '0');        
        nx_ram_input_addr_s   <= (others => '0');
        nx_ram_input_s        <= (others => '0');
        nx_ram_write_s        <= '0';
      else                    
        slv_data_out_o        <= (others => '0');
        slv_unknown_addr_o    <= '0';
        slv_no_more_data_o    <= '0';
        write_defaults_start  <= '0';
        read_defaults_start   <= '0';
        register_mem_read_s   <= '0';
        register_mem_read     <= register_mem_read_s;
        nx_ram_output_addr_s  <= (others => '0');
        nx_ram_input_addr_s   <= (others => '0');
        nx_ram_input_s        <= (others => '0');
        nx_ram_write_s        <= '0';

        if (register_mem_read = '1') then
          slv_data_out_o(7 downto 0)  <= nx_ram_output;
          slv_data_out_o(31 downto 8) <= (others => '0');
          slv_ack_o                   <= '1';

        
        elsif (SLV_WRITE_IN  = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            if (i2c_lock_o = '1') then
              slv_no_more_data_o      <= '1';
              slv_ack_o               <= '0';
            else
              if (register_access_type(
                to_integer(unsigned(SLV_ADDR_IN(5 downto 0)))) = '1')
              then
                nx_ram_input_addr_s   <= SLV_ADDR_IN(5 downto 0);
                nx_ram_input_s        <= SLV_DATA_IN(7 downto 0);
                nx_ram_write_s        <= '1';
              end if;
              slv_ack_o               <= '1';
            end if;

          else
            case SLV_ADDR_IN is
              when x"0040" =>
                write_defaults_start  <= '1';
                slv_ack_o             <= '1';
                
              when x"0041" =>
                read_defaults_start   <= '1';
                slv_ack_o             <= '1';
                                    
              when others =>          
                slv_unknown_addr_o    <= '1';
                slv_ack_o             <= '0';    
                                    
            end case;                     
          end if;

        elsif (SLV_READ_IN = '1') then
          if (SLV_ADDR_IN >= x"0000" and SLV_ADDR_IN <= x"002d") then
            nx_ram_output_addr_s      <= SLV_ADDR_IN(5 downto 0);
            register_mem_read_s       <= '1';
            slv_ack_o                 <= '0';
          else
            case SLV_ADDR_IN is       
              when x"0040" =>         
                slv_data_out_o        <= x"deadbeef";
                slv_ack_o             <= '1';
                                    
              when x"0041" =>         
                slv_data_out_o        <= i2c_data;
                slv_ack_o             <= '1';
                                    
              when others =>          
                slv_unknown_addr_o    <= '1';
                slv_ack_o             <= '0';
                                    
            end case;                 
          end if;

        else                        
          slv_ack_o                   <= '0';
        end if;

      end if;
    end if;           
  end process PROC_SLAVE_BUS;

  -----------------------------------------------------------------------------
  -- Output Signals
  -----------------------------------------------------------------------------
  
  I2C_COMMAND_OUT  <= i2c_command_o;
  I2C_LOCK         <= i2c_lock_o;
  
  SPI_COMMAND_OUT  <= spi_command_o;
  spi_command_o    <= (others => '0');

  -- Slave Bus
  SLV_DATA_OUT         <= slv_data_out_o;    
  SLV_NO_MORE_DATA_OUT <= slv_no_more_data_o; 
  SLV_UNKNOWN_ADDR_OUT <= slv_unknown_addr_o;
  SLV_ACK_OUT          <= slv_ack_o; 

end Behavioral;
