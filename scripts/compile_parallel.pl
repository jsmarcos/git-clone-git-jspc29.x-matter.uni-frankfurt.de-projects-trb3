#!/usr/bin/perl
use warnings;
use strict;
use Cwd;

my %compile_list=(
		  trb3_periph_32PinAddOn =>{path=>"../../trb3/32PinAddOn"},
		  trb3_periph_ADA        =>{path=>"../../trb3/ADA_Addon"},
		  trb3_periph_gpin       =>{path=>"../../trb3/gpin"},
		  trb3_periph_padiwa     =>{path=>"../../trb3/wasa"},
#		  trb3_periph_hadesstart =>{path=>"../../trb3/hadesstart"},
#		  trb3_periph_hub        =>{path=>"../../trb3/hub"},
#		  trb3_central_cts       =>{path=>"../../trb3/cts"},
		  cbmtof                 =>{path=>"../../trb3/cbmtof"},
#		  trb3sc                 =>{path=>"../../trb3sc/tdctemplate"},
#		  dirich                 =>{path=>"../../dirich/dirich"},
		 );



###################################################################################
#Options for the script
my $help = $ARGV[0];

if ($help eq "-h") {
  system("./compile.pl -h");
  exit;
}

my $cwd = getcwd();
my $tab = 1;

for my $design (sort keys %compile_list) {
  my $path = $compile_list{$design}{path};
  print "$path\n";
  print "\033]777;tabbedex;new_tab\007";
  sleep 0.1;
  print "\033]777;tabbedex;make_current;$tab\007";
  print "\033]777;tabbedex;set_tab_name;$design\007";
  print "\033]777;tabbedex;interactive_command;cd $cwd; cd $path\007";
  print "\033]777;tabbedex;interactive_command;./compile.pl @ARGV\007";
  sleep 1;
  $tab = $tab+1;
}
