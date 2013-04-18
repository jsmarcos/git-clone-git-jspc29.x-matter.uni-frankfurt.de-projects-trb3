#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "trb3_periph";  #Name of top-level entity


#create full lpf file
system("cp ../base/trb3_periph_mainz.lpf diamond/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.4/trbnet_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.4/tdc_constraints.lpf >> diamond/$TOPNAME.lpf");

