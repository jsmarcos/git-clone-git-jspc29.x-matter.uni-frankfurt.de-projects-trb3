#!/usr/bin/perl
use warnings;
use strict;
use FileHandle;



#sub RetriveChannelNumber()
my $FileNameA = "trb3_periph.vhd";             #to retrive the channel number 
my $FileNameB = "Channel.vhd";                 #to retrive carry chain elements
my $FileNameC = "trb3_periph_constraints.lpf"; #to retrive names of the starting points of channels (slice names)

my $ChannelNumber;
my $fhA = new FileHandle("< $FileNameA");
while(<$fhA>)
{
    chomp($_);
    my $lineA = $_;
    if( $lineA =~ /CHANNEL_NUMBER\s=>\s(\d+),/ ) {$ChannelNumber = $1;}   
}
if( defined $ChannelNumber ){	print "Channel number: $ChannelNumber\n";}
else{print "Channel number is not defined ! Exit.";    exit(0);}
$fhA->close();

my $CarryChainNumber;
my $fhB = new FileHandle("< $FileNameB");
while(<$fhB>)
{
    chomp($_);
    my $lineB = $_;
    if( $lineB =~ /FC\s:\sAdder_(\d+)/ ) {$CarryChainNumber = $1;}   
}
if( defined $CarryChainNumber ){	print "Carry chain number number: $CarryChainNumber\n";}
else{print "Carry chain number is not defined ! Exit.";    exit(0);}
$fhB->close();

my $FFLocationR;
my $FFLocationC;
my $FFLocation;
my $HitNumber;
my $FFPart;
my $fhC = new FileHandle("< $FileNameC");
my $fhD = new FileHandle("> ff_constrains.lpf");
my $TmpText;

while(<$fhC>)
{
    chomp($_);
    my $lineD = $_;
    if( $lineD =~ /LOCATE\sUGROUP\s\"FC_(.+)\"\s\SITE\s\"R(\d+)C(\d+)(.+)\"/ ) 
    {
	$FFLocationR = $2; 
	$FFLocationC = $3; 
	$HitNumber = $1;
	
	#print "FF location : $FFLocation\n"; 
	if( $HitNumber < ($ChannelNumber+1) )
	{
	    for (my $i=0;$i<$CarryChainNumber;$i++)
	    {
		if($i % 3 == 0) {$FFPart = 'A';}
		if($i % 3 == 1) {$FFPart = 'B';}
		if($i % 3 == 2) {$FFPart = 'C';}
		$FFLocation = $FFLocationC + int($i/3);
		$TmpText = "LOCATE COMP \"THE_TDC/GEN_Channels_${HitNumber}_Channels/FC/FF_$i SITE \"R${FFLocationR}C${FFLocation}${FFPart}\"\n";
		print $TmpText;
		print {$fhD} $TmpText;
	    }
	}
    }   
}




