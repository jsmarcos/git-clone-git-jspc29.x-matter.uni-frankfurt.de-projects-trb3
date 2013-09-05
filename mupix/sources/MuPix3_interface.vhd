-----------------------------------------------------------------------------
-- MUPIX3 readout interface
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
-- Adepted to TRBv3 Readout: Tobias Weber, University Mainz
-----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.mupix_components.all;

entity mupix_interface is
  port (
    rstn       : in  std_logic;
    clk        : in  std_logic;
    -- MUPIX IF
    ldpix      : out std_logic;
    ldcol      : out std_logic;
    rdcol      : out std_logic;
    pulldown   : out std_logic;
    timestamps : out std_logic_vector(7 downto 0);
    priout     : in  std_logic;
    hit_col    : in  std_logic_vector(5 downto 0);
    hit_row    : in  std_logic_vector(5 downto 0);
    hit_time   : in  std_logic_vector(7 downto 0);

    -- MEMORY IF
    memdata    : out std_logic_vector(31 downto 0);
    memwren    : out std_logic;
    endofevent : out std_logic;

    --Readout Indicator
    ro_busy : out std_logic;

    --TRB SlowControl
    SLV_READ_IN          : in  std_logic;
    SLV_WRITE_IN         : in  std_logic;
    SLV_DATA_OUT         : out std_logic_vector(31 downto 0);
    SLV_DATA_IN          : in  std_logic_vector(31 downto 0);
    SLV_ADDR_IN          : in  std_logic_vector(15 downto 0);
    SLV_ACK_OUT          : out std_logic;
    SLV_NO_MORE_DATA_OUT : out std_logic;
    SLV_UNKNOWN_ADDR_OUT : out std_logic

    );
end mupix_interface;


architecture RTL of mupix_interface is
  

  type   ro_state_type is (reset, waiting, readman, loadpix, pulld, loadcol, readcol, hitgenerator, hitgeneratorwait);
  signal state : ro_state_type;



  signal delcounter : unsigned(3 downto 0);
  signal delaycounters : std_logic_vector(31 downto 0);

  signal ro_busy_int : std_logic;

  signal graycount : std_logic_vector(7 downto 0);

  signal eventcounter : unsigned(31 downto 0);

  signal hitcounter : unsigned(10 downto 0);


  signal triggering            : std_logic;
  signal busy_r                : std_logic := '0';
  signal continousread         : std_logic;
  signal readnow               : std_logic;
  signal readmanual            : std_logic;
  signal reseteventcount       : std_logic;
  signal generatehit           : std_logic;
  signal generatehits          : std_logic;
  signal generatetriggeredhits : std_logic;

  signal ngeneratehits           : std_logic_vector(15 downto 0);
  signal ngeneratehitscounter    : unsigned(15 downto 0);
  signal generatehitswaitcounter : unsigned(31 downto 0);

  signal gen_hit_col  : std_logic_vector(5 downto 0) := (others => '0');
  signal gen_hit_row  : std_logic_vector(5 downto 0) := (others => '0');
  signal gen_hit_time : std_logic_vector(7 downto 0) := (others => '0');

  signal testoutro : std_logic_vector (127 downto 0);


  signal resetgraycounter : std_logic;

  --Control Registers
  signal roregwritten         : std_logic                     := '0';
  signal roregister           : std_logic_vector(31 downto 0) := (others => '0');
  signal rocontrolbits        : std_logic_vector(31 downto 0) := (others => '0');
  signal timestampcontrolbits : std_logic_vector(31 downto 0) := (others => '0');
  signal generatehitswait     : std_logic_vector(31 downto 0) := (others => '0');
  
