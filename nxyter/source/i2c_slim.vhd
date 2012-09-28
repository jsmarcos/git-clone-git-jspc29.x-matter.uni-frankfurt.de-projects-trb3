library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.adcmv3_components.all;

-- BUG: does alway set bit 0 of address byte to zero !!!!
-- REMARK: this is not a bug, but a feature....

entity i2c_slim is
  port(
    CLK_IN          : in    std_logic;
    RESET_IN        : in    std_logic;

    -- I2C command / setup
    I2C_GO_IN       : in    std_logic; -- startbit to trigger I2C actions
    ACTION_IN       : in    std_logic; -- '0' -> write, '1' -> read
    I2C_SPEED_IN    : in    std_logic_vector( 5 downto 0 ); -- speed adjustment (to be defined)
    I2C_ADR_IN      : in    std_logic_vector( 7 downto 0 ); -- I2C address byte (R/W bit is ignored)
    I2C_CMD_IN      : in    std_logic_vector( 7 downto 0 ); -- I2C command byte (sent after address byte)
    I2C_DW_IN       : in    std_logic_vector( 7 downto 0 ); -- data word for write command
    I2C_DR_OUT      : out   std_logic_vector( 7 downto 0 ); -- data word from read command
    STATUS_OUT      : out   std_logic_vector( 7 downto 0 ); -- status and error bits
    I2C_BUSY_OUT    : out   std_logic;

    -- I2C connections
    SDA_IN          : in    std_logic;
    SDA_OUT         : out   std_logic;
    SCL_IN          : in    std_logic;
    SCL_OUT         : out   std_logic;

    -- Debug
    STAT            : out   std_logic_vector(31 downto 0)
    );
end i2c_slim;

architecture Behavioral of i2c_slim is

-- Signals
  type STATES is (SLEEP,
                  LOADA,
                  GSTART,
                  SENDA,
                  LOADC,
                  SENDC,
                  LOADD,
                  SENDD,
                  GSTOP,
                  INC,
                  E_START,
                  E_ADDR,
                  E_CMD,
                  E_WD,
                  E_RSTART,
                  E_RADDR,
                  DONE,
                  FAILED,
                  CLRERR);
  signal CURRENT_STATE, NEXT_STATE: STATES;

  signal bsm          : std_logic_vector( 4 downto 0 );
  signal phase        : std_logic; -- '0' => first phase, '1' => second phase of read cycle

  signal start_x      : std_logic;
  signal start        : std_logic; -- '0' => generate STOP, '1' => generate START
  signal dostart_x    : std_logic;
  signal dostart      : std_logic; -- trigger the GenStart module
  signal dobyte_x     : std_logic;
  signal dobyte       : std_logic; -- trigger the ByteSend module
  signal i2c_done_x   : std_logic;
  signal i2c_done     : std_logic; -- acknowledge signal to the outside world
  signal running_x    : std_logic;
  signal running      : std_logic; -- legacy

  signal load_a_x     : std_logic;
  signal load_a       : std_logic;
  signal load_c_x     : std_logic;
  signal load_c       : std_logic;
  signal load_d_x     : std_logic;
  signal load_d       : std_logic;

  signal sdone        : std_logic; -- acknowledge signal from GenStart module
  signal sok          : std_logic; -- status signal from GenStart module
  signal bdone        : std_logic; -- acknowledge signal from SendByte module
  signal bok          : std_logic; -- status signal from SendByte module
  signal e_sf         : std_logic; -- Start failed
  signal e_anak       : std_logic; -- Adress byte NAK
  signal e_cnak       : std_logic; -- Command byte NAK
  signal e_dnak       : std_logic; -- Data byte NAK
  signal e_rsf        : std_logic; -- Repeated Start failed
  signal e_ranak      : std_logic; -- Repeated Adress NAK
  signal i2c_byte     : std_logic_vector( 8 downto 0 );
  signal i2c_dr       : std_logic_vector( 8 downto 0 );

  signal s_scl        : std_logic;
  signal r_scl        : std_logic;
  signal s_sda        : std_logic;
  signal r_sda        : std_logic;
  signal r_scl_gs     : std_logic;
  signal s_scl_gs     : std_logic;
  signal r_sda_gs     : std_logic;
  signal s_sda_gs     : std_logic;
  signal r_scl_sb     : std_logic;
  signal s_scl_sb     : std_logic;
  signal r_sda_sb     : std_logic;
  signal s_sda_sb     : std_logic;

  signal gs_debug     : std_logic_vector(3 downto 0);

  signal i2c_speed    : std_logic_vector(7 downto 0);

begin

  i2c_speed <= i2c_speed_in & "00";

