-- VHDL netlist generated by SCUBA Diamond_3.0_Production (94)
-- Module  Version: 5.5
--/opt/lattice/diamond/3.0_x64/ispfpga/bin/lin64/scuba -w -n FIFO_DC_36x16_OutReg -lang vhdl -synth synplify -bus_exp 7 -bb -arch ep5c00 -type ebfifo -depth 16 -width 36 -depth 16 -rdata_width 36 -regout -no_enable -pe -1 -pf 6 -e 

-- Wed May  7 16:20:30 2014

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity FIFO_DC_36x16_OutReg is
    port (
        Data: in  std_logic_vector(35 downto 0); 
        WrClock: in  std_logic; 
        RdClock: in  std_logic; 
        WrEn: in  std_logic; 
        RdEn: in  std_logic; 
        Reset: in  std_logic; 
        RPReset: in  std_logic; 
        Q: out  std_logic_vector(35 downto 0); 
        Empty: out  std_logic; 
        Full: out  std_logic; 
        AlmostFull: out  std_logic);
end FIFO_DC_36x16_OutReg;

architecture Structure of FIFO_DC_36x16_OutReg is

    -- internal signal declarations
    signal invout_1: std_logic;
    signal invout_0: std_logic;
    signal w_gdata_0: std_logic;
    signal w_gdata_1: std_logic;
    signal w_gdata_2: std_logic;
    signal w_gdata_3: std_logic;
    signal wptr_0: std_logic;
    signal wptr_1: std_logic;
    signal wptr_2: std_logic;
    signal wptr_3: std_logic;
    signal wptr_4: std_logic;
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
    signal co2: std_logic;
    signal co1: std_logic;
    signal wcount_4: std_logic;
    signal ircount_0: std_logic;
    signal ircount_1: std_logic;
    signal r_gctr_ci: std_logic;
    signal ircount_2: std_logic;
    signal ircount_3: std_logic;
    signal co0_1: std_logic;
    signal ircount_4: std_logic;
    signal co2_1: std_logic;
    signal co1_1: std_logic;
    signal rcount_4: std_logic;
    signal rden_i: std_logic;
    signal cmp_ci: std_logic;
    signal wcount_r0: std_logic;
    signal w_g2b_xor_cluster_0: std_logic;
    signal rcount_0: std_logic;
    signal rcount_1: std_logic;
    signal co0_2: std_logic;
    signal wcount_r2: std_logic;
    signal wcount_r3: std_logic;
    signal rcount_2: std_logic;
    signal rcount_3: std_logic;
    signal co1_2: std_logic;
    signal empty_cmp_clr: std_logic;
    signal empty_cmp_set: std_logic;
    signal empty_d: std_logic;
    signal empty_d_c: std_logic;
    signal cmp_ci_1: std_logic;
    signal wcount_0: std_logic;
    signal wcount_1: std_logic;
    signal co0_3: std_logic;
    signal wcount_2: std_logic;
    signal wcount_3: std_logic;
    signal co1_3: std_logic;
    signal full_cmp_clr: std_logic;
    signal full_cmp_set: std_logic;
    signal full_d: std_logic;
    signal full_d_c: std_logic;
    signal scuba_vhi: std_logic;
    signal iaf_setcount_0: std_logic;
    signal iaf_setcount_1: std_logic;
    signal af_set_ctr_ci: std_logic;
    signal iaf_setcount_2: std_logic;
    signal iaf_setcount_3: std_logic;
    signal co0_4: std_logic;
    signal iaf_setcount_4: std_logic;
    signal co2_2: std_logic;
    signal co1_4: std_logic;
    signal af_setcount_4: std_logic;
    signal wren_i: std_logic;
    signal cmp_ci_2: std_logic;
    signal rcount_w0: std_logic;
    signal r_g2b_xor_cluster_0: std_logic;
    signal af_setcount_0: std_logic;
    signal af_setcount_1: std_logic;
    signal co0_5: std_logic;
    signal rcount_w2: std_logic;
    signal rcount_w3: std_logic;
    signal af_setcount_2: std_logic;
    signal af_setcount_3: std_logic;
    signal co1_5: std_logic;
    signal af_set_cmp_clr: std_logic;
    signal af_set_cmp_set: std_logic;
    signal af_set: std_logic;
    signal af_set_c: std_logic;
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
    component PDPW16KC
        generic (GSR : in String; CSDECODE_R : in String; 
                CSDECODE_W : in String; REGMODE : in String; 
                DATA_WIDTH_R : in Integer; DATA_WIDTH_W : in Integer);
        port (DI0: in  std_logic; DI1: in  std_logic; DI2: in  std_logic; 
            DI3: in  std_logic; DI4: in  std_logic; DI5: in  std_logic; 
            DI6: in  std_logic; DI7: in  std_logic; DI8: in  std_logic; 
            DI9: in  std_logic; DI10: in  std_logic; DI11: in  std_logic; 
            DI12: in  std_logic; DI13: in  std_logic; 
            DI14: in  std_logic; DI15: in  std_logic; 
            DI16: in  std_logic; DI17: in  std_logic; 
            DI18: in  std_logic; DI19: in  std_logic; 
            DI20: in  std_logic; DI21: in  std_logic; 
            DI22: in  std_logic; DI23: in  std_logic; 
            DI24: in  std_logic; DI25: in  std_logic; 
            DI26: in  std_logic; DI27: in  std_logic; 
            DI28: in  std_logic; DI29: in  std_logic; 
            DI30: in  std_logic; DI31: in  std_logic; 
            DI32: in  std_logic; DI33: in  std_logic; 
            DI34: in  std_logic; DI35: in  std_logic; 
            ADW0: in  std_logic; ADW1: in  std_logic; 
            ADW2: in  std_logic; ADW3: in  std_logic; 
            ADW4: in  std_logic; ADW5: in  std_logic; 
            ADW6: in  std_logic; ADW7: in  std_logic; 
            ADW8: in  std_logic; BE0: in  std_logic; BE1: in  std_logic; 
            BE2: in  std_logic; BE3: in  std_logic; CEW: in  std_logic; 
            CLKW: in  std_logic; CSW0: in  std_logic; 
            CSW1: in  std_logic; CSW2: in  std_logic; 
            ADR0: in  std_logic; ADR1: in  std_logic; 
            ADR2: in  std_logic; ADR3: in  std_logic; 
            ADR4: in  std_logic; ADR5: in  std_logic; 
            ADR6: in  std_logic; ADR7: in  std_logic; 
            ADR8: in  std_logic; ADR9: in  std_logic; 
            ADR10: in  std_logic; ADR11: in  std_logic; 
            ADR12: in  std_logic; ADR13: in  std_logic; 
            CER: in  std_logic; CLKR: in  std_logic; CSR0: in  std_logic; 
            CSR1: in  std_logic; CSR2: in  std_logic; RST: in  std_logic; 
            DO0: out  std_logic; DO1: out  std_logic; 
            DO2: out  std_logic; DO3: out  std_logic; 
            DO4: out  std_logic; DO5: out  std_logic; 
            DO6: out  std_logic; DO7: out  std_logic; 
            DO8: out  std_logic; DO9: out  std_logic; 
            DO10: out  std_logic; DO11: out  std_logic; 
            DO12: out  std_logic; DO13: out  std_logic; 
            DO14: out  std_logic; DO15: out  std_logic; 
            DO16: out  std_logic; DO17: out  std_logic; 
            DO18: out  std_logic; DO19: out  std_logic; 
            DO20: out  std_logic; DO21: out  std_logic; 
            DO22: out  std_logic; DO23: out  std_logic; 
            DO24: out  std_logic; DO25: out  std_logic; 
            DO26: out  std_logic; DO27: out  std_logic; 
            DO28: out  std_logic; DO29: out  std_logic; 
            DO30: out  std_logic; DO31: out  std_logic; 
            DO32: out  std_logic; DO33: out  std_logic; 
            DO34: out  std_logic; DO35: out  std_logic);
    end component;
    attribute MEM_LPC_FILE : string; 
    attribute MEM_INIT_FILE : string; 
    attribute RESETMODE : string; 
    attribute GSR : string; 
    attribute MEM_LPC_FILE of pdp_ram_0_0_0 : label is "FIFO_DC_36x16_OutReg.lpc";
    attribute MEM_INIT_FILE of pdp_ram_0_0_0 : label is "";
    attribute RESETMODE of pdp_ram_0_0_0 : label is "SYNC";
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
    attribute NGD_DRC_MASK : integer;
    attribute NGD_DRC_MASK of Structure : architecture is 1;

