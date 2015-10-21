TOPNAME                      => "trb3_periph_hub",
lm_license_file_for_synplify => "27000\@lxcad01.gsi.de",
lm_license_file_for_par      => "1702\@hadeb05.gsi.de",
lattice_path                 => '/opt/lattice/diamond/3.5_x64/',
synplify_path                => '/opt/synplicity/J-2014.09-SP2',
#synplify_command             => "/opt/lattice/diamond/3.4_x64/bin/lin64/synpwrap -fg -options",
synplify_command             => "/opt/synplicity/J-2014.09-SP2/bin/synplify_premier_dp",

#Include only necessary lpf files
include_TDC                  => 0,
include_GBE                  => 0,
include_CTS                  => 0,
include_HUB                  => 1, # for the hub design on periph fpga
central_FPGA                 => 0,

#Report settings
firefox_open                 => 1,
twr_number_of_errors         => 20,


