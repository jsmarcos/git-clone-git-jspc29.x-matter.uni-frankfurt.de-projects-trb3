#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;




###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph";  #Name of top-level entity
my $lattice_path                 = '/usr/local/opt/lattice_diamond/diamond/3.2';
my $synplify_path                = '/usr/local/opt/synplify/I-2013.09-SP1/';
my $lm_license_file_for_synplify = "27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";
###################################################################################


use FileHandle;

$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
#$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;

my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";


#create full lpf file
system("cp ./$TOPNAME"."_nxyter.lpf workdir/$TOPNAME.lpf");
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
my $c = "";

$c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME.prj";
$r=execute($c, "do_not_exit" );


chdir "workdir";
$fh = new FileHandle("<$TOPNAME".".srr");
my @a = <$fh>;
$fh -> close;

foreach (@a)
{
    if(/\@E:/)
    {
	print STDERR  "\n";
	$c="cat $TOPNAME.srr | grep \"\@E\"";
	system($c);
        print STDERR  "\n\n";
	exit 129;
    }
}


$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

$c=qq| $lattice_path/ispfpga/bin/lin64/edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin64/edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin64/ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq|$lattice_path/ispfpga/bin/lin64/map  -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);

system("rm -vf $TOPNAME.ncd");
system("rm -vf $TOPNAME.dir/*");

$c=qq|$lattice_path/ispfpga/bin/lin64/par -f "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.dir" "$TOPNAME.prf"|;
execute($c, "do_not_exit");

print STDERR  "Do 0\n";

system("cp -va ${TOPNAME}.dir/*.ncd ./${TOPNAME}.ncd");

print STDERR  "Do 1\n";


# IOR IO Timing Report
$c=qq|$lattice_path/ispfpga/bin/lin64/iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

print STDERR  "Do 2\n";

# TWR Timing Report
$c=qq|$lattice_path/ispfpga/bin/lin64/trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

print STDERR  "Do 3\n";

$c=qq|$lattice_path/ispfpga/bin/lin64/trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

print STDERR  "Do 4\n";

$c=qq|$lattice_path/ispfpga/bin/lin64/ltxt2ptxt $TOPNAME.ncd|;
execute($c);

print STDERR  "Do 5\n";

$c=qq|$lattice_path/ispfpga/bin/lin64/bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No  $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
# $c=qq|$lattice_path/ispfpga/bin/lin64/bitgen  -w "$TOPNAME.ncd"  "$TOPNAME.prf"|;

print STDERR  "Do 6\n";

execute($c);

chdir "..";

exit;

sub execute {
    my ($c, $op) = @_;
    #print STDERR  "option: $op \n";
    $op = "" if(!$op);
    print STDERR  "\n\ncommand to execute: $c \n";
    $r=system($c);
    if($r) {
	print STDERR "$!";
	if($op ne "do_not_exit") {
	    print STDERR "------- EXIT by function execute --------\n";
            exit;
	}
    }

    return $r;

}
