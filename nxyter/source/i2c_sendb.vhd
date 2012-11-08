library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library work;
use work.adcmv3_components.all;

entity i2c_sendb is
  port(
    CLK_IN          : in    std_logic;
    RESET_IN        : in    std_logic;
    DOBYTE_IN       : in    std_logic;
    I2C_SPEED_IN    : in    std_logic_vector( 8 downto 0 );
    I2C_BYTE_IN     : in    std_logic_vector( 8 downto 0 );
    I2C_BACK_OUT    : out   std_logic_vector( 8 downto 0 );
    SDA_IN          : in    std_logic;
    R_SDA_OUT       : out   std_logic;
    S_SDA_OUT       : out   std_logic;
    R_SCL_OUT       : out   std_logic;
    S_SCL_OUT       : out   std_logic;
    BDONE_OUT       : out   std_logic;
    BOK_OUT         : out   std_logic;
    BSM_OUT         : out   std_logic_vector( 3 downto 0 )
    );
end entity;

architecture Behavioral of i2c_sendb is

-- Signals
  type STATES is (SLEEP,
                  LCL,
                  WCL,
                  LCH,
                  WCH,
                  FREE,
                  DONE);
  signal CURRENT_STATE, NEXT_STATE: STATES;

  signal bsm          : std_logic_vector( 3 downto 0 );

  signal inc_bit_x    : std_logic;
  signal inc_bit      : std_logic; -- increment bit counter for byte to send
  signal rst_bit_x    : std_logic;
  signal rst_bit      : std_logic; -- reset bit counter for byte to send
  signal load_cyc_x   : std_logic;
  signal load_cyc     : std_logic; -- load cycle counter (SCL length)
  signal dec_cyc_x    : std_logic;
  signal dec_cyc      : std_logic; -- decrement cycle counter (SCL length)
  signal load_sr_x    : std_logic;
  signal load_sr      : std_logic; -- load output shift register
  signal shift_o_x    : std_logic;
  signal shift_o      : std_logic; -- output shift register control
  signal shift_i_x    : std_logic;
  signal shift_i      : std_logic; -- input shift register control
  signal bdone_x      : std_logic;
  signal bdone        : std_logic;
  signal r_scl_x      : std_logic;
  signal r_scl        : std_logic; -- output for SCL
  signal s_scl_x      : std_logic;
  signal s_scl        : std_logic; -- output for SCL

  signal bctr         : std_logic_vector( 3 downto 0 ); -- bit counter    (1...9)
  signal cctr         : unsigned(8 downto 0); -- counter for bit length
  signal bok          : std_logic;
  signal cycdone      : std_logic; -- one counter period done
  signal bytedone     : std_logic; -- all bits sents
  signal in_sr        : std_logic_vector( 8 downto 0 ); -- shift register for byte in
  signal out_sr       : std_logic_vector( 8 downto 0 ); -- shift register for byte out
  signal i2c_back     : std_logic_vector( 8 downto 0 ); -- shift register for byte in
  signal r_sda        : std_logic; -- output for SDA
  signal s_sda        : std_logic; -- output for SDA
  signal load         : std_logic; -- delay register
  signal i2c_d        : std_logic; -- auxiliary register

-- Moduls

begin

-- Bit counter  (for byte to send)
  THE_BIT_CTR_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        bctr <= (others => '0');
      elsif( rst_bit = '1' ) then
        bctr <= (others => '0');
      elsif( inc_bit = '1' ) then
        bctr <= bctr + 1;
      end if;
    end if;
  end process THE_BIT_CTR_PROC;

-- end of byte recognition
  bytedone <= '1' when (bctr = x"a") else '0';

-- Countdown for one half of SCL (adjustable clock width)
  THE_CYC_CTR_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        cctr <= (others => '0');
      elsif( load_cyc = '1' ) then
        cctr <= i2c_speed_in;
      elsif( dec_cyc = '1' ) then
        cctr <= cctr - 1;
      end if;
    end if;
  end process THE_CYC_CTR_PROC;

-- end of cycle recognition
  cycdone <= '1' when (cctr = 0) else '0';

-- Bit output
  THE_BIT_OUT_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        out_sr <= (others => '0');
        i2c_d <= '1';
      elsif( load_sr = '1' ) then
        out_sr <= i2c_byte_in;
        i2c_d  <= '1';
      elsif( shift_o = '1' ) then
        i2c_d <= out_sr(8);
        out_sr(8 downto 0) <= out_sr(7 downto 0) & '0';
      end if;
    end if;
  end process THE_BIT_OUT_PROC;

-- Bit input
  THE_BIT_IN_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if   ( reset_in = '1' ) then
        in_sr <= (others => '1');
      elsif( shift_o = '1' ) then
        in_sr(8 downto 1) <= in_sr(7 downto 0);
        in_sr(0) <= sda_in;
      end if;
    end if;
  end process THE_BIT_IN_PROC;

-- Output register for readback data (could be reduced to SR_IN_INT)
  THE_I2C_BACK_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        i2c_back <= (others => '1');
      elsif( shift_i = '1' ) then
        i2c_back(8 downto 1) <= in_sr(7 downto 0);
        i2c_back(0) <= sda_in;
      end if;
    end if;
  end process THE_I2C_BACK_PROC;

