#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;
use Getopt::Long;
use Term::ANSIColor qw(:constants);
use Cwd;

###################################################################################
#Options for the script
my $help = "";
my $isMultiPar  = 0;   # set it to zero for single par run on the local machine
my $nrNodes     = 0;   # set it to one for single par run on the local machine
my $all         = 1;
my $syn         = 0;
my $map         = 0;
my $par         = 0;
my $timing      = 0;
my $bitgen      = 0;
my $con         = 0;
my $guidefile   = 0;
my $compile_all = 0;
my $design      = "";
my $result = GetOptions (
			 "h|help"     => \$help,
			 "m|mpar=i"   => \$nrNodes,
			 "a|all"      => \$all,
			 "c|con"      => \$con,
			 "s|syn"      => \$syn,
			 "mp|map"     => \$map,
			 "p|par"      => \$par,
			 "t|timing"   => \$timing,
			 "b|bitgen"   => \$bitgen,
			 "g|guide"    => \$guidefile,
			 "d|design=s" => \$design,
			);

if ($help) {
  print "Usage: compile_priph_gsi.de <OPTIONS><ARGUMENTS>\n\n";
  print "-h  --help\tPrints the usage manual.\n";
  print "-a  --all\tRun all compile script. By default the script is going to run the whole process.\n";
  print "-c  --con\tCompile constraints only.\n";
  print "-s  --syn\tRun synthesis part of the compile script.\n";
  print "-mp --map\tRun map part of the compile script.\n";
  print "-p  --par\tRun par part of the compile script.\n";
  print "-t  --timing\tRun timing analysis part of the compile script.\n";
  print "-b  --bitgen\tRun bit generation part of the compile script.\n";
  print "-m  --mpar\tSwitch for multi par. \"-m <number_of_nodes>\" (Default = off)\n";
  print "\t\tThe node list file name has to be edited in the script. (Default = nodes_lxhadeb07.txt)\n";
  print "-g  --guide\tDefine guide file for the guided placement & routing\n";
  print "-d  --design\tSelect the design to compile. Overrides the TOPNAME option in config_compile.pl\n";
  print "\t\t\"-d <DESIGN_TOPNAME>\"\n";
  print "\n";
  exit;
}

if ($nrNodes!=0) {
  $isMultiPar=1;
}
if ($con!=0 || $syn!=0 || $map!=0 || $par!=0 || $timing!=0 || $bitgen!=0) {
  $all=0;
}
###################################################################################

###################################################################################
#Settings for this project
my %config = do "config_compile.pl";


my $TOPNAME                      = $design || $config{TOPNAME};
my $project_path                 = $config{project_path};
my $lattice_path                 = $config{lattice_path};
my $synplify_path                = $config{synplify_path}; 
my $lm_license_file_for_synplify = $config{lm_license_file_for_synplify};
my $lm_license_file_for_par      = $config{lm_license_file_for_par};
my $synplify_command             = $config{synplify_command};

#my $synplify_locale_workaround   = "en_US\@UTF-8";
my $synplify_locale_workaround   = "C";
my $lattice_bin_path             = "$lattice_path/bin/lin64"; # note the lin/lin64 at the end, no isfgpa needed

my $include_TDC                  = $config{include_TDC} || 0;
my $include_GBE                  = $config{include_GBE} || 0;
my $include_CTS                  = $config{include_CTS} || 0;
my $include_HUB                  = $config{include_HUB} || 0;
my $twr_number_of_errors         = $config{twr_number_of_errors} || 10;
#my $pinout_file                  = $config{pinout_file} || $TOPNAME;
my $nodelist_file                = $config{nodelist_file};
my $par_options                  = $config{par_options};
###################################################################################


# source the standard lattice environment
$ENV{bindir}="$lattice_bin_path";

#open my $SOURCE, "bash -c '. $lattice_bin_path/diamond_env >& /dev/null; env'|" or
#  die "Can't fork: $!";
#while (<$SOURCE>) {
#  if (/^(.*)=(.*)/) {
#    $ENV{$1} = ${2} ;
#  }
#}
#close $SOURCE;


