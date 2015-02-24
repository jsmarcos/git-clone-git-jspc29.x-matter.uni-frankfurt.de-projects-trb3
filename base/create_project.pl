#!/usr/bin/env perl

# small straight-forward program to create a diamond project based on the standard trb3 project structure
# execute the script with the current project as working directory. if existing the current project may be altered.
# take care !


use strict;
use warnings;
use Data::Dumper;
use File::Copy;
use Term::ANSIColor;
use Cwd 'abs_path';

sub parsePRJ {
   my $input = shift;
   my $options = {};
   my @files = ();
   
   open FH, "<" , $input;
   while (my $line = <FH>) {
      chomp $line;
      if ($line =~ m/^\s*set_option -([^\s]+)\s+"?([^"]+)"?\s*$/) {
         $options->{$1} = $2;
      }
      
      if ($line =~ m/^\s*add_file -(vhdl|verilog|fpga_constraint)( -lib "?([^"\s]+)"?|)? "?([^"]+)"?\s*$/g) {
         push @files, [$3, $4];
      }
      

   }
   
   close FH;

   return ($options, \@files);
}

sub generateLDF {
   my $prj_file = shift;
   my $options = shift;
   my $files = shift;
   
   my $path = '../';
   
   open FH, ">", $prj_file;
      
   my $device = $options->{'part'} . $options->{'speed_grade'} . $options->{'package'};
   $device =~ s/_/\-/g;

   my $prj_title = $options->{'top_module'};
   $prj_title =~ s/trb3_(central|periph)_(.+)/$2/;

   my $def_impl = $options->{'top_module'};
   
   my $inclPath = $options->{'include_path'};
   $inclPath = '' if (!$inclPath);
   $inclPath =~ s/\{(.*)\}$/$1/;
   #$inclPath = abs_path($inclPath) if ($inclPath);

   print FH "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
   print FH "<BaliProject version=\"3.2\" title=\"$prj_title\" device=\"$device\" default_implementation=\"$def_impl\">\n";
   print FH "    <Options/>\n";
   print FH "    <Implementation title=\"$def_impl\" dir=\"$def_impl\" description=\"Automatically generated implemenatation\" default_strategy=\"Strategy1\">\n";
   print FH "        <Options def_top=\"$def_impl\">\n";
   print FH "            <Option name=\"include path\" value=\"$path$inclPath\" />\n" if ($inclPath);
   print FH "            <Option name=\"top\" value=\"$def_impl\" />\n";
   print FH "        </Options>\n";
      

   my $lpf_included = 0;
   
   for my $filer (@{$files}) {
      my $file = $filer->[1];
      my $lib = $filer->[0];
      my $suffix = $file;
      my $fpath = $path . $file;
      $suffix =~ s/^.*\.([^.]+)$/$1/g;
      if ("vhd" eq $suffix) {
         print FH "        <Source name=\"$fpath\" type=\"VHDL\" type_short=\"VHDL\"><Options " . ($lib? " lib=\"$lib\"":'') . " /></Source>\n";
      } elsif ("v" eq $suffix) {
         print FH "        <Source name=\"$fpath\" type=\"Verilog\" type_short=\"Verilog\"><Options " . ($lib? " lib=\"$lib\"":'') . " /></Source>\n";
      } elsif ("lpf" eq $suffix) {
         print FH "        <Source name=\"$fpath\" type=\"Logic Preference\" type_short=\"LPF\"><Options/></Source>\n";
         $lpf_included = 1;
      } elsif ("fdc" eq $suffix) {
         print FH "        <Source name=\"$fpath\" type=\"Synplify Design Constraints File\" type_short=\"SDC\"><Options/></Source>\n";
      } else {
         print "WARNING: Could not determine type of input file $file. Not included!\n";
      }
   }
   
   print FH "    </Implementation>\n";
   print FH "    <Strategy name=\"Strategy1\" file=\"auto_strat.sty\"/>\n";
   print FH "</BaliProject>\n";
   
   close FH;
   
   if (!$lpf_included) {
      print color "red bold";
      print "WARNING: No lpf included. You won't be able to load this project with diamond. Check your compile_constraints.pl script!\n";
      print color "reset";
   }
}