-- ByteOK is the inverted ACK bit from readback data.
  bok <= not i2c_back(0); -- BUG

-- The main state machine
-- State memory process
  STATE_MEM: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1') then
        CURRENT_STATE <= SLEEP;
        inc_bit       <= '0';
        rst_bit       <= '0';
        load_cyc      <= '0';
        dec_cyc       <= '0';
        load_sr       <= '0';
        shift_o       <= '0';
        shift_i       <= '0';
        bdone         <= '0';
        r_scl         <= '0';
        s_scl         <= '0';
      else
        CURRENT_STATE <= NEXT_STATE;
        inc_bit       <= inc_bit_x;
        rst_bit       <= rst_bit_x;
        load_cyc      <= load_cyc_x;
        dec_cyc       <= dec_cyc_x;
        load_sr       <= load_sr_x;
        shift_o       <= shift_o_x;
        shift_i       <= shift_i_x;
        bdone         <= bdone_x;
        r_scl         <= r_scl_x;
        s_scl         <= s_scl_x;
      end if;
    end if;
  end process STATE_MEM;

-- Transition matrix
  TRANSFORM: process(CURRENT_STATE, dobyte_in, cycdone, bytedone)
  begin
    NEXT_STATE <= SLEEP;
    inc_bit_x  <= '0';
    rst_bit_x  <= '0';
    load_cyc_x <= '0';
    dec_cyc_x  <= '0';
    load_sr_x  <= '0';
    shift_o_x  <= '0';
    shift_i_x  <= '0';
    bdone_x    <= '0';
    r_scl_x    <= '0';
    s_scl_x    <= '0';
    case CURRENT_STATE is
      when SLEEP  =>  if( dobyte_in = '1' ) then
                        NEXT_STATE <= LCL;
                        inc_bit_x  <= '1';
                        load_cyc_x <= '1';
                        shift_o_x  <= '1';
                        r_scl_x    <= '1';
                      else
                        NEXT_STATE <= SLEEP;
                        load_sr_x  <= '1';
                      end if;
      when LCL    =>  NEXT_STATE <= WCL;
                      dec_cyc_x  <= '1';
      when WCL    =>  if( cycdone = '1' ) then
                        NEXT_STATE <= LCH;
                        load_cyc_x <= '1';
                        s_scl_x    <= '1';
                      else
                        NEXT_STATE <= WCL;
                        dec_cyc_x  <= '1';
                      end if;
      when LCH    =>  NEXT_STATE <= WCH;
                      dec_cyc_x  <= '1';
      when WCH    =>  if   ( (cycdone = '1') and (bytedone = '0') ) then
                        NEXT_STATE <= LCL;
                        inc_bit_x  <= '1';
                        load_cyc_x <= '1';
                        shift_o_x  <= '1';
                        r_scl_x    <= '1';
                      elsif( (cycdone = '1') and (bytedone = '1') ) then
                        NEXT_STATE <= FREE;
                        shift_o_x  <= '1';
                        shift_i_x  <= '1';
                        r_scl_x    <= '1';
                      else
                        NEXT_STATE <= WCH;
                        dec_cyc_x  <= '1';
                      end if;
      when FREE   =>  NEXT_STATE <= DONE;
                      rst_bit_x  <= '1';
                      bdone_x    <= '1';
      when DONE   =>  if( dobyte_in = '0' ) then
                        NEXT_STATE <= SLEEP;
                      else
                        NEXT_STATE <= DONE;
                        rst_bit_x  <= '1';
                        bdone_x    <= '1';
                      end if;
                      -- Just in case...
      when others =>  NEXT_STATE <= SLEEP;
    end case;
  end process TRANSFORM;

-- Output decoding
  DECODE: process(CURRENT_STATE)
  begin
    case CURRENT_STATE is
      when SLEEP  =>  bsm <= x"0";
      when LCL    =>  bsm <= x"1";
      when WCL    =>  bsm <= x"2";
      when LCH    =>  bsm <= x"3";
      when WCH    =>  bsm <= x"4";
      when FREE   =>  bsm <= x"5";
      when DONE   =>  bsm <= x"6";
      when others =>  bsm <= x"f";
    end case;
  end process DECODE;

-- SCL and SDA output pulses
  THE_SDA_OUT_PROC: process( clk_in )
  begin
    if( rising_edge(clk_in) ) then
      if( reset_in = '1' ) then
        load  <= '0'; -- was a bug, found 081008
        r_sda <= '0';
        s_sda <= '0';
      else
        load  <= shift_o;
        r_sda <= load and not i2c_d;
        s_sda <= load and     i2c_d;
      end if;
    end if;
  end process THE_SDA_OUT_PROC;

-- Outputs
  r_scl_out    <= r_scl;
  s_scl_out    <= s_scl;
  r_sda_out    <= r_sda;
  s_sda_out    <= s_sda;

  i2c_back_out <= i2c_back;

  bdone_out    <= bdone;
  bok_out      <= bok;

-- Debugging
  bsm_out      <= bsm;

end Behavioral;
