#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;
use Getopt::Long;
use Term::ANSIColor qw(:constants);

my %config = do "config_compile.pl";


my $TOPNAME                      = $config{TOPNAME};
my $lattice_path                 = $config{lattice_path};
my $synplify_path                = $config{synplify_path}; 
my $lm_license_file_for_synplify = $config{lm_license_file_for_synplify};
my $lm_license_file_for_par      = $config{lm_license_file_for_par};
my $synplify_command             = $config{synplify_command};

my $synplify_locale_workaround   = "en_US\@UTF-8";
my $lattice_bin_path             = "$lattice_path/bin/lin64"; # note the lin/lin64 at the end, no isfgpa needed

my $include_TDC                  = $config{include_TDC} || 0;
my $include_GBE                  = $config{include_GBE} || 0;
my $twr_number_of_errors         = $config{twr_number_of_errors} || 10;


###################################################################################
#Settings for this project

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
    print "-a  --all\tRun all compile script. By default the script is going to run the whole process.\n";
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
$ENV{bindir}="$lattice_bin_path";
open my $SOURCE, "bash -c '. $lattice_bin_path/diamond_env >& /dev/null; env'|" or
  die "Can't fork: $!";
while (<$SOURCE>) {
  if (/^(.*)=(.*)/) {
    $ENV{$1} = ${2} ;
  }
}
close $SOURCE;



$ENV{'PAR_DESIGN_NAME'}=$TOPNAME;
$ENV{'SYNPLIFY'}=$synplify_path;
$ENV{'LC_ALL'}="en_US\@UTF-8";
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
print GREEN, "Generating constraints file...\n\n", RESET;
system("cp ../base/$TOPNAME.lpf $WORKDIR/$TOPNAME.lpf");

