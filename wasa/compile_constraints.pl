#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME  = "trb3_periph_padiwa"; #Name of top-level entity

#create full lpf file
system("cp ../base/$TOPNAME.lpf diamond/trb3_periph.lpf");
system("cat currentRelease/trbnet_constraints.lpf >> diamond/trb3_periph.lpf");
system("cat currentRelease/tdc_constraints_64.lpf >> diamond/trb3_periph.lpf");
system("cat currentRelease/unimportant_lines_constraints.lpf >> diamond/trb3_periph.lpf");
system("cat unimportant_lines_constraints.lpf >> diamond/trb3_periph.lpf");


#$TOPNAME  = "panda_dirc_wasa"; #Name of top-level entity

##create full lpf file
#system("cp ../base/".$TOPNAME."1.lpf workdir/$TOPNAME.lpf");
#system("cat ".$TOPNAME."_constraints.lpf >> workdir/$TOPNAME.lpf");

