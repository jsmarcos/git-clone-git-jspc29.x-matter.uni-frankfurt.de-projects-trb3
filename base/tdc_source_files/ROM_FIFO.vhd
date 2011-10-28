-- VHDL netlist generated by SCUBA Diamond_1.1_Production (517)
-- Module  Version: 5.0
--/opt/lattice/diamond/1.1/ispfpga/bin/lin/scuba -w -lang vhdl -synth synplify -bus_exp 7 -bb -arch ep5m00 -type bram -wp 00 -rp 1100 -addr_width 8 -data_width 4 -num_rows 256 -resetmode SYNC -memfile /home/cahit/Projects/TDC/IPExpress_Modules/ROM_FIFO_Mask/ROM_FIFO_0/rom0_mem_file.mem -memformat hex -cascade -1 -e 

-- Fri May 27 11:15:53 2011

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp2m;
use ecp2m.components.all;
-- synopsys translate_on

entity ROM_FIFO is
    port (
        Address: in  std_logic_vector(7 downto 0); 
        OutClock: in  std_logic; 
        OutClockEn: in  std_logic; 
        Reset: in  std_logic; 
        Q: out  std_logic_vector(3 downto 0));
end ROM_FIFO;

architecture Structure of ROM_FIFO is

    -- internal signal declarations
    signal scuba_vhi: std_logic;
    signal scuba_vlo: std_logic;

    -- local component declarations
    component VHI
        port (Z: out  std_logic);
    end component;
    component VLO
        port (Z: out  std_logic);
    end component;
    component DP16KB
    -- synopsys translate_off
        generic (INITVAL_3F : in String; INITVAL_3E : in String; 
                INITVAL_3D : in String; INITVAL_3C : in String; 
                INITVAL_3B : in String; INITVAL_3A : in String; 
                INITVAL_39 : in String; INITVAL_38 : in String; 
                INITVAL_37 : in String; INITVAL_36 : in String; 
                INITVAL_35 : in String; INITVAL_34 : in String; 
                INITVAL_33 : in String; INITVAL_32 : in String; 
                INITVAL_31 : in String; INITVAL_30 : in String; 
                INITVAL_2F : in String; INITVAL_2E : in String; 
                INITVAL_2D : in String; INITVAL_2C : in String; 
                INITVAL_2B : in String; INITVAL_2A : in String; 
                INITVAL_29 : in String; INITVAL_28 : in String; 
                INITVAL_27 : in String; INITVAL_26 : in String; 
                INITVAL_25 : in String; INITVAL_24 : in String; 
                INITVAL_23 : in String; INITVAL_22 : in String; 
                INITVAL_21 : in String; INITVAL_20 : in String; 
                INITVAL_1F : in String; INITVAL_1E : in String; 
                INITVAL_1D : in String; INITVAL_1C : in String; 
                INITVAL_1B : in String; INITVAL_1A : in String; 
                INITVAL_19 : in String; INITVAL_18 : in String; 
                INITVAL_17 : in String; INITVAL_16 : in String; 
                INITVAL_15 : in String; INITVAL_14 : in String; 
                INITVAL_13 : in String; INITVAL_12 : in String; 
                INITVAL_11 : in String; INITVAL_10 : in String; 
                INITVAL_0F : in String; INITVAL_0E : in String; 
                INITVAL_0D : in String; INITVAL_0C : in String; 
                INITVAL_0B : in String; INITVAL_0A : in String; 
                INITVAL_09 : in String; INITVAL_08 : in String; 
                INITVAL_07 : in String; INITVAL_06 : in String; 
                INITVAL_05 : in String; INITVAL_04 : in String; 
                INITVAL_03 : in String; INITVAL_02 : in String; 
                INITVAL_01 : in String; INITVAL_00 : in String; 
                GSR : in String; WRITEMODE_B : in String; 
                CSDECODE_B : in std_logic_vector(2 downto 0); 
                CSDECODE_A : in std_logic_vector(2 downto 0); 
                WRITEMODE_A : in String; RESETMODE : in String; 
                REGMODE_B : in String; REGMODE_A : in String; 
                DATA_WIDTH_B : in Integer; DATA_WIDTH_A : in Integer);
    -- synopsys translate_on
        port (DIA0: in  std_logic; DIA1: in  std_logic; 
            DIA2: in  std_logic; DIA3: in  std_logic; 
            DIA4: in  std_logic; DIA5: in  std_logic; 
            DIA6: in  std_logic; DIA7: in  std_logic; 
            DIA8: in  std_logic; DIA9: in  std_logic; 
            DIA10: in  std_logic; DIA11: in  std_logic; 
            DIA12: in  std_logic; DIA13: in  std_logic; 
            DIA14: in  std_logic; DIA15: in  std_logic; 
            DIA16: in  std_logic; DIA17: in  std_logic; 
            ADA0: in  std_logic; ADA1: in  std_logic; 
            ADA2: in  std_logic; ADA3: in  std_logic; 
            ADA4: in  std_logic; ADA5: in  std_logic; 
            ADA6: in  std_logic; ADA7: in  std_logic; 
            ADA8: in  std_logic; ADA9: in  std_logic; 
            ADA10: in  std_logic; ADA11: in  std_logic; 
            ADA12: in  std_logic; ADA13: in  std_logic; 
            CEA: in  std_logic; CLKA: in  std_logic; WEA: in  std_logic; 
            CSA0: in  std_logic; CSA1: in  std_logic; 
            CSA2: in  std_logic; RSTA: in  std_logic; 
            DIB0: in  std_logic; DIB1: in  std_logic; 
            DIB2: in  std_logic; DIB3: in  std_logic; 
            DIB4: in  std_logic; DIB5: in  std_logic; 
            DIB6: in  std_logic; DIB7: in  std_logic; 
            DIB8: in  std_logic; DIB9: in  std_logic; 
            DIB10: in  std_logic; DIB11: in  std_logic; 
            DIB12: in  std_logic; DIB13: in  std_logic; 
            DIB14: in  std_logic; DIB15: in  std_logic; 
            DIB16: in  std_logic; DIB17: in  std_logic; 
            ADB0: in  std_logic; ADB1: in  std_logic; 
            ADB2: in  std_logic; ADB3: in  std_logic; 
            ADB4: in  std_logic; ADB5: in  std_logic; 
            ADB6: in  std_logic; ADB7: in  std_logic; 
            ADB8: in  std_logic; ADB9: in  std_logic; 
            ADB10: in  std_logic; ADB11: in  std_logic; 
            ADB12: in  std_logic; ADB13: in  std_logic; 
            CEB: in  std_logic; CLKB: in  std_logic; WEB: in  std_logic; 
            CSB0: in  std_logic; CSB1: in  std_logic; 
            CSB2: in  std_logic; RSTB: in  std_logic; 
            DOA0: out  std_logic; DOA1: out  std_logic; 
            DOA2: out  std_logic; DOA3: out  std_logic; 
            DOA4: out  std_logic; DOA5: out  std_logic; 
            DOA6: out  std_logic; DOA7: out  std_logic; 
            DOA8: out  std_logic; DOA9: out  std_logic; 
            DOA10: out  std_logic; DOA11: out  std_logic; 
            DOA12: out  std_logic; DOA13: out  std_logic; 
            DOA14: out  std_logic; DOA15: out  std_logic; 
            DOA16: out  std_logic; DOA17: out  std_logic; 
            DOB0: out  std_logic; DOB1: out  std_logic; 
            DOB2: out  std_logic; DOB3: out  std_logic; 
            DOB4: out  std_logic; DOB5: out  std_logic; 
            DOB6: out  std_logic; DOB7: out  std_logic; 
            DOB8: out  std_logic; DOB9: out  std_logic; 
            DOB10: out  std_logic; DOB11: out  std_logic; 
            DOB12: out  std_logic; DOB13: out  std_logic; 
            DOB14: out  std_logic; DOB15: out  std_logic; 
            DOB16: out  std_logic; DOB17: out  std_logic);
    end component;
    attribute MEM_LPC_FILE : string; 
    attribute MEM_INIT_FILE : string; 
    attribute INITVAL_3F : string; 
    attribute INITVAL_3E : string; 
    attribute INITVAL_3D : string; 
    attribute INITVAL_3C : string; 
    attribute INITVAL_3B : string; 
    attribute INITVAL_3A : string; 
    attribute INITVAL_39 : string; 
    attribute INITVAL_38 : string; 
    attribute INITVAL_37 : string; 
    attribute INITVAL_36 : string; 
    attribute INITVAL_35 : string; 
    attribute INITVAL_34 : string; 
    attribute INITVAL_33 : string; 
    attribute INITVAL_32 : string; 
    attribute INITVAL_31 : string; 
    attribute INITVAL_30 : string; 
    attribute INITVAL_2F : string; 
    attribute INITVAL_2E : string; 
    attribute INITVAL_2D : string; 
    attribute INITVAL_2C : string; 
    attribute INITVAL_2B : string; 
    attribute INITVAL_2A : string; 
    attribute INITVAL_29 : string; 
    attribute INITVAL_28 : string; 
    attribute INITVAL_27 : string; 
    attribute INITVAL_26 : string; 
    attribute INITVAL_25 : string; 
    attribute INITVAL_24 : string; 
    attribute INITVAL_23 : string; 
    attribute INITVAL_22 : string; 
    attribute INITVAL_21 : string; 
    attribute INITVAL_20 : string; 
    attribute INITVAL_1F : string; 
    attribute INITVAL_1E : string; 
    attribute INITVAL_1D : string; 
    attribute INITVAL_1C : string; 
    attribute INITVAL_1B : string; 
    attribute INITVAL_1A : string; 
    attribute INITVAL_19 : string; 
    attribute INITVAL_18 : string; 
    attribute INITVAL_17 : string; 
    attribute INITVAL_16 : string; 
    attribute INITVAL_15 : string; 
    attribute INITVAL_14 : string; 
    attribute INITVAL_13 : string; 
    attribute INITVAL_12 : string; 
    attribute INITVAL_11 : string; 
    attribute INITVAL_10 : string; 
    attribute INITVAL_0F : string; 
    attribute INITVAL_0E : string; 
    attribute INITVAL_0D : string; 
    attribute INITVAL_0C : string; 
    attribute INITVAL_0B : string; 
    attribute INITVAL_0A : string; 
    attribute INITVAL_09 : string; 
    attribute INITVAL_08 : string; 
    attribute INITVAL_07 : string; 
    attribute INITVAL_06 : string; 
    attribute INITVAL_05 : string; 
    attribute INITVAL_04 : string; 
    attribute INITVAL_03 : string; 
    attribute INITVAL_02 : string; 
    attribute INITVAL_01 : string; 
    attribute INITVAL_00 : string; 
    attribute CSDECODE_B : string; 
    attribute CSDECODE_A : string; 
    attribute WRITEMODE_B : string; 
    attribute WRITEMODE_A : string; 
    attribute GSR : string; 
    attribute RESETMODE : string; 
    attribute REGMODE_B : string; 
    attribute REGMODE_A : string; 
    attribute DATA_WIDTH_B : string; 
    attribute DATA_WIDTH_A : string; 
    attribute MEM_LPC_FILE of ROM_FIFO_0_0_0 : label is "ROM_FIFO.lpc";
    attribute MEM_INIT_FILE of ROM_FIFO_0_0_0 : label is "rom0_mem_file.mem";
    attribute INITVAL_3F of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_3E of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_3D of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_3C of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_3B of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_3A of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_39 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_38 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_37 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_36 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_35 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_34 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_33 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_32 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_31 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_30 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2F of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2E of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2D of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2C of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2B of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_2A of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_29 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_28 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_27 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_26 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_25 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_24 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_23 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_22 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_21 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_20 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1F of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1E of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1D of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1C of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1B of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_1A of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_19 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_18 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_17 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_16 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_15 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_14 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_13 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_12 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_11 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_10 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0F of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0E of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0D of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0C of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0B of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_0A of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_09 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_08 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_07 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_06 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_05 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_04 of ROM_FIFO_0_0_0 : label is "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000";
    attribute INITVAL_03 of ROM_FIFO_0_0_0 : label is "0x10010040100601004010080100401006010040100A01004010060100401008010040100601004010";
    attribute INITVAL_02 of ROM_FIFO_0_0_0 : label is "0x0C010040100601004010080100401006010040100A01004010060100401008010040100601004010";
    attribute INITVAL_01 of ROM_FIFO_0_0_0 : label is "0x0E010040100601004010080100401006010040100A01004010060100401008010040100601004010";
    attribute INITVAL_00 of ROM_FIFO_0_0_0 : label is "0x0C010040100601004010080100401006010040100A01004010060100401008010040100601004010";
    attribute CSDECODE_B of ROM_FIFO_0_0_0 : label is "0b111";
    attribute CSDECODE_A of ROM_FIFO_0_0_0 : label is "0b000";
    attribute WRITEMODE_B of ROM_FIFO_0_0_0 : label is "NORMAL";
    attribute WRITEMODE_A of ROM_FIFO_0_0_0 : label is "NORMAL";
    attribute GSR of ROM_FIFO_0_0_0 : label is "DISABLED";
    attribute RESETMODE of ROM_FIFO_0_0_0 : label is "SYNC";
    attribute REGMODE_B of ROM_FIFO_0_0_0 : label is "NOREG";
    attribute REGMODE_A of ROM_FIFO_0_0_0 : label is "NOREG";
    attribute DATA_WIDTH_B of ROM_FIFO_0_0_0 : label is "4";
    attribute DATA_WIDTH_A of ROM_FIFO_0_0_0 : label is "4";