if($include_TDC) {
  system("cat tdc_release/trbnet_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
  system("cat tdc_release/tdc_constraints_64.lpf >> $WORKDIR/$TOPNAME.lpf");
  system("cat tdc_release/unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
  system("cat unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
}
if($include_GBE) {

}

if($include_TDC) {
  #copy delay line to project folder
  system("rm $WORKDIR/Adder_304.ngo");
  system("ln -s ../../../tdc/base/cores/ecp3/TDC/Adder_304.ngo $WORKDIR/Adder_304.ngo");
}

system("cd workdir; ../../base/linkdesignfiles.sh; cd ..");

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

chdir $WORKDIR;
if($syn==1 || $all==1){
    system("rm $TOPNAME.edf");
    print GREEN, "Starting synthesis process...\n\n", RESET;
    $c="$synplify_path/bin/synplify_premier_dp -batch ../$TOPNAME.prj";
    $r=execute($c, "do_not_exit" );

    $fh = new FileHandle("<$TOPNAME".".srr");
    @a = <$fh>;
    $fh -> close;
    
    foreach (@a)
    {
	if(/\@E:/)
	{
	    print "\n";
	    $c="cat $TOPNAME.srr | egrep --color \"\@E:\"";
	    system($c);
	    print RED, "ERROR in the log file $TOPNAME.srr Exiting...\n\n", RESET;
	    exit 129;
	}
    }
}



$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

if($map==1 || $all==1){
    print GREEN, "Starting mapping process...\n\n", RESET;

    $c=qq|edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
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
    my $i=1;
    my $print=0;
    foreach (@a)
    {
	if(/WARNING/|$print)
	{
	    if((grep /WARNING - map: There are semantic errors in the preference file/, $_) & ($i == 1))
	    {
		last;
	    }
	    elsif(grep /WARNING - map: There are semantic errors in the preference file/, $_)
	    {
		print RED, "There are errors in the constraints file. Better have a look...\n\n", RESET;
		sleep(5); # ERROR -> sleep is effective before the print
		last;
	    }
	    elsif ($i == 1)
	    {
		print RED,"\n\n", RESET;
		print RED,"#################################################\n", RESET;
		print RED,"CONSTRAINTS ERRORS\n", RESET;
		print RED,"#################################################\n\n", RESET;
	    }
	    $print=1;
	    if(grep /WARNING.*UGROUP/, $_)
	    {
		print RED, $_, RESET;
	    }
	    elsif(grep /FC|hitBuf|ff_en/, $_)
	    {
		print YELLOW, $_, RESET;
	    }
	    else
	    {
		print $_;
	    }
	    $i++;
	}
    }
}

if($par==1 || $all==1){
    print GREEN, "Starting placement process...\n\n", RESET;

    system("rm $TOPNAME.ncd");
    if ($isMultiPar)
    {
	$c=qq|LC_ALL=en_US.UTF-8; par -m ../nodes_lxhadeb07.txt -n $nrNodes -w -i 15 -l 5 -y -s 8 -t 1 -c 1 -e 2 -exp parCDP=1:parCDR=1:parPlcInLimit=0:parPlcInNeighborSize=1:parPathBased=ON:parHold=1:parHoldLimit=10000:paruseNBR=1 $tpmap.ncd $TOPNAME.dir $TOPNAME.prf;|;
	execute($c);

        # find and copy the .ncd file which has met the timing constraints
	$fh = new FileHandle("<$TOPNAME".".par");
	my @a = <$fh>;
	my $isSuccess = 0;
	$fh -> close;
	my $i=1;
	foreach (@a)
	{
	    my @line = split(/\s+/, $_);

	    if(@line && ($line[2] =~ m/^[0-9]+$/) && ($line[4] =~ m/^[0-9]+$/))
	    {	
	    	if(($line[2] == 0) && ($line[4] == 0))
	    	{
	    	    print GREEN, "Copying $line[0].ncd file to workdir\n", RESET;
	    	    my $c="cp $TOPNAME.dir/$line[0].ncd $TOPNAME.ncd";
	    	    system($c);
	    	    print "\n\n";
	    	    $isSuccess = 1;
	    	    last;
	    	}
	    }
	}
	
	if (!$isSuccess){
	    print RED, "\n\n", RESET;
	    print RED, "#################################################\n", RESET;
	    print RED, "#           !!!PAR not successfull!!!            #\n", RESET;
	    print RED, "#################################################\n\n", RESET;
	    exit 129;
	}
    }
    else
    {
	$c=qq|par -w -i 15 -l 5 -y -s 8 -t 1 -c 1 -e 2 -exp parCDP=1:parCDR=1:parPlcInLimit=0:parPlcInNeighborSize=1:parPathBased=ON:parHold=1:parHoldLimit=10000:paruseNBR=1 $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
	execute($c);
	my $c="cp $TOPNAME.dir/5_1.ncd $TOPNAME.ncd";
	system($c);
    }
    my $c="cat $TOPNAME.par";
    system($c);

}


if($timing==1 || $all==1){
    print GREEN, "Generating timing report...\n\n", RESET;

    # IOR IO Timing Report
    $c=qq|iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);

    # TWR Timing Report
    $c=qq|trce -c -v $twr_number_of_errors -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);
    
    $c=qq|trce -hld -c -v $twr_number_of_errors -o "$TOPNAME.twr.hold" "$TOPNAME.ncd" "$TOPNAME.prf"|;
    execute($c);

    my $c="cat $TOPNAME.par";
    system($c);
}

if($bitgen==1 || $all==1){
    print GREEN, "Generating bit file...\n\n", RESET;

    $c=qq|ltxt2ptxt $TOPNAME.ncd|;
    execute($c);

    $c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
    execute($c);
}

$c=qq|htmlrpt -mrp $TOPNAME.mrp -mtwr $TOPNAME.twr.hold -ptwr $TOPNAME.twr.setup $TOPNAME|;
execute($c);

if($config{firefox_open}) {
  $c=qq|firefox $TOPNAME.html|;
  execute($c);
}

chdir "..";
exit;

sub execute {
    my ($c, $op) = @_;
    #print "option: $op \n";
    $op = "" if(!$op);
    print GREEN, "\n\ncommand to execute: $c \n", RESET;
    $r=system($c);
    if($r) {
	print "$!";
	if($op ne "do_not_exit") {
	    exit;
	}
    }
    return $r;
}
