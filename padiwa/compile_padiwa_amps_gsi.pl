#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;




###################################################################################
#Settings for this project
my $TOPNAME                      = "padiwa_amps";  #Name of top-level entity
my $lattice_path                 = '/opt/lattice/diamond/2.2_x64';
my $lattice_bin_path             = "$lattice_path/bin/lin64"; # note the lin/lin64 at the end, no isfgpa needed
my $synplify_path                = '/opt/synplicity/F-2012.03-SP1';
my $lm_license_file_for_synplify = '27000@lxcad01.gsi.de';
my $lm_license_file_for_par      = '1702@hadeb05.gsi.de';
###################################################################################



# source the standard lattice environment
$ENV{bindir}="$lattice_bin_path";
open my $SOURCE, "bash -c '. $lattice_bin_path/diamond_env >& /dev/null; env'|" or
  die "Can't fork: $!";
while (<$SOURCE>) {
  if (/^(.*)=(.*)/) {
    $ENV{$1} = ${2} ;
  }
}
close $SOURCE;


$ENV{'PAR_DESIGN_NAME'}=$TOPNAME;

# 
# set_option -technology MACHXO2
# set_option -part LCMXO2_4000HC
# set_option -package FTG256C
# set_option -speed_grade -6
# set_option -part_companion ""

$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;




my $FAMILYNAME="MACHXO2";
my $DEVICENAME="LCMXO2-4000HC";
my $PACKAGE="FTBGA256";
my $SPEEDGRADE="6";

my $WORKDIR = "workdir";
unless(-d $WORKDIR) {
  mkdir $WORKDIR or die "can't create workdir '$WORKDIR': $!";
}

system("ln -sfT $lattice_path $WORKDIR/lattice-diamond");

#create full lpf file
system("cp ../base/".$TOPNAME.".lpf $WORKDIR/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");


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


chdir $WORKDIR;
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

$c=qq|edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq|map  -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);

system("rm $TOPNAME.ncd");

#$c=qq|mpartrce -p "../$TOPNAME.p2t" -log "$TOPNAME.log" -o "$TOPNAME.rpt" -pr "$TOPNAME.prf" -tf "$TOPNAME.pt" "|.$TOPNAME.qq|_map.ncd" "$TOPNAME.ncd"|;
#  $c=qq|multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
$c=qq|par -w -l 5 -i 6 -t 1 -c 0 -e 0 -exp parUseNBR=1:parCDP=0:parCDR=0:parPathBased=OFF $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
execute($c);

# IOR IO Timing Report
$c=qq|iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

# TWR Timing Report
$c=qq|trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

# $c=qq|ltxt2ptxt $TOPNAME.ncd|;
# execute($c);

$c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -jedec  $TOPNAME.ncd $TOPNAME.jed $TOPNAME.prf|;
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
