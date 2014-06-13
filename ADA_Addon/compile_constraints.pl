#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "trb3_periph_ADA";  #Name of top-level entity


#create full lpf file
system("cp ../base/trb3_periph_ADA.lpf diamond/$TOPNAME.lpf");
system("cat currentRelease/trbnet_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat currentRelease/tdc_constraints_64.lpf >> diamond/$TOPNAME.lpf");
system("cat currentRelease/unimportant_lines_constraints.lpf >> diamond/$TOPNAME.lpf");
system("cat unimportant_lines_constraints.lpf >> diamond/$TOPNAME.lpf");

