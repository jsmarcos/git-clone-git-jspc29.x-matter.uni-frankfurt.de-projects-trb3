#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME  = "trb3_periph_adc"; #Name of top-level entity

system("cp ../base/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> workdir/$TOPNAME.lpf");