sub generateSTY {
   my $file = shift;
   open FH, ">", $file;
   print FH <<STY
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE strategy>
<Strategy version="1.0" predefined="0" description="" label="Strategy1">
    <Property name="PROP_BD_EdfHardtimer" value="Enable" time="0"/>
    <Property name="PROP_BD_EdfInBusNameConv" value="None" time="0"/>
    <Property name="PROP_BD_EdfInLibPath" value="" time="0"/>
    <Property name="PROP_BD_EdfInRemLoc" value="Off" time="0"/>
    <Property name="PROP_BD_EdfMemPath" value="" time="0"/>
    <Property name="PROP_BIT_AddressBitGen" value="Increment" time="0"/>
    <Property name="PROP_BIT_AllowReadBitGen" value="Disable" time="0"/>
    <Property name="PROP_BIT_CapReadBitGen" value="Disable" time="0"/>
    <Property name="PROP_BIT_ConModBitGen" value="Disable" time="0"/>
    <Property name="PROP_BIT_CreateBitFile" value="True" time="0"/>
    <Property name="PROP_BIT_DisRAMResBitGen" value="True" time="0"/>
    <Property name="PROP_BIT_DonePinBitGen" value="Pullup" time="0"/>
    <Property name="PROP_BIT_DoneSigBitGen" value="4" time="0"/>
    <Property name="PROP_BIT_EnIOBitGen" value="TriStateDuringReConfig" time="0"/>
    <Property name="PROP_BIT_EnIntOscBitGen" value="Disable" time="0"/>
    <Property name="PROP_BIT_ExtClockBitGen" value="False" time="0"/>
    <Property name="PROP_BIT_GSREnableBitGen" value="True" time="0"/>
    <Property name="PROP_BIT_GSRRelOnBitGen" value="DoneIn" time="0"/>
    <Property name="PROP_BIT_GranTimBitGen" value="0" time="0"/>
    <Property name="PROP_BIT_IOTriRelBitGen" value="Cycle 2" time="0"/>
    <Property name="PROP_BIT_JTAGEnableBitGen" value="False" time="0"/>
    <Property name="PROP_BIT_LenBitsBitGen" value="24" time="0"/>
    <Property name="PROP_BIT_MIFFileBitGen" value="" time="0"/>
    <Property name="PROP_BIT_NoHeader" value="False" time="0"/>
    <Property name="PROP_BIT_OutFormatBitGen" value="Bit File (Binary)" time="0"/>
    <Property name="PROP_BIT_OutFormatBitGen_REF" value="" time="0"/>
    <Property name="PROP_BIT_OutFormatPromGen" value="Intel Hex 32-bit" time="0"/>
    <Property name="PROP_BIT_ParityCheckBitGen" value="True" time="0"/>
    <Property name="PROP_BIT_RemZeroFramesBitGen" value="False" time="0"/>
    <Property name="PROP_BIT_RunDRCBitGen" value="True" time="0"/>
    <Property name="PROP_BIT_SearchPthBitGen" value="" time="0"/>
    <Property name="PROP_BIT_StartUpClkBitGen" value="Cclk" time="0"/>
    <Property name="PROP_BIT_SynchIOBitGen" value="True" time="0"/>
    <Property name="PROP_BIT_SysClockConBitGen" value="Reset" time="0"/>
    <Property name="PROP_BIT_SysConBitGen" value="Reset" time="0"/>
    <Property name="PROP_BIT_WaitStTimBitGen" value="5" time="0"/>
    <Property name="PROP_IOTIMING_AllSpeed" value="False" time="0"/>
    <Property name="PROP_LST_CarryChain" value="True" time="0"/>
    <Property name="PROP_LST_CarryChainLength" value="0" time="0"/>
    <Property name="PROP_LST_CmdLineArgs" value="" time="0"/>
    <Property name="PROP_LST_EBRUtil" value="100" time="0"/>
    <Property name="PROP_LST_EdfFrequency" value="200" time="0"/>
    <Property name="PROP_LST_EdfHardtimer" value="Enable" time="0"/>
    <Property name="PROP_LST_EdfInLibPath" value="" time="0"/>
    <Property name="PROP_LST_EdfInRemLoc" value="Off" time="0"/>
    <Property name="PROP_LST_EdfMemPath" value="" time="0"/>
    <Property name="PROP_LST_FSMEncodeStyle" value="Auto" time="0"/>
    <Property name="PROP_LST_ForceGSRInfer" value="Auto" time="0"/>
    <Property name="PROP_LST_IOInsertion" value="True" time="0"/>
    <Property name="PROP_LST_InterFileDump" value="False" time="0"/>
    <Property name="PROP_LST_MaxFanout" value="1000" time="0"/>
    <Property name="PROP_LST_MuxStyle" value="Auto" time="0"/>
    <Property name="PROP_LST_NumCriticalPaths" value="3" time="0"/>
    <Property name="PROP_LST_OptimizeGoal" value="Balanced" time="0"/>
    <Property name="PROP_LST_PrfOutput" value="False" time="0"/>
    <Property name="PROP_LST_PropagatConst" value="True" time="0"/>
    <Property name="PROP_LST_RAMStyle" value="Auto" time="0"/>
    <Property name="PROP_LST_ROMStyle" value="Auto" time="0"/>
    <Property name="PROP_LST_RemoveDupRegs" value="True" time="0"/>
    <Property name="PROP_LST_ResolvedMixedDrivers" value="False" time="0"/>
    <Property name="PROP_LST_ResourceShare" value="True" time="0"/>
    <Property name="PROP_LST_UseIOReg" value="True" time="0"/>
    <Property name="PROP_MAPSTA_AnalysisOption" value="Standard Setup and Hold Analysis" time="0"/>
    <Property name="PROP_MAPSTA_AutoTiming" value="True" time="0"/>
    <Property name="PROP_MAPSTA_CheckUnconstrainedConns" value="False" time="0"/>
    <Property name="PROP_MAPSTA_CheckUnconstrainedPaths" value="False" time="0"/>
    <Property name="PROP_MAPSTA_FullName" value="False" time="0"/>
    <Property name="PROP_MAPSTA_NumUnconstrainedPaths" value="0" time="0"/>
    <Property name="PROP_MAPSTA_ReportStyle" value="Verbose Timing Report" time="0"/>
    <Property name="PROP_MAPSTA_RouteEstAlogtithm" value="0" time="0"/>
    <Property name="PROP_MAPSTA_RptAsynTimLoop" value="False" time="0"/>
    <Property name="PROP_MAPSTA_WordCasePaths" value="1" time="0"/>
    <Property name="PROP_MAP_GuideFileMapDes" value="" time="0"/>
    <Property name="PROP_MAP_IgnorePreErr" value="True" time="0"/>
    <Property name="PROP_MAP_MAPIORegister" value="Auto" time="0"/>
    <Property name="PROP_MAP_MAPInferGSR" value="True" time="0"/>
    <Property name="PROP_MAP_MapModArgs" value="" time="0"/>
    <Property name="PROP_MAP_OvermapDevice" value="False" time="0"/>
    <Property name="PROP_MAP_PackLogMapDes" value="" time="0"/>
    <Property name="PROP_MAP_RegRetiming" value="False" time="0"/>
    <Property name="PROP_MAP_SigCrossRef" value="False" time="0"/>
    <Property name="PROP_MAP_SymCrossRef" value="False" time="0"/>
    <Property name="PROP_MAP_TimingDriven" value="False" time="0"/>
    <Property name="PROP_MAP_TimingDrivenNodeRep" value="False" time="0"/>
    <Property name="PROP_MAP_TimingDrivenPack" value="False" time="0"/>
    <Property name="PROP_PARSTA_AnalysisOption" value="Standard Setup and Hold Analysis" time="0"/>
    <Property name="PROP_PARSTA_AutoTiming" value="True" time="0"/>
    <Property name="PROP_PARSTA_CheckUnconstrainedConns" value="False" time="0"/>
    <Property name="PROP_PARSTA_CheckUnconstrainedPaths" value="False" time="0"/>
    <Property name="PROP_PARSTA_FullName" value="False" time="0"/>
    <Property name="PROP_PARSTA_NumUnconstrainedPaths" value="0" time="0"/>
    <Property name="PROP_PARSTA_ReportStyle" value="Verbose Timing Report" time="0"/>
    <Property name="PROP_PARSTA_RptAsynTimLoop" value="False" time="0"/>
    <Property name="PROP_PARSTA_SpeedForHoldAnalysis" value="m" time="0"/>
    <Property name="PROP_PARSTA_SpeedForSetupAnalysis" value="default" time="0"/>
    <Property name="PROP_PARSTA_WordCasePaths" value="10" time="0"/>
    <Property name="PROP_PAR_CrDlyStFileParDes" value="False" time="0"/>
    <Property name="PROP_PAR_DisableTDParDes" value="False" time="0"/>
    <Property name="PROP_PAR_EffortParDes" value="5" time="0"/>
    <Property name="PROP_PAR_NewRouteParDes" value="NBR" time="0"/>
    <Property name="PROP_PAR_PARClockSkew" value="Off" time="0"/>
    <Property name="PROP_PAR_PARModArgs" value="" time="0"/>
    <Property name="PROP_PAR_ParGuideRepMatch" value="False" time="0"/>
    <Property name="PROP_PAR_ParMatchFact" value="" time="0"/>
    <Property name="PROP_PAR_ParMultiNodeList" value="" time="0"/>
    <Property name="PROP_PAR_ParNCDGuideFile" value="" time="0"/>
    <Property name="PROP_PAR_ParRunPlaceOnly" value="False" time="0"/>
    <Property name="PROP_PAR_PlcIterParDes" value="1" time="0"/>
    <Property name="PROP_PAR_PlcStCostTblParDes" value="1" time="0"/>
    <Property name="PROP_PAR_PrefErrorOut" value="True" time="0"/>
    <Property name="PROP_PAR_RemoveDir" value="True" time="0"/>
    <Property name="PROP_PAR_RouteDlyRedParDes" value="0" time="0"/>
    <Property name="PROP_PAR_RoutePassParDes" value="6" time="0"/>
    <Property name="PROP_PAR_RouteResOptParDes" value="0" time="0"/>
    <Property name="PROP_PAR_RoutingCDP" value="Auto" time="0"/>
    <Property name="PROP_PAR_RoutingCDR" value="1" time="0"/>
    <Property name="PROP_PAR_RunParWithTrce" value="False" time="0"/>
    <Property name="PROP_PAR_SaveBestRsltParDes" value="1" time="0"/>
    <Property name="PROP_PAR_StopZero" value="False" time="0"/>
    <Property name="PROP_PAR_parHold" value="Off" time="0"/>
    <Property name="PROP_PAR_parPathBased" value="Off" time="0"/>
    <Property name="PROP_PRE_CmdLineArgs" value="" time="0"/>
    <Property name="PROP_PRE_EdfArrayBoundsCase" value="False" time="0"/>
    <Property name="PROP_PRE_EdfAutoResOfRam" value="False" time="0"/>
    <Property name="PROP_PRE_EdfClockDomainCross" value="False" time="0"/>
    <Property name="PROP_PRE_EdfDSPAcrossHie" value="False" time="0"/>
    <Property name="PROP_PRE_EdfFullCase" value="False" time="0"/>
    <Property name="PROP_PRE_EdfIgnoreRamRWCol" value="False" time="0"/>
    <Property name="PROP_PRE_EdfMissConstraint" value="False" time="0"/>
    <Property name="PROP_PRE_EdfNetFanout" value="True" time="0"/>
    <Property name="PROP_PRE_EdfParaCase" value="False" time="0"/>
    <Property name="PROP_PRE_EdfReencodeFSM" value="True" time="0"/>
    <Property name="PROP_PRE_EdfResSharing" value="True" time="0"/>
    <Property name="PROP_PRE_EdfTimingViolation" value="True" time="0"/>
    <Property name="PROP_PRE_EdfUseSafeFSM" value="False" time="0"/>
    <Property name="PROP_PRE_EdfVlog2001" value="True" time="0"/>
    <Property name="PROP_PRE_VSynComArea" value="False" time="0"/>
    <Property name="PROP_PRE_VSynCritcal" value="3" time="0"/>
    <Property name="PROP_PRE_VSynFSM" value="Auto" time="0"/>
    <Property name="PROP_PRE_VSynFreq" value="200" time="0"/>
    <Property name="PROP_PRE_VSynGSR" value="False" time="0"/>
    <Property name="PROP_PRE_VSynGatedClk" value="False" time="0"/>
    <Property name="PROP_PRE_VSynIOPad" value="False" time="0"/>
    <Property name="PROP_PRE_VSynOutNetForm" value="None" time="0"/>
    <Property name="PROP_PRE_VSynOutPref" value="False" time="0"/>
    <Property name="PROP_PRE_VSynRepClkFreq" value="True" time="0"/>
    <Property name="PROP_PRE_VSynRetime" value="True" time="0"/>
    <Property name="PROP_PRE_VSynTimSum" value="10" time="0"/>
    <Property name="PROP_PRE_VSynTransform" value="True" time="0"/>
    <Property name="PROP_PRE_VSyninpd" value="0" time="0"/>
    <Property name="PROP_PRE_VSynoutd" value="0" time="0"/>
    <Property name="PROP_SYN_CmdLineArgs" value="" time="0"/>
    <Property name="PROP_SYN_EdfAllowDUPMod" value="False" time="0"/>
    <Property name="PROP_SYN_EdfArea" value="False" time="0"/>
    <Property name="PROP_SYN_EdfArrangeVHDLFiles" value="True" time="0"/>
    <Property name="PROP_SYN_EdfDefEnumEncode" value="Default" time="0"/>
    <Property name="PROP_SYN_EdfFanout" value="100" time="0"/>
    <Property name="PROP_SYN_EdfFixGateClocks" value="3" time="0"/>
    <Property name="PROP_SYN_EdfFixGeneratedClocks" value="3" time="0"/>
    <Property name="PROP_SYN_EdfFrequency" value="200" time="0"/>
    <Property name="PROP_SYN_EdfGSR" value="False" time="0"/>
    <Property name="PROP_SYN_EdfInPrfWrite" value="False" time="0"/>
    <Property name="PROP_SYN_EdfInsertIO" value="False" time="0"/>
    <Property name="PROP_SYN_EdfNumCritPath" value="3" time="0"/>
    <Property name="PROP_SYN_EdfNumStartEnd" value="0" time="0"/>
    <Property name="PROP_SYN_EdfOutNetForm" value="None" time="0"/>
    <Property name="PROP_SYN_EdfPushTirstates" value="True" time="0"/>
    <Property name="PROP_SYN_EdfResSharing" value="True" time="0"/>
    <Property name="PROP_SYN_EdfRunRetiming" value="None" time="0"/>
    <Property name="PROP_SYN_EdfSymFSM" value="True" time="0"/>
    <Property name="PROP_SYN_EdfUnconsClk" value="True" time="0"/>
    <Property name="PROP_SYN_EdfVerilogInput" value="Verilog 2001" time="0"/>
    <Property name="PROP_SYN_ResolvedMixedDrivers" value="True" time="0"/>
    <Property name="PROP_SYN_UpdateCompilePtTimData" value="False" time="0"/>
    <Property name="PROP_TIM_MaxDelSimDes" value="" time="0"/>
    <Property name="PROP_TIM_MinSpeedGrade" value="False" time="0"/>
    <Property name="PROP_TIM_ModPreSimDes" value="" time="0"/>
    <Property name="PROP_TIM_NegStupHldTim" value="True" time="0"/>
    <Property name="PROP_TIM_TimSimGenPUR" value="True" time="0"/>
    <Property name="PROP_TIM_TimSimGenX" value="False" time="0"/>
    <Property name="PROP_TIM_TimSimHierSep" value="" time="0"/>
    <Property name="PROP_TIM_TrgtSpeedGrade" value="" time="0"/>
    <Property name="PROP_TIM_WriteVerboseNetlist" value="False" time="0"/>
</Strategy>
STY
;
   close FH;
}

