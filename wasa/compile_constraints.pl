#!/usr/bin/perl

use Data::Dumper;
use warnings;
use strict;

my $TOPNAME  = "trb3_periph_padiwa"; #Name of top-level entity

#create full lpf file
system("cp ../base/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.3/trbnet_constraints.lpf >> workdir/$TOPNAME.lpf");
system("cat ../tdc_releases/tdc_v1.3/tdc_constraints.lpf >> workdir/$TOPNAME.lpf");
