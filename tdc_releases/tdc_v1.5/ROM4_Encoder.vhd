-- VHDL netlist generated by SCUBA Diamond_2.0_Production (151)
-- Module  Version: 5.0
--/opt/lattice/diamond/2.01/ispfpga/bin/lin/scuba -w -lang vhdl -synth synplify -bus_exp 7 -bb -arch ep5c00 -type bram -wp 00 -rp 1100 -addr_width 10 -data_width 8 -num_rows 1024 -outdata REGISTERED -memfile /home/cugur/Projects/encoder/encoder_304_ROM4/source/rom_encoder.mem -memformat orca -cascade -1 -e 

-- Mon Mar  4 14:23:33 2013

library IEEE;
use IEEE.std_logic_1164.all;
-- synopsys translate_off
library ecp3;
use ecp3.components.all;
-- synopsys translate_on

entity ROM4_Encoder is
  port (
    Address    : in  std_logic_vector(9 downto 0);
    OutClock   : in  std_logic;
    OutClockEn : in  std_logic;
    Reset      : in  std_logic;
    Q          : out std_logic_vector(7 downto 0));
end ROM4_Encoder;

architecture Structure of ROM4_Encoder is

  -- internal signal declarations
  signal scuba_vhi : std_logic;
  signal scuba_vlo : std_logic;

  -- local component declarations
  component VHI
    port (Z : out std_logic);
  end component;
  component VLO
    port (Z : out std_logic);
  end component;
  component DP16KC
    generic (INITVAL_3F : in string; INITVAL_3E : in string;
    INITVAL_3D          : in string; INITVAL_3C : in string;
    INITVAL_3B          : in string; INITVAL_3A : in string;
    INITVAL_39          : in string; INITVAL_38 : in string;
    INITVAL_37          : in string; INITVAL_36 : in string;
    INITVAL_35          : in string; INITVAL_34 : in string;
    INITVAL_33          : in string; INITVAL_32 : in string;
    INITVAL_31          : in string; INITVAL_30 : in string;
    INITVAL_2F          : in string; INITVAL_2E : in string;
    INITVAL_2D          : in string; INITVAL_2C : in string;
    INITVAL_2B          : in string; INITVAL_2A : in string;
    INITVAL_29          : in string; INITVAL_28 : in string;
    INITVAL_27          : in string; INITVAL_26 : in string;
    INITVAL_25          : in string; INITVAL_24 : in string;
    INITVAL_23          : in string; INITVAL_22 : in string;
    INITVAL_21          : in string; INITVAL_20 : in string;
    INITVAL_1F          : in string; INITVAL_1E : in string;
    INITVAL_1D          : in string; INITVAL_1C : in string;
    INITVAL_1B          : in string; INITVAL_1A : in string;
    INITVAL_19          : in string; INITVAL_18 : in string;
    INITVAL_17          : in string; INITVAL_16 : in string;
    INITVAL_15          : in string; INITVAL_14 : in string;
    INITVAL_13          : in string; INITVAL_12 : in string;
    INITVAL_11          : in string; INITVAL_10 : in string;
    INITVAL_0F          : in string; INITVAL_0E : in string;
    INITVAL_0D          : in string; INITVAL_0C : in string;
    INITVAL_0B          : in string; INITVAL_0A : in string;
    INITVAL_09          : in string; INITVAL_08 : in string;
    INITVAL_07          : in string; INITVAL_06 : in string;
    INITVAL_05          : in string; INITVAL_04 : in string;
    INITVAL_03          : in string; INITVAL_02 : in string;
    INITVAL_01          : in string; INITVAL_00 : in string;
    GSR                 : in string; WRITEMODE_B : in string;
    WRITEMODE_A         : in string; CSDECODE_B : in string;
    CSDECODE_A          : in string; REGMODE_B : in string;
    REGMODE_A           : in string; DATA_WIDTH_B : in integer;
    DATA_WIDTH_A        : in integer);
    port (DIA0 : in  std_logic; DIA1 : in std_logic;
    DIA2       : in  std_logic; DIA3 : in std_logic;
    DIA4       : in  std_logic; DIA5 : in std_logic;
    DIA6       : in  std_logic; DIA7 : in std_logic;
    DIA8       : in  std_logic; DIA9 : in std_logic;
    DIA10      : in  std_logic; DIA11 : in std_logic;
    DIA12      : in  std_logic; DIA13 : in std_logic;
    DIA14      : in  std_logic; DIA15 : in std_logic;
    DIA16      : in  std_logic; DIA17 : in std_logic;
    ADA0       : in  std_logic; ADA1 : in std_logic;
    ADA2       : in  std_logic; ADA3 : in std_logic;
    ADA4       : in  std_logic; ADA5 : in std_logic;
    ADA6       : in  std_logic; ADA7 : in std_logic;
    ADA8       : in  std_logic; ADA9 : in std_logic;
    ADA10      : in  std_logic; ADA11 : in std_logic;
    ADA12      : in  std_logic; ADA13 : in std_logic;
    CEA        : in  std_logic; CLKA : in std_logic; OCEA : in std_logic;
    WEA        : in  std_logic; CSA0 : in std_logic; CSA1 : in std_logic;
    CSA2       : in  std_logic; RSTA : in std_logic;
    DIB0       : in  std_logic; DIB1 : in std_logic;
    DIB2       : in  std_logic; DIB3 : in std_logic;
    DIB4       : in  std_logic; DIB5 : in std_logic;
    DIB6       : in  std_logic; DIB7 : in std_logic;
    DIB8       : in  std_logic; DIB9 : in std_logic;
    DIB10      : in  std_logic; DIB11 : in std_logic;
    DIB12      : in  std_logic; DIB13 : in std_logic;
    DIB14      : in  std_logic; DIB15 : in std_logic;
    DIB16      : in  std_logic; DIB17 : in std_logic;
    ADB0       : in  std_logic; ADB1 : in std_logic;
    ADB2       : in  std_logic; ADB3 : in std_logic;
    ADB4       : in  std_logic; ADB5 : in std_logic;
    ADB6       : in  std_logic; ADB7 : in std_logic;
    ADB8       : in  std_logic; ADB9 : in std_logic;
    ADB10      : in  std_logic; ADB11 : in std_logic;
    ADB12      : in  std_logic; ADB13 : in std_logic;
    CEB        : in  std_logic; CLKB : in std_logic; OCEB : in std_logic;
    WEB        : in  std_logic; CSB0 : in std_logic; CSB1 : in std_logic;
    CSB2       : in  std_logic; RSTB : in std_logic;
    DOA0       : out std_logic; DOA1 : out std_logic;
    DOA2       : out std_logic; DOA3 : out std_logic;
    DOA4       : out std_logic; DOA5 : out std_logic;
    DOA6       : out std_logic; DOA7 : out std_logic;
    DOA8       : out std_logic; DOA9 : out std_logic;
    DOA10      : out std_logic; DOA11 : out std_logic;
    DOA12      : out std_logic; DOA13 : out std_logic;
    DOA14      : out std_logic; DOA15 : out std_logic;
    DOA16      : out std_logic; DOA17 : out std_logic;
    DOB0       : out std_logic; DOB1 : out std_logic;
    DOB2       : out std_logic; DOB3 : out std_logic;
    DOB4       : out std_logic; DOB5 : out std_logic;
    DOB6       : out std_logic; DOB7 : out std_logic;
    DOB8       : out std_logic; DOB9 : out std_logic;
    DOB10      : out std_logic; DOB11 : out std_logic;
    DOB12      : out std_logic; DOB13 : out std_logic;
    DOB14      : out std_logic; DOB15 : out std_logic;
    DOB16      : out std_logic; DOB17 : out std_logic);
  end component;
  attribute MEM_LPC_FILE                        : string;
  attribute MEM_INIT_FILE                       : string;
  attribute RESETMODE                           : string;
  attribute MEM_LPC_FILE of ROM4_Encoder_0_0_0  : label is "ROM4_Encoder.lpc";
  attribute MEM_INIT_FILE of ROM4_Encoder_0_0_0 : label is "rom_encoder.mem";
  attribute RESETMODE of ROM4_Encoder_0_0_0     : label is "SYNC";

