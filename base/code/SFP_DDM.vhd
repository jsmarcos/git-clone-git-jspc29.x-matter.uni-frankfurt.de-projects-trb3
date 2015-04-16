----------------------------------------------------------------------------------
-- Company:             GSI, Darmstadt (CSEE)
-- Engineer:        Henning Heggen
-- 
-- Create Date:         09:50:07 11/27/2014 
-- Design Name: 
-- Module Name:         SFP_DDM - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;


entity SFP_DDM is
  port(
    CLK100       : in    std_logic;
    SLOW_CTRL_IN : in    std_logic_vector(31 downto 0);
    DATA_OUT     : out   std_logic_vector(3*32-1 downto 0);
    SCL_EXT      : out   std_logic_vector(8 downto 1);
    SDA_EXT      : inout std_logic_vector(8 downto 1)
    );
end SFP_DDM;

architecture Behavioral of SFP_DDM is

  signal SDA_IN   : std_logic;
  signal SDA      : std_logic;
  signal SCL      : std_logic;
  signal resetI2C : std_logic;
  
  type state_type is (reset, start, s00, s01, s02, s03, s04, s05, s06, s07, s08, s09,
                      s10, s11, s12, s13, s14, s15, s16, s17, s18, s19, s20, s21, s22, stop0, stop1, stop2);
  signal state         : state_type;
  signal bitcount      : integer range 0 to 7;
  constant slaveAddr_W : std_logic_vector(7 downto 0) := "10100010";  --slaveAddr & '0';
  constant slaveAddr_R : std_logic_vector(7 downto 0) := "10100011";  --slaveAddr & '1';
  signal byteAddr      : std_logic_vector(7 downto 0);
  signal dataRcvd      : std_logic_vector(15 downto 0);
  signal latch_data    : std_logic                    := '0';

  -- Clock division for I2C state machine
  signal div512  : std_logic_vector(8 downto 0) := "000000000";
  signal CLK_I2C : std_logic;

  -- Signals for control state machine
  signal counter : integer range 0 to 127  := 0;
  signal SEL     : integer range 0 to 1535 := 0;
  signal run     : std_logic;
  signal running : std_logic               := '0';
  signal selSFPs : std_logic_vector(8 downto 1);

