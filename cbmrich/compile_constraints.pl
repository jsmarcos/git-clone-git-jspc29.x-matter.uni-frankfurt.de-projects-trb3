#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "cbmrich";  #Name of top-level entity


#create full lpf file
system("cp ../base/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.1.1/tdc_constraints.lpf >> workdir/$TOPNAME.lpf");