-- Read phase indicator
  THE_PHASE_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        phase <= '0';
      elsif( CURRENT_STATE = INC ) then
        phase <= '1';
      elsif( (CURRENT_STATE = DONE) or (CURRENT_STATE = SLEEP) ) then
        phase <= '0';
      end if;
    end if;
  end process THE_PHASE_PROC;

-- The main state machine
-- State memory process
  STATE_MEM: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        CURRENT_STATE <= SLEEP;
        start         <= '0';
        dostart       <= '0';
        dobyte        <= '0';
        i2c_done      <= '0';
        running       <= '0';
        load_a        <= '0';
        load_c        <= '0';
        load_d        <= '0';
      else
        CURRENT_STATE <= NEXT_STATE;
        start         <= start_x;
        dostart       <= dostart_x;
        dobyte        <= dobyte_x;
        i2c_done      <= i2c_done_x;
        running       <= running_x;
        load_a        <= load_a_x;
        load_c        <= load_c_x;
        load_d        <= load_d_x;
      end if;
    end if;
  end process STATE_MEM;

-- Transition matrix
  TRANSFORM: process(CURRENT_STATE, i2c_go_in, sdone, sok, phase, bdone, bok, action_in)
  begin
    NEXT_STATE <= SLEEP;
    start_x    <= '0';
    dostart_x  <= '0';
    dobyte_x   <= '0';
    i2c_done_x <= '0';
    running_x  <= '1';
    load_a_x   <= '0';
    load_c_x   <= '0';
    load_d_x   <= '0';
    case CURRENT_STATE is
      when SLEEP      =>  if( i2c_go_in = '1' ) then
                            NEXT_STATE <= CLRERR;
                          else
                            NEXT_STATE <= SLEEP;
                            running_x  <= '0';
                          end if;
      when CLRERR     =>  NEXT_STATE <= LOADA;
                          load_a_x   <= '1';
      when LOADA      =>  NEXT_STATE <= GSTART;
                          start_x    <= '1';
                          dostart_x  <= '1';
      when GSTART     =>  if   ( (sdone = '1') and (sok = '1') ) then
                            NEXT_STATE <= SENDA;
                            dobyte_x   <= '1';
                          elsif( (sdone = '1') and (sok = '0') and (phase = '0') ) then
                            NEXT_STATE <= E_START; -- first START condition failed
                          elsif( (sdone = '1') and (sok = '0') and (phase = '1') ) then
                            NEXT_STATE <= E_RSTART; -- second START condition failed
                          else
                            NEXT_STATE <= GSTART;
                            start_x    <= '1';
                            dostart_x  <= '1';
                          end if;
      when E_START    =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when E_RSTART   =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when SENDA      =>  if   ( (bdone = '1') and (bok = '1') and (action_in = '0') ) then
                            NEXT_STATE <= LOADC; -- I2C write
                            load_c_x   <= '1';
                          elsif( (bdone = '1') and (bok = '1') and (action_in = '1') and (phase = '0') ) then
                            NEXT_STATE <= LOADC;    -- I2C read, send register address
                            load_c_x   <= '1';
                          elsif( (bdone = '1') and (bok = '1') and (action_in = '1') and (phase = '1') ) then
                            NEXT_STATE <= LOADD;    -- I2C read, send 0xff dummy byte
                            load_d_x   <= '1';
                          elsif( (bdone = '1') and (bok = '0') and (phase = '0') ) then
                            NEXT_STATE <= E_ADDR; -- first address phase failed
                          elsif( (bdone = '1') and (bok = '0') and (phase = '1') ) then
                            NEXT_STATE <= E_RADDR; -- second address phase failed
                          else
                            NEXT_STATE <= SENDA;
                            dobyte_x   <= '1';
                          end if;
      when E_ADDR     =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when E_RADDR    =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when LOADC      =>  NEXT_STATE <= SENDC;
