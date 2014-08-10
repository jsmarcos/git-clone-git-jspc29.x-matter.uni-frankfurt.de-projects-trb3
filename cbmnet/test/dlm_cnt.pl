#!/usr/bin/perl
use warnings;
use strict;
use POSIX;
use Time::HiRes qw(usleep gettimeofday tv_interval);

$ENV{'SIMPATH'}='/d/salt/fairsoft/fairsoft_dec13/';

sub getTrb3Status {
   my $info = `./info.pl s`;
   my $count = '-';
   my $dlmRecv = '-';
   
   $count = hex($1) if $info =~ /stat_dlm_counter_i\(15 downto 0\)\s*\|\s*0x(....)/;
   $dlmRecv = $1 if $info =~ /rx_data_sp_i0\(17 downto 0\)\s*\|\s*.+: DLM(\d+)/;
   
 #  print "$count $dlmRecv\n";
   
   return ($count, $dlmRecv);
}

my $dlm_cmd = 'ssh jspc58 "/u/mpenschuck/Documents/flesnet/build/dlm %DLM%"';
#$dlm_cmd = 'ssh root@jspc58 "/u/mpenschuck/Downloads/dlm_nocp %DLM%"';
if ($ARGV[0]) {
   $dlm_cmd = '../../../flesnet/ctrl/control/cliclient/cliclient jspc58:9750 dlm 0x1 %DLM%';
}

#print $dlm_cmd;

my $interval = 0 * 1e6;

my @starttime = gettimeofday;

my $cnt = 0;
my $iteration = 1;

my ($startCount, $dlmRecv) = getTrb3Status();

printf "% 10s % 10s % 10s % 10s % 10s % 10s\n", "Time", "Iter", "Trb3Cnt", "CntDiff", "DLM sent", "DLM recv";

printf "Start count: %d\n", $startCount;

my $lastCount = 0;

my $dlmMatches = 0;
my $dlmMatchesOff = 0;
my $lastDlmSend = 0;
my %deltaHist = (-1,0, 0,0, 1,0, 2,0, 3,0, 4,0);

while($iteration < 10000) {
   my $dlm = $lastDlmSend;
   while($dlm == $lastDlmSend || $dlm < 2) {$dlm = int(rand(16));}

   my $cmd = $dlm_cmd;
   $cmd =~ s/%DLM%/$dlm/;
   `$cmd`;
   
   usleep($interval);
   
   my ($count, $dlmRecv) = getTrb3Status();
   
   my $timeEla = tv_interval([@starttime]);
   
   my $counts = ($count eq '-') ? '-' : (($count - $startCount) & 0xffff);
   my $countDif = $counts - $lastCount;
   
   $deltaHist{$countDif}++ if (exists $deltaHist{$countDif});
   $dlmMatches++ if ($dlmRecv == $dlm);
   $dlmMatchesOff++ if ($dlmRecv == $lastDlmSend);
	 
   my $prob = '';
   $prob = "!!!!!!" unless ($dlmRecv == $dlm);   

   printf "% 10s % 10s % 10s % 10s % 10s % 10s % 10s\n", $timeEla, $iteration, $counts, $countDif, $dlm, $dlmRecv, $prob;

#exit() if $countDif == 2 and $ARGV[1] or not ($dlmRecv == $dlm);;
   
   $lastCount = $counts;
   $lastDlmSend = $dlm;
   $iteration++;
}

my $totIter = $iteration-1;

printf "Correct DLM recv: %d (% 3.2f %%)\n", $dlmMatches, 100 * $dlmMatches / $totIter;
printf "Correct DLM recv (assuming 1 off): %d (% 3.2f %%)\n", $dlmMatchesOff, 100 * $dlmMatchesOff / ($totIter-1);
print "Iterations with CntDiff:\n";
for my $key (sort keys %deltaHist) {
   printf "% 5s: % 5d (% 3.2f %%)\n", $key, $deltaHist{$key}, 100 * $deltaHist{$key} / $totIter;
}
