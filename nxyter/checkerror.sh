#!/bin/sh

echo "trb3_periph.twr.setup"
grep 'Error: The following path exceeds requirements by' ./workdir/trb3_periph.twr.setup 
echo "trb3_periph.twr.hold"
grep 'Error:' ./workdir/trb3_periph.twr.hold
grep 'potential circuit loops' ./workdir/*
