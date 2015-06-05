#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;




###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph_hub";  #Name of top-level entity
my $lm_license_file_for_synplify = "1702\@hadeb05.gsi.de"; #"27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";

my $lattice_path                 = '/d/jspc29/lattice/diamond/3.4_x64';
my $synplify_path                = '/d/jspc29/lattice/synplify/J-2014.09-SP2/';
###################################################################################


$ENV{'PAR_DESIGN_NAME'}=$TOPNAME;





use FileHandle;

$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;




my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";


#create full lpf file
system("cp ../base/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> workdir/$TOPNAME.lpf");


#set -e
#set -o errexit

#generate timestamp
my $t=time;
my $fh = new FileHandle(">version.vhd");
die "could not open file" if (! defined $fh);
print $fh <<EOF;

--## attention, automatically generated. Don't change by hand.
library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_ARITH.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;
use ieee.numeric_std.all;

package version is

    constant VERSION_NUMBER_TIME  : integer   := $t;

end package version;
EOF
$fh->close;

system("env| grep LM_");
my $r = "";

my $c="$lattice_path/bin/lin64/synpwrap -fg -options -batch $TOPNAME.prj";
$r=execute($c, "do_not_exit" );


chdir "workdir";
$fh = new FileHandle("<$TOPNAME".".srr");
my @a = <$fh>;
$fh -> close;



foreach (@a)
{
    if(/\@E:/)
    {
	print "\n";
	$c="cat $TOPNAME.srr | grep \"\@E\"";
	system($c);
        print "\n\n";
	exit 129;
    }
}


$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;


$c=qq| $lattice_path/ispfpga/bin/lin/edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq|$lattice_path/ispfpga/bin/lin/map  -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);

system("rm $TOPNAME.ncd");

# $c=qq|mpartrce -p "../$TOPNAME.p2t" -f "../$TOPNAME.p3t" -tf "$TOPNAME.pt" "|.$TOPNAME.qq|_map.ncd" "$TOPNAME.ncd"|;
#$c=qq|$lattice_path/ispfpga/bin/lin/multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
$c=qq|$lattice_path/ispfpga/bin/lin/par -w -l 5 -i 6 -t 3 -c 0 -e 0 -exp parUseNBR=1:parCDP=0:parCDR=0:parPathBased=OFF $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
execute($c);

# IOR IO Timing Report
# $c=qq|$lattice_path/ispfpga/bin/lin/iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
# execute($c);

# TWR Timing Report
$c=qq|$lattice_path/ispfpga/bin/lin/trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/ltxt2ptxt $TOPNAME.ncd|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No  $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
# $c=qq|$lattice_path/ispfpga/bin/lin/bitgen  -w "$TOPNAME.ncd"  "$TOPNAME.prf"|;
execute($c);

chdir "..";

exit;

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print "\n\ncommand to execute: $c \n";
    $r=system($c);
    if($r) {
	print "$!";
	if($op ne "do_not_exit") {
	    exit;
	}
    }

    return $r;

}
