#!/usr/bin/perl
use warnings;
use strict;
use File::Basename;
use Cwd 'realpath';

my $TOPNAME = 'trb3_central';
my $workdir = './workdir';

my $script_dir = dirname(realpath(__FILE__));
$workdir = $ARGV[0] if (@ARGV);


# get activated modules
my %configSettings = ();
open(CONFIG, 'config.vhd');
my $config = "#!!! This file was compiled using compile_contraints.pl.\n#!!! DO NOT EDIT AS ALL CHANGES WILL BE OVERRIDEN\n\n";
print "The following module configuration was derived from config.vhd:\n";
while(my $line = <CONFIG>) {
   if ($line =~ /(INCLUDE_\S+).*:=.*c_(yes|no)/i) {
      my $mod = uc $1;
      my $ena = (lc $2) eq 'yes' ? 1 : 0;
      $configSettings{$mod} = $ena;
      
      my $conf = "set $mod $ena\n";
      print ' ' . $conf;
      $config .= $conf;
   }
}
close(CONFIG);

open TCLCONF, '>', $TOPNAME . '_prjconfig.tcl';
print TCLCONF $config;
close TCLCONF;


die("workdir has to be relative to compile_constraints.pl") if $workdir =~ m/^\//;
die("workdir must not contain ..") if $workdir =~ m/\.\./;
$workdir =~ s/(\.\/|\/$)//g; # remove ./ and trailing slash
$workdir =~ s/\/{2,}/\//g; # remove multiple // in path

my $back = "../" x ($workdir =~ tr/\///);
$back = './' unless $back;

chdir($script_dir);

unless(-e $workdir) {
  print "Creating workdir\n";
  system ("mkdir $workdir");
}

chdir($workdir);
system ("$back/../../base/linkdesignfiles.sh '$back'");
symlink "$back/../../base/cores/cbmnet_sfp1.txt", 'cbmnet_sfp1.txt';
symlink "$back/../tdc_release/Adder_304.ngo", "Adder_304.ngo";

chdir($script_dir);

system("cp ../base/trb3_central_cts.lpf $workdir/$TOPNAME.lpf");
system("cat tdc_release/tdc_constraints_4.lpf >> $workdir/$TOPNAME.lpf") if $configSettings{'INCLUDE_TDC'};
#system("cat tdc_release/unimportant_lines_constraints.lpf >> $workdir/$TOPNAME.lpf") if $configSettings{'INCLUDE_TDC'};
system("cat cbmnet_bridge/cbmnet_bridge.lpf >> $workdir/$TOPNAME.lpf") if $configSettings{'INCLUDE_CBMNET'};
system("cat ".$TOPNAME."_constraints.lpf >> $workdir/$TOPNAME.lpf");

open FILE, "<$workdir/$TOPNAME.lpf" or die "Couldnt open file: $!";
my $lpf = join('', <FILE>); 
close FILE;

$lpf =~ s#THE_CBM_BRIDGE/#GEN_CBMNET.THE_CBM_BRIDGE/#g;


$lpf =~ s#THE_TDC/#GEN_TDC.THE_TDC/#g;
$lpf =~ s#GEN_Channels_(\d+)_Channels#GEN_Channels.$1.Channels#g;
$lpf =~ s#SimAdderNo_FC#SimAdderNo.FC#g;
$lpf =~ s#GEN_Channels_*_Channels/sync_q_2*#GEN_Channels.*.Channels/sync_q[2]#g;
# $lpf =~ s#THE_TDC/GEN_Channels_*_Channels/gen_DEBUG_risingEdgeDetect_1/PULSE_OUT#GEN_TDC.THE_TDC/GEN_Channels.*.Channels/risingEdgeDetect_1/PULSE_OUT#g;
$lpf =~ s#GEN_TDC(.*)The_Buffer#GEN_TDC$1Buffer_64.The_Buffer#g;
$lpf =~ s#THE_TDC/GenCoarseCounter_(\d+)_TheCoarseCounter#THE_TDC/GenCoarseCounter.$1.TheCoarseCounter#g;
$lpf =~ s#THE_TDC/TheReadout#THE_TDC/TheFirstReadout#g;
$lpf =~ s#gen_DEBUG_risingEdgeDetect_1#gen_DEBUG.risingEdgeDetect_1#g;

open FILE, ">$workdir/$TOPNAME.lpf" or die "Couldnt open file: $!";
print FILE $lpf;
close FILE; 