----------------------------------------------------------------------------------
begin  ---- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN ----- BEGIN ----- 
----------------------------------------------------------------------------------

  -- Global signal assignments
  run                    <= not SLOW_CTRL_IN(0);
  selSFPs(8 downto 1)    <= not SLOW_CTRL_IN(11 downto 4);
  DATA_OUT(95 downto 64) <= x"00000000";

  -- Address of diagnostic byte to read
  -- Bytes 96/97:       Temperature MSB/LSB
  -- Bytes 98/99:       Vcc MSB/LSB
  -- Bytes 100/101:     Tx bias current
  -- Bytes 102/103:     Transceiver Tx power MSB/LSB
  -- Bytes 104/105:     Transceiver Rx power MSB/LSB
  byteAddr <= CONV_STD_LOGIC_VECTOR(104, 8);

  ------------------------------------------------------------------------------
  -- Clock for I2C state machine
  -- FSM states toggle SCL => 2 FSM cycles = 1 SCL cycle (transfer of 1 bit)
  -- => FSM must run at twice the SCL frequency
  -- I2C standard: SCL = 100kHz => CLK_I2C needs to run at 200kHz
  ------------------------------------------------------------------------------
  I2C_Clock : process (CLK100)
  begin
    if RISING_EDGE(CLK100) then
      div512 <= div512 + 1;
      if (div512(8) = '0') then
        CLK_I2C <= '0';
      else
        CLK_I2C <= '1';
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- Slow control
  ------------------------------------------------------------------------------
  Control_FSM : process(CLK_I2C)
  begin
    if RISING_EDGE(CLK_I2C) then
      if (run = '1' and running = '0') then
        counter  <= 1;
        SEL      <= 1;
        running  <= '1';
        resetI2C <= '0';
      elsif (running = '1' and SEL /= 0) then
        resetI2C <= '0';
        counter  <= counter + 1;        -- Overflow every 128 cycles of CLK_I2C
        if (counter = 0) then
          SEL <= SEL + 1;
        end if;
        if (counter = 2) then
          case SEL is

            when 1 =>
              if (selSFPs(1) = '1') then
                resetI2C <= '1';
              end if;

            when 2 =>
              if (selSFPs(2) = '1') then
                resetI2C <= '1';
              end if;

            when 3 =>
              if (selSFPs(3) = '1') then
                resetI2C <= '1';
              end if;

            when 4 =>
              if (selSFPs(4) = '1') then
                resetI2C <= '1';
              end if;

            when 5 =>
              if (selSFPs(5) = '1') then
                resetI2C <= '1';
              end if;

            when 6 =>
              if (selSFPs(6) = '1') then
                resetI2C <= '1';
              end if;

            when 7 =>
              if (selSFPs(7) = '1') then
                resetI2C <= '1';
              end if;

            when 8 =>
              if (selSFPs(8) = '1') then
                resetI2C <= '1';
              end if;

            when 1535 =>
              SEL     <= 0;
              running <= '0';
              
            when others =>
              
          end case;
        end if;
      end if;
    end if;
  end process;

  -- I2C state machine output multiplexer (selects between SFP modules)
  process(CLK100, SEL)
  begin
    if RISING_EDGE(CLK100) then
      if (running = '0' and run = '0') then
        DATA_OUT(63 downto 0) <= x"FEFEFEFEFEFEFEFE";
      else
        case SEL is
          when 1 =>
            if (selSFPs(1) = '1') then
              SDA_EXT(1) <= SDA;
              SCL_EXT(1) <= SCL;
              SDA_IN     <= SDA_EXT(1);
              if (latch_data = '1') then
                DATA_OUT(7 downto 0) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(7 downto 0) <= x"FE";
            end if;
            
          when 2 =>
            if (selSFPs(2) = '1') then
              SDA_EXT(2) <= SDA;
              SCL_EXT(2) <= SCL;
              SDA_IN     <= SDA_EXT(2);
              if (latch_data = '1') then
                DATA_OUT(15 downto 8) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(15 downto 8) <= x"FE";
            end if;
            
          when 3 =>
            if (selSFPs(3) = '1') then
              SDA_EXT(3) <= SDA;
              SCL_EXT(3) <= SCL;
              SDA_IN     <= SDA_EXT(3);
              if (latch_data = '1') then
                DATA_OUT(23 downto 16) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(23 downto 16) <= x"FE";
            end if;

          when 4 =>
            if (selSFPs(4) = '1') then
              SDA_EXT(4) <= SDA;
              SCL_EXT(4) <= SCL;
              SDA_IN     <= SDA_EXT(4);
              if (latch_data = '1') then
                DATA_OUT(31 downto 24) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(31 downto 24) <= x"FE";
            end if;
            
          when 5 =>
            if (selSFPs(5) = '1') then
              SDA_EXT(5) <= SDA;
              SCL_EXT(5) <= SCL;
              SDA_IN     <= SDA_EXT(5);
              if (latch_data = '1') then
                DATA_OUT(39 downto 32) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(39 downto 32) <= x"FE";
            end if;

          when 6 =>
            if (selSFPs(6) = '1') then
              SDA_EXT(6) <= SDA;
              SCL_EXT(6) <= SCL;
              SDA_IN     <= SDA_EXT(6);
              if (latch_data = '1') then
                DATA_OUT(47 downto 40) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(47 downto 40) <= x"FE";
            end if;

          when 7 =>
            if (selSFPs(7) = '1') then
              SDA_EXT(7) <= SDA;
              SCL_EXT(7) <= SCL;
              SDA_IN     <= SDA_EXT(7);
              if (latch_data = '1') then
                DATA_OUT(55 downto 48) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(55 downto 48) <= x"FE";
            end if;

          when 8 =>
            if (selSFPs(8) = '1') then
              SDA_EXT(8) <= SDA;
              SCL_EXT(8) <= SCL;
              SDA_IN     <= SDA_EXT(8);
              if (latch_data = '1') then
                DATA_OUT(63 downto 56) <= dataRcvd(11 downto 4);
              end if;
            else
              DATA_OUT(63 downto 56) <= x"FE";
            end if;

          when others =>
            SCL_EXT <= (others => 'Z');
            SDA_EXT <= (others => 'Z');
        end case;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------------
  -- I2C state machine
  ------------------------------------------------------------------------------
  I2C_FSM : process (CLK_I2C, resetI2C)
  begin
    if RISING_EDGE(CLK_I2C) then
      if (resetI2C = '1') then          -- Reset
        state <= reset;
      else
        case state is
          ------------------------------------------------------------------
          -- Start signal
          ------------------------------------------------------------------
          when reset =>                 -- Idle
            SCL        <= 'Z';
            SDA        <= 'Z';
            dataRcvd   <= x"0FE0";
            latch_data <= '0';
            state      <= start;
            
          when start =>                 -- Start
            SCL      <= 'Z';
            SDA      <= '0';  -- SDA changes from 1 to 0 while SCL is 1 -> start
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
            SCL <= 'Z';
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
            SDA   <= 'Z';
            state <= s03;
            
          when s03 =>
            SCL <= 'Z';
            if SDA_IN = '0' then
              state <= s04;             -- Acknowledge received => go on
            else
              state <= stop1;           -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------
          -- Send 8-bit address of diagnostic byte, MSB first
          ------------------------------------------------------------------
          when s04 =>
            SCL   <= '0';
            SDA   <= byteAddr(bitcount);
            state <= s05;
            
          when s05 =>
            SCL <= 'Z';
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
            SDA   <= 'Z';
            state <= s07;
            
          when s07 =>
            SCL <= 'Z';
            if SDA_IN = '0' then
              state <= s08;             -- Acknowledge received => go on
            else
              state <= stop1;           -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------
          -- Send repeated start signal
          ------------------------------------------------------------------
          when s08 =>
            SCL <= '0';
            SDA <= 'Z';
            if SDA_IN = '0' then  -- SDA should still be 0 here from acknowledgement
              state <= s09;
            else
              state <= stop1;           -- No acknowledge => abort
            end if;
            
          when s09 =>
            SCL   <= 'Z';
            SDA   <= 'Z';
            state <= s10;
            
          when s10 =>                   -- Start
            SCL   <= 'Z';
            SDA   <= '0';  -- SDA changes from 1 to 0 while SCL is 1 -> Start
            state <= s11;

          ------------------------------------------------------------------    
          -- Send 7-bit slave address plus read bit, MSB first
          ------------------------------------------------------------------
          when s11 =>
            SCL   <= '0';
            SDA   <= slaveAddr_R(bitcount);
            state <= s12;
            
          when s12 =>
            SCL <= 'Z';
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
            SDA   <= 'Z';
            state <= s14;
            
          when s14 =>
            SCL <= 'Z';
            if SDA_IN = '0' then
              state <= s15;             -- Acknowledge received => go on
            else
              state <= stop1;           -- No acknowledge => abort
            end if;

          ------------------------------------------------------------------    
          -- Read 1st byte (MSB) from slave (MSB first)
          ------------------------------------------------------------------
          when s15 =>
            SCL   <= '0';
            SDA   <= 'Z';
            state <= s16;
            
          when s16 =>
            SCL                    <= 'Z';
            dataRcvd(8 + bitcount) <= SDA_IN;  -- Read byte from bus MSB first
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
            SDA   <= '0';               -- Send acknowledge signal (0)
            state <= s18;
            
          when s18 =>
            SCL   <= 'Z';               -- Clocking out acknowledge signal
            state <= s19;

          ------------------------------------------------------------------
          -- Read 2nd byte (LSB) from slave (MSB first)
          ------------------------------------------------------------------
          when s19 =>
            SCL   <= '0';
            SDA   <= 'Z';
            state <= s20;
            
          when s20 =>
            SCL                <= 'Z';
            dataRcvd(bitcount) <= SDA_IN;  -- Read byte from bus MSB first
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
            SDA   <= 'Z';               -- Send not acknowledge signal (1)
            state <= s22;
            
          when s22 =>
            SCL   <= 'Z';               -- Clocking out not acknowledge signal
            state <= stop0;


          ------------------------------------------------------------------
          -- STOP transfer and handle received data
          ------------------------------------------------------------------
          when stop0 =>
            SCL   <= '0';
            SDA   <= '0';  -- SDA goes to 0 to prepare for 0 to 1 transition
            state <= stop1;
            
          when stop1 =>
            SCL        <= 'Z';
            SDA        <= '0';
            latch_data <= '1';
            state      <= stop2;
            
          when stop2 =>
            SCL        <= 'Z';
            SDA        <= 'Z';  -- SDA changes from 0 to 1 while SCL is 1 -> Stop
            latch_data <= '0';
            state      <= stop2;        -- FSM idle until next reset

            ------------------------------------------------------------------
            -- Error (only usefull if status checked externally)
            ------------------------------------------------------------------
            -- Gets here only if Ack is error
            --WHEN x"EE" =>
            --  SCL <= '1';
            --  SDA <= '1';
            --  state <= x"EE";

          -- Catch invalid states
          when others =>
            SCL <= 'Z';
            SDA <= 'Z';
        end case;
      end if;
    end if;
  end process;


----------------------------------------------------------------------------------------------
end Behavioral;  --- END --- END --- END --- END --- END --- END --- END --- END --- END ---
----------------------------------------------------------------------------------------------
