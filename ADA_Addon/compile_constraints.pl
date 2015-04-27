#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "trb3_periph_ADA";  #Name of top-level entity


#create full lpf file
system("cp ../base/trb3_periph_ADA.lpf workdir/diamond/$TOPNAME.lpf");
system("cat tdc_release/trbnet_constraints.lpf >> workdir/diamond/$TOPNAME.lpf");
system("cat tdc_release/tdc_constraints_64.lpf >> workdir/diamond/$TOPNAME.lpf");
system("cat tdc_release/unimportant_lines_constraints.lpf >> workdir/diamond/$TOPNAME.lpf");
system("cat unimportant_lines_constraints.lpf >> workdir/diamond/$TOPNAME.lpf");