# Search project file
   my @prj_files = glob('*.prj');
   die "No .prj found? Is the current working dir the project root?" if 0 == scalar @prj_files;
   die "Multiple prj-files found. This is not supported by this tool." if 1 < scalar @prj_files;
   my $input = shift @prj_files;

   print "NOTE: Use $input as input file\n";
  
# parse PRJ file
   my ($options, $files) = parsePRJ $input;
   
# create dir if necessary
   mkdir 'project' unless (-e 'project');

# create workdir
   if (-e './compile_constraints.pl') {
      my $workdir = 'project/' . $options->{'top_module'};
      my $lpffile = $workdir . '/' . $options->{'top_module'} . ".lpf";
      
      print "NOTE: execute ./compile_constraints.pl $workdir\n";
      system "./compile_constraints.pl $workdir";
      
      if(-e $lpffile) {
         rename $lpffile, 'project/' . $options->{'top_module'} . '.lpf';         
         push @$files, ['work', 'project/' . $options->{'top_module'} . '.lpf'];
      } else {
         print "WARNING: compile_constraints did not generate $lpffile. Please include the necessary contraint files manually\n";
      }
   } else {
      print "No ./compile_constraints.pl script found. Please make sure, the workdir contains all links and constraint-files\n";
   }
   
# generate ldf
   my $project_file = 'project/' . $options->{'top_module'} . '.ldf';
   if (-e $project_file) {move $project_file, $project_file . '.backup'};
   generateLDF $project_file, $options, $files;
   print "NOTE: LDF generated\n";

# generate strategy file  
   unless (-e 'project/auto_strat.sty') {
      generateSTY 'project/auto_strat.sty';
      print "NOTE: STY generated\n";
   }
   
   
   
print "\nNOTE: The version.vhd file is neither generated nor updated when building in diamond.\n";
print "\nUse command-line compilation to create a version file.\n";
print "\nDone. Execute \n> diamond $project_file\nto open the project\n";
