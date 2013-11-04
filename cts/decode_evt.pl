#!/usr/bin/env perl
# little tool to decode a CTS subevent provided via stdin in the daq_anal
# format. just copy and paste the frame starting with the subevent header

use strict;
use warnings;
use Data::Dumper;

my $input = '';
while (my $line = <STDIN>) {
   chomp($line);
   last unless $line;
   $input .= $line . ' ';
};

my @dec = grep(/^0x/, (split /\s+/, $input));
shift @dec;


my $word = hex(shift @dec);
my $evt = {
   'itc_state' => $word & 0xffff,
   'input_counters' => ($word >> 16) & 0xf,
   'itc_counters' => ($word >> 20) & 0xf,
   'idledead'  => ($word >> 25) & 0x1,
   'trigger_stats'  => ($word >> 26) & 0x1,
   'timestamp'  => ($word >> 27) & 0x1,
   'etm_mode'  => ($word >> 28) & 0x2
};

print Dumper $evt;

for(my $i=0; $i < $evt->{'input_counters'}; $i++) {
   printf "Input %d Level Counter: % 14d\n", $i, hex(shift(@dec));
   printf "Input %d Edge  Counter: % 14d\n", $i, hex(shift(@dec));
}

for(my $i=0; $i < $evt->{'itc_counters'}; $i++) {
   printf "ITC %02d Level Counter:  % 14d\n", $i, hex(shift(@dec));
   printf "ITC %02d Edge  Counter:  % 14d\n", $i, hex(shift(@dec));
}

if ($evt->{'idledead'}) {
   printf "Idle Time: %e s\n",  hex(shift(@dec)) * 1e-8;
   printf "Dead Time: %e s\n",  hex(shift(@dec)) * 1e-8;
}

if ($evt->{'trigger_stats'}) {
   printf "Trigger asserted   : % 14d cycles\n",  hex(shift(@dec));
   printf "Trigger rising edge: % 14d edges\n",  hex(shift(@dec));
   printf "Trigger accepted   : % 14d evts\n",  hex(shift(@dec));
}

if ($evt->{'timestamp'}) {
   printf "Timestamp: %d cycles\n",  hex(shift(@dec));
}

my $etmno = (!$evt->{'timestamp'} < 2) ? (!$evt->{'timestamp'}) : ((!$evt->{'timestamp'} == 2) ? 4 : -1);
if ($etmno >= 0) {
   for(my $i=0; $i < $etmno; $i++) {
      printf "ETM data: %s\n", $i, shift(@dec);
   }
} 