begin

  -----------------------------------------------------------------------------
  --SLV Bus Handler
  --x0020: Readoutregister
  --x0021: Readout Controlbits (manual readout)
  --x0022: Timestamp Controlbits
  --x0023: Hit Generator
  --x0024: Delay Counters
  --x0025: EventCounter
  -----------------------------------------------------------------------------

  SLV_HANDLER : process(clk)
  begin  -- process SLV_HANDLER
    if rising_edge(clk) then
      SLV_DATA_OUT         <= (others => '0');
      SLV_UNKNOWN_ADDR_OUT <= '0';
      SLV_NO_MORE_DATA_OUT <= '0';
      SLV_ACK_OUT          <= '0';
      roregwritten         <= '0';

      if SLV_READ_IN = '1' then
        case SLV_ADDR_IN is
          when x"0020" =>
            SLV_DATA_OUT <= roregister;
            SLV_ACK_OUT  <= '1';
          when x"0021" =>
            SLV_DATA_OUT <= rocontrolbits;
            SLV_ACK_OUT  <= '1';
          when x"0022" =>
            SLV_DATA_OUT <= timestampcontrolbits;
            SLV_ACK_OUT  <= '1';
          when x"0023" =>
            SLV_DATA_OUT <= generatehitswait;
            SLV_ACK_OUT  <= '1';
          when x"0024" =>
            SLV_DATA_OUT <= delaycounters;
            SLV_ACK_OUT  <= '1';
          when x"0025" =>
            SLV_DATA_OUT <= std_logic_vector(eventcounter);
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;
      end if;

      if SLV_WRITE_IN = '1' then
        case SLV_ADDR_IN is
          when x"0020" =>
            roregister   <= SLV_DATA_IN;
            roregwritten <= '1';        --trigger the readout
            SLV_ACK_OUT  <= '1';
          when x"0021" =>
            rocontrolbits <= SLV_DATA_IN;
            SLV_ACK_OUT   <= '1';
          when x"0022" =>
            timestampcontrolbits <= SLV_DATA_IN;
            SLV_ACK_OUT          <= '1';
          when x"0023" =>
            generatehitswait <= SLV_DATA_IN;
            SLV_ACK_OUT      <= '1';
          when x"0024" =>
            delaycounters <= SLV_DATA_IN;
            SLV_ACK_OUT <= '1';
          when others =>
            SLV_UNKNOWN_ADDR_OUT <= '1';
        end case;
      end if;
    end if;
  end process SLV_HANDLER;

  -----------------------------------------------------------------------------
  --Readout Control
  -----------------------------------------------------------------------------

  process(rstn, clk)
  begin
    if(rstn = '0') then
      triggering            <= '0';
      continousread         <= '0';
      readnow               <= '0';
      readmanual            <= '0';
      reseteventcount       <= '0';
      generatehit           <= '0';
      generatehits          <= '0';
      generatetriggeredhits <= '0';
      ngeneratehits         <= (others => '0');
    elsif(clk'event and clk = '1') then
      triggering    <= roregister(0);
      continousread <= roregister(1);
      if(roregister(2) = '1' and roregwritten = '1') then
        readnow <= '1';
      else
        readnow <= '0';
      end if;
      readmanual <= roregister(3);
      if(roregister(4) = '1' and roregwritten = '1') then
        reseteventcount <= '1';
      else
        reseteventcount <= '0';
      end if;
      if(roregister(5) = '1' and roregwritten = '1') then
        generatehit <= '1';
      else
        generatehit <= '0';
      end if;
      generatehits          <= roregister(6);
      generatetriggeredhits <= roregister(8);
      ngeneratehits         <= roregister(31 downto 16);
    end if;
  end process;


  --testout_ena <= '1';

  --testout(127 downto 64) <= testoutro(127 downto 64);
  --testout(63 downto 16)  <= testouttlu(63 downto 16);
  --testout(15 downto 0)   <= testoutro(15 downto 0);

  -----------------------------------------------------------------------------
  --MuPix 3 Readout Statemachine
  -----------------------------------------------------------------------------

  ro_statemachine : process(rstn, clk)
  begin
    
    if(rstn = '0') then
      state        <= waiting;
      ldpix        <= '0';
      ldcol        <= '0';
      rdcol        <= '0';
      pulldown     <= '0';
      memwren      <= '0';
      ro_busy_int  <= '0';
      eventcounter <= (others => '0');
      testoutro    <= (others => '0');
      endofevent   <= '0';
    elsif(clk'event and clk = '1') then
      testoutro      <= (others => '0');
      testoutro(124) <= priout;

      case state is
        when reset =>
          testoutro(0) <= '1';
          state        <= waiting;
          ldpix        <= '0';
          ldcol        <= '0';
          rdcol        <= '0';
          pulldown     <= '0';
          memwren      <= '0';
          ro_busy_int  <= '0';
          eventcounter <= (others => '0');
          --timeoutcounter <= (others => '0');
          endofevent   <= '0';
        when waiting =>
          testoutro(1) <= '1';
          memwren      <= '0';
          ro_busy_int  <= '0';
          endofevent   <= '0';
          hitcounter   <= (others => '0');
          eventcounter <= eventcounter;
          if(reseteventcount = '1') then
            eventcounter <= (others => '0');
          end if;
          ldpix    <= '0';
          ldcol    <= '0';
          rdcol    <= '0';
          pulldown <= '0';
          if(readmanual = '1') then
            state <= readman;
          elsif(continousread = '1' or readnow = '1') then
            state        <= loadpix;
            ldpix        <= '1';
            delcounter   <= unsigned(delaycounters(3 downto 0));
            eventcounter <= eventcounter + 1;
          elsif(generatetriggeredhits = '1' and busy_r = '0') then
            state        <= hitgenerator;
            delcounter   <= "0100";
            eventcounter <= eventcounter + 1;
          elsif(generatehit = '1' or generatehits = '1') then
            state        <= hitgenerator;
            delcounter   <= "0100";
            eventcounter <= eventcounter + 1;
          else
            state <= waiting;
          end if;
          
        when readman =>
          testoutro(9) <= '1';
          ro_busy_int  <= '1';
          ldpix        <= rocontrolbits(0);
          pulldown     <= rocontrolbits(1);
          ldcol        <= rocontrolbits(2);
          rdcol        <= rocontrolbits(3);
          if(readmanual = '1') then
            state <= readman;
          else
            state <= waiting;
          end if;
          endofevent <= '0';
        when loadpix =>
          ro_busy_int  <= '1';
          testoutro(2) <= '1';
          ldpix        <= '0';
          delcounter   <= delcounter - 1;
          memwren      <= '0';
          state        <= loadpix;
          if(delcounter = "100") then   -- write event header
            memdata <= "11111010101111101010101110111010";     --0xFABEABBA
            memwren <= '1';
          elsif(delcounter = "011") then  -- write event counter
            memdata <= std_logic_vector(eventcounter);
            memwren <= '1';
          elsif(delcounter = "001") then
            memwren <= '1';
            memdata <= x"00000000";     --add empty trigger
                                        --number
          end if;
          if(delcounter = "000") then
            state      <= pulld;
            pulldown   <= '1';
            delcounter <= unsigned(delaycounters(7 downto 4));
          end if;
          endofevent <= '0';
        when pulld =>
          testoutro(3) <= '1';
          memwren      <= '0';
          if unsigned(delaycounters(7 downto 4)) = delcounter + 1 then
            pulldown     <= '0';
          end if;
          delcounter   <= delcounter - 1;
          state        <= pulld;
          if(delcounter = "000") then
            state      <= loadcol;
            ldcol      <= '1';
            delcounter <= unsigned(delaycounters(11 downto 8));
          end if;
          endofevent <= '0';
        when loadcol =>
          testoutro(4) <= '1';
          memwren      <= '0';
          if(delcounter + 1 = unsigned(delaycounters(11 downto 8))) then
            ldcol <= '0';
          end if;
          delcounter   <= delcounter - 1;
          state        <= loadcol;
          endofevent   <= '0';
          if(delcounter = "000" and priout = '1') then
            state      <= readcol;
            rdcol      <= '1';
            delcounter <= unsigned(delaycounters(15 downto 12));
          elsif(delcounter = "000") then
            -- end of event
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
            state      <= waiting;
          end if;
        when readcol =>
          testoutro(5) <= '1';
          if(delcounter = unsigned(delaycounters(15 downto 12)) - unsigned(delaycounters(23 downto 20))) then
            rdcol <= '0';
          end if;
          delcounter   <= delcounter - 1;
          memwren      <= '0';
          state        <= readcol;
          endofevent   <= '0';
          if(delcounter = "010") then
            memdata    <= "111100001111" & hit_col & hit_row & hit_time;  --0xF0F
            memwren    <= '1';
            hitcounter <= hitcounter + 1;
            state      <= readcol;
          elsif(delcounter = "000" and hitcounter = "11111111111") then
            -- 2048 hits - force end of event 
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
            state      <= waiting;
          elsif(delcounter = "000" and priout = '1') then
            state      <= readcol;
            rdcol      <= '1';
            delcounter <= unsigned(delaycounters(15 downto 12));
          elsif(delcounter = "000") then
            state      <= pulld;
            pulldown   <= '1';
            delcounter <= unsigned(delaycounters(19 downto 16));
          end if;
          
        when hitgenerator =>
          ro_busy_int  <= '1';
          testoutro(6) <= '1';
          state        <= hitgenerator;
          if(delcounter = "0100") then   -- write event header
            state                   <= hitgenerator;
            memdata                 <= "11111010101111101010101110111010";  --0xFABEABBA
            memwren                 <= '1';
            ngeneratehitscounter    <= unsigned(ngeneratehits);
            generatehitswaitcounter <= unsigned(generatehitswait);
            gen_hit_col             <= (others => '0');
            gen_hit_row             <= (others => '0');
            gen_hit_time            <= (others => '0');
            delcounter              <= delcounter - 1;
            endofevent              <= '0';
          elsif(delcounter = "0011") then    -- write event counter
            state      <= hitgenerator;
            memdata    <= std_logic_vector(eventcounter);
            memwren    <= '1';
            delcounter <= delcounter - 1;
            endofevent <= '0';
          elsif(delcounter = "010") then
            state      <= hitgenerator;
            memwren    <= '0';
            delcounter <= delcounter - 1;
            endofevent <= '0';
          elsif(delcounter = "0001") then    -- write trigger number
            state      <= hitgenerator;
            memdata    <= (others => '0');  --empty trigger number
            memwren    <= '1';
            delcounter <= delcounter - 1;
            endofevent <= '0';
          elsif(delcounter = "0000" and ngeneratehitscounter > "0000000000000000") then
            state                <= hitgenerator;
            delcounter           <= delcounter;
            ngeneratehitscounter <= ngeneratehitscounter - 1;
            gen_hit_col          <= std_logic_vector(unsigned(gen_hit_col) + 5);
            gen_hit_row          <= std_logic_vector(unsigned(gen_hit_row) + 7);
            if(gen_hit_row > "10000") then
              gen_hit_row <= "000000";
            end if;
            memdata    <= "111100001111" & "0" & gen_hit_col(4 downto 0) & gen_hit_row & graycount;  --0xF0F
            memwren    <= '1';
            endofevent <= '0';
          elsif(delcounter = "0000" and ngeneratehitscounter = "0000000000000000" and generatehits = '0') then
            state      <= waiting;
            -- end of event
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
          elsif(delcounter = "0000" and ngeneratehitscounter = "0000000000000000" and generatehits = '1') then
            state      <= hitgeneratorwait;
            -- end of event
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
          else
            state      <= hitgenerator;
            memwren    <= '0';
            endofevent <= '0';
          end if;
          
        when hitgeneratorwait =>
          ro_busy_int             <= '0';
          state                   <= hitgeneratorwait;
          testoutro(7)            <= '1';
          memwren                 <= '0';
          endofevent              <= '0';
          generatehitswaitcounter <= generatehitswaitcounter - 1;
          if(to_integer(generatehitswaitcounter) = 0)then
            state        <= hitgenerator;
            delcounter   <= "0100";
            eventcounter <= eventcounter + 1;
          end if;
          
        when others =>
          testoutro(8) <= '1';
          state        <= waiting;
          endofevent   <= '0';
      end case;
    end if;
  end process;

  tsgen :
  process(rstn, clk)
  begin
    if(rstn = '0') then
      timestamps <= (others => '0');
    elsif(clk'event and clk = '1') then
      if(timestampcontrolbits(8) = '1') then
        timestamps <= graycount;
      else
        timestamps <= timestampcontrolbits(7 downto 0);
      end if;
    end if;
  end process;

  resetgraycounter <= not rstn;

  grcount : Graycounter
    generic map(
      COUNTWIDTH => 8
      )
    port map(
      clk        => clk,
      reset      => resetgraycounter,
      sync_reset => timestampcontrolbits(9),
      counter    => graycount
      );

  
  ro_busy <= ro_busy_int;
end RTL;
