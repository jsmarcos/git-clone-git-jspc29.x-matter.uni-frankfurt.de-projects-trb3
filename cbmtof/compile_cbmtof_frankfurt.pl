#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;
use Getopt::Long;

###################################################################################
#Settings for this project
my $TOPNAME                      = "cbmtof";  #Name of top-level entity
my $lm_license_file_for_synplify = "1702\@hadeb05.gsi.de"; #"27000\@lxcad01.gsi.de";
my $lm_license_file_for_par      = "1702\@hadeb05.gsi.de";

my $lattice_path                 = '/d/jspc29/lattice/diamond/3.4_x64';
my $synplify_path                = '/d/jspc29/lattice/synplify/J-2014.09-SP2/';
my $lattice_bin_path             = "$lattice_path/bin/lin64"; # note the lin/lin64 at the end, no isfgpa needed
###################################################################################

###################################################################################
#Options for the script
my $help = "";
my $isMultiPar = 0; # set it to zero for single par run on the local machine
my $nrNodes    = 0; # set it to one for single par run on the local machine
my $all        = 1;
my $syn        = 0;
my $map        = 0;
my $par        = 0;
my $timing     = 0;
my $bitgen     = 0;

my $result = GetOptions (
    "h|help"   => \$help,
    "m|mpar=i" => \$nrNodes,
    "a|all"    => \$all,
    "s|syn"    => \$syn,
    "mp|map"   => \$map,
    "p|par"    => \$par,
    "t|timing" => \$timing,
    "b|bitgen" => \$bitgen,
    );

if($help) {
    print "Usage: compile_priph_gsi.de <OPTIONS><ARGUMENTS>\n\n";
    print "-h  --help\tPrints the usage manual.\n";
    print "-a  --all\tRun all compile script. By default the script is going to rung the whole process.\n";
    print "-s  --syn\tRun synthesis part of the compile script.\n";
    print "-mp --map\tRun map part of the compile script.\n";
    print "-p  --par\tRun par part of the compile script.\n";
    print "-t  --timing\tRun timing analysis part of the compile script.\n";
    print "-b  --bitgen\tRun bit generation part of the compile script.\n";
    print "-m  --mpar\tSwitch for multi par. \"-m <number_of_nodes>\" (Default = off)\n";
    print "\t\tThe node list file name has to be edited in the script. (Default = nodes_lxhadeb07.txt)\n";
    print "\n";
    exit;
}

if ($nrNodes!=0){
    $isMultiPar=1;
}
if ($syn!=0 || $map!=0 || $par!=0 || $timing!=0 || $bitgen!=0){
    $all=0;
}
###################################################################################



# source the standard lattice environment
# $ENV{bindir}="$lattice_bin_path";
# open my $SOURCE, "bash -c '. $lattice_bin_path/diamond_env >& /dev/null; env'|" or
#   die "Can't fork: $!";
# while (<$SOURCE>) {
#   if (/^(.*)=(.*)/) {
#     $ENV{$1} = ${2} ;
#   }
# }
# close $SOURCE;


$ENV{'PAR_DESIGN_NAME'}=$TOPNAME;
$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;


my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";

my $WORKDIR = "workdir";
unless(-d $WORKDIR) {
  mkdir $WORKDIR or die "can't create workdir '$WORKDIR': $!";
}

system("ln -sfT $lattice_path $WORKDIR/lattice-diamond");

