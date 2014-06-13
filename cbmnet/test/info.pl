#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use File::Basename;
use List::Util  qw(first max reduce);
use POSIX qw/ceil/;

use Term::ANSIColor;
use bigint;


sub readFile {
   open FILE, "<", shift;
   my @lines = <FILE>;
   
   my $begin = first { $lines[$_] =~ /-- DEBUG_OUT_BEGIN/ } 0..$#lines; 
   my $end   = first { $lines[$_] =~ /-- DEBUG_OUT_END/ } 0..$#lines; 
   
   close FILE;
   
   return @lines[$begin+1 .. $end-1];
}

sub interpretLine {
   my $line = shift;
   return () unless ($line =~ m/DEBUG_OUT\s*\(\s*(\d+)\s*downto\s*(\d+)\s*\)\s*<=\s*([^;]+);/);
   my $globFrom = $2;
   my $globTo   = $1;
   my @exprs = reverse (split /\s*&\s*/, $3);
   
   my @defs = ();
   my $index = $globFrom;
   
   for my $expr (@exprs) {
      $expr =~ s/when.*$//;
         
      return () if ($expr =~ m/\(others/) ;
      
      if ($expr =~ m/"([01]+)"/) {
         $index += length $1;
      } else {
         my $len = 1;
         if ($expr =~ m/\(\s*(\d+)\s*downto\s*(\d+)\s*\)/) {
            $len = 1 + $1 - $2;
         }
         push @defs, [$expr, $index, $len];
         $index += $len;
     }
   }
   
   my $expLen = $globTo - $globFrom + 1;
   my $totLen = $index - $globFrom;
   
   print "width mismatch (expected $expLen, got $totLen): $line" if $expLen != $totLen;
   
   return @defs;
}

sub readRegs {
   my $endpoint = shift;
   my $length = shift;
   my $firstReg = 0xa008;
   my $res = `trbcmd rm $endpoint $firstReg $length 0`;
   
   my $reg = 0;
   my $i = 0;
   for my $line (split /\n/, $res) {
      if ($line =~ m/^0x....\s+0x(.{8})/) {
         $reg += hex($1) << (32 * $i++) ;
      }
   }
   
   return $reg;
}

sub paddListL {
   my $maxLen = max (map {length $_} @_);
   return map { ' ' x ($maxLen - length $_) . $_ } @_;
}

sub paddListR {
   my $maxLen = max (map {length $_} @_);
   return map { $_ . ' ' x ($maxLen - length $_) } @_;
}

my @lines = readFile( dirname(__FILE__) . "/../code/cbmnet_phy_ecp3.vhd" );
my @defs = ();

for my $line (@lines) {
   @defs = (@defs, interpretLine $line);
}

@defs = sort {(lc $a->[0]) cmp (lc $b->[0])} @defs;
my @names = paddListR (map {$_->[0]} @defs);


sub show8b10b {
   my $data = shift;
   my $k = shift;
   
   if ($k) {
      my %codes = (
         28, "K.28.0",
         60, "K.28.1",
         92, "K.28.2",
         124, "K.28.3",
         156, "K.28.4",
         188, "K.28.5",
         220, "K.28.6",
         252, "K.28.7",
         247, "K.23.7",
         251, "K.27.7",
         253, "K.29.7",
         254, "K.30.7");
   
      return $codes{$data};
   } else {
      return sprintf("D.%02d.%d", $data & 0x1f, ($data >> 5) & 0x7);
   }
}

sub show8b10bWord {
   my $data = shift;
   return
      show8b10b( ($data >> 8) & 0xff, ($data >> 17) & 1 ) . " " .
      show8b10b( ($data >> 0) & 0xff, ($data >> 16) & 1 );
}      


my @old_results;
my $first_one = 1;
while (1) {
   my @results = ();

   for my $i (1 .. 1) {
      my $reg = readRegs 0x8000 + $i, 8;
      my @slices = ();
      for my $def (@defs) {
         my $idx = $def->[1];
         my $len = $def->[2];
         my $text = sprintf($len == 1 ? "%x" : "0x%0" . (ceil(($len+3) / 4.0)) . "x", ($reg >> $idx) & ((1 << $len) - 1));
         if ($len == 18) {
            $text .= " " . show8b10bWord(($reg >> $idx) & ((1 << $len) - 1));
         }
         push @slices, $text;
      }
      
      push @results, [paddListL @slices];
   }

   for my $idx (0..$#names) {
      my $line = $names[$idx] . " | ";
   
      for my $i (0..$#results) {
         if ($#old_results > 0 and $results[$i]->[$idx] ne $old_results[$i]->[$idx]) {
            $line .= (color 'bold') . $results[$i]->[$idx] . (color 'reset');
         } else {
            $line .= $results[$i]->[$idx];
         }
         
         $line .= " | " if ($i < $#old_results);
      }
   
   
      print "$line\n";
   }
   
   @old_results = @results;
   
   
   sleep 1;
print $first_one ? `reset` : chr(27) . "[1;1H";
$first_one = 0;
}
