#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $workdir = shift @ARGV || 'workdir';
unless(-d $workdir) {
	print "Creating workdir $workdir\n";
	mkdir $workdir or die "cant create $workdir: $!";
}

my $TOPNAME  = "trb3_periph_adc"; #Name of top-level entity

system("cp ../base/$TOPNAME.lpf $workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> $workdir/$TOPNAME.lpf");