begin
  -- component instantiation statements
  scuba_vhi_inst : VHI
    port map (Z => scuba_vhi);

  scuba_vlo_inst : VLO
    port map (Z => scuba_vlo);

  ROM4_Encoder_0_0_0 : DP16KC
    generic map (INITVAL_3F  => "0x00080000400000000001000800000100001000020008000002000800000200080000020008000003",
                 INITVAL_3E  => "0x00080000800008000003000800008000080000030008000080000800000300080000800008000004",
                 INITVAL_3D  => "0x00080000800008000080000800008000080000040008000080000800008000080000800008000004",
                 INITVAL_3C  => "0x00080000800008000080000800008000080000040008000080000800008000080000800008000005",
                 INITVAL_3B  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000005",
                 INITVAL_3A  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000005",
                 INITVAL_39  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000005",
                 INITVAL_38  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000046",
                 INITVAL_37  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_36  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000006",
                 INITVAL_35  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_34  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000006",
                 INITVAL_33  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_32  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000006",
                 INITVAL_31  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_30  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000047",
                 INITVAL_2F  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_2E  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_2D  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_2C  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000007",
                 INITVAL_2B  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_2A  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_29  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_28  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000047",
                 INITVAL_27  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_26  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_25  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_24  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_23  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_22  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_21  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_20  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1F  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1E  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1D  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1C  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1B  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_1A  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_19  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_18  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_17  => "0x00047000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_16  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_15  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_14  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_13  => "0x00007000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_12  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_11  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_10  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0F  => "0x00047000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0E  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0D  => "0x00006000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0C  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0B  => "0x00006000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_0A  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_09  => "0x00006000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_08  => "0x00080000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_07  => "0x00046000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_06  => "0x00005000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_05  => "0x00005000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_04  => "0x00005000800008000080000800008000080000800008000080000800008000080000800008000080",
                 INITVAL_03  => "0x00005000800008000080000800008000080000800000400080000800008000080000800008000080",
                 INITVAL_02  => "0x00004000800008000080000800008000080000800000400080000800008000080000800008000080",
                 INITVAL_01  => "0x00004000800008000080000030008000080000800000300080000800008000003000800008000080",
                 INITVAL_00  => "0x00003000800000200080000020008000002000800000200001000010008000001000800004000080",
                 CSDECODE_B  => "0b111", CSDECODE_A => "0b000", WRITEMODE_B => "NORMAL",
                 WRITEMODE_A => "NORMAL", GSR => "DISABLED", REGMODE_B => "NOREG",
                 REGMODE_A   => "OUTREG", DATA_WIDTH_B => 18, DATA_WIDTH_A => 18)
    port map (DIA0  => scuba_vlo, DIA1 => scuba_vlo, DIA2 => scuba_vlo,
              DIA3  => scuba_vlo, DIA4 => scuba_vlo, DIA5 => scuba_vlo,
              DIA6  => scuba_vlo, DIA7 => scuba_vlo, DIA8 => scuba_vlo,
              DIA9  => scuba_vlo, DIA10 => scuba_vlo, DIA11 => scuba_vlo,
              DIA12 => scuba_vlo, DIA13 => scuba_vlo, DIA14 => scuba_vlo,
              DIA15 => scuba_vlo, DIA16 => scuba_vlo, DIA17 => scuba_vlo,
              ADA0  => scuba_vlo, ADA1 => scuba_vlo, ADA2 => scuba_vlo,
              ADA3  => scuba_vlo, ADA4 => Address(0), ADA5 => Address(1),
              ADA6  => Address(2), ADA7 => Address(3), ADA8 => Address(4),
              ADA9  => Address(5), ADA10 => Address(6), ADA11 => Address(7),
              ADA12 => Address(8), ADA13 => Address(9), CEA => OutClockEn,
              CLKA  => OutClock, OCEA => OutClockEn, WEA => scuba_vlo,
              CSA0  => scuba_vlo, CSA1 => scuba_vlo, CSA2 => scuba_vlo,
              RSTA  => Reset, DIB0 => scuba_vlo, DIB1 => scuba_vlo,
              DIB2  => scuba_vlo, DIB3 => scuba_vlo, DIB4 => scuba_vlo,
              DIB5  => scuba_vlo, DIB6 => scuba_vlo, DIB7 => scuba_vlo,
              DIB8  => scuba_vlo, DIB9 => scuba_vlo, DIB10 => scuba_vlo,
              DIB11 => scuba_vlo, DIB12 => scuba_vlo, DIB13 => scuba_vlo,
              DIB14 => scuba_vlo, DIB15 => scuba_vlo, DIB16 => scuba_vlo,
              DIB17 => scuba_vlo, ADB0 => scuba_vhi, ADB1 => scuba_vlo,
              ADB2  => scuba_vlo, ADB3 => scuba_vlo, ADB4 => scuba_vlo,
              ADB5  => scuba_vlo, ADB6 => scuba_vlo, ADB7 => scuba_vlo,
              ADB8  => scuba_vlo, ADB9 => scuba_vlo, ADB10 => scuba_vlo,
              ADB11 => scuba_vlo, ADB12 => scuba_vlo, ADB13 => scuba_vlo,
              CEB   => scuba_vhi, CLKB => scuba_vlo, OCEB => scuba_vhi,
              WEB   => scuba_vlo, CSB0 => scuba_vlo, CSB1 => scuba_vlo,
              CSB2  => scuba_vlo, RSTB => scuba_vlo, DOA0 => Q(0), DOA1 => Q(1),
              DOA2  => Q(2), DOA3 => Q(3), DOA4 => Q(4), DOA5 => Q(5), DOA6 => Q(6),
              DOA7  => Q(7), DOA8 => open, DOA9 => open, DOA10 => open, DOA11 => open,
              DOA12 => open, DOA13 => open, DOA14 => open, DOA15 => open,
              DOA16 => open, DOA17 => open, DOB0 => open, DOB1 => open, DOB2 => open,
              DOB3  => open, DOB4 => open, DOB5 => open, DOB6 => open, DOB7 => open,
              DOB8  => open, DOB9 => open, DOB10 => open, DOB11 => open,
              DOB12 => open, DOB13 => open, DOB14 => open, DOB15 => open,
              DOB16 => open, DOB17 => open);

end Structure;

-- synopsys translate_off
library ecp3;
configuration Structure_CON of ROM4_Encoder is
  for Structure
    for all : VHI use entity ecp3.VHI(V); end for;
    for all : VLO use entity ecp3.VLO(V); end for;
    for all : DP16KC use entity ecp3.DP16KC(V); end for;
  end for;
end Structure_CON;

-- synopsys translate_on