--                          dobyte_x   <= '1';
      when SENDC      =>  if   ( (bdone = '1') and (bok = '1') and (action_in = '0') ) then
                            NEXT_STATE <= LOADD; -- I2C write, prepare data
                            load_d_x   <= '1';
                          elsif( (bdone = '1') and (bok = '1') and (action_in = '1') ) then
                            NEXT_STATE <= GSTOP; -- I2C read, first phase ends
                            dostart_x  <= '1';
                          elsif( (bdone = '1') and (bok = '0') ) then
                            NEXT_STATE <= E_CMD; -- command phase failed
                          else
                            NEXT_STATE <= SENDC;
                            dobyte_x   <= '1';
                          end if;
      when E_CMD      =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when LOADD      =>  NEXT_STATE <= SENDD;
      when SENDD      =>  if   ( (bdone = '1') and (bok = '1') and (action_in = '0') ) then
                            NEXT_STATE <= GSTOP;    -- I2C write, data phase failed
                            dostart_x  <= '1';
                          elsif( (bdone = '1') and                 (action_in = '1') ) then
                            NEXT_STATE <= GSTOP; -- I2C read, data phase
                            dostart_x  <= '1';
                          elsif( (bdone = '1') and (bok = '0') and (action_in = '0') ) then
                            NEXT_STATE <= E_WD; -- I2C write, data phase failed
                          else
                            NEXT_STATE <= SENDD;
                            dobyte_x   <= '1';
                          end if;
      when E_WD       =>  NEXT_STATE <= FAILED;
                          dostart_x  <= '1';
      when GSTOP      =>  if   ( (sdone = '1') and (action_in = '0') ) then
                            NEXT_STATE <= DONE;
                          elsif( (sdone = '1') and (action_in = '1') and (phase = '1') ) then
                            NEXT_STATE <= DONE;
                          elsif( (sdone = '1') and (action_in = '1') and (phase = '0') ) then
                            NEXT_STATE <= INC;
                          else
                            NEXT_STATE <= GSTOP;
                            dostart_x  <= '1';
                          end if;
      when INC        =>  NEXT_STATE <= LOADA;
                          load_a_x   <= '1';
      when FAILED     =>  if( sdone = '1' ) then
                            NEXT_STATE <= DONE;
                            i2c_done_x <= '1';
                            running_x  <= '0';
                          else
                            NEXT_STATE <= FAILED;
                            dostart_x  <= '1';
                          end if;
      when DONE       =>  if( i2c_go_in = '1' ) then
                            NEXT_STATE <= DONE;
                            i2c_done_x <= '1';
                            running_x  <= '0';
                          else
                            NEXT_STATE <= SLEEP;
                          end if;
                          -- Just in case...
      when others     =>  NEXT_STATE <= SLEEP;
    end case;
  end process TRANSFORM;

-- Output decoding
  DECODE: process(CURRENT_STATE)
  begin
    case CURRENT_STATE is
      when SLEEP      =>  bsm <= b"00000"; -- 00
      when CLRERR     =>  bsm <= b"01100"; -- 0c
      when LOADA      =>  bsm <= b"00001"; -- 01
      when GSTART     =>  bsm <= b"00010"; -- 02
      when SENDA      =>  bsm <= b"00011"; -- 03
      when LOADC      =>  bsm <= b"00100"; -- 04
      when SENDC      =>  bsm <= b"00101"; -- 05
      when LOADD      =>  bsm <= b"00110"; -- 06
      when SENDD      =>  bsm <= b"00111"; -- 07
      when GSTOP      =>  bsm <= b"01000"; -- 08
      when INC        =>  bsm <= b"01001"; -- 09
      when FAILED     =>  bsm <= b"01010"; -- 0a
      when DONE       =>  bsm <= b"01011"; -- 0b
      when E_START    =>  bsm <= b"10000"; -- 10
      when E_RSTART   =>  bsm <= b"10001"; -- 11
      when E_ADDR     =>  bsm <= b"10010"; -- 12
      when E_RADDR    =>  bsm <= b"10011"; -- 13
      when E_CMD      =>  bsm <= b"10100"; -- 14
      when E_WD       =>  bsm <= b"10101"; -- 15
      when others     =>  bsm <= b"11111"; -- 1f
    end case;
  end process DECODE;

-- We need to load different data sets
--LOAD_DATA_PROC: process( clk_in, reset_in, CURRENT_STATE, action_in, phase)
  LOAD_DATA_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if   ( reset_in = '1' ) then
        i2c_byte <= (others => '1');
      elsif( (CURRENT_STATE = LOADA) and (phase = '0') ) then
        i2c_byte <= i2c_adr_in(6 downto 0) & '0' & '1'; -- send write address, receive ACK
      elsif( (CURRENT_STATE = LOADA) and (phase = '1') ) then
        i2c_byte <= i2c_adr_in(6 downto 0) & '1' & '1'; -- send read address, receive ACK
      elsif( (CURRENT_STATE = LOADC) and (action_in = '0') ) then
        i2c_byte <= i2c_cmd_in(7 downto 1) & '0' & '1'; -- send command byte (WRITE), receive ACK
      elsif( (CURRENT_STATE = LOADC) and (action_in = '1') ) then
        i2c_byte <= i2c_cmd_in(7 downto 1) & '1' & '1'; -- send command byte (READ), receive ACK
      elsif( (CURRENT_STATE = LOADD) and (action_in = '0') ) then
        i2c_byte <= i2c_dw_in & '1'; -- send data byte, receive ACK
      elsif( (CURRENT_STATE = LOADD) and (action_in = '1') ) then
        i2c_byte <= x"ff" & '1'; -- send 0xff byte, send NACK
      end if;
    end if;
  end process LOAD_DATA_PROC;

