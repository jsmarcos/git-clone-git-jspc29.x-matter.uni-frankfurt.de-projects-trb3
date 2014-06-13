#!/usr/bin/perl
use warnings;
use strict;
use File::Basename;
use Cwd 'realpath';

my $TOPNAME = 'trb3_central';
my $workdir = './workdir';

my $script_dir = dirname(realpath(__FILE__));
$workdir = $ARGV[0] if (@ARGV);

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

chdir($script_dir);

system ("ln -sfT $back/../tdc_release/Adder_304.ngo $workdir/Adder_304.ngo");

system("cp ../base/trb3_central_cts.lpf $workdir/$TOPNAME.lpf");
system("cat tdc_release/tdc_constraints_4.lpf >> $workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> $workdir/$TOPNAME.lpf");
system("sed -i 's#THE_TDC/#gen_TDC_THE_TDC/#g' $workdir/$TOPNAME.lpf");