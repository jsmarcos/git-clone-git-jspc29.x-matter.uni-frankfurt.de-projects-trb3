#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;


my $build_master = 1;
my $build_slave  = 1;

my $mode = $ARGV[0];
$mode = 's' unless defined $mode;
 
$build_master = 0 if $mode eq 's';
$build_slave  = 0 if $mode eq 'm' or $mode eq 'w';

print "Will build:\n";
print " -> Slave\n" if $build_slave;
print " -> Master\n" if $build_master;

print "\n\n";
 local $| = 1;
if ($mode eq 'w') {
   print "Wait for slave process\n";
   while(-e 'workdir') {
      sleep 3;
      print ('.');
   }
}

if ($build_master and $build_slave) {
   system "xterm -e './compile_periph_frankfurt.pl s; read' &";
   sleep 5;
   system "xterm -e './compile_periph_frankfurt.pl w; read' &";      
   sleep 5;
   local $| = 1;
   while ( (-e '.lock_slave') or (-e '.lock_master')) {
      sleep 3;
      print '.';
   }
   
   exit;
}


###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph_cbmnet";  #Name of top-level entity
my $BasePath                     = "../base/";     #path to "base" directory
my $CbmNetPath                   = "../../cbmnet";
my $lattice_path                 = '/d/jspc29/lattice/diamond/2.01';
my $synplify_path                = '/d/jspc29/lattice/synplify/F-2012.03-SP1/';
my $lm_license_file_for_synplify = "27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";
###################################################################################

my $workdir = "workdir_" . ($build_slave ? 'slave' : 'master');

system "touch .lock_" . ($build_slave ? 'slave' : 'master');
symlink($CbmNetPath, 'cbmnet') unless (-e 'cbmnet');

unless(-e $workdir) {
   mkdir $workdir;
   chdir $workdir;
   system '../../base/linkdesignfiles.sh';
   symlink '../cores/cbmnet_sfp1.txt', 'cbmnet_sfp1.txt';
   chdir '..';
}

unlink 'workdir';
symlink $workdir, 'workdir';

use FileHandle;

$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;


my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";

#create full lpf file
system("cp $BasePath/$TOPNAME.lpf $workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> $workdir/$TOPNAME.lpf");

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
    constant CBM_FEE_MODE_C       : integer   := $build_slave;

end package version;
EOF
$fh->close;

system("env| grep LM_");
my $r = "";

my $c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME.prj";
$r=execute($c, "do_not_exit" );

system 'rm -f workdir';

chdir $workdir;
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

$c=qq| $lattice_path/ispfpga/bin/lin/edif2ngd  -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

my $tpmap = $TOPNAME . "_map" ;

$c=qq|$lattice_path/ispfpga/bin/lin/map  -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);


system("rm $TOPNAME.ncd");

$c=qq|$lattice_path/ispfpga/bin/lin/multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
#$c=qq|$lattice_path/ispfpga/bin/lin/par -f "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.dir" "$TOPNAME.prf"|;
execute($c);

#Make Bitfile
$c=qq|$lattice_path/ispfpga/bin/lin/ltxt2ptxt $TOPNAME.ncd|;
execute($c);
$c=qq|$lattice_path/ispfpga/bin/lin/bitgen  -w "$TOPNAME.ncd"  "$TOPNAME.prf"|;
execute($c);


# IOR IO Timing Report
$c=qq|$lattice_path/ispfpga/bin/lin/iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

# TWR Timing Report
$c=qq|$lattice_path/ispfpga/bin/lin/trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|$lattice_path/ispfpga/bin/lin/trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);


chdir "..";

unlink ".lock_" . ($build_slave ? 'slave' : 'master');

print "DONE\n";

unless (-e "$workdir/trb3_periph_cbmnet.bit") {
   print "no bit file found. press enter to continue\n\a"; <>;
}
  

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print "\n\ncommand to execute: $c \n";
    $r=system($c);
    if($r) {
  print "$!";
  if($op ne "do_not_exit") {
      wait;
  }
    }

    return $r;

}

