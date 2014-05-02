#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "trb3_periph_32PinAddOn";  #Name of top-level entity


#create full lpf file
system("cp ../base/trb3_periph_32PinAddOn.lpf diamond/$TOPNAME.lpf");
system("cat currentRelease/trbnet_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat currentRelease/tdc_constraints.lpf >> diamond/$TOPNAME.lpf");

