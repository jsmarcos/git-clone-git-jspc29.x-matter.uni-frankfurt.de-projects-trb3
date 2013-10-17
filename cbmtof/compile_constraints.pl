#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "cbmtof";  #Name of top-level entity


#create full lpf file
system("cp ../base/cbmtof.lpf diamond/$TOPNAME.lpf");
system("cat currentRelease/trbnet_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat currentRelease/tdc_constraints.lpf >> diamond/$TOPNAME.lpf");

