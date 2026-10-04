#!/bin/bash

#SBATCH --job-name=submit-omp.sh
#SBATCH -D .
#SBATCH --output=submit-omp.sh.o%j
#SBATCH --error=submit-omp.sh.e%j
#SBATCH --partition=execution

PROG=pi_omp
make $PROG

size=1000000000

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi

#export OMP_NUM_THREADS=1
export OMP_NUM_THREADS=8

/usr/bin/time -o time-${PROG}-${OMP_NUM_THREADS}-${HOST} ./$PROG $size
