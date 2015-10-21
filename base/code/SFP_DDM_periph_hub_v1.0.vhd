----------------------------------------------------------------------------------
-- Company:             GSI, Darmstadt (RBEE)
-- Engineer:            Henning Heggen
-- 
-- Create Date:         2015/08/11
-- Design Name: 
-- Module Name:         SFP_DDM_periph_hub - Behavioral 
-- Project Name: 
-- Target Devices:      TRB3 peripheral FPGA with HUB Addon
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

library work;
use work.trb_net_std.all;


entity SFP_DDM_periph_hub is
  port(
    CLK100    : in std_logic;
    TRB_RESET : in std_logic;

    BUSDDM_RX : in  CTRLBUS_RX;
    BUSDDM_TX : out CTRLBUS_TX;

    SCL_EXT : out   std_logic_vector(6 downto 1);
    SDA_EXT : inout std_logic_vector(6 downto 1)
    );
end SFP_DDM_periph_hub;

architecture Behavioral of SFP_DDM_periph_hub is

  -- Control and data register
  signal CTRL_DATA_REG : std_logic_vector(2*32-1 downto 0) := x"FBFBFBFBFBFBFFFF";

  -- I2C state machine signals
  signal SCL      : std_logic;
  signal SDA      : std_logic;
  signal SDA_IN   : std_logic;
  signal resetI2C : std_logic;
  type state_type is (reset, start, s00, s01, s02, s03, s04, s05, s06, s07, s08, s09,
                      s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, stop0, stop1, stop2, Err);
  signal state         : state_type;
  signal bitcount      : integer range 0 to 7;
  constant slaveAddr_W : std_logic_vector(7 downto 0) := "10100010";  --slaveAddr & '0';
  constant slaveAddr_R : std_logic_vector(7 downto 0) := "10100011";  --slaveAddr & '1';
  signal byteAddr      : std_logic_vector(7 downto 0) := x"68";       -- Address of first diagnostic byte to read (2 bytes read)
                                                                      -- Bytes 96/97:       Temperature MSB/LSB
                                                                      -- Bytes 98/99:       Vcc MSB/LSB
                                                                      -- Bytes 100/101:     Tx bias current
                                                                      -- Bytes 102/103:     Transceiver Tx power MSB/LSB
                                                                      -- Bytes 104/105:     Transceiver Rx power MSB/LSB
  signal dataRcvd      : std_logic_vector(15 downto 0);

  -- I2C output signals
  signal SCL_OUT : std_logic_vector(6 downto 1);
  signal SDA_OUT : std_logic_vector(6 downto 1);

  -- Clock division for I2C state machine
  signal div512  : unsigned(8 downto 0) := (others => '0');
  signal CLK_I2C : std_logic;

  -- Signals for control state machine / multiplexing
  signal SEL    : integer range 1 to 6     := 1;
  signal enable : std_logic_vector(6 downto 1);
  signal timer  : integer range 0 to 32767 := 0;