-- The SendByte module
  THE_I2C_SENDB: I2C_SENDB
    port map(
      CLK_IN          => clk_in,
      RESET_IN        => reset_in,
      DOBYTE_IN       => dobyte,
      I2C_SPEED_IN    => i2c_speed,
      I2C_BYTE_IN     => i2c_byte,
      I2C_BACK_OUT    => i2c_dr,
      SDA_IN          => sda_in,
      R_SDA_OUT       => r_sda_sb,
      S_SDA_OUT      => s_sda_sb,
--  SCL_IN          => scl_in,
      R_SCL_OUT       => r_scl_sb,
      S_SCL_OUT       => s_scl_sb,
      BDONE_OUT       => bdone,
      BOK_OUT         => bok,
      BSM_OUT         => open
      );

-- The GenStart module
  THE_I2C_GSTART: I2C_GSTART
    port map(
      CLK_IN          => clk_in,
      RESET_IN        => reset_in,
      START_IN        => start,
      DOSTART_IN      => dostart,
      I2C_SPEED_IN    => i2c_speed,
      SDONE_OUT       => sdone,
      SOK_OUT         => sok,
      SDA_IN          => sda_in,
      SCL_IN          => scl_in,
      R_SCL_OUT       => r_scl_gs,
      S_SCL_OUT       => s_scl_gs,
      R_SDA_OUT       => r_sda_gs,
      S_SDA_OUT       => s_sda_gs,
      BSM_OUT         => gs_debug --open
      );

  r_scl <= r_scl_gs or r_scl_sb;
  s_scl <= s_scl_gs or s_scl_sb;
  r_sda <= r_sda_gs or r_sda_sb;
  s_sda <= s_sda_gs or s_sda_sb;

-- Output flipflops for SCL and SDA lines
  THE_SCL_SDA_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        scl_out <= '1';
        sda_out <= '1';
      elsif( (r_scl = '1') and (s_scl = '0') ) then
        scl_out <= '0';
      elsif( (r_scl = '0') and (s_scl = '1') ) then
        scl_out <= '1';
      elsif( (r_sda = '1') and (s_sda = '0') ) then
        sda_out <= '0';
      elsif( (r_sda = '0') and (s_sda = '1') ) then
        sda_out <= '1';
      end if;
    end if;
  end process THE_SCL_SDA_PROC;

-- Error bits
  THE_ERR_REG_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        e_sf        <= '0';
        e_anak      <= '0';
        e_cnak      <= '0';
        e_dnak      <= '0';
        e_rsf       <= '0';
        e_ranak     <= '0';
      elsif( CURRENT_STATE = CLRERR ) then
        e_sf        <= '0';
        e_anak      <= '0';
        e_cnak      <= '0';
        e_dnak      <= '0';
        e_rsf       <= '0';
        e_ranak     <= '0';
      elsif( CURRENT_STATE = E_START ) then
        e_sf        <= '1';
      elsif( CURRENT_STATE = E_RSTART ) then
        e_rsf       <= '1';
      elsif( CURRENT_STATE = E_ADDR ) then
        e_anak      <= '1';
      elsif( CURRENT_STATE = E_RADDR ) then
        e_ranak     <= '1';
      elsif( CURRENT_STATE = E_CMD ) then
        e_cnak      <= '1';
      elsif( CURRENT_STATE = E_WD ) then
        e_dnak      <= '1';
      end if;
    end if;
  end process THE_ERR_REG_PROC;

  status_out(7) <= running;
  status_out(6) <= i2c_done;
  status_out(5) <= e_ranak;
  status_out(4) <= e_rsf;
  status_out(3) <= e_dnak;
  status_out(2) <= e_cnak;
  status_out(1) <= e_anak;
  status_out(0) <= e_sf;

-- Outputs
  i2c_dr_out      <= i2c_dr(8 downto 1);
  i2c_busy_out    <= running;

-- Debug stuff
  stat(31 downto 28) <= (others => '0');
  stat(27)           <= s_sda;
  stat(26)           <= r_sda;
  stat(25)           <= s_scl;
  stat(24)           <= r_scl;
  stat(23)           <= s_sda_sb;
  stat(22)           <= r_sda_sb;
  stat(21)           <= s_scl_sb;
  stat(20)           <= r_scl_sb;
  stat(19)           <= s_sda_gs;
  stat(18)           <= r_sda_gs;
  stat(17)           <= s_scl_gs;
  stat(16)           <= r_scl_gs;
  stat(15 downto 12) <= gs_debug;
  stat(11)           <= bok;
  stat(10)           <= bdone;
  stat(9)            <= dobyte;
  stat(8)            <= sok;
  stat(7)            <= dobyte;
  stat(6)            <= s_sda_sb;
  stat(5)            <= r_sda_sb;
  stat(4 downto 0)   <= bsm;


end Behavioral;
