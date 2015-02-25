#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;



###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph";  #Name of top-level entity
my $lattice_path                 = '/opt/lattice/diamond/3.2_x64/';
my $lattice_bin_path             = "$lattice_path/bin/lin64";
my $synplify_path                = '/opt/synplicity/I-2013.09-SP1';
my $lm_license_file_for_synplify = "27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";
###################################################################################





# source the standard lattice environment
$ENV{bindir}="$lattice_bin_path";
open my $SOURCE, "bash -c '. $lattice_bin_path/diamond_env ; env'|" or
  die "Can't fork: $!";
while (<$SOURCE>) {
  if (/^(.*)=(.*)/) {
    $ENV{$1} = ${2} ;
  }
}
close $SOURCE;

$ENV{'PAR_DESIGN_NAME'}=$TOPNAME;
$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;




my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";


my $WORKDIR = "workdir";
unless(-d $WORKDIR) {
    mkdir $WORKDIR or die "can't create workdir '$WORKDIR': $!";
}

system("ln -sfT $lattice_path $WORKDIR/lattice-diamond");


#create full lpf file
system("cp ../base/$TOPNAME"."_mupix.lpf workdir/$TOPNAME.lpf");
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

my $c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME.prj";
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


$c=qq| edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq| edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq| ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq| map  -hier -td_pack -retime EFFORT=6 -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);

system("rm $TOPNAME.ncd");


#$c=qq| multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
#execute($c);
#$c=qq|par -w -l 5 -t 1 $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
#execute($c);
#$c="cp $TOPNAME.dir/5_1.ncd $TOPNAME.ncd";
#system($c);
#$c="cat $TOPNAME.par";
#system($c);
# dont forget to create a nodelist.txt for multipar / mpartrce
$c=qq|mpartrce -p "../$TOPNAME.p2t" -f "../$TOPNAME.p3t" -tf "$TOPNAME.pt" "$tpmap.ncd" "$TOPNAME.ncd"|;
execute($c);

# IOR IO Timing Report
$c=qq| iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

# TWR Timing Report
$c=qq| trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq| trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq| ltxt2ptxt $TOPNAME.ncd|;
execute($c);

$c=qq| bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No  $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
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
