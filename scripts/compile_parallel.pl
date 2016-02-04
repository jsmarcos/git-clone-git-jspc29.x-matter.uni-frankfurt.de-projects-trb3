#!/usr/bin/perl
use warnings;
use strict;
use Cwd;

my @compile_list = ("trb3_periph_32PinAddOn", "trb3_periph_ADA", "trb3_periph_gpin", "trb3_periph_padiwa",
#		    "trb3_periph_hadesstart", "cbmtof", "trb3sc", "dirich",
#		    "trb3_periph_hub", "trb3_central_cts",
		   );
my $cwd = getcwd();

for my $i (0 .. $#compile_list) {
  my $design = $compile_list[$i];
  my $tab = $i+1;
  print "\033]777;tabbedex;new_tab\007";
  sleep 0.1;
  print "\033]777;tabbedex;make_current;$tab\007";
  print "\033]777;tabbedex;set_tab_name;$design\007";
  print "\033]777;tabbedex;interactive_command;cd $cwd\007";
  print "\033]777;tabbedex;interactive_command;./compile.pl -d $design\007";
  sleep 1;
}
