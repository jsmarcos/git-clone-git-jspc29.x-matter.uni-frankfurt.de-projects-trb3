#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;

my $TOPNAME                      = "trb3_periph";  #Name of top-level entity
my $BasePath                     = "../base/";     #path to "base" directory

#create full lpf file
system("cp $BasePath/".$TOPNAME."_ada.lpf workdir/$TOPNAME.lpf");
system("cat ".$TOPNAME."_constraints.lpf >> workdir/$TOPNAME.lpf");

