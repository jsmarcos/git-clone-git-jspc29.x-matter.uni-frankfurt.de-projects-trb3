#!/bin/bash
#These files should be linked in your workdir for new projects
#they have to be in the directory were all the reports and bitfiles end up!
#usually ./workdir (command line script) or ./$PROJECTNAME (Diamond)

#it is assumed, that pwd is the first dir in the designs directory, e.g.
#trb3/DESIGN/workdir. If this is not the case pass as first parameter a
#path suffix to get to this level. For instance if you're in
#trb3/DESIGN/project/TOPNAME call "../../../base/linkdesignfiles.sh .."

if [ $1 ]
then
   prefix=$1
else
   prefix="."
fi

ln -sf $prefix/../../../trb3/base/cores/sgmii_gbe_pcs35.ngo
ln -sf $prefix/../../../trb3/base/cores/tsmac35.ngo
ln -sf $prefix/../../../trb3/base/cores/pmi_ram_dpEbnonessdn208256208256.ngo
ln -sf $prefix/../../../trb3/base/cores/pmi_ram_dpEbnonessdn96649664.ngo
#ln -sf $prefix/../../../trbnet/gbe2_ecp3/ipcores_ecp3/serdes_gbe_0ch/serdes_gbe_0ch.txt
#ln -sf $prefix/../../../trbnet/gbe2_ecp3/ipcores_ecp3/serdes_ch4.txt
ln -sf $prefix/../../../trbnet/gbe_trb/media/serdes_gbe_4ch.txt

ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/sfp_0_200_int.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/sfp_1_200_int.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/sfp_1_125_int.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/sfp_0_200_ctc.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_onboard_full.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_sync_0.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_sync_3.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_sync_4.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_sync_4_slave3.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_sync_125_0.txt
ln -sf $prefix/../../../trbnet/media_interfaces/ecp3_sfp/serdes_full_ctc.txt

#ln -s ../../../trbnet/gbe2_ecp3/ipcores_ecp3/sgmii_gbe_pcs36.ngo
#ln -s ../../../trbnet/gbe2_ecp3/ipcores_ecp3/tsmac36.ngo
#ln -s ../../../trbnet/gbe2_ecp3/ipcores_ecp3/pmi_ram_dpEbnonessdn208256208256p13732cfe.ngo
#ln -s ../../../trbnet/gbe2_ecp3/ipcores_ecp3/pmi_ram_dpEbnonessdn96649664p132b6db5.ngo