-------------------------------------------------------------------------------
begin  ---- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN - 
-------------------------------------------------------------------------------

  -- Output MUX
  with SEL select SCL_OUT <=
    (1      => SCL, others => '1') when 1,
    (2      => SCL, others => '1') when 2,
    (3      => SCL, others => '1') when 3,
    (4      => SCL, others => '1') when 4,
    (5      => SCL, others => '1') when 5,
    (6      => SCL, others => '1') when 6,
    (others => '1')                when others;

  with SEL select SDA_OUT <=
    (1      => SDA, others => '1') when 1,
    (2      => SDA, others => '1') when 2,
    (3      => SDA, others => '1') when 3,
    (4      => SDA, others => '1') when 4,
    (5      => SDA, others => '1') when 5,
    (6      => SDA, others => '1') when 6,
    (others => '1')                when others;

  -- Input MUX
  with SEL select SDA_IN <=
    SDA_EXT(1) when 1,
    SDA_EXT(2) when 2,
    SDA_EXT(3) when 3,
    SDA_EXT(4) when 4,
    SDA_EXT(5) when 5,
    SDA_EXT(6) when 6,
    '1'        when others;

  -- Tri-state IO-buffers
  SCL_EXT(1) <= '0' when SCL_OUT(1) = '0' else 'Z';
  SCL_EXT(2) <= '0' when SCL_OUT(2) = '0' else 'Z';
  SCL_EXT(3) <= '0' when SCL_OUT(3) = '0' else 'Z';
  SCL_EXT(4) <= '0' when SCL_OUT(4) = '0' else 'Z';
  SCL_EXT(5) <= '0' when SCL_OUT(5) = '0' else 'Z';
  SCL_EXT(6) <= '0' when SCL_OUT(6) = '0' else 'Z';

  SDA_EXT(1) <= '0' when SDA_OUT(1) = '0' else 'Z';
  SDA_EXT(2) <= '0' when SDA_OUT(2) = '0' else 'Z';
  SDA_EXT(3) <= '0' when SDA_OUT(3) = '0' else 'Z';
  SDA_EXT(4) <= '0' when SDA_OUT(4) = '0' else 'Z';
  SDA_EXT(5) <= '0' when SDA_OUT(5) = '0' else 'Z';
  SDA_EXT(6) <= '0' when SDA_OUT(6) = '0' else 'Z';

  -- Enable signals (slow control)
  enable(6 downto 1) <= CTRL_DATA_REG(5 downto 0);

  -----------------------------------------------------------------------------
  -- SFP DDM CTRL_DATA_REG Bus Handler 
  -----------------------------------------------------------------------------
  PROC_CTRL_DATA_REG : process
    variable pos : integer;
  begin
    wait until rising_edge(CLK100);
    if (TRB_RESET = '1') then
      CTRL_DATA_REG(15 downto 0) <= x"FFFF";  -- On reset, enable all channels
    end if;
    pos            := to_integer(unsigned(busddm_rx.addr))*32;
    busddm_tx.data <= CTRL_DATA_REG(pos+31 downto pos);
    busddm_tx.ack  <= busddm_rx.read;
    if busddm_rx.write = '1' and to_integer(unsigned(busddm_rx.addr)) = 0 then
      CTRL_DATA_REG(15 downto 0) <= busddm_rx.data(15 downto 0);
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Clock for I2C state machine (200kHz for 100kHz bit rate (SCL))
  ------------------------------------------------------------------------------
  I2C_Clock : process (CLK100)
  begin
    if RISING_EDGE(CLK100) then
      div512  <= to_unsigned((to_integer(div512) + 1), 9);
      CLK_I2C <= div512(8);
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Timer (Periodically toggles selected CH and resets I2C statemachine)
  ------------------------------------------------------------------------------
  Timer_Proc : process(CLK_I2C)
  begin
    if RISING_EDGE(CLK_I2C) then

      timer <= timer + 1;

      if (timer = 0) then
        if (SEL < 6) then
          SEL <= SEL + 1;
        else
          SEL <= 1;
        end if;
        resetI2C <= '1';
      else
        resetI2C <= '0';
      end if;
      
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- I2C state machine
  ------------------------------------------------------------------------------
  I2C_FSM : process (CLK_I2C, resetI2C, SEL)
  begin
    if RISING_EDGE(CLK_I2C) then
      if (resetI2C = '1') then          -- Periodic reset
        state <= reset;
      else
        case state is
          ------------------------------------------------------------------
          -- Start signal
          ------------------------------------------------------------------
          when reset =>                 -- Idle
            SCL <= '1';
            SDA <= '1';
            if (enable(SEL)) = '1' then -- If selected CH enabled -> Start
              dataRcvd <= x"0FC0";
              state    <= start;
            else
              dataRcvd <= x"0FD0"; -- If not -> mark as disabled
              state    <= stop1;
            end if;
            
          when start =>                 -- Start
            SCL      <= '1';
            SDA      <= '0';            -- SDA changes from 1 to 0 while SCL is 1 -> start
            bitcount <= 7;              -- Initializing bit counter
            state    <= s00;

          ------------------------------------------------------------------
          -- Send 7-bit slave address plus write bit, MSB first
          ------------------------------------------------------------------
          when s00 =>
            SCL   <= '0';
            SDA   <= slaveAddr_W(bitcount);
            state <= s01;

          when s01 =>
            SCL <= '1';
            if (bitcount - 1) >= 0 then
              bitcount <= bitcount - 1;
              state    <= s00;          -- Continue transfer
            else
              bitcount <= 7;
              state    <= s02;          -- Check for acknowledgement
            end if;

          -- Get acknowledgement from slave and continue
          when s02 =>
            SCL   <= '0';
            SDA   <= '1';
            state <= s03;

          when s03 =>
            SCL <= '1';
            if SDA_IN = '0' then
              state <= s04;             -- Acknowledge received => go on
            else
              state <= Err;             -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------
          -- Send 8-bit address of diagnostic byte, MSB first
          ------------------------------------------------------------------
          when s04 =>
            SCL   <= '0';
            SDA   <= byteAddr(bitcount);
            state <= s05;

          when s05 =>
            SCL <= '1';
            if (bitcount - 1) >= 0 then
              bitcount <= bitcount - 1;
              state    <= s04;          -- continue transfer
            else
              bitcount <= 7;
              state    <= s06;          -- check for acknowledgement
            end if;

          -- Get acknowledgement from slave and continue
          when s06 =>
            SCL   <= '0';
            SDA   <= '1';
            state <= s07;

          when s07 =>
            SCL <= '1';
            if SDA_IN = '0' then
              state <= s08;             -- Acknowledge received => go on
            else
              state <= Err;             -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------
          -- Send repeated start signal
          ------------------------------------------------------------------
          when s08 =>
            SCL <= '0';
            SDA <= '1';
            if SDA_IN = '0' then        -- SDA should still be 0 here from acknowledgement
              state <= s09;
            else
              state <= Err;             -- No acknowledge => abort
            end if;

          when s09 =>
            SCL   <= '1';
            SDA   <= '1';
            state <= s10;

          when s10 =>                   -- Start
            SCL   <= '1';
            SDA   <= '0';               -- SDA changes from 1 to 0 while SCL is 1 -> Start
            state <= s11;

          ------------------------------------------------------------------    
          -- Send 7-bit slave address plus read bit, MSB first
          ------------------------------------------------------------------
          when s11 =>
            SCL   <= '0';
            SDA   <= slaveAddr_R(bitcount);
            state <= s12;

          when s12 =>
            SCL <= '1';
            if (bitcount - 1) >= 0 then
              bitcount <= bitcount - 1;
              state    <= s11;          -- continue transfer
            else
              bitcount <= 7;
              state    <= s13;          -- check for acknowledgement
            end if;

          -- Get acknowledgement from slave and continue
          when s13 =>
            SCL   <= '0';
            SDA   <= '1';
            state <= s14;

          when s14 =>
            SCL <= '1';
            if SDA_IN = '0' then
              state <= s15;             -- Acknowledge received => go on
            else
              state <= Err;             -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------    
          -- Read 1st byte (MSB) from slave (MSB first)
          ------------------------------------------------------------------
          when s15 =>
            SCL   <= '0';
            SDA   <= '1';
            state <= s16;

          when s16 =>
            SCL                    <= '1';
            dataRcvd(8 + bitcount) <= SDA_IN;   -- Read byte from bus MSB first
            if (bitcount - 1) >= 0 then
              bitcount <= bitcount - 1;
              state    <= s15;
            else
              bitcount <= 7;
              state    <= s17;
            end if;

          -- Send acknowledge signal
          when s17 =>
            SCL   <= '0';
            SDA   <= '0';        -- Send acknowledge signal (0)
            state <= s18;

          when s18 =>
            SCL   <= '1';        -- Clocking out acknowledge signal
            state <= s19;

          ------------------------------------------------------------------
          -- Read 2nd byte (LSB) from slave (MSB first)
          ------------------------------------------------------------------
          when s19 =>
            SCL   <= '0';
            SDA   <= '1';
            state <= s20;

          when s20 =>
            SCL                <= '1';
            dataRcvd(bitcount) <= SDA_IN;       -- Read byte from bus MSB first
            if (bitcount - 1) >= 0 then
              bitcount <= bitcount - 1;
              state    <= s19;
            else
              bitcount <= 7;
              state    <= s21;
            end if;

          -- Send not acknowledge signal
          when s21 =>
            SCL   <= '0';
            SDA   <= '1';       -- Send not acknowledge signal (1)
            state <= s22;

          when s22 =>
            SCL   <= '1';       -- Clocking out not acknowledge signal
            state <= stop0;


          ------------------------------------------------------------------
          -- STOP transfer and handle received data
          ------------------------------------------------------------------
          when stop0 =>
            SCL   <= '0';
            SDA   <= '0';       -- SDA goes to 0 to prepare for 0 to 1 transition
            state <= stop1;

          when stop1 =>
            SCL <= '1';
            SDA <= '0';
            if (SEL = 1) then
              CTRL_DATA_REG(16+1*8-1 downto 16+(1-1)*8) <= dataRcvd(11 downto 4);
            elsif (SEL = 2) then
              CTRL_DATA_REG(16+2*8-1 downto 16+(2-1)*8) <= dataRcvd(11 downto 4);
            elsif (SEL = 3) then
              CTRL_DATA_REG(16+3*8-1 downto 16+(3-1)*8) <= dataRcvd(11 downto 4);
            elsif (SEL = 4) then
              CTRL_DATA_REG(16+4*8-1 downto 16+(4-1)*8) <= dataRcvd(11 downto 4);
            elsif (SEL = 5) then
              CTRL_DATA_REG(16+5*8-1 downto 16+(5-1)*8) <= dataRcvd(11 downto 4);
            elsif (SEL = 6) then
              CTRL_DATA_REG(16+6*8-1 downto 16+(6-1)*8) <= dataRcvd(11 downto 4);
            else
              CTRL_DATA_REG <= CTRL_DATA_REG;
            end if;
            state <= stop2;

          when stop2 =>
            SCL   <= '1';
            SDA   <= '1';       -- SDA changes from 0 to 1 while SCL is 1 -> Stop
            state <= stop2;     -- FSM idle until next reset

          ------------------------------------------------------------------
          -- Error
          ------------------------------------------------------------------
          -- Gets here only if Ack is error
          when Err =>
            SCL      <= '0';
            SDA      <= '0';
            dataRcvd <= x"0FE0";
            state    <= stop1;

          -- Catch invalid states
          when others =>
            SCL   <= '1';
            SDA   <= '1';
            state <= Err;
        end case;
      end if;
    end if;
  end process;


----------------------------------------------------------------------------------------------
end Behavioral;  --- END --- END --- END --- END --- END --- END --- END --- END --- END ---
----------------------------------------------------------------------------------------------
