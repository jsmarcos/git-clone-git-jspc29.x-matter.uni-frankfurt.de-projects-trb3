#!/usr/bin/env perl
use warnings;
use strict;
use Data::Dumper;
use POSIX qw/ceil/;

my @packet = ();

my $success = 0;
my $errors = 0;
my $skipped = 0;
my $line = 0;
my $matched = 0;
my $ref = "";


sub fassert {
   my $cond = shift;
   my $msg = shift;
   
   unless ($cond) {
      @packet = ();
      $errors++;
      print "Error in $line ($ref): $msg\n";
   }
   
   return $cond;
}

sub stats {
   printf("Read: % 9d | Skipped: % 9d | Success: % 9d | Errors: % 9d | Unmatched: % 9d (%.1f %%)\n", $line, $skipped, $success, $errors, $line - $matched, 100* ($line - $matched) / $line )
}

my $lastFrameNo = -1;
my $lastTransNo = -1;

my $lastInnerTransNo = -1;

while(my $frame = <STDIN>) {
   $line++;
   $frame =~ /DATA\((.*)\):/;
   $ref = $1;
   $frame =~ s/DATA\(.*\):\s+//;
   $frame =~ s/\s+$//;
   my @frameData = map {hex} split(" ", $frame);
   
   next unless fassert($#frameData+1 >= 4,  "Frame must no be shorter than 8 bytes. Got " . (2*$#frameData+2));
   next unless fassert($#frameData+1 <= 32, "Frame must no be longer than 64 bytes. Got " . (2*$#frameData+2));

   my $hdr = shift @frameData;
      
   my $start = ($hdr & 0x4000) != 0;
   my $end   = ($hdr & 0x8000) != 0;
   my $frameNo = $hdr & 0x7f;
   my $transNo = ($hdr >> 7) & 0x1f;
   
   if ($start or $end) {
      $transNo = $hdr & 0xfff;
   }
   
   #print "$#frameData\n";
   
   next unless fassert($#frameData == 30 or $end, "Only last frame can be shorted than 64 bytes. Got " . (2*$#frameData+2));
   
   
   if ($start) {
      my $exp = ($lastTransNo+1) & 0xfff;
      fassert($lastTransNo == -1 or $exp == $transNo, "Expected sequential transaction numbers. Exp $exp. Got $transNo");
      fassert(-1 == $#packet, "Unexpected start");
      @packet = @frameData;
      $lastTransNo = $transNo;
   } else {
   
      if ($#packet == -1) {
         $skipped++;
      } else {
         my $exp = (($#packet+1)/31) & 0x7f;
         next unless fassert($end or $exp == $frameNo, "FrameNo mismatch. Exp $exp, Got: $frameNo " );
         next unless fassert(($lastTransNo & ($end ? 0xfff : 0x1f)) == $transNo, "TransNo mismatch. Exp $lastTransNo, Got: $transNo");
         @packet = (@packet, @frameData);
      }
   }

  # print join(" ", map{sprintf("%04x", $_)} @packet) . "\n";
   
   if ($end and $#packet > 0) {
      my $expectLength = ($packet[0] << 16) | $packet[1];
      
      pop @packet while ((2*$#packet+2) > $expectLength and $packet[-1] == 0xaaaa);
      next unless fassert($expectLength == 2*$#packet+2, "Length mismatch. Packet says $expectLength. Got " . (2*$#packet+2));
            
      my $payloadLength = ($expectLength - 16 - 8);
      next unless fassert($payloadLength % 4 == 0, "Payload length has to be a multiple of 4. Got $payloadLength bytes");
      
      my $payloadWords = $payloadLength / 4;
      my $fail=0;
      for(my $i = 0; $i < $payloadWords and !$fail; $i++) {
         $fail=1 unless fassert($fail or $packet[$i*2 + 8] == $packet[8], "TrbTransactionNo mismatch");
         unless($fail) {
            my $exp = ($payloadWords - $i) & 0xfff;
            my $got = $packet[$i*2 + 8 + 1] & 0xfff;
            $fail=1 unless fassert($fail or $exp == $got, "Payload-RunNo mismatch. Exp: $exp, Got: $got");
         }
      }
      
      unless($fail) {
         next unless fassert($fail or ($packet[8] & 0xff00) == 0xbb00, "Expected 0xbb-- as first word of payload");
         
         if ($lastInnerTransNo != -1) {
            my $exp = ($lastInnerTransNo + 1) & 0xff;
            my $got = $packet[8] & 0xff;
         #  print "Error at $line: Inner TransNo mismatch. Exp: $exp, Got $got\n" unless ($exp == $got);
         }
         
         $lastInnerTransNo = $packet[8] & 0xff;      
         
         $fail=1 unless fassert($fail or $packet[-1] == 0xc0de, "Trailer mismatch");
         $fail=1 unless fassert($fail or $packet[-2] == 0xbeaf, "Trailer mismatch");
         $fail=1 unless fassert($fail or $packet[-3] == 0x5555, "Trailer mismatch");
         $fail=1 unless fassert($fail or $packet[-4] == 0x0001, "Trailer mismatch");
         
         unless ($fail) {
            $success++;
            $matched += ceil(($#packet+1)/31);
         }
         
      }
      #print "Sucessfully read packet with $expectLength bytes\n" unless $fail;
      @packet = ();
   }
   
   stats() unless ($line % 10000);
}

stats();