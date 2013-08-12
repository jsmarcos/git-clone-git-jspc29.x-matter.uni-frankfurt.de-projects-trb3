-----------------------------------------------------------------------------
-- MUPIX3 readout interface
--
-- Niklaus Berger, Heidelberg University
-- nberger@physi.uni-heidelberg.de
--
-----------------------------------------------------------------------------




library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
use work.mupix_comp.all;

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
    -- TLU IF
    trig    : in  std_logic;
    busy    : out std_logic;
    trigclk : out std_logic;

    -- Configuration
    roregister           : in std_logic_vector(31 downto 0);
    roregwritten         : in std_logic;
    rocontrolbits        : in std_logic_vector(31 downto 0);
    timestampcontrolbits : in std_logic_vector(31 downto 0);
    generatehitswait     : in std_logic_vector(31 downto 0);

    -- test ports  
    testout     : out std_logic_vector (127 downto 0);
    testout_ena : out std_logic

    );
end mupix_interface;


architecture RTL of mupix_interface is
  
  type   tlu_state_type is (reset, waiting, manual, triggered, rectrignum, waiting_for_ro);
  signal tlustate : tlu_state_type;

  signal trigclk_r : std_logic;
  signal busy_r    : std_logic;

  type   ro_state_type is (reset, waiting, readman, loadpix, pulld, loadcol, readcol, hitgenerator, hitgeneratorwait);
  signal state : ro_state_type;

  signal tlu_counter      : std_logic_vector(4 downto 0);
  signal trignum_shift    : std_logic_vector(14 downto 0);
  signal trignum          : std_logic_vector(14 downto 0);
  signal trignum_ena      : std_logic;
  signal trignum_ena_last : std_logic;
  signal tlumanual        : std_logic;

  signal trigcounter : std_logic_vector(14 downto 0);

  signal tlu_divider : std_logic_vector(4 downto 0);

  signal delcounter : std_logic_vector(2 downto 0);

  signal ro_busy_int : std_logic;

  signal graycount : std_logic_vector(7 downto 0);

  signal eventcounter : std_logic_vector(31 downto 0);

  signal hitcounter : std_logic_vector(10 downto 0);


  signal triggering            : std_logic;
  signal continousread         : std_logic;
  signal readnow               : std_logic;
  signal readmanual            : std_logic;
  signal reseteventcount       : std_logic;
  signal generatehit           : std_logic;
  signal generatehits          : std_logic;
  signal generatetriggeredhits : std_logic;

  signal ngeneratehits           : std_logic_vector(15 downto 0);
  signal ngeneratehitscounter    : std_logic_vector(15 downto 0);
  signal generatehitswaitcounter : std_logic_vector(31 downto 0);

  signal gen_hit_col  : std_logic_vector(5 downto 0);
  signal gen_hit_row  : std_logic_vector(5 downto 0);
  signal gen_hit_time : std_logic_vector(7 downto 0);

  signal testoutro  : std_logic_vector (127 downto 0);
  signal testouttlu : std_logic_vector (127 downto 0);

  signal resetgraycounter : std_logic;
  