begin
    -- component instantiation statements
    AND2_t10: AND2
        port map (A=>WrEn, B=>invout_1, Z=>wren_i);

    INV_1: INV
        port map (A=>full_i, Z=>invout_1);

    AND2_t9: AND2
        port map (A=>RdEn, B=>invout_0, Z=>rden_i);

    INV_0: INV
        port map (A=>empty_i, Z=>invout_0);

    OR2_t8: OR2
        port map (A=>Reset, B=>RPReset, Z=>rRst);

    XOR2_t7: XOR2
        port map (A=>wcount_0, B=>wcount_1, Z=>w_gdata_0);

    XOR2_t6: XOR2
        port map (A=>wcount_1, B=>wcount_2, Z=>w_gdata_1);

    XOR2_t5: XOR2
        port map (A=>wcount_2, B=>wcount_3, Z=>w_gdata_2);

    XOR2_t4: XOR2
        port map (A=>wcount_3, B=>wcount_4, Z=>w_gdata_3);

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
        port map (AD3=>w_gcount_r21, AD2=>w_gcount_r22, 
            AD1=>w_gcount_r23, AD0=>w_gcount_r24, 
            DO0=>w_g2b_xor_cluster_0);

    LUT4_12: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r23, AD2=>w_gcount_r24, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>wcount_r3);

    LUT4_11: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r22, AD2=>w_gcount_r23, 
            AD1=>w_gcount_r24, AD0=>scuba_vlo, DO0=>wcount_r2);

    LUT4_10: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>w_gcount_r20, AD2=>w_gcount_r21, 
            AD1=>w_gcount_r22, AD0=>wcount_r3, DO0=>wcount_r0);

    LUT4_9: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w21, AD2=>r_gcount_w22, 
            AD1=>r_gcount_w23, AD0=>r_gcount_w24, 
            DO0=>r_g2b_xor_cluster_0);

    LUT4_8: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w23, AD2=>r_gcount_w24, AD1=>scuba_vlo, 
            AD0=>scuba_vlo, DO0=>rcount_w3);

    LUT4_7: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w22, AD2=>r_gcount_w23, 
            AD1=>r_gcount_w24, AD0=>scuba_vlo, DO0=>rcount_w2);

    LUT4_6: ROM16X1A
        generic map (initval=> X"6996")
        port map (AD3=>r_gcount_w20, AD2=>r_gcount_w21, 
            AD1=>r_gcount_w22, AD0=>rcount_w3, DO0=>rcount_w0);

    LUT4_5: ROM16X1A
        generic map (initval=> X"0410")
        port map (AD3=>rptr_4, AD2=>rcount_4, AD1=>w_gcount_r24, 
            AD0=>scuba_vlo, DO0=>empty_cmp_set);

    LUT4_4: ROM16X1A
        generic map (initval=> X"1004")
        port map (AD3=>rptr_4, AD2=>rcount_4, AD1=>w_gcount_r24, 
            AD0=>scuba_vlo, DO0=>empty_cmp_clr);

    LUT4_3: ROM16X1A
        generic map (initval=> X"0140")
        port map (AD3=>wptr_4, AD2=>wcount_4, AD1=>r_gcount_w24, 
            AD0=>scuba_vlo, DO0=>full_cmp_set);

    LUT4_2: ROM16X1A
        generic map (initval=> X"4001")
        port map (AD3=>wptr_4, AD2=>wcount_4, AD1=>r_gcount_w24, 
            AD0=>scuba_vlo, DO0=>full_cmp_clr);

    LUT4_1: ROM16X1A
        generic map (initval=> X"4c32")
        port map (AD3=>af_setcount_4, AD2=>wcount_4, AD1=>r_gcount_w24, 
            AD0=>wptr_4, DO0=>af_set_cmp_set);

    LUT4_0: ROM16X1A
        generic map (initval=> X"8001")
        port map (AD3=>af_setcount_4, AD2=>wcount_4, AD1=>r_gcount_w24, 
            AD0=>wptr_4, DO0=>af_set_cmp_clr);

    pdp_ram_0_0_0: PDPW16KC
        generic map (CSDECODE_R=> "0b001", CSDECODE_W=> "0b001", GSR=> "DISABLED", 
        REGMODE=> "OUTREG", DATA_WIDTH_R=>  36, DATA_WIDTH_W=>  36)
        port map (DI0=>Data(0), DI1=>Data(1), DI2=>Data(2), DI3=>Data(3), 
            DI4=>Data(4), DI5=>Data(5), DI6=>Data(6), DI7=>Data(7), 
            DI8=>Data(8), DI9=>Data(9), DI10=>Data(10), DI11=>Data(11), 
            DI12=>Data(12), DI13=>Data(13), DI14=>Data(14), 
            DI15=>Data(15), DI16=>Data(16), DI17=>Data(17), 
            DI18=>Data(18), DI19=>Data(19), DI20=>Data(20), 
            DI21=>Data(21), DI22=>Data(22), DI23=>Data(23), 
            DI24=>Data(24), DI25=>Data(25), DI26=>Data(26), 
            DI27=>Data(27), DI28=>Data(28), DI29=>Data(29), 
            DI30=>Data(30), DI31=>Data(31), DI32=>Data(32), 
            DI33=>Data(33), DI34=>Data(34), DI35=>Data(35), ADW0=>wptr_0, 
            ADW1=>wptr_1, ADW2=>wptr_2, ADW3=>wptr_3, ADW4=>scuba_vlo, 
            ADW5=>scuba_vlo, ADW6=>scuba_vlo, ADW7=>scuba_vlo, 
            ADW8=>scuba_vlo, BE0=>scuba_vhi, BE1=>scuba_vhi, 
            BE2=>scuba_vhi, BE3=>scuba_vhi, CEW=>wren_i, CLKW=>WrClock, 
            CSW0=>scuba_vhi, CSW1=>scuba_vlo, CSW2=>scuba_vlo, 
            ADR0=>scuba_vlo, ADR1=>scuba_vlo, ADR2=>scuba_vlo, 
            ADR3=>scuba_vlo, ADR4=>scuba_vlo, ADR5=>rptr_0, ADR6=>rptr_1, 
            ADR7=>rptr_2, ADR8=>rptr_3, ADR9=>scuba_vlo, 
            ADR10=>scuba_vlo, ADR11=>scuba_vlo, ADR12=>scuba_vlo, 
            ADR13=>scuba_vlo, CER=>scuba_vhi, CLKR=>RdClock, 
            CSR0=>rden_i, CSR1=>scuba_vlo, CSR2=>scuba_vlo, RST=>Reset, 
            DO0=>Q(18), DO1=>Q(19), DO2=>Q(20), DO3=>Q(21), DO4=>Q(22), 
            DO5=>Q(23), DO6=>Q(24), DO7=>Q(25), DO8=>Q(26), DO9=>Q(27), 
            DO10=>Q(28), DO11=>Q(29), DO12=>Q(30), DO13=>Q(31), 
            DO14=>Q(32), DO15=>Q(33), DO16=>Q(34), DO17=>Q(35), 
            DO18=>Q(0), DO19=>Q(1), DO20=>Q(2), DO21=>Q(3), DO22=>Q(4), 
            DO23=>Q(5), DO24=>Q(6), DO25=>Q(7), DO26=>Q(8), DO27=>Q(9), 
            DO28=>Q(10), DO29=>Q(11), DO30=>Q(12), DO31=>Q(13), 
            DO32=>Q(14), DO33=>Q(15), DO34=>Q(16), DO35=>Q(17));

    FF_57: FD1P3BX
        port map (D=>iwcount_0, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>wcount_0);

    FF_56: FD1P3DX
        port map (D=>iwcount_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_1);

    FF_55: FD1P3DX
        port map (D=>iwcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_2);

    FF_54: FD1P3DX
        port map (D=>iwcount_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_3);

    FF_53: FD1P3DX
        port map (D=>iwcount_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>wcount_4);

    FF_52: FD1P3DX
        port map (D=>w_gdata_0, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_0);

    FF_51: FD1P3DX
        port map (D=>w_gdata_1, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_1);

    FF_50: FD1P3DX
        port map (D=>w_gdata_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_2);

    FF_49: FD1P3DX
        port map (D=>w_gdata_3, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_3);

    FF_48: FD1P3DX
        port map (D=>wcount_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>w_gcount_4);

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

    FF_42: FD1P3BX
        port map (D=>ircount_0, SP=>rden_i, CK=>RdClock, PD=>rRst, 
            Q=>rcount_0);

    FF_41: FD1P3DX
        port map (D=>ircount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_1);

    FF_40: FD1P3DX
        port map (D=>ircount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_2);

    FF_39: FD1P3DX
        port map (D=>ircount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_3);

    FF_38: FD1P3DX
        port map (D=>ircount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rcount_4);

    FF_37: FD1P3DX
        port map (D=>r_gdata_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_0);

    FF_36: FD1P3DX
        port map (D=>r_gdata_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_1);

    FF_35: FD1P3DX
        port map (D=>r_gdata_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_2);

    FF_34: FD1P3DX
        port map (D=>r_gdata_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_3);

    FF_33: FD1P3DX
        port map (D=>rcount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>r_gcount_4);

    FF_32: FD1P3DX
        port map (D=>rcount_0, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_0);

    FF_31: FD1P3DX
        port map (D=>rcount_1, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_1);

    FF_30: FD1P3DX
        port map (D=>rcount_2, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_2);

    FF_29: FD1P3DX
        port map (D=>rcount_3, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_3);

    FF_28: FD1P3DX
        port map (D=>rcount_4, SP=>rden_i, CK=>RdClock, CD=>rRst, 
            Q=>rptr_4);

    FF_27: FD1S3DX
        port map (D=>w_gcount_0, CK=>RdClock, CD=>Reset, Q=>w_gcount_r0);

    FF_26: FD1S3DX
        port map (D=>w_gcount_1, CK=>RdClock, CD=>Reset, Q=>w_gcount_r1);

    FF_25: FD1S3DX
        port map (D=>w_gcount_2, CK=>RdClock, CD=>Reset, Q=>w_gcount_r2);

    FF_24: FD1S3DX
        port map (D=>w_gcount_3, CK=>RdClock, CD=>Reset, Q=>w_gcount_r3);

    FF_23: FD1S3DX
        port map (D=>w_gcount_4, CK=>RdClock, CD=>Reset, Q=>w_gcount_r4);

    FF_22: FD1S3DX
        port map (D=>r_gcount_0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w0);

    FF_21: FD1S3DX
        port map (D=>r_gcount_1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w1);

    FF_20: FD1S3DX
        port map (D=>r_gcount_2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w2);

    FF_19: FD1S3DX
        port map (D=>r_gcount_3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w3);

    FF_18: FD1S3DX
        port map (D=>r_gcount_4, CK=>WrClock, CD=>rRst, Q=>r_gcount_w4);

    FF_17: FD1S3DX
        port map (D=>w_gcount_r0, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r20);

    FF_16: FD1S3DX
        port map (D=>w_gcount_r1, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r21);

    FF_15: FD1S3DX
        port map (D=>w_gcount_r2, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r22);

    FF_14: FD1S3DX
        port map (D=>w_gcount_r3, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r23);

    FF_13: FD1S3DX
        port map (D=>w_gcount_r4, CK=>RdClock, CD=>Reset, 
            Q=>w_gcount_r24);

    FF_12: FD1S3DX
        port map (D=>r_gcount_w0, CK=>WrClock, CD=>rRst, Q=>r_gcount_w20);

    FF_11: FD1S3DX
        port map (D=>r_gcount_w1, CK=>WrClock, CD=>rRst, Q=>r_gcount_w21);

    FF_10: FD1S3DX
        port map (D=>r_gcount_w2, CK=>WrClock, CD=>rRst, Q=>r_gcount_w22);

    FF_9: FD1S3DX
        port map (D=>r_gcount_w3, CK=>WrClock, CD=>rRst, Q=>r_gcount_w23);

    FF_8: FD1S3DX
        port map (D=>r_gcount_w4, CK=>WrClock, CD=>rRst, Q=>r_gcount_w24);

    FF_7: FD1S3BX
        port map (D=>empty_d, CK=>RdClock, PD=>rRst, Q=>empty_i);

    FF_6: FD1S3DX
        port map (D=>full_d, CK=>WrClock, CD=>Reset, Q=>full_i);

    FF_5: FD1P3BX
        port map (D=>iaf_setcount_0, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>af_setcount_0);

    FF_4: FD1P3BX
        port map (D=>iaf_setcount_1, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>af_setcount_1);

    FF_3: FD1P3DX
        port map (D=>iaf_setcount_2, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>af_setcount_2);

    FF_2: FD1P3BX
        port map (D=>iaf_setcount_3, SP=>wren_i, CK=>WrClock, PD=>Reset, 
            Q=>af_setcount_3);

    FF_1: FD1P3DX
        port map (D=>iaf_setcount_4, SP=>wren_i, CK=>WrClock, CD=>Reset, 
            Q=>af_setcount_4);

    FF_0: FD1S3DX
        port map (D=>af_set, CK=>WrClock, CD=>Reset, Q=>AlmostFull);

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
        port map (CI=>co1, PC0=>wcount_4, PC1=>scuba_vlo, CO=>co2, 
            NC0=>iwcount_4, NC1=>open);

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
        port map (A0=>rcount_0, A1=>rcount_1, B0=>wcount_r0, 
            B1=>w_g2b_xor_cluster_0, CI=>cmp_ci, GE=>co0_2);

    empty_cmp_1: AGEB2
        port map (A0=>rcount_2, A1=>rcount_3, B0=>wcount_r2, 
            B1=>wcount_r3, CI=>co0_2, GE=>co1_2);

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
        port map (A0=>wcount_0, A1=>wcount_1, B0=>rcount_w0, 
            B1=>r_g2b_xor_cluster_0, CI=>cmp_ci_1, GE=>co0_3);

    full_cmp_1: AGEB2
        port map (A0=>wcount_2, A1=>wcount_3, B0=>rcount_w2, 
            B1=>rcount_w3, CI=>co0_3, GE=>co1_3);

    full_cmp_2: AGEB2
        port map (A0=>full_cmp_set, A1=>scuba_vlo, B0=>full_cmp_clr, 
            B1=>scuba_vlo, CI=>co1_3, GE=>full_d_c);

    a1: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>full_d_c, COUT=>open, S0=>full_d, 
            S1=>open);

    scuba_vhi_inst: VHI
        port map (Z=>scuba_vhi);

    af_set_ctr_cia: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vhi, B0=>scuba_vlo, 
            B1=>scuba_vhi, CI=>scuba_vlo, COUT=>af_set_ctr_ci, S0=>open, 
            S1=>open);

    af_set_ctr_0: CU2
        port map (CI=>af_set_ctr_ci, PC0=>af_setcount_0, 
            PC1=>af_setcount_1, CO=>co0_4, NC0=>iaf_setcount_0, 
            NC1=>iaf_setcount_1);

    af_set_ctr_1: CU2
        port map (CI=>co0_4, PC0=>af_setcount_2, PC1=>af_setcount_3, 
            CO=>co1_4, NC0=>iaf_setcount_2, NC1=>iaf_setcount_3);

    af_set_ctr_2: CU2
        port map (CI=>co1_4, PC0=>af_setcount_4, PC1=>scuba_vlo, 
            CO=>co2_2, NC0=>iaf_setcount_4, NC1=>open);

    af_set_cmp_ci_a: FADD2B
        port map (A0=>scuba_vlo, A1=>wren_i, B0=>scuba_vlo, B1=>wren_i, 
            CI=>scuba_vlo, COUT=>cmp_ci_2, S0=>open, S1=>open);

    af_set_cmp_0: AGEB2
        port map (A0=>af_setcount_0, A1=>af_setcount_1, B0=>rcount_w0, 
            B1=>r_g2b_xor_cluster_0, CI=>cmp_ci_2, GE=>co0_5);

    af_set_cmp_1: AGEB2
        port map (A0=>af_setcount_2, A1=>af_setcount_3, B0=>rcount_w2, 
            B1=>rcount_w3, CI=>co0_5, GE=>co1_5);

    af_set_cmp_2: AGEB2
        port map (A0=>af_set_cmp_set, A1=>scuba_vlo, B0=>af_set_cmp_clr, 
            B1=>scuba_vlo, CI=>co1_5, GE=>af_set_c);

    scuba_vlo_inst: VLO
        port map (Z=>scuba_vlo);

    a2: FADD2B
        port map (A0=>scuba_vlo, A1=>scuba_vlo, B0=>scuba_vlo, 
            B1=>scuba_vlo, CI=>af_set_c, COUT=>open, S0=>af_set, 
            S1=>open);

    Empty <= empty_i;
    Full <= full_i;
end Structure;

-- synopsys translate_off
library ecp3;
configuration Structure_CON of FIFO_DC_36x16_OutReg is
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
        for all:PDPW16KC use entity ecp3.PDPW16KC(V); end for;
    end for;
end Structure_CON;

-- synopsys translate_on
