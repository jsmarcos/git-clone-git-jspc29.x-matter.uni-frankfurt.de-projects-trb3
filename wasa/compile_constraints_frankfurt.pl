#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME  = "trb3_periph_padiwa"; #Name of top-level entity

#create full lpf file
system("cp ../base/$TOPNAME.lpf workdir/$TOPNAME.lpf");
system("cat tdc_release/trbnet_constraints.lpf >> workdir/$TOPNAME.lpf");
system("cat tdc_release/tdc_constraints_4.lpf >> workdir/$TOPNAME.lpf");


#$TOPNAME  = "panda_dirc_wasa"; #Name of top-level entity

#create full lpf file
#system("cp ../base/".$TOPNAME."1.lpf workdir/$TOPNAME.lpf");
#system("cat ".$TOPNAME."_constraints.lpf >> workdir/$TOPNAME.lpf");