#create full lpf file
system("cp ../base/$TOPNAME.lpf $WORKDIR/$TOPNAME.lpf");
system("cat currentRelease/trbnet_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
system("cat currentRelease/tdc_constraints_64.lpf >> $WORKDIR/$TOPNAME.lpf");
system("cat currentRelease/unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
system("cat unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");


#generate timestamp
my $t=time;
my $fh = new FileHandle(">version.vhd");
die "could not open file" if (! defined $fh);
print $fh <<EOF;

--## attention, automatically generated. Don't change by hand.
library ieee;
USE IEEE.std_logic_1164.ALL;
USE IEEE.std_logic_ARITH.ALL;
USE IEEE.std_logic_UNSIGNED.ALL;
use ieee.numeric_std.all;

package version is

    constant VERSION_NUMBER_TIME  : integer   := $t;

end package version;
EOF
$fh->close;

system("env| grep LM_");
my $r     = "";
my $c     = "";
my @a     = ();
my $tpmap = $TOPNAME . "_map" ;

if($syn==1 || $all==1){
#     $c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME.prj";
    $c="$lattice_path/bin/lin64/synpwrap -fg -options -batch $TOPNAME.prj";
    $r=execute($c, "do_not_exit" );
}

chdir $WORKDIR;

if($syn==1 || $all==1){
    $fh = new FileHandle("<$TOPNAME".".srr");
    @a = <$fh>;
    $fh -> close;
    
    foreach (@a)
    {
	if(/\@E:/)
	{
	    print "\n";
	    $c="cat $TOPNAME.srr | grep \"\@E\"";
	    system($c);
	    print "\n\n";
	    exit 129;
	}
    }
}

$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

if($map==1 || $all==1){
    $c=qq| edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
    execute($c);
    
    $c=qq|edfupdate -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
    execute($c);
    
    $c=qq|ngdbuild -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
    execute($c);
    
    $c=qq|map -retime -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd" -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
    execute($c);

    $c=qq|htmlrpt -mrp $TOPNAME.mrp $TOPNAME|;
    execute($c);

    $fh = new FileHandle("<$TOPNAME"."_mrp.html");
    @a = <$fh>;
    $fh -> close;
    foreach (@a)
    {
	if(/FC_|HitInvert|ff_en_/)
	{
	    print "\n\n";
	    print "#################################################\n";
	    print "#        !!!Possible Placement Errors!!!        #\n";
	    print "#################################################\n\n";
	    
	    my $c="egrep 'WARNING.*hitBuf_|Channels/hit_buf_RNO|WARNING.*FC_|Channels/Channel200/SimAdderNo_FC|WARNING.*ff_en_|Channels/Channel200/ff_array_en_i_1_i'"." $TOPNAME"."_mrp.html";
	    system($c);
	    last;
	}
    }
}

if($par==1 || $all==1){
    system("rm $TOPNAME.ncd");
    #$c=qq|mpartrce -p "../$TOPNAME.p2t" -log "$TOPNAME.log" -o "$TOPNAME.rpt" -pr "$TOPNAME.prf" -tf "$TOPNAME.pt" "|.$TOPNAME.qq|_map.ncd" "$TOPNAME.ncd"|;
    #$c=qq|$lattice_path/ispfpga/bin/lin/multipar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t" "$tpmap.ncd" "$TOPNAME.ncd"|;
    if ($isMultiPar)
    {
	#$c=qq|par -m ../nodes_lxhadeb07.txt -n $nrNodes -stopzero -w -l 5 -t 1 -e 100 -exp parDisablePgroup=0:parUseNBR=1:parCDP=1:parPathBased=ON $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
	#$c=qq|par -m ../nodes_lxhadeb07.txt -n $nrNodes -stopzero -w -l 5 -i 6 -t 1 -c 0 -e 0 -exp parDisablePgroup=0:parUseNBR=1:parCDP=0:parCDR=0:parPathBased=ON $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
	$c=qq|par -m ../nodes_lxhadeb07.txt -n $nrNodes -w -l 5 -t 1 $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
	execute($c);
        # find and copy the .ncd file which has met the timing constraints
	$fh = new FileHandle("<$TOPNAME".".par");
	my @a = <$fh>;
	my $isSuccess = 0;
	$fh -> close;
	foreach (@a)
	{
	    my @line = split(' ', $_);
	    if(@line && ($line[2] =~ m/^[0-9]+$/) && ($line[3] =~ m/^[0-9]+$/))
	    {	
		if(($line[2] == 0) && ($line[3] == 0))
		{
		    print "Copying $line[0].ncd file to workdir\n";
		    my $c="cp $TOPNAME.dir/$line[0].ncd $TOPNAME.ncd";
		    system($c);
		    print "\n\n";
		    $isSuccess = 1;
		    last;
		}
	    }
	}
	
	if (!$isSuccess){
	    print "\n\n";
	    print "#################################################\n";
	    print "#           !!!PAR not succesfull!!!            #\n";
	    print "#################################################\n\n";
	    exit 129;
	}
    }
    else
    {
	#$c=qq|par -w -l 5 -i 6 -t 1 -c 0 -e 0 -exp parUseNBR=1:parCDP=0:parCDR=0:parPathBased=ON $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
	$c=qq|par -w -l 5 -t 1 $tpmap.ncd $TOPNAME.dir $TOPNAME.prf|;
	execute($c);
	my $c="cp $TOPNAME.dir/5_1.ncd $TOPNAME.ncd";
	system($c);
    }
    my $c="cat $TOPNAME.par";
    system($c);

}


if($timing==1 || $all==1){
    # IOR IO Timing Report
    $c=qq|iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);

    # TWR Timing Report
    $c=qq|trce -c -v 65 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);
    
    $c=qq|trce -hld -c -v 65 -o "$TOPNAME.twr.hold" "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);
    
    $c=qq|ltxt2ptxt $TOPNAME.ncd|;
    execute($c);
    
    my $c="cat $TOPNAME.par";
    system($c);

}

if($bitgen==1 || $all==1){
    $c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
    # $c=qq|$lattice_path/ispfpga/bin/lin/bitgen -w "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);
}

$c=qq|htmlrpt -mrp $TOPNAME.mrp -mtwr $TOPNAME.twr.hold -ptwr $TOPNAME.twr.setup $TOPNAME|;
execute($c);

$c=qq|firefox $TOPNAME.html|;
execute($c);

chdir "..";
exit;

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print "\n\ncommand to execute: $c \n";
    $r=system($c);
    if($r) {
	print "$!";
	if($op ne "do_not_exit") {
	    exit;
	}
    }
    return $r;
}
