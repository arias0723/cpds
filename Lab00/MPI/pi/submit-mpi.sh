#!/bin/bash

#SBATCH --job-name=submit-mpi.sh
#SBATCH -D .
#SBATCH --output=submit-mpi.sh.o%j
#SBATCH --error=submit-mpi.sh.e%j
#SBATCH --partition=execution
## #SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12


PROGRAM=pi_mpi
size=1073741824

# Make sure that all binaries exist
make $PROGRAM 2>&1
if [[ $? -ne 0 ]]; then
    echo "Abort: Compilation error, parallel version"
    exit 0
fi

HOST=$(echo $HOSTNAME | cut -f 1 -d'.')

if [ ${HOST} = 'boada-11' ] || [ ${HOST} = 'boada-12' ] || [ ${HOST} == 'boada-13' ]
then
    echo "Use sbatch to execute this script"
    exit 0
fi


#mpirun.mpich -np 12 -machinefile $TMPDIR/machines ./$PROGRAM $size
mpirun.mpich -np 12 ./$PROGRAM $size

