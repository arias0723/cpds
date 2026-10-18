#!/bin/bash
echo Compiling codes
mpicc -o sendrecv sendrecv.c 
mpicc -o compare_bcast compare_bcast.c
mpicc -o probe probe.c
mpicc -o maxloc maxloc.c
mpicc -o ownreductionop ownreductionop.c
echo Compilation finished