my %FPGA=(
    trb3_periph_32PinAddOn =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"32PinAddOn"},
    trb3_periph_ADA        =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"ADA_Addon"},
    trb3_periph_gpin       =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"gpin"},
    trb3_periph_padiwa     =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"wasa"},
    trb3_periph_hadesstart =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"hadesstart"},
    trb3_periph_hub        =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"hub"},
    trb3_central_cts       =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA1156", path=>"cts"},
    cbmtof                 =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA672",  path=>"cbmtof"},
#   trb3sc                 =>{family=>"LatticeECP3", device=>"LFE3-150EA", speed=>"8", package=>"FPBGA1156", path=>"../trb3sc/tdctemplate"},
#   dirich                 =>{family=>"ECP5UM",      device=>"LFE5UM-85F", speed=>"8", package=>"BG381C",    path=>"../dirich/dirich"},
    );

compile();


sub compile {
  unless (defined $FPGA{$TOPNAME}) {
    print RED, "Project $TOPNAME is not defined. Please edit the FPGA details in the compile script.\n", RESET;
    exit 129;
  }
  if ($design) {
    $project_path = $FPGA{$TOPNAME}{path};
  }

  $ENV{'PAR_DESIGN_NAME'}=$TOPNAME;
  $ENV{'SYNPLIFY'}=$synplify_path;
  $ENV{'LC_ALL'}=$synplify_locale_workaround;
  $ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
  $ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;
  $ENV{'SYNPLIFY_BINARY'}=$config{synplify_binary};

  my $FAMILYNAME= $FPGA{$TOPNAME}{family};
  my $DEVICENAME= $FPGA{$TOPNAME}{device};
  my $SPEEDGRADE= $FPGA{$TOPNAME}{speed};
  my $PACKAGE= $FPGA{$TOPNAME}{package};

  unless(-d "../$project_path") {
    print "Project path does not exit.\n";
    exit 129;
  }
  chdir "../$project_path";
  my $cwd = getcwd();
  my $WORKDIR = "workdir";
  unless(-d $WORKDIR) {
    mkdir $WORKDIR or die "can't create workdir '$WORKDIR': $!";
    system("cd $WORKDIR; ../../base/linkdesignfiles.sh; cd ..");
  }

  system("ln -sfT $lattice_path $WORKDIR/lattice-diamond");

  print GREEN, "Compiling $TOPNAME project in $cwd/$WORKDIR...\n\n", RESET;

  if ($con==1 || $all==1) {
    #create full lpf file
    my $pinout_file                  = $config{pinout_file} || $TOPNAME;
    print GREEN, "Generating constraints file...\n\n", RESET;
    system("cp ../base/$pinout_file.lpf $WORKDIR/$TOPNAME.lpf");

    if ($include_TDC && $include_CTS==0) {
      system("cat tdc_release/trbnet_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
      system("cat tdc_release/tdc_constraints_64.lpf >> $WORKDIR/$TOPNAME.lpf");
      system("cat tdc_release/unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
      system("cat unimportant_lines_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");

      #change the Ring buffer name in the constraints file according to the config.vhd
      my $fh = new FileHandle("<config.vhd");
      my @a = <$fh>;
      $fh -> close;
      my $ringbuffersize;
      my $chNumber;

      foreach (@a) {
	$ringbuffersize = $1 if $_ =~ /constant\s+RING_BUFFER_SIZE\s*:.*:=\s*(\d+);/;
	$chNumber = $1       if $_ =~ /constant\s+NUM_TDC_CHANNELS\s*:.*:=\s*(\d+);/;
      }
#      print "$ringbuffersize\n";
#      print "$chNumber\n";

      my @newline;
      $fh = new FileHandle("<$WORKDIR/$TOPNAME".".lpf");
      @a = <$fh>;
      $fh -> close;

      foreach (@a) {
	if ($ringbuffersize == 0) {
	  $_ =~ s/Buffer_128.The_Buffer/Buffer_32.The_Buffer/g;
	} elsif ($ringbuffersize == 1 || $ringbuffersize == 5) {
	  $_ =~ s/Buffer_128.The_Buffer/Buffer_64.The_Buffer/g;
	} elsif ($ringbuffersize == 2) {
	  $_ =~ s/Buffer_128.The_Buffer/Buffer_96.The_Buffer/g;
	} elsif ($ringbuffersize == 3 || $ringbuffersize == 7) {
	  $_ =~ s/Buffer_128.The_Buffer/Buffer_128.The_Buffer/g;
	} else {
	  print "unknown ringbuffer size... \n";
	  exit 129;
	}

	my $ch = 1;
	$ch = $1 if $_ =~ /.*[]BLKNAME|PROHIBIT].*[GEN_Channels|GEN_hit_mux]\.(\d+).*/;
	if ($ch >= $chNumber) {
#	  print "Channel $ch doesn't exist.\nold line $_";
	  $_ =~ s/$_/#$_/;
#	  print GREEN "new line $_\n\n\n", RESET;
	}

	push(@newline,$_);
      }
      $fh = new FileHandle(">$WORKDIR/$TOPNAME".".lpf");
      print $fh @newline;
      $fh -> close;
    }

    if ($include_GBE) {

    }
    if ($include_HUB) {
      system("cat trb3_periph_hub_constraints.lpf >> $WORKDIR/$TOPNAME.lpf");
    }
  }

  if ($include_CTS) {
    my $CbmNetPath                   = "../../cbmnet";
    my $config_vhd                   = 'config_mainz_a2.vhd';
    system("ln -f -s $config_vhd config.vhd") unless (-e "config.vhd");
    system("./compile_constraints.pl");
    system("cp ../base/mulipar_nodelist_example.txt $WORKDIR/nodelist.txt") unless (-e "$WORKDIR/nodelist.txt");
    symlink($CbmNetPath, '../cbmnet/cbmnet') unless (-e '../cbmnet/cbmnet');
  }

  if ($include_TDC) {
    #copy delay line to project folder
    system("rm $WORKDIR/Adder_304.ngo");
    system("ln -s ../../../tdc/base/cores/ecp3/TDC/Adder_304.ngo $WORKDIR/Adder_304.ngo");
  }

  if ($guidefile &&  -f "$TOPNAME.ncd") {
    system("cp $TOPNAME.ncd guidefile.ncd");
    $guidefile = " -g guidefile.ncd "
  } else {
    $guidefile = "";
  }


  #generate timestamp
  my $t=time;
  my $fh = new FileHandle(">$WORKDIR/version.vhd");
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
  if ($syn==1 || $all==1) {
    print GREEN, "Starting synthesis process...\n\n", RESET;
    $c="$synplify_path/bin/synplify_premier_dp -batch ../$TOPNAME.prj";
    $r=execute($c, "do_not_exit" );

    $fh = new FileHandle("<$TOPNAME".".srr");
    @a = <$fh>;
    $fh -> close;

    foreach (@a) {
      if (/\@E:/) {
	print "\n";
	$c = "cat $TOPNAME.srr | egrep --color \"\@E:\"";
	system($c);
	print RED, "ERROR in the log file $TOPNAME.srr Exiting...\n\n", RESET;
	exit 129;
      }
    }
  }

  $ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

  if ($map==1 || $all==1) {
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
    foreach (@a) {
      if (/WARNING/|$print) {
	if ((grep /WARNING - map: There are semantic errors in the preference file/, $_) & ($i == 1)) {
	  last;
	} elsif (grep /WARNING - map: There are semantic errors in the preference file/, $_) {
	  print RED, "There are errors in the constraints file. Better have a look...\n\n", RESET;
	  sleep(5);		# ERROR -> sleep is effective before the print
	  last;
	} elsif ($i == 1) {
	  print RED,"\n\n", RESET;
	  print RED,"#################################################\n", RESET;
	  print RED,"CONSTRAINTS ERRORS\n", RESET;
	  print RED,"#################################################\n\n", RESET;
	}
	$print=1;
	if (grep /WARNING.*UGROUP/, $_) {
	  print RED, $_, RESET;
	} elsif (grep /FC|hitBuf|ff_en/, $_) {
	  print YELLOW, $_, RESET;
	} else {
	  print $_;
	}
	$i++;
      }
    }
  }

  if ($par==1 || $all==1) {
    print GREEN, "Starting placement process...\n\n", RESET;

    system("rm $TOPNAME.ncd");
    if ($isMultiPar) {
      $c=qq|LC_ALL=en_US.UTF-8; par -m $nodelist_file -n $nrNodes -f $par_options $guidefile $tpmap.ncd $TOPNAME.dir $TOPNAME.prf;|;
      #    $c=qq|LC_ALL=en_US.UTF-8; par -m $nodelist_file -n $nrNodes -w -i 15 -l 5 -y -s 8 -t 1 -c 1 -e 2 -exp parCDP=1:parCDR=1:parPlcInLimit=0:parPlcInNeighborSize=1:parPathBased=ON:parHold=1:parHoldLimit=10000:paruseNBR=1 $tpmap.ncd $TOPNAME.dir $TOPNAME.prf;|;
      execute($c);

      # find and copy the .ncd file which has met the timing constraints
      $fh = new FileHandle("<$TOPNAME".".par");
      my @a = <$fh>;
      $fh -> close;
      my $isSuccess = 0;
      my $i=1;
      foreach (@a) {
	my @line = split(/\s+/, $_);

	if (@line && ($line[2] =~ m/^[0-9]+$/) && ($line[4] =~ m/^[0-9]+$/)) {
	  if (($line[2] == 0) && ($line[4] == 0)) {
	    print GREEN, "Copying $line[0].ncd file to $WORKDIR\n", RESET;
	    my $c="cp $TOPNAME.dir/$line[0].ncd $TOPNAME.ncd";
	    system($c);
	    print "\n\n";
	    $isSuccess = 1;
	    last;
	  }
	}
      }

      if (!$isSuccess) {
	print RED, "\n\n", RESET;
	print RED, "#################################################\n", RESET;
	print RED, "#           !!!PAR not successfull!!!            #\n", RESET;
	print RED, "#################################################\n\n", RESET;
	exit 129;
      }
    } else {
      $c=qq|par -f $par_options $guidefile $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
      #    $c=qq|par -w -i 15 -l 5 -y -s 8 -t 1 -c 1 -e 2 -exp parCDP=1:parCDR=1:parPlcInLimit=0:parPlcInNeighborSize=1:parPathBased=ON:parHold=1:parHoldLimit=10000:paruseNBR=1 $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
      execute($c);
      my $c="cp $TOPNAME.dir/5_1.ncd $TOPNAME.ncd";
      system($c);
    }
    my $c="cat $TOPNAME.par";
    system($c);
  }


  if ($timing==1 || $all==1) {
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

  if ($bitgen==1 || $all==1) {
    print GREEN, "Generating bit file...\n\n", RESET;

    $c=qq|ltxt2ptxt $TOPNAME.ncd|;
    execute($c);

    $c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf|;
    execute($c);
  }

  $c=qq|htmlrpt -mrp $TOPNAME.mrp -mtwr $TOPNAME.twr.hold -ptwr $TOPNAME.twr.setup $TOPNAME|;
  execute($c);

  if ($config{firefox_open}) {
    $c=qq|firefox $TOPNAME.html|;
    execute($c);
  }

  chdir "..";
}

sub execute {
  my ($c, $op) = @_;
  #print "option: $op \n";
  $op = "" if(!$op);
  $c = ". $lattice_bin_path/diamond_env; " . $c;
  print GREEN, "\n\ncommand to execute: $c \n", RESET;
  my $r=system($c);
  if ($r) {
    print "$!";
    if ($op ne "do_not_exit") {
      exit;
    }
  }
  return $r;
}
