#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;
use Getopt::Long;

###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph_gpin";  #Name of top-level entity
my $IMPLEMENTATION               = "gpin";
my $lattice_path                 = '/opt/lattice/diamond/3.1/';
my $lattice_bin_path             = "$lattice_path/bin/lin"; # note the lin/lin64 at the end, no isfgpa needed
my $synplify_path                = '/opt/synplicity/I-2013.09-SP1'; 
my $lm_license_file_for_synplify = "27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";
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
$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;


my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";

my $WORKDIR = "workdir_bit";
unless(-d $WORKDIR) {
  mkdir $WORKDIR or die "can't create workdir '$WORKDIR': $!";
}

system("ln -sfT $lattice_path $WORKDIR/lattice-diamond");

chdir $WORKDIR;
system("cp -p ../diamond/$IMPLEMENTATION/sfp*.txt .");
system("cp -p ../diamond/$IMPLEMENTATION/$TOPNAME.ncd .");
system("cp -p ../diamond/$IMPLEMENTATION/$TOPNAME.prf .");

$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

my $c=qq|ltxt2ptxt $TOPNAME.ncd|;
execute($c);

$c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
# $c=qq|$lattice_path/ispfpga/bin/lin/bitgen -w "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

chdir "..";
exit;

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print "\n\ncommand to execute: $c \n";
    my $r=system($c);
    if($r) {
	print "$!";
	if($op ne "do_not_exit") {
	    exit;
	}
    }
    return $r;
}
