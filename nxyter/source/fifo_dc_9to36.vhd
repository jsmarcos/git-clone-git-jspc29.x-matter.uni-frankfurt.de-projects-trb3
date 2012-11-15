-- VHDL netlist generated by SCUBA Diamond_2.0_Production (151)
-- Module  Version: 5.4
--/usr/local/opt/lattice_diamond/diamond/2.0/ispfpga/bin/lin/scuba -w -lang vhdl -synth synplify -bus_exp 7 -bb -arch ep5c00 -type ebfifo -depth 64 -width 9 -depth 64 -rdata_width 36 -regout -no_enable -pe -1 -pf -1 -e 

-- Tue Nov 13 20:22:07 2012

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity fifo_dc_9to36 is
    port (
        Data: in  std_logic_vector(8 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(35 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic);
end fifo_dc_9to36;

architecture Structure of fifo_dc_9to36 is

    -- internal signal declarations
    signal invout_1: std_logic;
    signal invout_0: std_logic;
    signal wcount_r1: std_logic;
    signal wcount_r0: std_logic;
    signal w_gdata_0: std_logic;
    signal w_gdata_1: std_logic;
    signal w_gdata_2: std_logic;
    signal w_gdata_3: std_logic;
    signal w_gdata_4: std_logic;
    signal w_gdata_5: std_logic;
    signal wptr_0: std_logic;
    signal wptr_1: std_logic;
    signal wptr_2: std_logic;
    signal wptr_3: std_logic;
    signal wptr_4: std_logic;
    signal wptr_5: std_logic;
    signal wptr_6: std_logic;
    signal r_gdata_0: std_logic;
    signal r_gdata_1: std_logic;
    signal r_gdata_2: std_logic;
    signal r_gdata_3: std_logic;
    signal rptr_0: std_logic;
    signal rptr_1: std_logic;
    signal rptr_2: std_logic;
    signal rptr_3: std_logic;
    signal rptr_4: std_logic;
    signal w_gcount_0: std_logic;
    signal w_gcount_1: std_logic;
    signal w_gcount_2: std_logic;
    signal w_gcount_3: std_logic;
    signal w_gcount_4: std_logic;
    signal w_gcount_5: std_logic;
    signal w_gcount_6: std_logic;
    signal r_gcount_0: std_logic;
    signal r_gcount_1: std_logic;
    signal r_gcount_2: std_logic;
    signal r_gcount_3: std_logic;
    signal r_gcount_4: std_logic;
    signal w_gcount_r20: std_logic;
    signal w_gcount_r0: std_logic;
    signal w_gcount_r21: std_logic;
    signal w_gcount_r1: std_logic;
    signal w_gcount_r22: std_logic;
    signal w_gcount_r2: std_logic;
    signal w_gcount_r23: std_logic;
    signal w_gcount_r3: std_logic;
    signal w_gcount_r24: std_logic;
    signal w_gcount_r4: std_logic;
    signal w_gcount_r25: std_logic;
    signal w_gcount_r5: std_logic;
    signal w_gcount_r26: std_logic;
    signal w_gcount_r6: std_logic;
    signal r_gcount_w20: std_logic;
    signal r_gcount_w0: std_logic;
    signal r_gcount_w21: std_logic;
    signal r_gcount_w1: std_logic;
    signal r_gcount_w22: std_logic;
    signal r_gcount_w2: std_logic;
    signal r_gcount_w23: std_logic;
    signal r_gcount_w3: std_logic;
    signal r_gcount_w24: std_logic;
    signal r_gcount_w4: std_logic;
    signal empty_i: std_logic;
    signal rRst: std_logic;
    signal full_i: std_logic;
    signal iwcount_0: std_logic;
    signal iwcount_1: std_logic;
    signal w_gctr_ci: std_logic;
    signal iwcount_2: std_logic;
    signal iwcount_3: std_logic;
    signal co0: std_logic;
    signal iwcount_4: std_logic;
    signal iwcount_5: std_logic;
    signal co1: std_logic;
    signal iwcount_6: std_logic;
    signal co3: std_logic;
    signal wcount_6: std_logic;
    signal co2: std_logic;
    signal scuba_vhi: std_logic;
    signal ircount_0: std_logic;
    signal ircount_1: std_logic;
    signal r_gctr_ci: std_logic;
    signal ircount_2: std_logic;
    signal ircount_3: std_logic;
    signal co0_1: std_logic;
    signal ircount_4: std_logic;
    signal co2_1: std_logic;
    signal rcount_4: std_logic;
    signal co1_1: std_logic;
    signal rden_i: std_logic;
    signal cmp_ci: std_logic;
    signal wcount_r2: std_logic;
    signal w_g2b_xor_cluster_0: std_logic;
    signal rcount_0: std_logic;
    signal rcount_1: std_logic;
    signal co0_2: std_logic;
    signal wcount_r4: std_logic;
    signal wcount_r5: std_logic;
    signal rcount_2: std_logic;
    signal rcount_3: std_logic;
    signal co1_2: std_logic;
    signal empty_cmp_clr: std_logic;
    signal empty_cmp_set: std_logic;
    signal empty_d: std_logic;
    signal empty_d_c: std_logic;
    signal wren_i: std_logic;
    signal cmp_ci_1: std_logic;
    signal wcount_0: std_logic;
    signal wcount_1: std_logic;
    signal co0_3: std_logic;
    signal rcount_w0: std_logic;
    signal r_g2b_xor_cluster_0: std_logic;
    signal wcount_2: std_logic;
    signal wcount_3: std_logic;
    signal co1_3: std_logic;
    signal rcount_w2: std_logic;
    signal rcount_w3: std_logic;
    signal wcount_4: std_logic;
    signal wcount_5: std_logic;
    signal co2_2: std_logic;
    signal full_cmp_clr: std_logic;
    signal full_cmp_set: std_logic;
    signal full_d: std_logic;
    signal full_d_c: std_logic;
    signal scuba_vlo: std_logic;

    -- local component declarations
    component AGEB2
        port (A0: in  std_logic; A1: in  std_logic; B0: in  std_logic; 
            B1: in  std_logic; CI: in  std_logic; GE: out  std_logic);
    end component;
    component AND2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    component CU2
        port (CI: in  std_logic; PC0: in  std_logic; PC1: in  std_logic; 
            CO: out  std_logic; NC0: out  std_logic; NC1: out  std_logic);
    end component;
    component FADD2B
        port (A0: in  std_logic; A1: in  std_logic; B0: in  std_logic; 
            B1: in  std_logic; CI: in  std_logic; COUT: out  std_logic; 
            S0: out  std_logic; S1: out  std_logic);
    end component;
    component FD1P3BX
        port (D: in  std_logic; SP: in  std_logic; CK: in  std_logic; 
            PD: in  std_logic; Q: out  std_logic);
    end component;
    component FD1P3DX
        port (D: in  std_logic; SP: in  std_logic; CK: in  std_logic; 
            CD: in  std_logic; Q: out  std_logic);
    end component;
    component FD1S3BX
        port (D: in  std_logic; CK: in  std_logic; PD: in  std_logic; 
            Q: out  std_logic);
    end component;
    component FD1S3DX
        port (D: in  std_logic; CK: in  std_logic; CD: in  std_logic; 
            Q: out  std_logic);
    end component;
    component INV
        port (A: in  std_logic; Z: out  std_logic);
    end component;
    component OR2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    component ROM16X1A
        generic (INITVAL : in std_logic_vector(15 downto 0));
        port (AD3: in  std_logic; AD2: in  std_logic; AD1: in  std_logic; 
            AD0: in  std_logic; DO0: out  std_logic);
    end component;
    component VHI
        port (Z: out  std_logic);
    end component;
    component VLO
        port (Z: out  std_logic);
    end component;
    component XOR2
        port (A: in  std_logic; B: in  std_logic; Z: out  std_logic);
    end component;
    component DP16KC
        generic (GSR : in String; WRITEMODE_B : in String; 
                WRITEMODE_A : in String; CSDECODE_B : in String; 
                CSDECODE_A : in String; REGMODE_B : in String; 
                REGMODE_A : in String; DATA_WIDTH_B : in Integer; 
                DATA_WIDTH_A : in Integer);
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
            CEA: in  std_logic; CLKA: in  std_logic; OCEA: in  std_logic; 
            WEA: in  std_logic; CSA0: in  std_logic; CSA1: in  std_logic; 
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
            CEB: in  std_logic; CLKB: in  std_logic; OCEB: in  std_logic; 
            WEB: in  std_logic; CSB0: in  std_logic; CSB1: in  std_logic; 
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
    attribute RESETMODE : string; 
    attribute GSR : string; 
    attribute MEM_LPC_FILE of pdp_ram_0_0_2 : label is "fifo_dc_9to36.lpc";
    attribute MEM_INIT_FILE of pdp_ram_0_0_2 : label is "";
    attribute RESETMODE of pdp_ram_0_0_2 : label is "SYNC";
    attribute MEM_LPC_FILE of pdp_ram_0_1_1 : label is "fifo_dc_9to36.lpc";
    attribute MEM_INIT_FILE of pdp_ram_0_1_1 : label is "";
    attribute RESETMODE of pdp_ram_0_1_1 : label is "SYNC";
    attribute MEM_LPC_FILE of pdp_ram_0_2_0 : label is "fifo_dc_9to36.lpc";
    attribute MEM_INIT_FILE of pdp_ram_0_2_0 : label is "";
    attribute RESETMODE of pdp_ram_0_2_0 : label is "SYNC";
    attribute GSR of FF_61 : label is "ENABLED";
    attribute GSR of FF_60 : label is "ENABLED";
    attribute GSR of FF_59 : label is "ENABLED";
    attribute GSR of FF_58 : label is "ENABLED";
    attribute GSR of FF_57 : label is "ENABLED";
    attribute GSR of FF_56 : label is "ENABLED";
    attribute GSR of FF_55 : label is "ENABLED";
    attribute GSR of FF_54 : label is "ENABLED";
    attribute GSR of FF_53 : label is "ENABLED";
    attribute GSR of FF_52 : label is "ENABLED";
    attribute GSR of FF_51 : label is "ENABLED";
    attribute GSR of FF_50 : label is "ENABLED";
    attribute GSR of FF_49 : label is "ENABLED";
    attribute GSR of FF_48 : label is "ENABLED";
    attribute GSR of FF_47 : label is "ENABLED";
    attribute GSR of FF_46 : label is "ENABLED";
    attribute GSR of FF_45 : label is "ENABLED";
    attribute GSR of FF_44 : label is "ENABLED";
    attribute GSR of FF_43 : label is "ENABLED";
    attribute GSR of FF_42 : label is "ENABLED";
    attribute GSR of FF_41 : label is "ENABLED";
    attribute GSR of FF_40 : label is "ENABLED";
    attribute GSR of FF_39 : label is "ENABLED";
    attribute GSR of FF_38 : label is "ENABLED";
    attribute GSR of FF_37 : label is "ENABLED";
    attribute GSR of FF_36 : label is "ENABLED";
    attribute GSR of FF_35 : label is "ENABLED";
    attribute GSR of FF_34 : label is "ENABLED";
    attribute GSR of FF_33 : label is "ENABLED";
    attribute GSR of FF_32 : label is "ENABLED";
    attribute GSR of FF_31 : label is "ENABLED";
    attribute GSR of FF_30 : label is "ENABLED";
    attribute GSR of FF_29 : label is "ENABLED";
    attribute GSR of FF_28 : label is "ENABLED";
    attribute GSR of FF_27 : label is "ENABLED";
    attribute GSR of FF_26 : label is "ENABLED";
    attribute GSR of FF_25 : label is "ENABLED";
    attribute GSR of FF_24 : label is "ENABLED";
    attribute GSR of FF_23 : label is "ENABLED";
    attribute GSR of FF_22 : label is "ENABLED";
    attribute GSR of FF_21 : label is "ENABLED";
    attribute GSR of FF_20 : label is "ENABLED";
    attribute GSR of FF_19 : label is "ENABLED";
    attribute GSR of FF_18 : label is "ENABLED";
    attribute GSR of FF_17 : label is "ENABLED";
    attribute GSR of FF_16 : label is "ENABLED";
    attribute GSR of FF_15 : label is "ENABLED";
    attribute GSR of FF_14 : label is "ENABLED";
    attribute GSR of FF_13 : label is "ENABLED";
    attribute GSR of FF_12 : label is "ENABLED";
    attribute GSR of FF_11 : label is "ENABLED";
    attribute GSR of FF_10 : label is "ENABLED";
    attribute GSR of FF_9 : label is "ENABLED";
    attribute GSR of FF_8 : label is "ENABLED";
    attribute GSR of FF_7 : label is "ENABLED";
    attribute GSR of FF_6 : label is "ENABLED";
    attribute GSR of FF_5 : label is "ENABLED";
    attribute GSR of FF_4 : label is "ENABLED";
    attribute GSR of FF_3 : label is "ENABLED";
    attribute GSR of FF_2 : label is "ENABLED";
    attribute GSR of FF_1 : label is "ENABLED";
    attribute GSR of FF_0 : label is "ENABLED";
    attribute syn_keep : boolean;

begin
    -- component instantiation statements
    AND2_t12: AND2
        port map (A=>WrEn, B=>invout_1, Z=>wren_i);

    INV_1: INV
        port map (A=>full_i, Z=>invout_1);

    AND2_t11: AND2
        port map (A=>RdEn, B=>invout_0, Z=>rden_i);

    INV_0: INV
        port map (A=>empty_i, Z=>invout_0);

    OR2_t10: OR2
        port map (A=>Reset, B=>RPReset, Z=>rRst);

    XOR2_t9: XOR2
        port map (A=>wcount_0, B=>wcount_1, Z=>w_gdata_0);

    XOR2_t8: XOR2
        port map (A=>wcount_1, B=>wcount_2, Z=>w_gdata_1);

    XOR2_t7: XOR2
        port map (A=>wcount_2, B=>wcount_3, Z=>w_gdata_2);

    XOR2_t6: XOR2
        port map (A=>wcount_3, B=>wcount_4, Z=>w_gdata_3);

    XOR2_t5: XOR2
        port map (A=>wcount_4, B=>wcount_5, Z=>w_gdata_4);

    XOR2_t4: XOR2
        port map (A=>wcount_5, B=>wcount_6, Z=>w_gdata_5);

    XOR2_t3: XOR2
        port map (A=>rcount_0, B=>rcount_1, Z=>r_gdata_0);

    XOR2_t2: XOR2
        port map (A=>rcount_1, B=>rcount_2, Z=>r_gdata_1);

    XOR2_t1: XOR2
        port map (A=>rcount_2, B=>rcount_3, Z=>r_gdata_2);

    XOR2_t0: XOR2
        port map (A=>rcount_3, B=>rcount_4, Z=>r_gdata_3);

    LUT4_13: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r23, AD2=>w_gcount_r24, 
            AD1=>w_gcount_r25, AD0=>w_gcount_r26, 
            DO0=>w_g2b_xor_cluster_0);

    LUT4_12: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r25, AD2=>w_gcount_r26, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>wcount_r5);

    LUT4_11: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r24, AD2=>w_gcount_r25, 
            AD1=>w_gcount_r26, AD0=>scuba_vlo, DO0=>wcount_r4);

    LUT4_10: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r22, AD2=>w_gcount_r23, 
            AD1=>w_gcount_r24, AD0=>wcount_r5, DO0=>wcount_r2);

    LUT4_9: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r21, AD2=>w_gcount_r22, 
            AD1=>w_gcount_r23, AD0=>wcount_r4, DO0=>wcount_r1);

    LUT4_8: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r20, AD2=>w_gcount_r21, 
            AD1=>w_gcount_r22, AD0=>w_g2b_xor_cluster_0, DO0=>wcount_r0);

    LUT4_7: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w21, AD2=>r_gcount_w22, 
            AD1=>r_gcount_w23, AD0=>r_gcount_w24, 
            DO0=>r_g2b_xor_cluster_0);

    LUT4_6: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w23, AD2=>r_gcount_w24, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>rcount_w3);

    LUT4_5: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w22, AD2=>r_gcount_w23, 
            AD1=>r_gcount_w24, AD0=>scuba_vlo, DO0=>rcount_w2);

    LUT4_4: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w20, AD2=>r_gcount_w21, 
            AD1=>r_gcount_w22, AD0=>rcount_w3, DO0=>rcount_w0);

    LUT4_3: ROM16X1A
        generic map (initval=> X"0410")
        port map (AD3=>rptr_4, AD2=>rcount_4, AD1=>w_gcount_r26, 
            AD0=>scuba_vlo, DO0=>empty_cmp_set);

    LUT4_2: ROM16X1A
        generic map (initval=> X"1004")
        port map (AD3=>rptr_4, AD2=>rcount_4, AD1=>w_gcount_r26, 
            AD0=>scuba_vlo, DO0=>empty_cmp_clr);

    LUT4_1: ROM16X1A
        generic map (initval=> X"0140")
        port map (AD3=>wptr_6, AD2=>wcount_6, AD1=>r_gcount_w24, 
            AD0=>scuba_vlo, DO0=>full_cmp_set);

    LUT4_0: ROM16X1A
        generic map (initval=> X"4001")
        port map (AD3=>wptr_6, AD2=>wcount_6, AD1=>r_gcount_w24, 
            AD0=>scuba_vlo, DO0=>full_cmp_clr);

    pdp_ram_0_0_2: DP16KC
        generic map (CSDECODE_B=> "0b000", CSDECODE_A=> "0b000", 
        WRITEMODE_B=> "NORMAL", WRITEMODE_A=> "NORMAL", GSR=> "DISABLED", 
        REGMODE_B=> "OUTREG", REGMODE_A=> "OUTREG", DATA_WIDTH_B=>  18, 
        DATA_WIDTH_A=>  4)
        port map (DIA0=>Data(0), DIA1=>Data(1), DIA2=>Data(2), 
            DIA3=>Data(3), DIA4=>scuba_vlo, DIA5=>scuba_vlo, 
            DIA6=>scuba_vlo, DIA7=>scuba_vlo, DIA8=>scuba_vlo, 
            DIA9=>scuba_vlo, DIA10=>scuba_vlo, DIA11=>scuba_vlo, 
            DIA12=>scuba_vlo, DIA13=>scuba_vlo, DIA14=>scuba_vlo, 
            DIA15=>scuba_vlo, DIA16=>scuba_vlo, DIA17=>scuba_vlo, 
            ADA0=>scuba_vlo, ADA1=>scuba_vlo, ADA2=>wptr_0, ADA3=>wptr_1, 
            ADA4=>wptr_2, ADA5=>wptr_3, ADA6=>wptr_4, ADA7=>wptr_5, 
            ADA8=>scuba_vlo, ADA9=>scuba_vlo, ADA10=>scuba_vlo, 
            ADA11=>scuba_vlo, ADA12=>scuba_vlo, ADA13=>scuba_vlo, 
            CEA=>wren_i, CLKA=>WrClock, OCEA=>wren_i, WEA=>scuba_vhi, 
            CSA0=>scuba_vlo, CSA1=>scuba_vlo, CSA2=>scuba_vlo, 
            RSTA=>Reset, DIB0=>scuba_vlo, DIB1=>scuba_vlo, 
            DIB2=>scuba_vlo, DIB3=>scuba_vlo, DIB4=>scuba_vlo, 
            DIB5=>scuba_vlo, DIB6=>scuba_vlo, DIB7=>scuba_vlo, 
            DIB8=>scuba_vlo, DIB9=>scuba_vlo, DIB10=>scuba_vlo, 
            DIB11=>scuba_vlo, DIB12=>scuba_vlo, DIB13=>scuba_vlo, 
            DIB14=>scuba_vlo, DIB15=>scuba_vlo, DIB16=>scuba_vlo, 
            DIB17=>scuba_vlo, ADB0=>scuba_vlo, ADB1=>scuba_vlo, 
            ADB2=>scuba_vlo, ADB3=>scuba_vlo, ADB4=>rptr_0, ADB5=>rptr_1, 
            ADB6=>rptr_2, ADB7=>rptr_3, ADB8=>scuba_vlo, ADB9=>scuba_vlo, 
            ADB10=>scuba_vlo, ADB11=>scuba_vlo, ADB12=>scuba_vlo, 
            ADB13=>scuba_vlo, CEB=>rden_i, CLKB=>RdClock, 
            OCEB=>scuba_vhi, WEB=>scuba_vlo, CSB0=>scuba_vlo, 
            CSB1=>scuba_vlo, CSB2=>scuba_vlo, RSTB=>Reset, DOA0=>open, 
            DOA1=>open, DOA2=>open, DOA3=>open, DOA4=>open, DOA5=>open, 
            DOA6=>open, DOA7=>open, DOA8=>open, DOA9=>open, DOA10=>open, 
            DOA11=>open, DOA12=>open, DOA13=>open, DOA14=>open, 
            DOA15=>open, DOA16=>open, DOA17=>open, DOB0=>Q(0), 
            DOB1=>Q(1), DOB2=>Q(2), DOB3=>Q(3), DOB4=>Q(9), DOB5=>Q(10), 
            DOB6=>Q(11), DOB7=>Q(12), DOB8=>open, DOB9=>Q(18), 
            DOB10=>Q(19), DOB11=>Q(20), DOB12=>Q(21), DOB13=>Q(27), 
            DOB14=>Q(28), DOB15=>Q(29), DOB16=>Q(30), DOB17=>open);

    pdp_ram_0_1_1: DP16KC
        generic map (CSDECODE_B=> "0b000", CSDECODE_A=> "0b000", 
        WRITEMODE_B=> "NORMAL", WRITEMODE_A=> "NORMAL", GSR=> "DISABLED", 
        REGMODE_B=> "OUTREG", REGMODE_A=> "OUTREG", DATA_WIDTH_B=>  18, 
        DATA_WIDTH_A=>  4)
        port map (DIA0=>Data(4), DIA1=>Data(5), DIA2=>Data(6), 
            DIA3=>Data(7), DIA4=>scuba_vlo, DIA5=>scuba_vlo, 
            DIA6=>scuba_vlo, DIA7=>scuba_vlo, DIA8=>scuba_vlo, 
            DIA9=>scuba_vlo, DIA10=>scuba_vlo, DIA11=>scuba_vlo, 
            DIA12=>scuba_vlo, DIA13=>scuba_vlo, DIA14=>scuba_vlo, 
            DIA15=>scuba_vlo, DIA16=>scuba_vlo, DIA17=>scuba_vlo, 
            ADA0=>scuba_vlo, ADA1=>scuba_vlo, ADA2=>wptr_0, ADA3=>wptr_1, 
            ADA4=>wptr_2, ADA5=>wptr_3, ADA6=>wptr_4, ADA7=>wptr_5, 
            ADA8=>scuba_vlo, ADA9=>scuba_vlo, ADA10=>scuba_vlo, 
            ADA11=>scuba_vlo, ADA12=>scuba_vlo, ADA13=>scuba_vlo, 
            CEA=>wren_i, CLKA=>WrClock, OCEA=>wren_i, WEA=>scuba_vhi, 
            CSA0=>scuba_vlo, CSA1=>scuba_vlo, CSA2=>scuba_vlo, 
            RSTA=>Reset, DIB0=>scuba_vlo, DIB1=>scuba_vlo, 
            DIB2=>scuba_vlo, DIB3=>scuba_vlo, DIB4=>scuba_vlo, 
            DIB5=>scuba_vlo, DIB6=>scuba_vlo, DIB7=>scuba_vlo, 
            DIB8=>scuba_vlo, DIB9=>scuba_vlo, DIB10=>scuba_vlo, 
            DIB11=>scuba_vlo, DIB12=>scuba_vlo, DIB13=>scuba_vlo, 
            DIB14=>scuba_vlo, DIB15=>scuba_vlo, DIB16=>scuba_vlo, 
            DIB17=>scuba_vlo, ADB0=>scuba_vlo, ADB1=>scuba_vlo, 
            ADB2=>scuba_vlo, ADB3=>scuba_vlo, ADB4=>rptr_0, ADB5=>rptr_1, 
            ADB6=>rptr_2, ADB7=>rptr_3, ADB8=>scuba_vlo, ADB9=>scuba_vlo, 
            ADB10=>scuba_vlo, ADB11=>scuba_vlo, ADB12=>scuba_vlo, 
            ADB13=>scuba_vlo, CEB=>rden_i, CLKB=>RdClock, 
            OCEB=>scuba_vhi, WEB=>scuba_vlo, CSB0=>scuba_vlo, 
            CSB1=>scuba_vlo, CSB2=>scuba_vlo, RSTB=>Reset, DOA0=>open, 
            DOA1=>open, DOA2=>open, DOA3=>open, DOA4=>open, DOA5=>open, 
            DOA6=>open, DOA7=>open, DOA8=>open, DOA9=>open, DOA10=>open, 
            DOA11=>open, DOA12=>open, DOA13=>open, DOA14=>open, 
            DOA15=>open, DOA16=>open, DOA17=>open, DOB0=>Q(4), 
            DOB1=>Q(5), DOB2=>Q(6), DOB3=>Q(7), DOB4=>Q(13), DOB5=>Q(14), 
            DOB6=>Q(15), DOB7=>Q(16), DOB8=>open, DOB9=>Q(22), 
            DOB10=>Q(23), DOB11=>Q(24), DOB12=>Q(25), DOB13=>Q(31), 
            DOB14=>Q(32), DOB15=>Q(33), DOB16=>Q(34), DOB17=>open);

    pdp_ram_0_2_0: DP16KC
        generic map (CSDECODE_B=> "0b000", CSDECODE_A=> "0b000", 
        WRITEMODE_B=> "NORMAL", WRITEMODE_A=> "NORMAL", GSR=> "DISABLED", 
        REGMODE_B=> "OUTREG", REGMODE_A=> "OUTREG", DATA_WIDTH_B=>  18, 
        DATA_WIDTH_A=>  4)
        port map (DIA0=>Data(8), DIA1=>scuba_vlo, DIA2=>scuba_vlo, 
            DIA3=>scuba_vlo, DIA4=>scuba_vlo, DIA5=>scuba_vlo, 
            DIA6=>scuba_vlo, DIA7=>scuba_vlo, DIA8=>scuba_vlo, 
            DIA9=>scuba_vlo, DIA10=>scuba_vlo, DIA11=>scuba_vlo, 
            DIA12=>scuba_vlo, DIA13=>scuba_vlo, DIA14=>scuba_vlo, 
            DIA15=>scuba_vlo, DIA16=>scuba_vlo, DIA17=>scuba_vlo, 
            ADA0=>scuba_vlo, ADA1=>scuba_vlo, ADA2=>wptr_0, ADA3=>wptr_1, 
            ADA4=>wptr_2, ADA5=>wptr_3, ADA6=>wptr_4, ADA7=>wptr_5, 
            ADA8=>scuba_vlo, ADA9=>scuba_vlo, ADA10=>scuba_vlo, 
            ADA11=>scuba_vlo, ADA12=>scuba_vlo, ADA13=>scuba_vlo, 
            CEA=>wren_i, CLKA=>WrClock, OCEA=>wren_i, WEA=>scuba_vhi, 
            CSA0=>scuba_vlo, CSA1=>scuba_vlo, CSA2=>scuba_vlo, 
            RSTA=>Reset, DIB0=>scuba_vlo, DIB1=>scuba_vlo, 
            DIB2=>scuba_vlo, DIB3=>scuba_vlo, DIB4=>scuba_vlo, 
            DIB5=>scuba_vlo, DIB6=>scuba_vlo, DIB7=>scuba_vlo, 
            DIB8=>scuba_vlo, DIB9=>scuba_vlo, DIB10=>scuba_vlo, 
            DIB11=>scuba_vlo, DIB12=>scuba_vlo, DIB13=>scuba_vlo, 
            DIB14=>scuba_vlo, DIB15=>scuba_vlo, DIB16=>scuba_vlo, 
            DIB17=>scuba_vlo, ADB0=>scuba_vlo, ADB1=>scuba_vlo, 
            ADB2=>scuba_vlo, ADB3=>scuba_vlo, ADB4=>rptr_0, ADB5=>rptr_1, 
            ADB6=>rptr_2, ADB7=>rptr_3, ADB8=>scuba_vlo, ADB9=>scuba_vlo, 
            ADB10=>scuba_vlo, ADB11=>scuba_vlo, ADB12=>scuba_vlo, 
            ADB13=>scuba_vlo, CEB=>rden_i, CLKB=>RdClock, 
            OCEB=>scuba_vhi, WEB=>scuba_vlo, CSB0=>scuba_vlo, 
            CSB1=>scuba_vlo, CSB2=>scuba_vlo, RSTB=>Reset, DOA0=>open, 
            DOA1=>open, DOA2=>open, DOA3=>open, DOA4=>open, DOA5=>open, 
            DOA6=>open, DOA7=>open, DOA8=>open, DOA9=>open, DOA10=>open, 
            DOA11=>open, DOA12=>open, DOA13=>open, DOA14=>open, 
            DOA15=>open, DOA16=>open, DOA17=>open, DOB0=>Q(8), 
            DOB1=>open, DOB2=>open, DOB3=>open, DOB4=>Q(17), DOB5=>open, 
            DOB6=>open, DOB7=>open, DOB8=>open, DOB9=>Q(26), DOB10=>open, 
            DOB11=>open, DOB12=>open, DOB13=>Q(35), DOB14=>open, 
            DOB15=>open, DOB16=>open, DOB17=>open);

    FF_61: FD1P3BX
        port map (D=>iwcount_0, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>wcount_0);

    FF_60: FD1P3DX
        port map (D=>iwcount_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_1);

    FF_59: FD1P3DX
        port map (D=>iwcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_2);

    FF_58: FD1P3DX
        port map (D=>iwcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_3);

    FF_57: FD1P3DX
        port map (D=>iwcount_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_4);

    FF_56: FD1P3DX
        port map (D=>iwcount_5, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_5);

    FF_55: FD1P3DX
        port map (D=>iwcount_6, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_6);

    FF_54: FD1P3DX
        port map (D=>w_gdata_0, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_0);

    FF_53: FD1P3DX
        port map (D=>w_gdata_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_1);

    FF_52: FD1P3DX
        port map (D=>w_gdata_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_2);

    FF_51: FD1P3DX
        port map (D=>w_gdata_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_3);

    FF_50: FD1P3DX
        port map (D=>w_gdata_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_4);

    FF_49: FD1P3DX
        port map (D=>w_gdata_5, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_5);

    FF_48: FD1P3DX
        port map (D=>wcount_6, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_6);

    FF_47: FD1P3DX
        port map (D=>wcount_0, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_0);

    FF_46: FD1P3DX
        port map (D=>wcount_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_1);

    FF_45: FD1P3DX
        port map (D=>wcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_2);

    FF_44: FD1P3DX
        port map (D=>wcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_3);

    FF_43: FD1P3DX
        port map (D=>wcount_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_4);

    FF_42: FD1P3DX
        port map (D=>wcount_5, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_5);

    FF_41: FD1P3DX
        port map (D=>wcount_6, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wptr_6);

    FF_40: FD1P3BX
        port map (D=>ircount_0, SP=>rden_i, CK=>RdClock, PD=>rRst, 
            Q=>rcount_0);

    FF_39: FD1P3DX
        port map (D=>ircount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_1);

    FF_38: FD1P3DX
        port map (D=>ircount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_2);

    FF_37: FD1P3DX
        port map (D=>ircount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_3);

    FF_36: FD1P3DX
        port map (D=>ircount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_4);

    FF_35: FD1P3DX
        port map (D=>r_gdata_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_0);

    FF_34: FD1P3DX
        port map (D=>r_gdata_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_1);

    FF_33: FD1P3DX
        port map (D=>r_gdata_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_2);

    FF_32: FD1P3DX
        port map (D=>r_gdata_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_3);

    FF_31: FD1P3DX
        port map (D=>rcount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_4);

    FF_30: FD1P3DX
        port map (D=>rcount_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_0);

    FF_29: FD1P3DX
        port map (D=>rcount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_1);

    FF_28: FD1P3DX
        port map (D=>rcount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_2);

    FF_27: FD1P3DX
        port map (D=>rcount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_3);

    FF_26: FD1P3DX
        port map (D=>rcount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_4);

    FF_25: FD1S3DX
        port map (D=>w_gcount_0, CK=>RdClock, CD=>Reset, Q=>w_gcount_r0);

    FF_24: FD1S3DX
        port map (D=>w_gcount_1, CK=>RdClock, CD=>Reset, Q=>w_gcount_r1);

    FF_23: FD1S3DX
        port map (D=>w_gcount_2, CK=>RdClock, CD=>Reset, Q=>w_gcount_r2);

    FF_22: FD1S3DX
        port map (D=>w_gcount_3, CK=>RdClock, CD=>Reset, Q=>w_gcount_r3);

    FF_21: FD1S3DX
        port map (D=>w_gcount_4, CK=>RdClock, CD=>Reset, Q=>w_gcount_r4);

    FF_20: FD1S3DX
        port map (D=>w_gcount_5, CK=>RdClock, CD=>Reset, Q=>w_gcount_r5);

    FF_19: FD1S3DX
        port map (D=>w_gcount_6, CK=>RdClock, CD=>Reset, Q=>w_gcount_r6);

    FF_18: FD1S3DX
        port map (D=>r_gcount_0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w0);

    FF_17: FD1S3DX
        port map (D=>r_gcount_1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w1);

    FF_16: FD1S3DX
        port map (D=>r_gcount_2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w2);

    FF_15: FD1S3DX
        port map (D=>r_gcount_3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w3);

    FF_14: FD1S3DX
        port map (D=>r_gcount_4, CK=>WrClock, CD=>rRst, Q=>r_gcount_w4);

    FF_13: FD1S3DX
        port map (D=>w_gcount_r0, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r20);

    FF_12: FD1S3DX
        port map (D=>w_gcount_r1, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r21);

    FF_11: FD1S3DX
        port map (D=>w_gcount_r2, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r22);

    FF_10: FD1S3DX
        port map (D=>w_gcount_r3, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r23);

    FF_9: FD1S3DX
        port map (D=>w_gcount_r4, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r24);

    FF_8: FD1S3DX
        port map (D=>w_gcount_r5, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r25);

    FF_7: FD1S3DX
        port map (D=>w_gcount_r6, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r26);

    FF_6: FD1S3DX
        port map (D=>r_gcount_w0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w20);

    FF_5: FD1S3DX
        port map (D=>r_gcount_w1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w21);

    FF_4: FD1S3DX
        port map (D=>r_gcount_w2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w22);

    FF_3: FD1S3DX
        port map (D=>r_gcount_w3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w23);

    FF_2: FD1S3DX
        port map (D=>r_gcount_w4, CK=>WrClock, CD=>rRst, Q=>r_gcount_w24);

    FF_1: FD1S3BX
        port map (D=>empty_d, CK=>RdClock, PD=>rRst, Q=>empty_i);

    FF_0: FD1S3DX
        port map (D=>full_d, CK=>WrClock, CD=>Reset, Q=>full_i);

    w_gctr_cia: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vhi, B0=>scuba_vlo, 
            B1=>scuba_vhi, CI=>scuba_vlo, COUT=>w_gctr_ci, S0=>open, 
            S1=>open);

    w_gctr_0: CU2
        port map (CI=>w_gctr_ci, PC0=>wcount_0, PC1=>wcount_1, CO=>co0, 
            NC0=>iwcount_0, NC1=>iwcount_1);

    w_gctr_1: CU2
        port map (CI=>co0, PC0=>wcount_2, PC1=>wcount_3, CO=>co1, 
            NC0=>iwcount_2, NC1=>iwcount_3);

    w_gctr_2: CU2
        port map (CI=>co1, PC0=>wcount_4, PC1=>wcount_5, CO=>co2, 
            NC0=>iwcount_4, NC1=>iwcount_5);

    w_gctr_3: CU2
        port map (CI=>co2, PC0=>wcount_6, PC1=>scuba_vlo, CO=>co3, 
            NC0=>iwcount_6, NC1=>open);

    scuba_vhi_inst: VHI
        port map (Z=>scuba_vhi);

    r_gctr_cia: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vhi, B0=>scuba_vlo, 
            B1=>scuba_vhi, CI=>scuba_vlo, COUT=>r_gctr_ci, S0=>open, 
            S1=>open);

    r_gctr_0: CU2
        port map (CI=>r_gctr_ci, PC0=>rcount_0, PC1=>rcount_1, CO=>co0_1, 
            NC0=>ircount_0, NC1=>ircount_1);

    r_gctr_1: CU2
        port map (CI=>co0_1, PC0=>rcount_2, PC1=>rcount_3, CO=>co1_1, 
            NC0=>ircount_2, NC1=>ircount_3);

    r_gctr_2: CU2
        port map (CI=>co1_1, PC0=>rcount_4, PC1=>scuba_vlo, CO=>co2_1, 
            NC0=>ircount_4, NC1=>open);

    empty_cmp_ci_a: FADD2B
        port map (A0=>scuba_vlo, A1=>rden_i, B0=>scuba_vlo, B1=>rden_i, 
            CI=>scuba_vlo, COUT=>cmp_ci, S0=>open, S1=>open);

    empty_cmp_0: AGEB2
        port map (A0=>rcount_0, A1=>rcount_1, B0=>wcount_r2, 
            B1=>w_g2b_xor_cluster_0, CI=>cmp_ci, GE=>co0_2);

    empty_cmp_1: AGEB2
        port map (A0=>rcount_2, A1=>rcount_3, B0=>wcount_r4, 
            B1=>wcount_r5, CI=>co0_2, GE=>co1_2);

    empty_cmp_2: AGEB2
        port map (A0=>empty_cmp_set, A1=>scuba_vlo, B0=>empty_cmp_clr, 
            B1=>scuba_vlo, CI=>co1_2, GE=>empty_d_c);

    a0: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>empty_d_c, COUT=>open, S0=>empty_d, 
            S1=>open);

    full_cmp_ci_a: FADD2B
        port map (A0=>scuba_vlo, A1=>wren_i, B0=>scuba_vlo, B1=>wren_i, 
            CI=>scuba_vlo, COUT=>cmp_ci_1, S0=>open, S1=>open);

    full_cmp_0: AGEB2
        port map (A0=>wcount_0, A1=>wcount_1, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>cmp_ci_1, GE=>co0_3);

    full_cmp_1: AGEB2
        port map (A0=>wcount_2, A1=>wcount_3, B0=>rcount_w0, 
            B1=>r_g2b_xor_cluster_0, CI=>co0_3, GE=>co1_3);

    full_cmp_2: AGEB2
        port map (A0=>wcount_4, A1=>wcount_5, B0=>rcount_w2, 
            B1=>rcount_w3, CI=>co1_3, GE=>co2_2);

    full_cmp_3: AGEB2
        port map (A0=>full_cmp_set, A1=>scuba_vlo, B0=>full_cmp_clr, 
            B1=>scuba_vlo, CI=>co2_2, GE=>full_d_c);

    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    a1: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>full_d_c, COUT=>open, S0=>full_d, 
            S1=>open);

    Empty <= empty_i;
    Full <= full_i;
end Structure;

-- synopsys translate_off
library ecp3;
configuration Structure_CON of fifo_dc_9to36 is
    for Structure
        for all:AGEB2 use entity ecp3.AGEB2(V); end for;
        for all:AND2 use entity ecp3.AND2(V); end for;
        for all:CU2 use entity ecp3.CU2(V); end for;
        for all:FADD2B use entity ecp3.FADD2B(V); end for;
        for all:FD1P3BX use entity ecp3.FD1P3BX(V); end for;
        for all:FD1P3DX use entity ecp3.FD1P3DX(V); end for;
        for all:FD1S3BX use entity ecp3.FD1S3BX(V); end for;
        for all:FD1S3DX use entity ecp3.FD1S3DX(V); end for;
        for all:INV use entity ecp3.INV(V); end for;
        for all:OR2 use entity ecp3.OR2(V); end for;
        for all:ROM16X1A use entity ecp3.ROM16X1A(V); end for;
        for all:VHI use entity ecp3.VHI(V); end for;
        for all:VLO use entity ecp3.VLO(V); end for;
        for all:XOR2 use entity ecp3.XOR2(V); end for;
        for all:DP16KC use entity ecp3.DP16KC(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
