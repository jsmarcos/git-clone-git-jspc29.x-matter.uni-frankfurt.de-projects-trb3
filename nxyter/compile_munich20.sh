#!/bin/sh

. /usr/local/opt/lattice_diamond/diamond/2.0/bin/lin/diamond_env

exec ./compile_munich20.pl

grep 'Error: The following path exceeds requirements by' ./workdir/trb3_periph.twr.setup 
grep 'Error:' ./workdir/trb3_periph.twr.hold
grep 'potential circuit loops' ./workdir/*

echo "Script DONE!"

