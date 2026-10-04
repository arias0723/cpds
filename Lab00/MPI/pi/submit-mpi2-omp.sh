#!/bin/bash

#SBATCH --job-name=submit-mpi2-omp.sh
#SBATCH -D .
#SBATCH --output=submit-mpi2-omp.sh.o%j
#SBATCH --error=submit-mpi2-omp.sh.e%j
#SBATCH --partition=execution
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=32

PROGRAM=pi_mpi_omp
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


#for i in `seq 1 32`;
for i in 1 2 4 8 12 16 20 24 28 32 ;
do
    echo "Launching 2 MPI processes. Number of threads per process:" $i
    export OMP_NUM_THREADS=$i
    #mpirun.mpich -np 2 -machinefile $TMPDIR/machines ./$PROGRAM $size
    mpirun.mpich -np 2 ./$PROGRAM $size
done   
