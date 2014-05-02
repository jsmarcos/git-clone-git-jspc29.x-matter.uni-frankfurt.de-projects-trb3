#!/bin/sh

. /usr/local/opt/lattice_diamond/diamond/2.1/bin/lin64/diamond_env

./compile_munich21.pl

#grep -q 'Error:' ./workdir/trb3_periph.twr.setup && echo "Timing Errors found in trb3_periph.twr.setup"
grep 'Error: The following path exceeds requirements by' ./workdir/trb3_periph.twr.setup 
grep 'Error:' ./workdir/trb3_periph.twr.hold
grep 'potential circuit loops' ./workdir/*

echo "Script DONE!"
