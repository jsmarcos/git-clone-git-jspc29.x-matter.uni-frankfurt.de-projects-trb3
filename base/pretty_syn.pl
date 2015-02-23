#!/usr/bin/perl
use warnings;
use strict;
use Term::ANSIColor;

my $mode = 'normal';
while(my $line = <STDIN>) {
   if ($line =~ m/^(\@E|ERROR)[:\| ]/) {
      $mode = 'error';
      print color 'red';
   } elsif ($line =~ m/^(\@I|\@A|INFO)[:\| ]/) {
      $mode = 'info';
      print color 'BRIGHT_BLACK';
   } elsif ($line =~ m/^(\@N|NOTE)[:\| ]/) {
      $mode = 'note';
      print color 'cyan';
   } elsif ($line =~ m/^(\@W|WARNING)[:\| ]/) {
      $mode = 'warning';
      print color 'yellow';
   } elsif (not ($mode eq 'normal') and not $line =~ m/^\s/) {
      $mode = 'normal';
      print color 'reset';
   }
   
   print $line;
}

print color 'reset';
