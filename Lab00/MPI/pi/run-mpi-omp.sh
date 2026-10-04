#!/bin/bash

USAGE="\n USAGE: run-omp.sh PROG size n_th\n
        PROG   -> omp program name\n
        size   -> size of the problem\n
	n_th   -> number of processes\n"

if (test $# -lt 3 || test $# -gt 3)
then
	echo -e $USAGE
        exit 0
fi

for i in `seq 1 4`;
        do
                echo "Number of threads:",$i
                export OMP_NUM_THREADS=$i
                mpirun.mpich -np $3 ./$1 $2
        done   