begin
  
  
  
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

  trigclk <= trigclk_r;
  busy    <= busy_r;

  tlu_if :
  process(rstn, clk)
  begin
    if(rstn = '0') then
      tlu_counter <= (others => '0');
      busy_r      <= '0';
      trigclk_r   <= '0';
      tlustate    <= reset;
      trignum_ena <= '0';
      testouttlu  <= (others => '0');
      trigcounter <= (others => '0');
      tlumanual   <= '0';
    elsif(clk'event and clk = '1') then
      tlumanual                <= roregister(11);
      testouttlu               <= (others => '0');
      testouttlu(48)           <= trig;
      testouttlu(49)           <= trigclk_r;
      testouttlu(50)           <= busy_r;
      testouttlu(46 downto 32) <= trignum;
      testouttlu(30 downto 16) <= trigcounter;
      case tlustate is
        when reset =>
          testouttlu(56) <= '1';
          tlu_counter    <= (others => '0');
          busy_r         <= '0';
          trigclk_r      <= '0';
          tlustate       <= waiting;
          trignum_ena    <= '0';
        when waiting =>
          testouttlu(57) <= '1';
          tlu_counter    <= (others => '0');
          trigclk_r      <= '0';
          busy_r         <= '0';
          trignum_ena    <= '0';
          if(tlumanual = '1') then
            tlustate <= manual;
          elsif(trig = '1') then
            busy_r      <= '1';
            tlustate    <= triggered;
            trignum_ena <= '0';
            trigcounter <= trigcounter + '1';
          end if;
        when manual =>
          testouttlu(61) <= '1';
          if(tlumanual = '0') then
            tlustate <= waiting;
          end if;
          busy_r    <= roregister(9);
          trigclk_r <= roregister(10);
          tlustate  <= manual;
        when triggered =>
          testouttlu(58) <= '1';
          busy_r         <= '1';
          if(trig = '0') then
            tlustate    <= rectrignum;
            trigclk_r   <= '0';
            tlu_divider <= "00000";
          end if;
        when rectrignum =>
          testouttlu(59) <= '1';
          tlu_divider    <= tlu_divider + '1';
          busy_r         <= '1';
          tlustate       <= rectrignum;
          trignum_ena    <= trignum_ena;
          if(tlu_divider = "11111") then
            trigclk_r <= not trigclk_r;
            if(trigclk_r = '1')then
              trignum_shift(14)          <= trig;
              trignum_shift(13 downto 0) <= trignum_shift(14 downto 1);
              tlu_counter                <= tlu_counter + '1';
            end if;
          end if;
          if(tlu_counter = "01111" and tlu_divider = "00000") then
            trignum     <= trignum_shift;
            trignum_ena <= '1';
          end if;
          if(tlu_counter = "10000") then
            tlustate  <= waiting_for_ro;
            trigclk_r <= '0';
          end if;
        when waiting_for_ro =>
          testouttlu(60) <= '1';
          busy_r         <= '1';
          if(ro_busy_int = '0') then
            busy_r   <= '0';
            tlustate <= waiting;
          end if;
      end case;
    end if;
  end process;


  testout_ena <= '1';

  testout(127 downto 64) <= testoutro(127 downto 64);
  testout(63 downto 16)  <= testouttlu(63 downto 16);
  testout(15 downto 0)   <= testoutro(15 downto 0);

  ro_statemachine :
  process(rstn, clk)
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
          --timeoutcounter <= (others => '0');
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
          elsif(continousread = '1' or readnow = '1' or (triggering = '1' and trig = '1' and generatetriggeredhits = '0' and busy_r = '0' and tlumanual = '0')) then
            state        <= loadpix;
            ldpix        <= '1';
            delcounter   <= "100";
            eventcounter <= eventcounter + '1';
          elsif(triggering = '1' and trig = '1' and generatetriggeredhits = '1' and busy_r = '0' and tlumanual = '0') then
            state        <= hitgenerator;
            delcounter   <= "100";
            eventcounter <= eventcounter + '1';
          elsif(generatehit = '1' or generatehits = '1') then
            state        <= hitgenerator;
            delcounter   <= "100";
            eventcounter <= eventcounter + '1';
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
          delcounter   <= delcounter - '1';
          memwren      <= '0';
          state        <= loadpix;
          if(delcounter = "100") then   -- write event header
            memdata <= "11111010101111101010101110111010";     --0xFABEABBA
            memwren <= '1';
          elsif(delcounter = "011") then               -- write event counter
            memdata <= eventcounter;
            memwren <= '1';
          elsif(delcounter = "001" and triggering = '1' and trignum_ena = '1') then  -- write trigger number
            memdata <= "11001100110011000" & trignum;  -- 0xCCCC foolowed by trignum
            memwren <= '1';
          elsif(delcounter = "001" and triggering = '1' and trignum_ena = '0') then  -- wait for trigger number
            delcounter <= delcounter;
          elsif(delcounter = "001" and triggering = '0') then
            memwren <= '1';
            memdata <= x"00000000";     --add empty trigger
                                        --number
          end if;
          if(delcounter = "000") then
            state      <= pulld;
            pulldown   <= '1';
            delcounter <= "001";
          end if;
          endofevent <= '0';
        when pulld =>
          testoutro(3) <= '1';
          memwren      <= '0';
          pulldown     <= '0';
          delcounter   <= delcounter - '1';
          state        <= pulld;
          if(delcounter = "000") then
            state      <= loadcol;
            ldcol      <= '1';
            delcounter <= "001";
          end if;
          endofevent <= '0';
        when loadcol =>
          testoutro(4) <= '1';
          memwren      <= '0';
          ldcol        <= '0';
          delcounter   <= delcounter - '1';
          state        <= loadcol;
          endofevent   <= '0';
          if(delcounter = "000" and priout = '1') then
            state      <= readcol;
            rdcol      <= '1';
            delcounter <= "010";
          elsif(delcounter = "000") then
            -- end of event
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
            state      <= waiting;
          end if;
        when readcol =>
          testoutro(5) <= '1';
          rdcol        <= '0';
          delcounter   <= delcounter - '1';
          memwren      <= '0';
          state        <= readcol;
          endofevent   <= '0';
          if(delcounter = "010") then
            memdata    <= "111100001111" & hit_col & hit_row & hit_time;  --0xF0F
            memwren    <= '1';
            hitcounter <= hitcounter + '1';
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
            delcounter <= "010";
          elsif(delcounter = "000") then
            state      <= pulld;
            pulldown   <= '1';
            delcounter <= "001";
          end if;
          
        when hitgenerator =>
          ro_busy_int  <= '1';
          testoutro(6) <= '1';
          state        <= hitgenerator;
          if(delcounter = "100") then   -- write event header
            state                   <= hitgenerator;
            memdata                 <= "11111010101111101010101110111010";  --0xFABEABBA
            memwren                 <= '1';
            ngeneratehitscounter    <= ngeneratehits;
            generatehitswaitcounter <= generatehitswait;
            gen_hit_col             <= (others => '0');
            gen_hit_row             <= (others => '0');
            gen_hit_time            <= (others => '0');
            delcounter              <= delcounter - '1';
            endofevent              <= '0';
          elsif(delcounter = "011") then                 -- write event counter
            state      <= hitgenerator;
            memdata    <= eventcounter;
            memwren    <= '1';
            delcounter <= delcounter - '1';
            endofevent <= '0';
          elsif(delcounter = "010") then
            state      <= hitgenerator;
            memwren    <= '0';
            delcounter <= delcounter - '1';
            endofevent <= '0';
          elsif(delcounter = "001" and triggering = '1' and trignum_ena = '1') then  -- write trigger number
            state      <= hitgenerator;
            memdata    <= "11001100110011000" &trignum;  -- 0xCCCC foolowed by trignum
            memwren    <= '1';
            delcounter <= delcounter - '1';
            endofevent <= '0';
            --          elsif(delcounter = "001" and triggering = '1' and trignum_ena = '0' and timeoutcounter = "1111111111") then -- write fake trigger number
            --                  state     <= hitgenerator;
            --                  memdata <= "1100110011001100" & "1111111111111111"; -- 0xCCCC foolowed by trignum
            --                  memwren <= '1';
            --                  delcounter <= delcounter - '1';
            --                  endofevent              <= '0';                 
          elsif(delcounter = "001" and triggering = '1' and trignum_ena = '0') then  -- wait for trigger number
            state      <= hitgenerator;
            memwren    <= '0';
            delcounter <= delcounter;
            endofevent <= '0';
            --timeoutcounter <= timeoutcounter + '1';
          elsif(delcounter = "001" and triggering = '0') then
            state      <= hitgenerator;
            memwren    <= '1';
            memdata    <= x"00000000";  --add empty trigger
                                        --number
            delcounter <= delcounter - '1';
            endofevent <= '0';
          elsif(delcounter = "000" and ngeneratehitscounter > "0000000000000000") then
            state                <= hitgenerator;
            delcounter           <= delcounter;
            ngeneratehitscounter <= ngeneratehitscounter - '1';
            gen_hit_col          <= gen_hit_col + "0101";
            gen_hit_row          <= gen_hit_row + "0111";
            if(gen_hit_row > "10000") then
              gen_hit_row <= "000000";
            end if;
            memdata    <= "111100001111" & "0" & gen_hit_col(4 downto 0) & gen_hit_row & graycount;  --0xF0F
            memwren    <= '1';
            endofevent <= '0';
          elsif(delcounter = "000" and ngeneratehitscounter = "0000000000000000" and generatehits = '0') then
            state      <= waiting;
            -- end of event
            memwren    <= '1';
            memdata    <= "10111110111011111011111011101111";  --0xBEEFBEEF
            endofevent <= '1';
          elsif(delcounter = "000" and ngeneratehitscounter = "0000000000000000" and generatehits = '1') then
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
          generatehitswaitcounter <= generatehitswaitcounter - '1';
          if(conv_integer(generatehitswaitcounter) = 0)then
            state        <= hitgenerator;
            delcounter   <= "100";
            eventcounter <= eventcounter + '1';
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
