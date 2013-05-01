#!/bin/bash
# source this file to setup your shell to use lattice toolchain
TDIR=`pwd`
cd /opt/lattice/diamond/2.01/bin/lin
export bindir=`pwd`
source ./diamond_env
cd $TDIR