begin
    -- component instantiation statements
    scuba_vhi_inst: VHI
        port map (Z=>scuba_vhi);

    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    ROM_FIFO_0_0_0: DP16KB
        -- synopsys translate_off
        generic map (INITVAL_3F=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_3E=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_3D=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_3C=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_3B=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_3A=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_39=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_38=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_37=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_36=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_35=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_34=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_33=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_32=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_31=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_30=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2F=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2E=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2D=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2C=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2B=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_2A=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_29=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_28=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_27=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_26=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_25=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_24=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_23=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_22=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_21=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_20=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1F=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1E=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1D=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1C=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1B=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_1A=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_19=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_18=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_17=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_16=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_15=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_14=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_13=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_12=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_11=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_10=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0F=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0E=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0D=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0C=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0B=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_0A=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_09=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_08=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_07=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_06=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_05=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_04=> "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000", 
        INITVAL_03=> "0x10010040100601004010080100401006010040100A01004010060100401008010040100601004010", 
        INITVAL_02=> "0x0C010040100601004010080100401006010040100A01004010060100401008010040100601004010", 
        INITVAL_01=> "0x0E010040100601004010080100401006010040100A01004010060100401008010040100601004010", 
        INITVAL_00=> "0x0C010040100601004010080100401006010040100A01004010060100401008010040100601004010", 
        CSDECODE_B=> "111", CSDECODE_A=> "000", WRITEMODE_B=> "NORMAL", 
        WRITEMODE_A=> "NORMAL", GSR=> "DISABLED", RESETMODE=> "SYNC", 
        REGMODE_B=> "NOREG", REGMODE_A=> "NOREG", DATA_WIDTH_B=>  4, 
        DATA_WIDTH_A=>  4)
        -- synopsys translate_on
        port map (DIA0=>scuba_vlo, DIA1=>scuba_vlo, DIA2=>scuba_vlo, 
            DIA3=>scuba_vlo, DIA4=>scuba_vlo, DIA5=>scuba_vlo, 
            DIA6=>scuba_vlo, DIA7=>scuba_vlo, DIA8=>scuba_vlo, 
            DIA9=>scuba_vlo, DIA10=>scuba_vlo, DIA11=>scuba_vlo, 
            DIA12=>scuba_vlo, DIA13=>scuba_vlo, DIA14=>scuba_vlo, 
            DIA15=>scuba_vlo, DIA16=>scuba_vlo, DIA17=>scuba_vlo, 
            ADA0=>scuba_vlo, ADA1=>scuba_vlo, ADA2=>Address(0), 
            ADA3=>Address(1), ADA4=>Address(2), ADA5=>Address(3), 
            ADA6=>Address(4), ADA7=>Address(5), ADA8=>Address(6), 
            ADA9=>Address(7), ADA10=>scuba_vlo, ADA11=>scuba_vlo, 
            ADA12=>scuba_vlo, ADA13=>scuba_vlo, CEA=>OutClockEn, 
            CLKA=>OutClock, WEA=>scuba_vlo, CSA0=>scuba_vlo, 
            CSA1=>scuba_vlo, CSA2=>scuba_vlo, RSTA=>Reset, 
            DIB0=>scuba_vlo, DIB1=>scuba_vlo, DIB2=>scuba_vlo, 
            DIB3=>scuba_vlo, DIB4=>scuba_vlo, DIB5=>scuba_vlo, 
            DIB6=>scuba_vlo, DIB7=>scuba_vlo, DIB8=>scuba_vlo, 
            DIB9=>scuba_vlo, DIB10=>scuba_vlo, DIB11=>scuba_vlo, 
            DIB12=>scuba_vlo, DIB13=>scuba_vlo, DIB14=>scuba_vlo, 
            DIB15=>scuba_vlo, DIB16=>scuba_vlo, DIB17=>scuba_vlo, 
            ADB0=>scuba_vlo, ADB1=>scuba_vlo, ADB2=>scuba_vlo, 
            ADB3=>scuba_vlo, ADB4=>scuba_vlo, ADB5=>scuba_vlo, 
            ADB6=>scuba_vlo, ADB7=>scuba_vlo, ADB8=>scuba_vlo, 
            ADB9=>scuba_vlo, ADB10=>scuba_vlo, ADB11=>scuba_vlo, 
            ADB12=>scuba_vlo, ADB13=>scuba_vlo, CEB=>scuba_vhi, 
            CLKB=>scuba_vlo, WEB=>scuba_vlo, CSB0=>scuba_vlo, 
            CSB1=>scuba_vlo, CSB2=>scuba_vlo, RSTB=>scuba_vlo, 
            DOA0=>Q(0), DOA1=>Q(1), DOA2=>Q(2), DOA3=>Q(3), DOA4=>open, 
            DOA5=>open, DOA6=>open, DOA7=>open, DOA8=>open, DOA9=>open, 
            DOA10=>open, DOA11=>open, DOA12=>open, DOA13=>open, 
            DOA14=>open, DOA15=>open, DOA16=>open, DOA17=>open, 
            DOB0=>open, DOB1=>open, DOB2=>open, DOB3=>open, DOB4=>open, 
            DOB5=>open, DOB6=>open, DOB7=>open, DOB8=>open, DOB9=>open, 
            DOB10=>open, DOB11=>open, DOB12=>open, DOB13=>open, 
            DOB14=>open, DOB15=>open, DOB16=>open, DOB17=>open);

end Structure;

-- synopsys translate_off
library ecp2m;
configuration Structure_CON of ROM_FIFO is
    for Structure
        for all:VHI use entity ecp2m.VHI(V); end for;
        for all:VLO use entity ecp2m.VLO(V); end for;
        for all:DP16KB use entity ecp2m.DP16KB(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
