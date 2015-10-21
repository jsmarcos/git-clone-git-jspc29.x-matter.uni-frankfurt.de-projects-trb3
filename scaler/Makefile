TARGET=trb3_periph_scaler
FAMILYNAME=LatticeECP3
DEVICENAME=LFE3-150EA
PACKAGE=FPBGA672
SPEEDGRADE=8

TIMESTAMP=$(shell date '+%s')
VERSION=$(shell cat version-major-minor.txt)

# ------------------------------------------------------------------------------------

.PHONY: all
all: workdir/$(TARGET).bit

.PHONY: clean
clean:
	rm -rf workdir/* 
	rm -f workdir/.[a-z,A-Z]*

.PHONY: distclean
distclean:
	rm -rf workdir/* 

.PHONY: checkenv
checkenv:
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "--------------- Check Lattice Environment              ---------------"
	@echo "----------------------------------------------------------------------"
	@if [ -n "${LM_LICENSE_FILE}" ] ; then \
          echo "Lattice Environment is: ${LM_LICENSE_FILE}"; \
         else \
          echo "------> Lattice Environment is not set"; \
          exit 1; \
         fi

# ------------------------------------------------------------------------------------

# Bitgen
workdir/$(TARGET).bit: workdir/$(TARGET).ncd
	@$(MAKE) report

	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Bitgen ------------------------------------------------"
	@echo "----------------------------------------------------------------------"
	cd workdir && \
	  bitgen -w -g CfgMode:Disable -g RamCfg:Reset -g ES:No $(TARGET).ncd \
                 $(TARGET).bit $(TARGET).prf

	@$(MAKE) error	

# Place and Route (multipar)
workdir/$(TARGET).ncd: workdir/$(TARGET)_map.ncd
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Place and Route (multipar)-----------------------------"
	@echo "----------------------------------------------------------------------"
	rm -rf workdir/$(TARGET).ncd workdir/$(TARGET).dir
	cd workdir && \
	 par -f ../$(TARGET).p2t $(TARGET)_map.ncd $(TARGET).dir $(TARGET).prf
	cp workdir/$(TARGET).dir/*.ncd workdir/$(TARGET).ncd
	#
	# Multipar geht gerade nicht
	#par $(TARGET)_map.ncd $(TARGET).prf
	#mv $(TARGET).prf.ncd $(TARGET).ncd
	# par -f ../$(TARGET).p2t $(TARGET)_map.ncd $(TARGET).dir $(TARGET).prf
	#cp workdir/$(TARGET).dir/*.ncd workdir/$(TARGET).ncd


# Mapper
workdir/$(TARGET)_map.ncd: workdir/$(TARGET).ngd $(TARGET).lpf
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Mapper ------------------------------------------------"
	@echo "----------------------------------------------------------------------"
	cd workdir && \
	 map  -retime -split_node -a $(FAMILYNAME) -p $(DEVICENAME) \
	      -t $(PACKAGE) -s $(SPEEDGRADE) $(TARGET).ngd  -pr $(TARGET).prf \
	      -o $(TARGET)_map.ncd  -mp $(TARGET).mrp $(TARGET).lpf

# EDIF 2 NGD
workdir/$(TARGET).ngd: workdir/$(TARGET).edf
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- EDIF 2 NGD---------------------------------------------"
	@echo "----------------------------------------------------------------------"
	cd workdir && \
	 edif2ngd -l $(FAMILYNAME) -d $(DEVICENAME) \$(TARGET).edf $(TARGET).ngo
	cd workdir && \
	 edfupdate -t $(TARGET).tcy -w $(TARGET).ngo -m $(TARGET).ngo \
	           $(TARGET).ngx
	cd workdir && \
	 ngdbuild -a $(FAMILYNAME) -d $(DEVICENAME) -dt $(TARGET).ngo \
	          $(TARGET).ngd

# VHDL / Verilog Compiler
workdir/$(TARGET).edf:
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "--------------- Build All --------------------------------------------"
	@echo "----------------------------------------------------------------------"
	@$(MAKE) checkenv
	@$(MAKE) workdir
	@$(MAKE) version

	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "--------------- VHDL Compiler ----------------------------------------"
	@echo "----------------------------------------------------------------------"
	synpwrap -prj $(TARGET).prj || \
	 (grep "@E" workdir/$(TARGET).srr && exit 2)

# ------------------------------------------------------------------------------------

# Version File
.PHONY: version
version:
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "--------------- Version File -----------------------------------------"
	@echo "----------------------------------------------------------------------"
	@echo "-- attention, automatically generated. Don't change by hand." >  version.vhd
	@echo "library ieee;"                                                >> version.vhd
	@echo "USE IEEE.std_logic_1164.ALL;"                                 >> version.vhd
	@echo "USE IEEE.std_logic_ARITH.ALL;"                                >> version.vhd 
	@echo "USE IEEE.std_logic_UNSIGNED.ALL;"                             >> version.vhd
	@echo "use ieee.numeric_std.all;"	                             >> version.vhd
	@echo ""                                                             >> version.vhd
	@echo "package version is"                                           >> version.vhd
	@echo ""                                                             >> version.vhd
	@echo "   constant VERSION_NUMBER_TIME  : integer := $(TIMESTAMP);"  >> version.vhd
	@echo -n "   constant VERSION_NUMBER       : integer := "            >> version.vhd
	@echo "to_integer(x\"$(VERSION)\");"                                 >> version.vhd
	@echo ""                                                             >> version.vhd
	@echo "end package version;"                                         >> version.vhd
	@cat version.vhd

# Setup Workdir
.PHONY: workdir 
workdir:
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Setup Workdir -----------------------------------------"
	@echo "----------------------------------------------------------------------"
	mkdir -p workdir
	cd workdir && ../../base/linkdesignfiles.sh
	cp $(TARGET).lpf workdir/$(TARGET).lpf
	cat $(TARGET)_constraints.lpf >> workdir/$(TARGET).lpf
	cp nodelist.txt workdir/ 

# Timing Report
.PHONY: report
report: 
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Timing Report -----------------------------------------"
	@echo "----------------------------------------------------------------------"
	cd workdir && \
         iotiming -s $(TARGET).ncd $(TARGET).prf
	cd workdir && \
         trce -c -v 15 -o $(TARGET).twr.setup $(TARGET).ncd $(TARGET).prf
	cd workdir && \
	 trce -hld -c -v 5 -o $(TARGET).twr.hold  $(TARGET).ncd $(TARGET).prf
	cd workdir && \
         ltxt2ptxt $(TARGET).ncd

# Error Check
.PHONY: error
error: 
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "-------------- Error Check -----------------------------------------"
	@echo "----------------------------------------------------------------------"
	@echo -e "\n$(TARGET).mrp:"	
	@grep "Semantic error" ./workdir/$(TARGET).mrp || exit 0

	@echo -e "\n$(TARGET).twr.setup:"
	@grep 'Error: The following path exceeds requirements by' ./workdir/$(TARGET).twr.setup \
               || exit 0

	@echo -e "\n$(TARGET).twr.hold:"
	@grep "Error:" ./workdir/$(TARGET).twr.hold || exit 0

	@echo -e "\nCircuit Loops:"	
	@grep "potential circuit loops" ./workdir/* || exit 0

# ------------------------------------------------------------------------------------
# Extract dependencies from project file
#.PHONY: $(TARGET).dep
#$(TARGET).dep:
#	@echo ""
#	@echo "----------------------------------------------------------------------"
#	@echo "--------------- Extract Dependencies from Project File ---------------"
#	@echo "----------------------------------------------------------------------"
#	grep 'add_file' $(TARGET).prj | grep -v '#' | sed -r 's/^.*"(.*)"$$/\1/' \
#	| xargs echo "workdir/$(TARGET).edf:" > $(TARGET).dep
#	grep 'map_dep' $(TARGET).prj | grep -v '#' | sed -r 's/^.*"(.*)"$$/\1/' \
#	| xargs echo "workdir/$(TARGET)_map.ncd:" >> $(TARGET).dep
#
#-include $(TARGET).dep

