#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME  = "trb3_periph_gpin"; #Name of top-level entity

#create full lpf file
system("cp ../base/$TOPNAME.lpf diamond/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.5/trbnet_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.5/tdc_constraints.lpf >> diamond/$TOPNAME.lpf");

