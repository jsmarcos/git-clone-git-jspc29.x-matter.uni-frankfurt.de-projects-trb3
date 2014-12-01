#!/usr/bin/perl
use warnings;
use strict;
use File::Basename;
use Cwd 'realpath';

my $TOPNAME = 'trb3_periph_billboard';
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

system("cp ../base/$TOPNAME.lpf $workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> $workdir/$TOPNAME.lpf");

chdir($workdir);
system ("$back/../../base/linkdesignfiles.sh '$back'");