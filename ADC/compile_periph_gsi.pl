#!/usr/bin/perl
use Data::Dumper;
use warnings;
use strict;
use FileHandle;



###################################################################################
#Settings for this project
my $TOPNAME                      = "trb3_periph_adc"; #Name of top-level entity
my $lattice_path                 = '/opt/lattice/diamond/3.2_x64';
my $lattice_bin_path             = "$lattice_path/bin/lin64"; # note the lin/lin64 at the end, no isfgpa needed
my $synplify_path                = '/opt/synplicity/I-2013.09-SP1';
my $lm_license_file_for_synplify = '27000@lxcad01.gsi.de';
my $lm_license_file_for_par      = '1702@hadeb05.gsi.de';
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
$ENV{'SYN_DISABLE_RAINBOW_DONGLE'}=1;
$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_synplify;
my $tpmap = $TOPNAME . "_map" ;


my $FAMILYNAME="LatticeECP3";
my $DEVICENAME="LFE3-150EA";
my $PACKAGE="FPBGA672";
my $SPEEDGRADE="8";

# also links the design files and creates the workdir if necessary
system ("./compile_constraints.pl");
system ("../base/make_version_vhd.pl");


my $c="$synplify_path/bin/synplify_premier_dp -batch $TOPNAME.prj";
my $r;
$r=execute($c, "do_not_exit" );
checksrr();

$ENV{'LM_LICENSE_FILE'}=$lm_license_file_for_par;

$c=qq|edif2ngd -path "../" -path "." -l $FAMILYNAME -d $DEVICENAME "$TOPNAME.edf" "$TOPNAME.ngo" |;
execute($c);

$c=qq|edfupdate   -t "$TOPNAME.tcy" -w "$TOPNAME.ngo" -m "$TOPNAME.ngo" "$TOPNAME.ngx"|;
execute($c);

$c=qq|ngdbuild  -a $FAMILYNAME -d $DEVICENAME -p "$lattice_path/ispfpga/ep5c00/data" -dt "$TOPNAME.ngo" "$TOPNAME.ngd"|;
execute($c);

system("rm $tpmap.ncd");
$c=qq|map -td_pack -hier -retime EFFORT=6 -split_node -a $FAMILYNAME -p $DEVICENAME -t $PACKAGE -s $SPEEDGRADE "$TOPNAME.ngd" -pr "$TOPNAME.prf" -o "$tpmap.ncd"  -mp "$TOPNAME.mrp" "$TOPNAME.lpf"|;
execute($c);

system("rm $TOPNAME.ncd");

$c=qq|mpartrce -p "../$TOPNAME.p2t" -f "../$TOPNAME.p3t" -tf "$TOPNAME.pt" "$tpmap.ncd" "$TOPNAME.ncd"|;
#$c=qq|mpar -pr "$TOPNAME.prf" -o "mpar_$TOPNAME.rpt" -log "mpar_$TOPNAME.log" -p "../$TOPNAME.p2t"  "$tpmap.ncd" "$TOPNAME.ncd"|;
#$c=qq|par -w -l 5 -i 6 -t 5 -c 0 -e 0 -exp parUseNBR=1:parCDP=0:parCDR=0:parPathBased=OFF $tpmap.ncd $TOPNAME.ncd $TOPNAME.prf|;
execute($c);

$c=qq|ltxt2ptxt $TOPNAME.ncd|;
execute($c);

$c=qq|bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No  $TOPNAME.ncd $TOPNAME.bit $TOPNAME.prf &|;
# $c=qq|bitgen  -w "$TOPNAME.ncd"  "$TOPNAME.prf"|;
execute($c);

# TWR Timing Report
$c=qq|trce -c -v 15 -o "$TOPNAME.twr.setup" "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

$c=qq|trce -hld -c -v 5 -o "$TOPNAME.twr.hold"  "$TOPNAME.ncd" "$TOPNAME.prf"|;
execute($c);

#IOR IO Timing Report
$c=qq|iotiming -s "$TOPNAME.ncd" "$TOPNAME.prf"|;
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


sub checksrr {
  chdir "workdir";
  my $fh = new FileHandle("<$TOPNAME".".srr");
  my @a = <$fh>;
  $fh -> close;
  foreach (@a) {
    if(/\@E:/)  {
      print "\n";
      $c="cat $TOPNAME.srr | grep \"\@E\"";
      system($c);
      print "\n\n";
      exit 129;
      }
    }
  }
